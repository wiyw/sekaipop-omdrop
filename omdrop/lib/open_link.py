#!/usr/bin/env python3
# Derived from Omdrop's link handling in bin/omdrop.
# Omdrop is Copyright (c) 2026 Brent Kearney and MIT licensed; see THIRD_PARTY_NOTICES.md.

import os
import plistlib
import re
import shutil
import subprocess
import sys

MAX_LINK_BYTES = 64 * 1024


def link_url(path):
    """The URL inside a .url or .webloc shortcut, unchecked."""
    path = os.fspath(path)
    name = path.lower()
    try:
        if not os.path.isfile(path) or not os.access(path, os.R_OK):
            return ""
        if os.path.getsize(path) > MAX_LINK_BYTES:
            return ""
        if name.endswith(".url"):
            in_section = False
            with open(path, "r", encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    line = line.rstrip("\n").rstrip("\r")
                    if re.match(r"^[ \t]*\[", line):
                        in_section = line.lower().replace(" ", "").replace("\t", "") == "[internetshortcut]"
                        continue
                    if not in_section:
                        continue
                    match = re.match(r"^[ \t]*url[ \t]*=(.*)$", line, re.IGNORECASE)
                    if match:
                        return match.group(1).lstrip(" \t").rstrip(" \t")
            return ""
        if name.endswith(".webloc"):
            with open(path, "rb") as fh:
                url = plistlib.load(fh).get("URL")
            return url.strip() if isinstance(url, str) else ""
    except Exception:
        return ""
    return ""


def web_url(url):
    """The URL when it is a web page, the only kind we open."""
    if not isinstance(url, str):
        return ""
    url = url.strip()
    lower = url.lower()
    if not (lower.startswith("http://") or lower.startswith("https://")):
        return ""
    if any(ord(ch) <= 0x20 or ord(ch) == 0x7F for ch in url):
        return ""
    rest = lower.split("://", 1)[1]
    if rest == "" or rest.startswith("/"):
        return ""
    return url


def link_target(path):
    return web_url(link_url(path))


def browser_command():
    for name in ("omarchy-launch-browser",):
        found = shutil.which(name)
        if found:
            return [found]
    found = shutil.which("xdg-open")
    if found:
        return [found]
    found = shutil.which("gio")
    if found:
        return [found, "open"]
    return None


def launch(url):
    command = browser_command()
    if command is None:
        return False
    try:
        subprocess.Popen(
            command + [url],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
            close_fds=True,
        )
    except OSError:
        return False
    return True


def main(argv):
    if len(argv) != 2:
        return 2
    url = link_target(argv[1])
    if url == "":
        return 1
    return 0 if launch(url) else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
