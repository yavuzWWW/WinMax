# WinMax

**Windows-style maximize and restore for macOS.**

[![Build](https://github.com/yavuzWWW/WinMax/actions/workflows/build.yml/badge.svg)](https://github.com/yavuzWWW/WinMax/actions/workflows/build.yml)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-111111?logo=apple)](https://support.apple.com/macos)
[![Universal](https://img.shields.io/badge/Universal-arm64%20%2B%20x86__64-111111)](#compatibility)
[![License: MIT](https://img.shields.io/badge/License-MIT-111111)](LICENSE)

WinMax replaces the macOS green-button fullscreen action with a normal desktop maximize/restore action. A maximized window fills the usable display but stays in the current desktop, so other windows and dialogs can still appear above it and the Dock/menu bar remain part of the normal desktop workflow.

**Built by [Vast Hosting](https://vasthosting.cloud). Free and open source.**

## Why WinMax

macOS native fullscreen moves a window into a separate Space. WinMax is for users who want the more traditional Windows-style behavior: maximize the window on the current desktop, then restore it to its previous size.

WinMax does **not** replace Apple's WindowServer. It intercepts configured fullscreen/window-control actions and uses macOS Accessibility APIs to resize ordinary windows.

## Features

- **Green button → maximize / restore** instead of entering a separate fullscreen Space.
- **Double-click title bar → maximize / restore**.
- **Control + Command + F → maximize / restore** instead of native fullscreen.
- **Drag a WinMax-maximized title bar away → restore** for a Windows-like workflow.
- Attempts to **leave existing native fullscreen** before applying desktop maximize.
- Keeps other normal windows and dialogs able to appear above a maximized window.
- Respects the current display's menu bar and Dock.
- Multi-display support.
- Launch at login.
- Per-feature switches and a global pause control.
- Local rotating debug logs with privacy-safe diagnostics.
- No analytics, advertising or telemetry.
- Universal release build for Apple Silicon and Intel Macs.

## Install

### GitHub Release

1. Open **Releases** and download the latest `WinMax-x.y.z.dmg`.
2. Open the DMG and drag **WinMax** to **Applications**.
3. Open WinMax.
4. Select **Grant Access**.
5. Enable WinMax in **System Settings → Privacy & Security → Accessibility**.
6. Return to WinMax. The status should show **WinMax is active**.

A production release should be Developer ID signed and Apple-notarized. Development/ad-hoc builds may require macOS's manual Open flow and can require Accessibility permission again after rebuilding.

### Build from source

Requirements: macOS 13+ and Xcode Command Line Tools or Xcode.

```bash
git clone https://github.com/yavuzWWW/WinMax.git
cd WinMax
./install.sh
```

Or build without installing:

```bash
./build.sh
open build/WinMax.app
```

## Usage

| Action | Result |
|---|---|
| Click green button | Maximize / restore |
| Double-click title bar | Maximize / restore |
| `Control + Command + F` | Maximize / restore |
| Drag maximized title bar away | Restore and continue dragging |
| Menu bar → Enabled | Pause/resume WinMax |
| Menu bar → Open WinMax | Settings and diagnostics |

## Compatibility

- **macOS:** 13 Ventura or newer
- **CPU:** Apple Silicon (`arm64`) and Intel (`x86_64`)
- **Windows:** standard Accessibility-exposed, resizable macOS windows

Applications with completely custom window chrome, games, protected system surfaces, fixed-size windows or controls that do not expose a standard Accessibility zoom button may not support every override.

## Privacy and security

WinMax needs Accessibility access only to identify window controls and change window geometry. The app contains no telemetry, advertising, account system, updater or network client. Debug logs stay local and intentionally omit window titles and document contents.

See [Security model](docs/SECURITY_MODEL.md) and [Security policy](SECURITY.md).

## Troubleshooting

Open WinMax and use **Copy diagnostics**, then see [Troubleshooting](docs/TROUBLESHOOTING.md). Logs are stored at:

```text
~/Library/Logs/WinMax/winmax.log
```

## Development

```bash
./scripts/check.sh
```

The check builds a Universal app, validates the plist and signature, and verifies both supported architectures. Pull requests are also built on GitHub Actions.

See [CONTRIBUTING.md](CONTRIBUTING.md) and [Architecture](docs/ARCHITECTURE.md).

## Releases

Release tags such as `v1.0.0` are validated against `Info.plist`. The release workflow builds a Universal app, optionally signs/notarizes it, creates DMG/ZIP artifacts and publishes SHA-256 checksums.

See [Release documentation](docs/RELEASING.md).

## Uninstall

```bash
./uninstall.sh
```

Remove settings and logs too:

```bash
./uninstall.sh --purge
```

## License

WinMax is released under the [MIT License](LICENSE).

---

WinMax is a Vast Hosting open-source project.
