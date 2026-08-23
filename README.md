<div align="center">

# WinMax

### Windows-style desktop control for macOS

**Maximize normally. Snap windows. Reach a crowded menu bar. Stay in your current Space.**

[![Build](https://github.com/yavuzWWW/WinMax/actions/workflows/build.yml/badge.svg)](https://github.com/yavuzWWW/WinMax/actions/workflows/build.yml)
[![Release](https://img.shields.io/github/v/release/yavuzWWW/WinMax?display_name=tag&sort=semver)](https://github.com/yavuzWWW/WinMax/releases/latest)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-111111?logo=apple)](#compatibility)
[![Universal](https://img.shields.io/badge/Universal-arm64%20%2B%20x86__64-111111)](#compatibility)
[![License: MIT](https://img.shields.io/badge/License-MIT-111111)](LICENSE)

Built by **[Vast Hosting](https://vasthosting.cloud)** · Native Swift/AppKit · No telemetry

</div>

---

WinMax is a lightweight native macOS utility for people who prefer a traditional desktop workflow. It replaces the green-button fullscreen jump with normal maximize/restore, adds Windows-style edge snapping, and provides **Menu Vault** for searchable access to Accessibility-exposed menu-bar status items.

WinMax does not replace WindowServer and does not use Electron, a webview, or runtime dependencies. It works through public macOS Accessibility/AppKit/CoreGraphics APIs and stays in the menu bar.

## Highlights

### Desktop maximize

- **Green button → maximize / restore** without creating a separate fullscreen Space.
- **Double-click title bar → maximize / restore**.
- **Control + Command + F → desktop maximize / restore**.
- Drag a WinMax-managed title bar away to return to its previous normal size.
- Attempts to leave an existing Apple fullscreen Space before applying desktop maximize.
- Respects each display's usable area, menu bar and Dock.

### Aero Snap

Drag a normal window to a display edge and release:

| Drag target | Result |
|---|---|
| Left edge | Left 50% |
| Right edge | Right 50% |
| Top edge | Maximize |
| Top-left | Top-left quarter |
| Top-right | Top-right quarter |
| Bottom-left | Bottom-left quarter |
| Bottom-right | Bottom-right quarter |

A translucent preview shows the destination before release. Maximized and snapped windows share one restore history, so dragging between states does not create competing restore behavior.

### Menu Vault

Menu Vault provides a searchable, scrollable view of **status items exposed through macOS Accessibility**.

- Dedicated `•••`-style WinMax Vault item in the menu bar.
- Global **Control + Option + Command + V** shortcut, useful when menu-bar space itself is tight.
- Search by app or status-item label.
- Re-resolves an item's current Accessibility identity before activation instead of storing stale UI references.
- Scans off the main UI thread with bounded Accessibility timeouts.
- Does not require Screen Recording.

> **macOS limitation:** Apple does not provide a public API that guarantees access to every third-party or protected system status item. Menu Vault can only show items that the owning process exposes through `AXExtrasMenuBar`. This is intentionally safer than pretending unsupported items are controllable.

## Install

1. Open **[Releases](https://github.com/yavuzWWW/WinMax/releases/latest)** and download the latest `WinMax-x.y.z.dmg`.
2. Open the DMG and drag **WinMax** to **Applications**.
3. Launch `/Applications/WinMax.app`.
4. Follow the first-run setup and enable WinMax under **System Settings → Privacy & Security → Accessibility**.
5. Return to WinMax. Permission is detected automatically.

Development/ad-hoc builds can require macOS's manual **Open** flow. A Developer ID signed and Apple-notarized build provides the normal warning-free public installation experience.

## Usage

| Action | Result |
|---|---|
| Click green button | Maximize / restore |
| Double-click title bar | Maximize / restore |
| `Control + Command + F` | Maximize / restore |
| Drag title bar to screen edge/corner | Aero Snap |
| Drag a managed window away | Restore normal size and continue dragging |
| Click Menu Vault status item | Open searchable status-item panel |
| `Control + Option + Command + V` | Open/close Menu Vault globally |
| WinMax menu → Window Control Enabled | Pause/resume window overrides |
| WinMax menu → Open WinMax | Settings and diagnostics |

Every major behavior has its own switch in Settings. Pausing **Window Control** does not disable Menu Vault.

## Compatibility

- **macOS:** Ventura 13 or newer
- **CPU:** Apple Silicon (`arm64`) and Intel (`x86_64`)
- **Build:** one Universal application bundle
- **Windows supported:** ordinary Accessibility-exposed macOS windows whose position and size are settable

Fixed-size dialogs, protected system surfaces, games, custom title bars, and apps that do not expose standard Accessibility elements can reject some operations. Menu Vault has the separate Accessibility exposure limitation described above.

## Privacy & security

WinMax is local-only:

- no analytics or telemetry
- no advertising
- no account system
- no updater/network client
- no Screen Recording requirement
- no keystroke text logging
- no window titles, document names, or Menu Vault labels written to logs

Accessibility is used only for window geometry/control and status-item discovery/activation. Debug logs stay in `~/Library/Logs/WinMax/` and rotate locally.

See [Security model](docs/SECURITY_MODEL.md) and [Security policy](SECURITY.md).

## Troubleshooting

Use **Copy diagnostics** in WinMax Settings, then see [Troubleshooting](docs/TROUBLESHOOTING.md).

If Accessibility is visibly enabled in System Settings but WinMax still reports it as denied, macOS may have a stale TCC entry. The troubleshooting guide includes the safe reset command for WinMax's bundle ID.

## Build from source

Requirements: macOS 13+ and Xcode Command Line Tools or Xcode.

```bash
git clone https://github.com/yavuzWWW/WinMax.git
cd WinMax
./scripts/check.sh
./install.sh
```

`./scripts/check.sh` performs the production validation used by CI: source parsing with warnings treated as errors, deterministic Snap geometry tests, Universal build, bundle checks, code-signature validation and external dynamic-dependency checks.

Package locally with:

```bash
./scripts/package.sh
```

This creates a verified DMG, ZIP and `SHA256SUMS.txt` in `dist/`.

## Project structure

```text
Sources/
  WindowController.swift       Core event interception + maximize behavior
  WindowLayoutStore.swift      Shared maximize/Snap restore state
  AeroSnapManager.swift        Drag session + preview
  SnapGeometry.swift           Pure Snap target geometry
  MenuVaultController.swift    Status-item discovery and Vault UI
  SettingsWindowController.swift
  OnboardingWindowController.swift
scripts/
  build.sh
  check.sh
  package.sh
  test-snap-geometry.swift
docs/
```

See [Architecture](docs/ARCHITECTURE.md) for the full design.

## Contributing

Focused native improvements are welcome. Keep WinMax lightweight, privacy-safe and dependency-free unless a dependency clearly reduces risk.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR.

## Releases

Release tags must exactly match `CFBundleShortVersionString`. CI builds and validates both architectures, creates DMG/ZIP artifacts and publishes SHA-256 checksums. Apple signing/notarization is used when the repository's Developer ID credentials are configured.

See [Release documentation](docs/RELEASING.md).

## License

[MIT](LICENSE)

---

<div align="center">

**WinMax · a Vast Hosting open-source project**  
[vasthosting.cloud](https://vasthosting.cloud)

</div>
