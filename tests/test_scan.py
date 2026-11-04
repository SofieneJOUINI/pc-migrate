import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import scan  # noqa: E402


def flagged(line):
    return bool(scan.scan_text("f", line))


class ScanTest(unittest.TestCase):
    def test_catches_real_secrets(self):
        for line in [
            "export API_TOKEN=abcd1234efgh",  # pc-migrate: allow
            'password: "hunter2hunter2"',  # pc-migrate: allow
            "db_password: correcthorse",  # pc-migrate: allow
            "-----BEGIN OPENSSH PRIVATE KEY-----",  # pc-migrate: allow
            "key = AKIA" + "ABCDEFGHIJKLMNOP",
            "token ghp_" + "a" * 36,
        ]:
            with self.subTest(line=line):
                self.assertTrue(flagged(line))

    def test_ignores_references_and_code(self):
        for line in [
            'export KEYCLOAK_PASSWORD="$KEYCLOAK_PASSWORD_1"',
            'token = os.environ.get("GITHUB_TOKEN")',
            "spring.r2dbc.password=${DB_PASSWORD:postgres}",
            "--data grant_type=password",
            'meta["note"] = "No API token: title unknown"',
            "export SECRET=''",
        ]:
            with self.subTest(line=line):
                self.assertFalse(flagged(line))

    def test_allow_marker(self):
        self.assertFalse(flagged("export API_TOKEN=abcd1234efgh  # pc-migrate: allow"))


if __name__ == "__main__":
    unittest.main()
