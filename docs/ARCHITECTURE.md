# Architecture

WinMax is intentionally small and framework-free.

## Components

- `AppDelegate.swift` — app lifecycle and menu-bar UI.
- `WindowController.swift` — CoreGraphics event tap and Accessibility window operations.
- `SettingsWindowController.swift` — Vast Hosting-styled settings/onboarding UI.
- `SettingsStore.swift` — persistent preferences in `UserDefaults`.
- `LaunchAtLoginManager.swift` — macOS `SMAppService` login registration.
- `WinMaxLogger.swift` — bounded local logging.
- `Diagnostics.swift` — copyable runtime information for bug reports.

## Window interception

WinMax installs a session-level CoreGraphics event tap after Accessibility permission is granted. On a mouse-down event it resolves the Accessibility element under the cursor and walks up to its owning window. This avoids relying only on the currently focused window.

If the click is inside that window's standard Accessibility zoom button, the click sequence is consumed and WinMax resizes the window to the display's `visibleFrame`. Clicking again restores the frame WinMax stored before maximizing.

The title-bar double-click and default macOS fullscreen shortcut use the same maximize/restore path.

## Security model

WinMax is a local menu-bar application. It does not open listening sockets, call remote APIs, upload logs, inspect document contents, or store Accessibility data. It only keeps previous window rectangles in memory while running.

## Build assets

The application icon is generated during the macOS build from `scripts/generate-icon.swift`. This keeps the repository source-only and makes the shipped icon reproducible from audited source. Vast Hosting branding in the settings UI uses native typography and the WinMax symbol rather than loading remote assets.
