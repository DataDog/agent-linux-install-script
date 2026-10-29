import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


TEST_DIR = Path(__file__).resolve().parent
REPO_DIR = TEST_DIR.parent


class SsiStrictModeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run([sys.executable, str(TEST_DIR / "extract_functions.py")], check=True)
        template = (REPO_DIR / "install_script.sh.template").read_text()
        cls.install_step = template.split("# Install APM SSI if needed\n", 1)[1].split(
            "# Creating or overriding the install information", 1
        )[0]
        cls.apm_configuration = template.split(
            "DD_APM_INSTRUMENTATION_ENABLED_DOCKER_PLACEHOLDER\n", 1
        )[1].split("# Complete initialization", 1)[0]
        cls.agent_version_validation = 'if [ -n "$DD_APM_INSTRUMENTATION_ENABLED" ]' + template.split(
            'if [ -n "$DD_APM_INSTRUMENTATION_ENABLED" ]', 1
        )[1].split('\nif [ "$DISTRIBUTION" == "Darwin" ]', 1)[0]

    def run_install(self, strict=None, enabled=None, download_status=0,
                    installer_status=0, downloader="curl", missing_downloaders=False,
                    partial_download=False, agent_major_version="7"):
        with tempfile.TemporaryDirectory() as temporary:
            mock_bin = Path(temporary)
            mock = mock_bin / downloader
            mock.write_text(
                '#!/bin/bash\n'
                'if [ "$SSI_TEST_DOWNLOAD_STATUS" != 0 ] && [ "$SSI_TEST_PARTIAL_DOWNLOAD" != true ]; then\n'
                '  exit "$SSI_TEST_DOWNLOAD_STATUS"\n'
                'fi\n'
                'printf \'%s\\n\' \'echo SSI_SCRIPT_EXECUTED\' '
                '\'echo "SSI_MODE:$DD_APM_INSTRUMENTATION_ENABLED"\' '
                '\'exit "$SSI_TEST_INSTALLER_STATUS"\'\n'
                'exit "$SSI_TEST_DOWNLOAD_STATUS"\n'
            )
            mock.chmod(0o755)
            env = {key: value for key, value in os.environ.items() if not key.startswith("DD_")}
            env.update(
                PATH=str(mock_bin) + os.pathsep + env["PATH"],
                DD_SITE="datadoghq.com",
                SSI_TEST_AGENT_MAJOR_VERSION=agent_major_version,
                SSI_TEST_DOWNLOAD_STATUS=str(download_status),
                SSI_TEST_INSTALLER_STATUS=str(installer_status),
                SSI_TEST_PARTIAL_DOWNLOAD="true" if partial_download else "false",
            )
            if strict is not None:
                env["DD_APM_INSTRUMENTATION_STRICT"] = strict
            if enabled is not None:
                env["DD_APM_INSTRUMENTATION_ENABLED"] = enabled
            script = """
source "$1"
GENERAL_ERROR_CODE=1
INVALID_PARAMETERS_CODE=6
sudo_cmd=""
agent_version_custom=""
agent_major_version="$SSI_TEST_AGENT_MAJOR_VERSION"
report_telemetry() {
  echo "TELEMETRY:$ERROR_CODE:$ERROR_MESSAGE"
}
"""
            if downloader == "wget" or missing_downloaders:
                script += """
command() {
  if [ "$1" = "-v" ] && [ "$2" = "curl" ]; then
    return 1
  fi
"""
                if missing_downloaders:
                    script += """
  if [ "$1" = "-v" ] && [ "$2" = "wget" ]; then
    return 1
  fi
"""
                script += '  builtin command "$@"\n}\n'
            script += self.apm_configuration + self.agent_version_validation + self.install_step
            script += '\necho AGENT_INSTALL_CONTINUED\nprintf "NO_AGENT:%s\\n" "$no_agent"\n'
            return subprocess.run(
                ["bash", "-e", "-c", script, "test", str(TEST_DIR / "extracted_functions.sh")],
                env=env, capture_output=True, text=True, timeout=10,
            )

    def test_installer_failure_continues_by_default(self):
        for enabled in ("host", "docker", "all"):
            for strict in (None, ""):
                with self.subTest(enabled=enabled, strict=strict):
                    result = self.run_install(enabled=enabled, strict=strict, installer_status=42)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertIn("SSI_MODE:" + enabled, result.stdout)
                    self.assertIn("AGENT_INSTALL_CONTINUED", result.stdout)
                    self.assertIn("Warning:", result.stdout)
                    self.assertNotIn("TELEMETRY:", result.stdout)

    def test_strict_installer_failure_exits_for_each_instrumentation_mode(self):
        for strict in ("host", "docker", "all"):
            with self.subTest(strict=strict):
                result = self.run_install(strict=strict, installer_status=42)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("SSI_MODE:" + strict, result.stdout)
                self.assertNotIn("AGENT_INSTALL_CONTINUED", result.stdout)
                self.assertIn("TELEMETRY:1:", result.stdout)
                self.assertIn("DD_APM_INSTRUMENTATION_STRICT=" + strict, result.stdout)

    def test_download_failure_exits_only_in_strict_mode(self):
        for downloader, status in (("curl", 22), ("wget", 8)):
            for strict in ("host", None):
                with self.subTest(downloader=downloader, strict=strict):
                    result = self.run_install(
                        strict=strict, enabled=None if strict else "host",
                        downloader=downloader, download_status=status,
                    )
                    self.assertEqual(result.returncode, 1 if strict else 0,
                                     result.stdout + result.stderr)
                    self.assertEqual("AGENT_INSTALL_CONTINUED" in result.stdout, not strict)

    def test_wget_installer_failure_exits_in_strict_mode(self):
        result = self.run_install(strict="host", downloader="wget", installer_status=42)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertNotIn("AGENT_INSTALL_CONTINUED", result.stdout)

    def test_partial_download_fails_even_when_partial_script_succeeds(self):
        result = self.run_install(strict="host", download_status=18, partial_download=True)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("SSI_SCRIPT_EXECUTED", result.stdout)
        self.assertNotIn("AGENT_INSTALL_CONTINUED", result.stdout)

    def test_missing_downloaders_fail_in_strict_mode(self):
        result = self.run_install(strict="host", missing_downloaders=True)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertNotIn("AGENT_INSTALL_CONTINUED", result.stdout)

    def test_success_continues_in_both_modes(self):
        for mode in ("host", "docker", "all"):
            for strict in (True, False):
                with self.subTest(mode=mode, strict=strict):
                    result = self.run_install(strict=mode if strict else None,
                                              enabled=None if strict else mode)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertIn("SSI_SCRIPT_EXECUTED", result.stdout)
                    self.assertIn("SSI_MODE:" + mode, result.stdout)
                    self.assertIn("AGENT_INSTALL_CONTINUED", result.stdout)
                    self.assertEqual("NO_AGENT:true" in result.stdout, mode == "docker")
                    self.assertNotIn("Warning:", result.stdout)
                    self.assertNotIn("TELEMETRY:", result.stdout)

    def test_no_ssi_without_either_variable(self):
        for value in (None, ""):
            with self.subTest(value=value):
                result = self.run_install(strict=value, enabled=value, installer_status=42)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn("AGENT_INSTALL_CONTINUED", result.stdout)
                self.assertNotIn("SSI_SCRIPT_EXECUTED", result.stdout)
                self.assertNotIn("TELEMETRY:", result.stdout)

    def test_strict_mode_takes_precedence(self):
        result = self.run_install(strict="host", enabled="docker", installer_status=42)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("SSI_MODE:host", result.stdout)
        self.assertNotIn("AGENT_INSTALL_CONTINUED", result.stdout)

    def test_strict_mode_preserves_agent_6_rejection(self):
        result = self.run_install(strict="host", agent_major_version="6")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("not supported with Agent version 6", result.stdout)
        self.assertNotIn("SSI_SCRIPT_EXECUTED", result.stdout)


if __name__ == "__main__":
    unittest.main()
