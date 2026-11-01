# sekaipop-omdrop

A [SekaiPop](https://github.com/Blapples/SekaiPop) plugin for [Omdrop](https://github.com/netmojo-systems/omdrop-plugin),
AirDrop for Linux. It drives the existing `omdrop` command line; the radio backend stays Omdrop's
business.

| Surface            | Shows                                                                                                  |
| ------------------ | ------------------------------------------------------------------------------------------------------ |
| **Bar entry**      | whether this computer is receiving, and the time left (`9:58`, `On`, `Off`, `Hidden`, `Missing`)        |
| **Popup**          | start/stop, the window, Everyone / Contacts Only, name and folder, known senders, the radar, send files |
| **Desktop widget** | the same radar and nearby devices as a card (or, compact, the count and a small radar)                  |

Click a device on the radar or a row to send it files. While a send is running the row shows the
CLI's own progress; it can be cancelled. The popup scrolls, so every control stays reachable even
when the card is short.

## requirements

- SekaiPop with plugin API 1 (the bar entry, popup, widget and service interface in
  `docs/PLUGINS.md`).
- Omdrop's `omdrop` command on the shell's `PATH`, set up with `omdrop setup`, with a radio backend
  for this Wi-Fi card: `omdrop-awdl`, `omdrop-bcm4360`, or `omdrop-owl` from Owly.
- `omdrop doctor` should be happy. The radio side normally needs the polkit grant Omdrop's setup
  installs; without it, starting can ask for a password.

The plugin only calls `omdrop`; it installs no driver, writes no systemd unit and needs no root of
its own.

## install

**From the clone** (to work on it; SekaiPop then lists it as managed by you and never updates it):

```sh
git clone https://github.com/wiyw/sekaipop-omdrop.git ~/projects/sekaipop-omdrop
cd ~/projects/sekaipop-omdrop && ./install.sh
```

`install.sh` links the `omdrop` folder into `~/.config/sekaipop/plugins/`, reloads the shell's
plugins and puts the entry on the bar. Move it in Edit Desktop's BAR tab; add the widget from
Edit Desktop's shelf. `git pull` updates it; `./install.sh --remove` takes it away.

A keybind for the popup: `qs -c sekaipop ipc call plugins popup omdrop`.

## settings

Settings > Desktop > Plugins > Omdrop:

| Group     | Setting              | Default            |                                                                 |
| --------- | -------------------- | ------------------ | --------------------------------------------------------------- |
| Bar       | Bar entry            | Icon and state     | or Icon only (a state dot on the icon)                          |
| Bar       | Hide without Omdrop  | on                 | off the bar when the `omdrop` command isn't there               |
| Receiving | Stay visible for     | 10 minutes         | one file, 1/5/10/15/30 minutes, 1 hour, until turned off        |
| Receiving | Radar sounds         | on                 | blips as names arrive and pings as the sweep crosses a device   |
| Widget    | Widget look          | Full               | or Compact                                                      |
| Checking  | Check every          | 5 seconds          | while the popup or widget shows; the bar alone checks every 15 s |

The popup's window chooser changes the saved setting. Choosing a window while receiving restarts
the live window from that moment.

## development

- `omdrop/lib/Omdrop.js` is every rule (states, the bar's words and dot, the window chooser,
  signals, peer order, doctor output, poll pace) as pure functions; the QML only draws what it
  returns.
- `scripts/test.sh` runs its tests with the 95 % line, branch and function coverage floor.
- Check the QML by running it: Qt 6's `qmllint`, then a live SekaiPop.
- The sounds beside the QML are Omdrop's (MIT, copyright Brent Kearney); see `LICENSE`. They play through
  `pw-play`, with `paplay` as the fallback.

## license

MIT license: the plugin code is © 2026 Greyson; the included radar sounds are © 2026 Brent Kearney (MIT). The SekaiPop platform is GPL‑3.0, and this plugin’s MIT licence is compatible with it.

SekaiPop itself is GPL-3.0; this plugin is a separate set of files it loads, and MIT is compatible with it.
