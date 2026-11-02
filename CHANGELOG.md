# Changelog

All notable changes to this plugin are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2026-11-01

### Added

- Bundled Omdrop's MIT-licensed `.url`/`.webloc` link handling and browser launcher
  fallback, with attribution in `THIRD_PARTY_NOTICES.md`.

### Changed

- Received links no longer require `omdrop open-link` or Omarchy's
  `omarchy-launch-browser`; the bundled opener uses the first available
  `omarchy-launch-browser`, `xdg-open`, or `gio`.

## [0.2.0] - 2026-11-01

### Added

- A **Links** section in the popup for received `.url` and `.webloc` files. It
  lists the four newest and opens the selected page in the browser through
  `omdrop open-link`, which keeps the web-only `http`/`https` gate.
- A send-progress bar on device rows, with working, done, and failed states.
- A persistent device-name cache at
  `~/.local/state/sekaipop/plugins/omdrop-device-names.json`, so a radio restart
  does not send every device row back to its address.
- Click-to-focus on the name and sender fields, with Tab returning from the
  sender field to the name field.
- An explicit “Nothing nearby yet” message and a “learning names…” state while
  devices are first being identified.

### Changed

- Nearby Apple devices are now a plain list instead of a radar.
- The compact widget shows the icon and nearby count without the radar.

### Removed

- The radar view and its sound effects, along with the **Radar sounds** setting.
- The radar sound attribution from `LICENSE`.

## [0.1.0] - 2026-11-01

### Added

- Initial SekaiPop plugin for Omdrop: bar entry, popup, desktop widget, receiving
  controls, Everyone / Contacts Only modes, nearby devices, and file sending.
