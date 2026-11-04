import os
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import redact  # noqa: E402

FAKE = "s3cr3t-Value!"  # pc-migrate: allow


def read(path):
    with open(path) as f:
        return f.read()


class RedactTest(unittest.TestCase):
    def run_redact(self, text):
        out, wanted, manual = redact.redact(text, "~/.bashrc")
        self.assertNotIn(FAKE, out)
        return out, [v for v, _ in wanted], manual

    def test_export_line_becomes_reference(self):
        out, names, _ = self.run_redact(f"export KEYCLOAK_PASSWORD='{FAKE}'\n")
        self.assertEqual(out, 'export KEYCLOAK_PASSWORD="$KEYCLOAK_PASSWORD_1"\n')
        self.assertEqual(names, ["KEYCLOAK_PASSWORD_1"])

    def test_commented_alternatives_are_numbered(self):
        text = f'#export DB_TOKEN="{FAKE}"\nexport DB_TOKEN="{FAKE}2"\n'
        out, names, _ = self.run_redact(text)
        self.assertEqual(names, ["DB_TOKEN_1", "DB_TOKEN_2"])
        self.assertTrue(out.startswith('#export DB_TOKEN="$DB_TOKEN_1"'))

    def test_escaped_quotes_and_trailing_comment(self):
        out, _, _ = self.run_redact(f'export API_KEY="{FAKE}\\"x"  # prod\n')
        self.assertEqual(out, 'export API_KEY="$API_KEY_1" # prod\n')

    def test_inline_secret_named_after_function(self):
        text = f"function getToken(){{\ncurl --data password={FAKE} \\\n--data client_assertion={FAKE}x\n}}\n"
        out, names, _ = self.run_redact(text)
        self.assertEqual(names, ["GETTOKEN_PASSWORD", "GETTOKEN_CLIENT_ASSERTION"])
        self.assertIn('password="$GETTOKEN_PASSWORD"', out)

    def test_references_and_non_secrets_untouched(self):
        text = 'export TOKEN=$(aws get-token)\nexport KEYCLOAK_user=me\n--data grant_type=password\n'
        out, names, _ = self.run_redact(text)
        self.assertEqual(out, text)
        self.assertEqual(names, [])

    def test_single_quoted_inline_is_reported(self):
        _, names, manual = self.run_redact(f"curl -d 'password={FAKE}'\n".replace(FAKE, "abcdefg"))
        self.assertEqual((names, manual), ([], [1]))

    def test_variable_names_never_depend_on_value(self):
        _, a, _ = self.run_redact("export X_PASSWORD='admin'\n")
        _, b, _ = self.run_redact("export X_PASSWORD='hunter22'\n")  # pc-migrate: allow
        self.assertEqual(a, b)

    def test_cli_writes_template_without_values(self):
        with tempfile.TemporaryDirectory() as tmp:
            src, dest, tpl = (os.path.join(tmp, n) for n in (".bashrc", "out", "tpl"))
            with open(src, "w") as f:
                f.write(f"export MY_SECRET='{FAKE}'\n")
            subprocess.run([sys.executable, redact.__file__, src, dest, tpl], check=True, capture_output=True)
            out, template = read(dest), read(tpl)
            self.assertTrue(out.startswith(redact.SOURCE_LINE))
            self.assertNotIn(FAKE, out + template)
            self.assertIn("export MY_SECRET_1=''", template)


if __name__ == "__main__":
    unittest.main()
