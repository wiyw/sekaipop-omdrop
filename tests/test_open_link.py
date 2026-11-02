import importlib.util
import plistlib
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("open_link", ROOT / "omdrop" / "lib" / "open_link.py")
open_link = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(open_link)


class LinkFileTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, name, body):
        path = self.root / name
        if isinstance(body, str):
            path.write_text(body, encoding="utf-8")
        else:
            path.write_bytes(body)
        return path

    def test_windows_shortcut_uses_only_the_internet_shortcut_section(self):
        link = self.write(
            "site.url",
            "[Other]\nURL=https://decoy.example/\n"
            "[InternetShortcut]\r\nURL = https://example.com/a?b=1  \r\n",
        )
        self.assertEqual(open_link.link_target(link), "https://example.com/a?b=1")

    def test_a_url_outside_the_shortcut_section_is_not_the_link(self):
        link = self.write("site.url", "[Other]\nURL=https://example.com/\n")
        self.assertEqual(open_link.link_target(link), "")

    def test_webloc_opens_whether_xml_or_binary(self):
        for fmt in (plistlib.FMT_XML, plistlib.FMT_BINARY):
            link = self.write("site.webloc", plistlib.dumps({"URL": "https://example.com/?a=1&b=2"}, fmt=fmt))
            self.assertEqual(open_link.link_target(link), "https://example.com/?a=1&b=2")

    def test_only_http_and_https_are_opened(self):
        for url in ("file:///home", "smb://server/share", "https:///no-host", "https://example.com/a b"):
            link = self.write("site.url", f"[InternetShortcut]\nURL={url}\n")
            self.assertEqual(open_link.link_target(link), "")
        self.assertEqual(open_link.web_url("https://example.com/"), "https://example.com/")
        self.assertEqual(open_link.web_url("HTTPS://example.com/"), "HTTPS://example.com/")

    def test_oversized_and_unknown_files_are_refused(self):
        link = self.write("big.url", "[InternetShortcut]\nURL=https://example.com/\n" + "x" * open_link.MAX_LINK_BYTES)
        self.assertEqual(open_link.link_target(link), "")
        self.assertEqual(open_link.link_target(self.write("site.txt", "https://example.com/")), "")


class LaunchTests(unittest.TestCase):
    def test_omarchy_launcher_is_preferred(self):
        def which(name):
            return "/usr/bin/" + name if name == "omarchy-launch-browser" else None

        with mock.patch.object(open_link.shutil, "which", side_effect=which), \
                mock.patch.object(open_link.subprocess, "Popen") as popen:
            self.assertTrue(open_link.launch("https://example.com/"))
            self.assertEqual(popen.call_args.args[0], ["/usr/bin/omarchy-launch-browser", "https://example.com/"])

    def test_xdg_open_is_the_fallback(self):
        def which(name):
            return "/usr/bin/xdg-open" if name == "xdg-open" else None

        with mock.patch.object(open_link.shutil, "which", side_effect=which), \
                mock.patch.object(open_link.subprocess, "Popen") as popen:
            self.assertTrue(open_link.launch("https://example.com/"))
            self.assertEqual(popen.call_args.args[0], ["/usr/bin/xdg-open", "https://example.com/"])

    def test_gio_is_the_last_launcher(self):
        def which(name):
            return "/usr/bin/gio" if name == "gio" else None

        with mock.patch.object(open_link.shutil, "which", side_effect=which), \
                mock.patch.object(open_link.subprocess, "Popen") as popen:
            self.assertTrue(open_link.launch("https://example.com/"))
            self.assertEqual(popen.call_args.args[0], ["/usr/bin/gio", "open", "https://example.com/"])

    def test_no_launcher_is_a_failure(self):
        with mock.patch.object(open_link.shutil, "which", return_value=None):
            self.assertFalse(open_link.launch("https://example.com/"))


if __name__ == "__main__":
    unittest.main()
