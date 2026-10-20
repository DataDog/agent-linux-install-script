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

    def run_install(self, strict=None, enabled="host", download_status=0,
                    installer_status=0, downloader="curl", missing_downloaders=False,
                    partial_download=False):
        with tempfile.TemporaryDirectory() as temporary:
            mock_bin = Path(temporary)
            mock = mock_bin / downloader
            mock.write_text(
                '#!/bin/bash\n'
                'if [ "$SSI_TEST_DOWNLOAD_STATUS" != 0 ] && [ "$SSI_TEST_PARTIAL_DOWNLOAD" != true ]; then\n'
                '  exit "$SSI_TEST_DOWNLOAD_STATUS"\n'
                'fi\n'
                'printf \'%s\\n\' \'echo SSI_SCRIPT_EXECUTED\' \'exit "$SSI_TEST_INSTALLER_STATUS"\'\n'
                'exit "$SSI_TEST_DOWNLOAD_STATUS"\n'
            )
            mock.chmod(0o755)
            env = {key: value for key, value in os.environ.items() if not key.startswith("DD_")}
            env.update(
                PATH=str(mock_bin) + os.pathsep + env["PATH"],
                DD_APM_INSTRUMENTATION_ENABLED=enabled,
                DD_SITE="datadoghq.com",
                SSI_TEST_DOWNLOAD_STATUS=str(download_status),
                SSI_TEST_INSTALLER_STATUS=str(installer_status),
                SSI_TEST_PARTIAL_DOWNLOAD="true" if partial_download else "false",
            )
            if strict is not None:
                env["DD_APM_INSTRUMENTATION_STRICT"] = strict
            script = """
source "$1"
GENERAL_ERROR_CODE=1
sudo_cmd=""
agent_version_custom=""
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
            script += self.install_step + '\necho AGENT_INSTALL_CONTINUED\n'
            return subprocess.run(
                ["bash", "-e", "-c", script, "test", str(TEST_DIR / "extracted_functions.sh")],
                env=env, capture_output=True, text=True, timeout=10,
            )

    def test_installer_failure_continues_by_default(self):
        for strict in (None, "", "false"):
            with self.subTest(strict=strict):
                result = self.run_install(strict=strict, installer_status=42)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn("AGENT_INSTALL_CONTINUED", result.stdout)
                self.assertIn("Warning:", result.stdout)
                self.assertNotIn("TELEMETRY:", result.stdout)

    def test_strict_installer_failure_exits_for_each_instrumentation_mode(self):
        for enabled in ("host", "docker", "all"):
            with self.subTest(enabled=enabled):
                result = self.run_install(strict="true", enabled=enabled, installer_status=42)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertNotIn("AGENT_INSTALL_CONTINUED", result.stdout)
                self.assertIn("TELEMETRY:1:", result.stdout)
                self.assertIn("DD_APM_INSTRUMENTATION_STRICT=true", result.stdout)

    def test_download_failure_exits_only_in_strict_mode(self):
        for downloader, status in (("curl", 22), ("wget", 8)):
            for strict in ("true", "false"):
                with self.subTest(downloader=downloader, strict=strict):
                    result = self.run_install(
                        strict=strict, downloader=downloader, download_status=status,
                    )
                    self.assertEqual(result.returncode, 1 if strict == "true" else 0,
                                     result.stdout + result.stderr)
                    self.assertEqual("AGENT_INSTALL_CONTINUED" in result.stdout, strict != "true")

    def test_wget_installer_failure_exits_in_strict_mode(self):
        result = self.run_install(strict="true", downloader="wget", installer_status=42)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertNotIn("AGENT_INSTALL_CONTINUED", result.stdout)

    def test_partial_download_fails_even_when_partial_script_succeeds(self):
        result = self.run_install(strict="true", download_status=18, partial_download=True)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("SSI_SCRIPT_EXECUTED", result.stdout)
        self.assertNotIn("AGENT_INSTALL_CONTINUED", result.stdout)

    def test_missing_downloaders_fail_in_strict_mode(self):
        result = self.run_install(strict="true", missing_downloaders=True)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertNotIn("AGENT_INSTALL_CONTINUED", result.stdout)

    def test_success_continues_in_both_modes(self):
        for strict in ("true", "false"):
            with self.subTest(strict=strict):
                result = self.run_install(strict=strict)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn("SSI_SCRIPT_EXECUTED", result.stdout)
                self.assertIn("AGENT_INSTALL_CONTINUED", result.stdout)
                self.assertNotIn("Warning:", result.stdout)
                self.assertNotIn("TELEMETRY:", result.stdout)

    def test_strict_mode_does_not_install_ssi_unless_requested(self):
        result = self.run_install(strict="true", enabled="", installer_status=42)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("AGENT_INSTALL_CONTINUED", result.stdout)
        self.assertNotIn("SSI_SCRIPT_EXECUTED", result.stdout)
        self.assertNotIn("TELEMETRY:", result.stdout)


if __name__ == "__main__":
    unittest.main()
