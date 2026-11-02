import os
import plistlib
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VENDOR = ROOT / "omdrop" / "vendor" / "omdrop"
OMDROP = VENDOR / "bin" / "omdrop"


class VendoredFilesTests(unittest.TestCase):
    def test_runtime_is_present_and_executable(self):
        for relative in (
            "bin/omdrop",
            "bin/airdrop-serve.py",
            "share/airdrop-receiver.service",
            "manifest.json",
            "LICENSE",
            "UPSTREAM.md",
        ):
            self.assertTrue((VENDOR / relative).is_file(), relative)
        self.assertTrue(os.access(OMDROP, os.X_OK))

    def test_upstream_record_matches_manifest(self):
        upstream = (VENDOR / "UPSTREAM.md").read_text(encoding="utf-8")
        manifest = (VENDOR / "manifest.json").read_text(encoding="utf-8")
        recorded = re.search(r"^- Version: `([^`]+)`", upstream, re.MULTILINE)
        self.assertIsNotNone(recorded)
        self.assertIn(f'"version": "{recorded.group(1)}"', manifest)
        self.assertIn("0ac99a8c469e67a3fd15934d985fe0de0cc8abb0", upstream)

    def test_upstream_license_is_kept(self):
        license_text = (VENDOR / "LICENSE").read_text(encoding="utf-8")
        self.assertIn("MIT License", license_text)
        self.assertIn("Brent Kearney", license_text)
        notices = (ROOT / "THIRD_PARTY_NOTICES.md").read_text(encoding="utf-8")
        self.assertIn("omdrop/vendor/omdrop", notices)
        self.assertIn("Brent Kearney", notices)

    def test_script_parses(self):
        result = subprocess.run(["bash", "-n", str(OMDROP)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_service_uses_the_bundled_command(self):
        service = (ROOT / "omdrop" / "Service.qml").read_text(encoding="utf-8")
        self.assertIn('Qt.resolvedUrl("vendor/omdrop/bin/omdrop")', service)
        self.assertIn('SEKAIPOP_OMDROP_CLI', service)


class VendoredCommandTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()

    def tearDown(self):
        self.tmp.cleanup()

    def fake_open(self):
        output = self.root / "opened"
        script = self.bin / "xdg-open"
        script.write_text('#!/bin/sh\nprintf "%s" "$1" > "$OMDROP_TEST_OUTPUT"\n', encoding="utf-8")
        script.chmod(0o755)
        if sys.platform == "darwin":
            stat = self.bin / "stat"
            stat.write_text(
                '#!/bin/sh\nif [ "$1" = "-c" ] && [ "$2" = "%s" ]; then\n'
                '  shift 2; [ "$1" = "--" ] && shift; exec /usr/bin/stat -f %z "$@"\n'
                'fi\nexec /usr/bin/stat "$@"\n', encoding="utf-8")
            stat.chmod(0o755)
        env = os.environ.copy()
        env["PATH"] = f"{self.bin}:/usr/bin:/bin"
        env["OMDROP_TEST_OUTPUT"] = str(output)
        return output, env

    @unittest.skipIf(sys.platform == "darwin", "vendored Omdrop needs Bash 4")
    def test_open_link_falls_back_to_xdg_open(self):
        output, env = self.fake_open()
        link = self.root / "site.webloc"
        link.write_bytes(plistlib.dumps({"URL": "https://example.com/a?b=1"}))
        result = subprocess.run([str(OMDROP), "open-link", str(link)], env=env,
                                capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output.read_text(encoding="utf-8"), "https://example.com/a?b=1")

    @unittest.skipIf(sys.platform == "darwin", "vendored Omdrop needs Bash 4")
    def test_open_link_refuses_a_non_web_link(self):
        output, env = self.fake_open()
        link = self.root / "site.webloc"
        link.write_bytes(plistlib.dumps({"URL": "file:///etc/passwd"}))
        result = subprocess.run([str(OMDROP), "open-link", str(link)], env=env,
                                capture_output=True, text=True, timeout=15)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(output.exists())

    def test_removing_the_last_senders_leaves_an_empty_list(self):
        config = self.root / "config"
        contacts = config / "omdrop"
        contacts.mkdir(parents=True)
        known = contacts / "known-senders"
        known.write_text("first@example.com\n-second@example.com\n", encoding="utf-8")
        env = os.environ.copy()
        env["HOME"] = str(self.root / "home")
        env["XDG_CONFIG_HOME"] = str(config)
        env["PATH"] = f"{self.bin}:/usr/bin:/bin"
        result = subprocess.run(
            [str(OMDROP), "senders", "remove", "first@example.com", "-second@example.com"],
            env=env, capture_output=True, text=True, timeout=15,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Removed. 0 known now.", result.stdout)
        self.assertEqual(known.read_text(encoding="utf-8"), "")


class InstallScriptTests(unittest.TestCase):
    def test_install_script_parses(self):
        result = subprocess.run(["sh", "-n", str(ROOT / "install.sh")], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_help_lists_the_install_and_remove_modes(self):
        result = subprocess.run(["sh", str(ROOT / "install.sh"), "--help"],
                                capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("./install.sh --remove", result.stdout)
        self.assertNotIn("set -eu", result.stdout)


if __name__ == "__main__":
    unittest.main()
