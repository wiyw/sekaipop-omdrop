# Vendored Omdrop

This directory is Omdrop's runtime, copied here so the SekaiPop plugin works
without a separate Omdrop installation.

- Source: <https://github.com/netmojo-systems/omdrop-plugin>
- Version: `0.18.7`
- Commit: `0ac99a8c469e67a3fd15934d985fe0de0cc8abb0`
- License: MIT, Copyright (c) 2026 Brent Kearney

The copy includes `bin/`, `share/`, `skills/`, `docs/`, `manifest.json`,
`README.md` and `LICENSE` from that commit.

## Local changes

Two changes are kept in `bin/omdrop` so the bundled command works on a plain
Linux desktop and in this plugin:

1. `omdrop senders remove` handles the last entry, and identifiers beginning
   with `-`, without putting the old list back.
2. `omdrop open-link` falls back to `xdg-open` or `gio open` when Omarchy's
   `omarchy-launch-browser` is not installed.

The plugin's own received-link opener lives at `omdrop/lib/open_link.py` and is
derived from the same upstream code; see `THIRD_PARTY_NOTICES.md`.

## Updating

From a fresh Omdrop checkout at the new commit:

```sh
rsync -a --delete \
    --exclude .git --exclude .DS_Store \
    bin share skills docs manifest.json README.md LICENSE \
    omdrop/vendor/omdrop/
```

Then reapply the two local changes above, update this file, and run
`scripts/test.sh` and `./install.sh` on a Linux target.
