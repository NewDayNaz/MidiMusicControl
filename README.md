# MIDI Music Control

A macOS menu bar app that listens for MIDI messages and controls **Spotify** or **Apple Music** — fade tracks in and out, duck volume, and restore it again. Built for live use with hardware controllers.

## Features

- **Menu bar app** — runs in the background with no Dock icon
- **MIDI input selection** — choose which controller to listen to when you have multiple devices
- **Fade in / fade out** — smooth volume ramps for Spotify and Music
- **Ducking** — lower volume to a configurable percentage, then restore the previous level
- **Configurable mappings** — assign note or CC messages per action, with a **Learn** mode
- **Launch at login** — optional startup toggle (requires the `.app` bundle)
- **Persistent settings** — saved automatically via UserDefaults

## Requirements

- macOS 13 (Ventura) or later
- [Swift](https://swift.org) toolchain (Xcode or Command Line Tools)
- Spotify and/or Apple Music
- A MIDI input device

## Install

### Option 1: Build a `.app` bundle (recommended)

```bash
./scripts/build-app.sh --install
```

This compiles a release build, packages `dist/MidiMusicControl.app`, signs it ad-hoc, and copies it to `/Applications`.

Other flags:

```bash
./scripts/build-app.sh          # build only
./scripts/build-app.sh --open     # build and launch
./scripts/build-app.sh --install --open
```

### Option 2: Run from source

```bash
swift run
```

Launch at login is **not** available when running this way — use the `.app` bundle for that.

## Usage

1. Launch the app (menu bar icon: music note list).
2. Click the icon → **Settings…**
3. Select your **MIDI Input** and click **Refresh Devices** if needed.
4. Map your controller pads/knobs to actions (or use **Learn**).
5. Trigger fades and ducking from your MIDI controller.

### Default MIDI mappings

| Note | Action |
|------|--------|
| 60 (C4) | Spotify Fade In |
| 61 (C#4) | Spotify Fade Out |
| 62 (D4) | Music Fade In |
| 63 (D#4) | Music Fade Out |
| 64 (E4) | Spotify Duck |
| 65 (F4) | Spotify Unduck |
| 66 (F#4) | Music Duck |
| 67 (G4) | Music Unduck |

Default velocity for all mappings: **127**. Mappings match on exact note/CC **and** value.

### Settings overview

| Section | Description |
|---------|-------------|
| **Startup** | Open at login (`.app` only) |
| **MIDI Input** | Active controller and device refresh |
| **Fade Speed** | Total fade duration in seconds (0.5–15s) |
| **Ducking** | Target volume % while ducked (1–100%) |
| **Fade / Duck Mappings** | Per-action note/CC, value, type, and Learn |

**Learn mode:** click **Learn** on an action, then send the next MIDI message from the selected input. The note/CC and value are captured automatically.

## macOS permissions

On first use, macOS may prompt for:

- **Automation** — allow the app to control Spotify and/or Music  
  *(System Settings → Privacy & Security → Automation)*

If you enable **Open at login**, you may also need to approve the app under:

- **System Settings → General → Login Items**

## How it works

MIDI messages are received via **Core MIDI**. Matching triggers run **AppleScript** against Spotify or Music to adjust volume over time. Fade duration is split evenly across volume steps; ducking stores the pre-duck level and restores it on unduck.

## Project structure

```
midi-spotify-control/
├── Package.swift
├── scripts/
│   └── build-app.sh          # Build & package .app bundle
├── Sources/MidiMusicControl/
│   ├── main.swift
│   ├── AppDelegate.swift     # Menu bar & settings window
│   ├── SettingsView.swift    # SwiftUI settings UI
│   ├── MIDIManager.swift     # Core MIDI input & learn mode
│   ├── PlayerVolumeController.swift
│   ├── AppleScriptFade.swift # Fade & duck AppleScript
│   ├── LaunchAtLogin.swift
│   └── AppSettings.swift     # UserDefaults persistence
└── dist/                     # Built .app (after running build script)
```

## Development

```bash
# Debug build
swift build

# Run
swift run

# Release build
swift build -c release
```

To change the app version or bundle ID, edit the variables at the top of `scripts/build-app.sh`.

## License

Copyright © 2026 New Day Naz

This project is licensed under the **GNU General Public License v3.0 or later** (GPL-3.0-or-later). See [LICENSE](LICENSE) for the full text.

You are free to use, modify, and distribute this software under the terms of the GPL. If you distribute a modified version, you must also make your source code available under the same license.
