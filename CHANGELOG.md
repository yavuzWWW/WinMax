# Changelog

All notable WinMax changes are recorded here.

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
