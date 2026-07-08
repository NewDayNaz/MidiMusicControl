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

To change the app version or bundle ID, edit the variables at the top of `scripts/build-app.sh`, or set `VERSION` and `BUILD_NUMBER` when building in CI.

## CI/CD

GitHub Actions builds the project on every push and pull request to `main`, and publishes signed, notarized macOS releases when you push a version tag.

### Continuous integration

Workflow: [`.github/workflows/ci.yml`](.github/workflows/ci.yml)

- Runs on `macos-14`
- Validates shell scripts and entitlements
- `swift build` + `swift test` (MIDI parsing, settings, AppleScript generation)
- Builds `dist/MidiMusicControl.app`
- Verifies bundle structure, resources, metadata, and ad-hoc signature

Run the same checks locally with:

```bash
./scripts/ci-verify.sh
```

### Release builds

Workflow: [`.github/workflows/release.yml`](.github/workflows/release.yml)

Create a release by pushing a tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The release workflow will:

1. Run the full `ci-verify` checks for the tagged commit
2. Build, sign, and notarize the app (only if verification passes)
3. Publish a GitHub Release with a changelog listing each commit hash and subject since the previous tag
4. Attach `MidiMusicControl-<version>-macos.zip` to the release

### One-time Apple setup

1. Sign in at [Apple Developer](https://developer.apple.com/account).
2. Register the bundle ID `com.newdaynaz.midimusiccontrol` (Certificates, Identifiers & Profiles → Identifiers).
3. Create a **Developer ID Application** certificate.
4. Export the certificate as a `.p12` from Keychain Access.
5. Create an [App Store Connect API key](https://appstoreconnect.apple.com/access/integrations/api) with at least **Developer** access for notarization.

### GitHub repository secrets

| Secret | Description |
|--------|-------------|
| `MACOS_CERTIFICATE_P12` | Base64-encoded `.p12` export (on macOS: `base64 -i cert.p12 \| pbcopy`) |
| `MACOS_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` |
| `KEYCHAIN_PASSWORD` | Any strong random string used for the temporary CI keychain |
| `MACOS_SIGNING_IDENTITY` | Full cert name, e.g. `Developer ID Application: Your Name (TEAMID)` |
| `APPLE_TEAM_ID` | 10-character Team ID |
| `APP_STORE_CONNECT_API_KEY_ID` | API key ID (e.g. `ABCD123456`) |
| `APP_STORE_CONNECT_API_ISSUER_ID` | Issuer UUID from App Store Connect |
| `APP_STORE_CONNECT_API_KEY` | Base64-encoded `.p8` key file used directly by `notarytool` |

Release secrets are only required for tagged releases. CI builds work without any secrets configured.

### Local signed build

```bash
export MACOS_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
./scripts/build-app.sh
# or sign an existing build:
./scripts/sign-and-notarize.sh
```

## License

Copyright © 2026 New Day Naz

This project is licensed under the **GNU General Public License v3.0 or later** (GPL-3.0-or-later). See [LICENSE](LICENSE) for the full text.

You are free to use, modify, and distribute this software under the terms of the GPL. If you distribute a modified version, you must also make your source code available under the same license.
