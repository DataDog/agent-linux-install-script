import os
from pathlib import Path
import socket
import subprocess
import sys
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer


TEST_DIR = Path(__file__).resolve().parent


class CurlRetryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run([sys.executable, str(TEST_DIR / "extract_functions.py")], check=True)

    def run_bash(self, script, *args, **env):
        return subprocess.run(
            ["bash", "-e", "-c", 'source "$1"; shift\n' + script,
             "test", str(TEST_DIR / "extracted_functions.sh"), *args],
            env={**os.environ, **env},
            capture_output=True,
            text=True,
            timeout=20,
        )

    def mock_transfer(self, supported, sudo_cmd="", status=0):
        return self.run_bash(
            """
curl() {
  if [ "$REQUIRE_SUDO" = "true" ] && [ "$MOCK_PRIVILEGED" != "true" ]; then
    return 7
  fi
  if [ "$1" = "--retry-connrefused" ] && [ "$2" = "--version" ]; then
    echo "probe output must be suppressed" >&2
    return "$MOCK_PROBE_STATUS"
  fi
  printf '%s\\n' "$@"
  return "$MOCK_TRANSFER_STATUS"
}
mock_sudo() {
  echo "sudo" >&2
  MOCK_PRIVILEGED=true "$@"
}
curl_with_retry "$1" 5 -f -sSL -o "/tmp/key with spaces" "https://example.test/key"
""",
            sudo_cmd,
            MOCK_PROBE_STATUS="0" if supported else "2",
            MOCK_TRANSFER_STATUS=str(status),
            REQUIRE_SUDO="true" if sudo_cmd else "false",
        )

    def test_supported_curl_retries_refused_connections(self):
        result = self.mock_transfer(True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [
            "--retry", "5", "--retry-delay", "2", "--retry-connrefused",
            "-f", "-sSL", "-o", "/tmp/key with spaces", "https://example.test/key",
        ])
        self.assertEqual(result.stderr, "")

    def test_older_curl_uses_supported_options(self):
        result = self.mock_transfer(False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [
            "--retry", "5", "--retry-delay", "2",
            "-f", "-sSL", "-o", "/tmp/key with spaces", "https://example.test/key",
        ])
        self.assertEqual(result.stderr, "")

    def test_probe_and_transfer_use_sudo(self):
        result = self.mock_transfer(True, "mock_sudo")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--retry-connrefused", result.stdout)
        self.assertEqual(result.stderr, "sudo\n")

    def test_transfer_failure_is_preserved(self):
        result = self.mock_transfer(True, status=22)
        self.assertEqual(result.returncode, 22)

    def test_installer_pipeline_preserves_download_and_execution_failures(self):
        for download_status, installer_status, expected in ((0, 0, 0), (22, 0, 1), (0, 42, 1), (23, 0, 0)):
            with self.subTest(download_status=download_status, installer_status=installer_status):
                result = self.run_bash(
                    """
curl() {
  if [ "$1" = "--retry-connrefused" ]; then
    return 0
  fi
  if [ "$MOCK_DOWNLOAD_STATUS" -ne 22 ]; then
    printf 'exit %s\\n' "$MOCK_INSTALLER_STATUS"
  fi
  return "$MOCK_DOWNLOAD_STATUS"
}
_install_installer_script "https://example.test/install-ssi.sh"
""",
                    MOCK_DOWNLOAD_STATUS=str(download_status),
                    MOCK_INSTALLER_STATUS=str(installer_status),
                )
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)

    def serve_responses(self, responses):
        requests = []

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                status = responses[min(len(requests), len(responses) - 1)]
                requests.append(self.path)
                self.send_response(status)
                self.send_header("Content-Length", "2")
                self.end_headers()
                self.wfile.write(b"ok")

            def log_message(self, *args):
                pass

        server = HTTPServer(("127.0.0.1", 0), Handler)
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()

        def cleanup():
            server.shutdown()
            worker.join()
            server.server_close()

        self.addCleanup(cleanup)
        return f"http://127.0.0.1:{server.server_port}/", requests

    def test_real_curl_recovers_from_http_503(self):
        url, requests = self.serve_responses([503, 200])
        result = self.run_bash('curl_with_retry "" 1 -fsS --noproxy "*" "$1"', url)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "ok")
        self.assertEqual(len(requests), 2)

    def test_real_curl_exhausts_retries(self):
        url, requests = self.serve_responses([503])
        result = self.run_bash('curl_with_retry "" 1 -fsS --noproxy "*" "$1"', url)
        self.assertEqual(result.returncode, 22, result.stderr)
        self.assertEqual(len(requests), 2)

    def test_real_curl_does_not_retry_http_404(self):
        url, requests = self.serve_responses([404])
        result = self.run_bash('curl_with_retry "" 1 -fsS --noproxy "*" "$1"', url)
        self.assertEqual(result.returncode, 22, result.stderr)
        self.assertEqual(len(requests), 1)

    def test_real_curl_retries_connection_refused_when_supported(self):
        supported = subprocess.run(
            ["curl", "--retry-connrefused", "--version"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        ).returncode == 0
        with socket.socket() as port:
            port.bind(("127.0.0.1", 0))
            url = f"http://127.0.0.1:{port.getsockname()[1]}/"
        result = self.run_bash(
            'curl_with_retry "" 1 -sS --noproxy "*" --connect-timeout 2 "$1"', url,
        )
        self.assertEqual(result.returncode, 7, result.stderr)
        self.assertEqual(result.stderr.count("curl: (7)"), 2 if supported else 1)


if __name__ == "__main__":
    unittest.main()
