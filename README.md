# Autopilot for Codex

![macOS](https://img.shields.io/badge/macOS-13%2B-lightgrey)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![Notarized](https://img.shields.io/badge/Developer%20ID-notarized-brightgreen)

Tiny macOS menu bar utility for local Codex automations.

Autopilot for Codex stays in the menu bar, watches local Codex automation files, and gives you a quiet control surface for status, review, and approvals.

<p align="center">
  <img src="Resources/AppIcon.png" alt="Autopilot for Codex icon" width="128">
</p>

## Download

Download the latest notarized DMG from [GitHub Releases](https://github.com/dot-RealityTest/autopilot-for-codex/releases/latest).

Open the DMG, drag **Autopilot for Codex** into Applications, then launch it from Finder or Spotlight.

## What It Does

- Shows Codex automation status from the macOS menu bar.
- Highlights automations that are active, waiting for review, paused, or blocked.
- Opens a compact control window for inspection and approval context.
- Shows proposed changes, permissions, schedule, and recent runs.
- Opens Codex when you need to review or continue automation work.
- Supports notifications, launch at login, background stop/resume, and keyboard shortcuts.

## App Preview

<p align="center">
  <img src="docs/images/control-window.png" alt="Autopilot for Codex control window" width="900">
</p>

## Status Colors

- Green: running normally.
- Orange: waiting for review or approval.
- Red: needs attention.
- Gray: paused or no active automations.

## Local Data

The app reads local Codex automation files:

```text
~/.codex/automations/*/automation.toml
~/.codex/automations/*/memory.md
```

It does not upload automation data. It is a local macOS utility.

## Keyboard Shortcuts

- `⌘O`: open the control window.
- `⌘R`: refresh automation status.
- `⌘B`: show or hide the sidebar.
- `⌘I`: show or hide the inspector.
- `⌘S`: stop or resume background refresh.
- `⌘,`: open settings.
- `⌘Q`: quit.

## Build Locally

Requirements:

- macOS 13 or newer.
- Xcode command line tools.
- Swift 5.9 or newer.
- Node.js/npm for DMG packaging with `create-dmg`.

Build and run:

```sh
./scripts/build-app.sh
open "dist/Autopilot for Codex.app"
```

Create a signed DMG:

```sh
./scripts/package-dmg.sh
```

Notarize an existing DMG:

```sh
NOTARYTOOL_PROFILE=autopilot-codex ./scripts/notarize-dmg.sh
```

See [DISTRIBUTION.md](DISTRIBUTION.md) for signing, packaging, and notarization details.

## Release

Current release: `0.1.0`

- Renamed the app to **Autopilot for Codex**.
- Added a notarized Developer ID DMG.
- Added calm menu bar status, compact review flow, settings, notifications, and keyboard shortcuts.
- Added `create-dmg` packaging and `notarytool` notarization scripts.
