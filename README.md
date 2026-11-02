# sekaipop-omdrop

A [SekaiPop](https://github.com/Blapples/SekaiPop) plugin for [Omdrop](https://github.com/netmojo-systems/omdrop-plugin),
AirDrop for Linux. It bundles Omdrop's `omdrop` command and drives it; the radio backend stays
Omdrop's business.

| Surface            | Shows                                                                                                  |
| ------------------ | ------------------------------------------------------------------------------------------------------ |
| **Bar entry**      | whether this computer is receiving, and the time left (`9:58`, `On`, `Off`, `Hidden`, `Missing`)        |
| **Popup**          | start/stop, the window, Everyone / Contacts Only, name and folder, known senders, nearby devices, send files, received links |
| **Desktop widget** | nearby devices as a card (or, compact, the count) |

Click a device row to send it files. While a send is running the row shows a progress bar; it can be cancelled. The popup scrolls, so every control stays reachable even when the card is short.

Shared links arrive in the download folder as `.url` or `.webloc` files. The popup lists the four
newest; click a row or its **Open** key to open the page in your browser. Only `http` and `https`
links open; anything else is refused, because it was chosen by whoever sent it. The opener is
bundled from Omdrop's MIT-licensed link handling (see `THIRD_PARTY_NOTICES.md`) and uses
`omarchy-launch-browser`, `xdg-open`, or `gio`.

## requirements

- SekaiPop with plugin API 1 (the bar entry, popup, widget and service interface in
  `docs/PLUGINS.md`).
- A Linux desktop. On Arch and its derivatives, `install.sh` uses `pacman`/an AUR helper to install
  Omdrop's receiver libraries and a radio backend. Elsewhere, install those yourself.
- `python3` for the bundled link opener (standard library only), and `omarchy-launch-browser`,
  `xdg-open`, or `gio` to open the page.

No separate Omdrop installation is needed: the runtime is vendored under
`omdrop/vendor/omdrop/` and called directly. The radio side normally needs the polkit grant
Omdrop's setup installs; without it, starting can ask for a password. `omdrop doctor` should be
happy when setup finishes.

The plugin itself installs no driver, writes no systemd unit and needs no root of its own; that
happens only in `install.sh`, through the normal `sudo`/package-manager path. It remembers recently
seen device names in `~/.local/state/sekaipop/plugins/omdrop-device-names.json`, so the radio
restarting does not send every row back to an address.

## install

**From the clone** (to work on it; SekaiPop then lists it as managed by you and never updates it):

```sh
git clone https://github.com/wiyw/sekaipop-omdrop.git ~/projects/sekaipop-omdrop
cd ~/projects/sekaipop-omdrop && ./install.sh
```

`install.sh` links the `omdrop` folder into `~/.config/sekaipop/plugins/`, installs Omdrop's
receiver libraries, attempts a radio backend (`omdrop-owl-bin` on a PC, the Apple Silicon driver or
`omdrop-bcm4360` on a Mac), runs `omdrop setup`, and reloads the shell's plugins. It also patches
SekaiPop's `Bar.qml` so plugin popups take the keyboard, after saving a backup beside it. Move the
entry in Edit Desktop's BAR tab; add the widget from Edit Desktop's shelf. `git pull` updates it;
`./install.sh --remove` takes the plugin, command link, receiver unit and link handler written from
this clone away; Omdrop settings, identity, downloads and installed packages stay.

An existing `~/.local/bin/omdrop` is left alone unless it points into this clone. The plugin does
not depend on it: it calls the bundled command directly. Override that with
`SEKAIPOP_OMDROP_CLI` if you need a different copy.

A keybind for the popup: `qs -c sekaipop ipc call plugins popup omdrop`.

## settings

Settings > Desktop > Plugins > Omdrop:

| Group     | Setting              | Default            |                                                                 |
| --------- | -------------------- | ------------------ | --------------------------------------------------------------- |
| Bar       | Bar entry            | Icon and state     | or Icon only (a state dot on the icon)                          |
| Bar       | Hide without Omdrop  | on                 | off the bar when the `omdrop` command isn't there               |
| Receiving | Stay visible for     | 10 minutes         | one file, 1/5/10/15/30 minutes, 1 hour, until turned off        |
| Widget    | Widget look          | Full               | or Compact                                                      |
| Checking  | Check every          | 5 seconds          | while the popup or widget shows; the bar alone checks every 15 s |

The popup's window chooser changes the saved setting. Choosing a window while receiving restarts
the live window from that moment.

## development

- `omdrop/lib/Omdrop.js` is every rule (states, the bar's words and dot, the window chooser,
  signals, peer order, doctor output, poll pace) as pure functions; the QML only draws what it
  returns.
- `scripts/test.sh` runs its rules tests with the 95 % line, branch and function coverage floor,
  then the bundled link opener's Python tests and the vendored Omdrop checks.
- The vendored Omdrop version, upstream commit and local changes are in
  `omdrop/vendor/omdrop/UPSTREAM.md`. Keep `THIRD_PARTY_NOTICES.md` with it.
- Check the QML by running it: Qt 6's `qmllint`, then a live SekaiPop.

## license

MIT license: the plugin code is © 2026 Greyson. The SekaiPop platform is GPL‑3.0, and this plugin’s MIT licence is compatible with it.

The bundled Omdrop runtime is MIT, Copyright (c) 2026 Brent Kearney; see
`THIRD_PARTY_NOTICES.md` and `omdrop/vendor/omdrop/LICENSE`.

SekaiPop itself is GPL-3.0; this plugin is a separate set of files it loads, and MIT is compatible with it.
