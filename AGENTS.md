# AGENTS.md

A SekaiPop plugin: QML surfaces plus one `.pragma library` JS file, loaded by SekaiPop at runtime.

- **The plugin interface is SekaiPop's `docs/PLUGINS.md`** (desktop widget, bar entry, popup,
  service). A plugin can't import the shell's `qs.*` modules; `host` and the manifest are all it
  gets. Use only the theme names that file promises.
- **Rules go in `omdrop/lib/Omdrop.js`**, tested in node (`scripts/test.sh`, 95 % lines, branches
  and functions, never lowered). QML draws what it returns and holds no logic of its own.
- **All radio work goes through the user's `omdrop` command line.** The plugin must not talk to
  systemd, Owly, `awdl0` or the receiver directly, and must not install drivers. Read-only calls
  are `omdrop status --json`, `omdrop peers --json`, `omdrop doctor --json` and
  `omdrop senders list --json`; the rest change what this computer is advertising.
- **Never run `omdrop on`, `off`, `name`, `dir`, `visibility`, `senders`, `sound` or `send` while
  checking the UI** unless that is the test itself: they change the owner's machine. Use a fake
  `omdrop` on `PATH` for the other states.
- **The service owns every command.** Bar, popup and widget read `host.service` and call its
  functions, so one status poll feeds every monitor and a send survives the popup closing for the
  chooser.
- **Check QML by running it**: Qt 6's `qmllint`, then a live shell. On a machine without the QML
  tools, a live run on the target is the only check; say so rather than assuming it parses.
- `omdrop/lib/Omdrop.js` is loaded with `.pragma library`; keep it to pure ECMAScript that both
  QML's JS engine and node accept. `tests/load.js` executes it in node.
