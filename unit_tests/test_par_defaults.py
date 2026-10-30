import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

TEST_DIR = Path(__file__).resolve().parent
REPO_DIR = TEST_DIR.parent


class ParDefaultTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run([sys.executable, str(TEST_DIR / "extract_functions.py")], check=True)
        template = (REPO_DIR / "install_script.sh.template").read_text()
        cls.opt_out = template.split("# An explicit PAR opt-out", 1)[1].split("# DDOT configuration update", 1)[0]
        cls.opt_out = cls.opt_out[cls.opt_out.index('if [ -z "$no_agent" ]'):]

    def apply(self, original, enabled="", allowlist="", enrollment="", split="", existing=False, no_agent=""):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            config = directory / "datadog.yaml"
            config.write_text(original)
            env = dict(os.environ)
            # The production script runs on Linux and uses GNU sed.
            if sys.platform == "darwin":
                gsed = shutil.which("gsed")
                if not gsed:
                    self.skipTest("GNU sed is required (gsed on macOS)")
                (directory / "sed").symlink_to(gsed)
                env["PATH"] = str(directory) + os.pathsep + env["PATH"]
            script = 'source "$1"\nconfig_file="$2"\npar_enabled="$3"\nno_agent="$7"\nsudo_cmd=\n'
            script += self.opt_out if existing else 'update_par "" "$2" "$3" "$4" "$5" "$6"\n'
            result = subprocess.run(
                ["bash", "-e", "-c", script, "test", str(TEST_DIR / "extracted_functions.sh"),
                 str(config), enabled, allowlist, enrollment, split, no_agent],
                env=env, capture_output=True, text=True,
            )
            return result, config.read_text()

    def test_unset_preserves_package_default_and_other_settings(self):
        original = "api_key: test\nprivate_action_runner:\n  enabled: true\n  self_enroll: false\n"
        result, updated = self.apply(original)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(updated, original)

    def test_opt_out_overrides_fresh_package_default(self):
        for value in ("false", "FALSE", "0"):
            with self.subTest(value=value):
                result, updated = self.apply("private_action_runner:\n  enabled: true\n", value)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(updated, "private_action_runner:\n  enabled: false\n")

    def test_explicit_options_merge_into_fresh_template(self):
        result, updated = self.apply("private_action_runner:\n  enabled: true\n  self_enroll: false\n", "true", "custom.action,other.action", "true", "false")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(updated.count("private_action_runner:"), 1)
        for setting in ("enabled: true", "self_enroll: false", "actions_allowlist: [custom.action,other.action]", "api_key_only_enrollment: true", "split_enabled: false"):
            self.assertIn(setting, updated)

    def test_explicit_enable_without_package_default(self):
        result, updated = self.apply("api_key: test\n", "true")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("enabled: true", updated)

    def test_existing_opt_out_preserves_other_settings(self):
        original = "api_key: test\nprivate_action_runner:\n  enabled: true\n  self_enroll: false\n"
        result, updated = self.apply(original, "false", existing=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(updated, original.replace("enabled: true", "enabled: false"))

    def test_existing_config_without_explicit_opt_out_is_unchanged(self):
        original = "private_action_runner:\n  enabled: false\n"
        result, updated = self.apply(original, existing=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(updated, original)

    def test_no_agent_does_not_modify_existing_config(self):
        original = "private_action_runner:\n  enabled: true\n"
        result, updated = self.apply(original, "false", existing=True, no_agent="true")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(updated, original)

    def test_invalid_allowlist_does_not_modify_config(self):
        original = "private_action_runner:\n  enabled: true\n"
        result, updated = self.apply(original, "true", "bad;command")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(updated, original)
