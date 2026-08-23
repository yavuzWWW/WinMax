# Changelog

All notable WinMax changes are recorded here.

## 1.1.0 — 2026-08-23

### Added

- Windows-style **Aero Snap** for left/right halves, four quarter-screen corners and top-edge maximize.
- Live mouse-transparent Snap preview using the Vast Hosting accent.
- Shared maximize/Snap restore state with stale-state invalidation after manual window geometry changes.
- **Menu Vault**, a searchable and scrollable panel for Accessibility-exposed menu-bar status items.
- Dedicated Menu Vault status item and global `Control + Option + Command + V` shortcut.
- Background Menu Vault scanning with bounded Accessibility messaging timeouts.
- Fresh status-item re-resolution before `AXPress` activation to avoid stale Accessibility references.
- Dedicated Menu Vault settings and expanded first-run onboarding.
- Deterministic Snap geometry tests in the CI production gate, including trigger boundaries and negative-coordinate displays.

### Changed

- Consolidated window drag observation onto WinMax's existing CoreGraphics event tap instead of installing a second Snap event tap.
- Settings now use a scrollable native layout and separate Window Control / Menu Bar sections.
- Launch-at-login UI now treats macOS `requiresApproval` as a pending enabled request instead of repeatedly registering it.
- WinMax now prohibits multiple simultaneous app instances, reducing duplicate DMG/Application launches and Accessibility identity conflicts.
- Build validation treats Swift warnings as errors and checks for unexpected user/Homebrew dynamic dependencies.
- DMG/ZIP packaging now includes stronger cleanup, extraction and checksum verification.
- GitHub Actions uses the current checkout runtime for permanent build/release workflows.
- Repository documentation and release guidance were refreshed for the expanded WinMax product.

### Privacy and safety

- Menu Vault deliberately scans `AXExtrasMenuBar`, not normal File/Edit application menus.
- Off-screen/no-frame status items may be indexed when Accessibility exposes them; unsupported protected/custom items are reported as a macOS limitation rather than guessed.
- Menu Vault labels remain in-memory only and are excluded from logs/diagnostics.

## 1.0.1 — 2026-08-23

### Fixed

- Fixed the first-run Accessibility step getting stuck after permission was granted in System Settings.
- The onboarding wizard now polls Accessibility trust live and automatically advances once WinMax receives permission.

## 1.0.0 — 2026-08-23

### Added

- Windows-style green-button maximize/restore override.
- Double-click title-bar maximize/restore.
- `Control + Command + F` fullscreen-shortcut override.
- Restore-on-title-bar-drag behavior for WinMax-maximized windows.
- Existing native-fullscreen recovery before desktop maximize.
- Multi-display visible-frame handling.
- Vast Hosting-branded settings interface.
- Dedicated first-run setup wizard with an Accessibility permission walkthrough.
- Branded drag-to-Applications DMG installer experience.
- Accessibility permission status and onboarding.
- Launch-at-login support.
- Menu-bar controls, including an option to run setup again.
- Local rotating diagnostics logs.
- Universal Apple Silicon + Intel builds.
- DMG/ZIP packaging and SHA-256 checksums.
- GitHub Actions build and release workflows.

### Privacy

- Window titles and document names are excluded from debug descriptions/logs.
- No telemetry or analytics.
