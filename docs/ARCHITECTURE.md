# Architecture

WinMax is a native Swift/AppKit menu-bar utility. It intentionally avoids runtime dependencies, helper daemons, webviews and network services.

## Runtime components

- `AppDelegate.swift` — lifecycle and primary WinMax status menu.
- `WindowController.swift` — the **single** CoreGraphics session event tap, keyboard shortcuts and Accessibility window operations.
- `WindowLayoutStore.swift` — shared in-memory restore state for maximized and snapped windows.
- `AeroSnapManager.swift` — drag sessions and preview UI. It receives mouse events from `WindowController`; it does not install a second event tap.
- `SnapGeometry.swift` — pure edge/corner target calculations, independently tested by CI.
- `MenuVaultController.swift` — Menu Vault status item, panel, background Accessibility scanner and fresh item re-resolution.
- `SettingsStore.swift` — persistent preferences in `UserDefaults`.
- `SettingsWindowController.swift` / `OnboardingWindowController.swift` — Vast Hosting-styled native UI.
- `LaunchAtLoginManager.swift` — `SMAppService` registration.
- `WinMaxLogger.swift` / `Diagnostics.swift` — bounded local diagnostics.

## Window interception

After Accessibility permission is granted, `WindowController` creates one `.cgSessionEventTap` for configured left-mouse and key-down events. It resolves the Accessibility element under the pointer and walks to the owning window.

The event tap consumes only interactions WinMax intentionally replaces, such as the green zoom button and configured fullscreen shortcut. Other mouse/key events continue to the target application.

## Shared layout state

Maximize and Aero Snap use `WindowLayoutStore` rather than separate restore dictionaries. A state records:

- owning process ID
- normal restore frame
- frame last applied by WinMax
- current managed mode (`maximized` or a Snap zone)

Before reusing a state, WinMax compares the real window frame with the managed frame. If the user or application manually moved/resized the window, that stale state is discarded. Process termination also removes associated states.

This prevents maximize, Snap and manual resizing from fighting over an outdated restore rectangle.

## Aero Snap

On a single title-bar mouse-down, `WindowController` starts an Aero Snap session. `AeroSnapManager` observes subsequent drag/up events through that same event tap.

If a WinMax-managed window is dragged away, it first returns to its stored normal size under the pointer. `SnapGeometry` selects the destination using the pointer and the display's full/visible Accessibility-coordinate frames. The preview is mouse-transparent and never steals focus.

At mouse-up, the current normal frame is stored and the target frame is applied. Multi-display selection uses the screen containing the pointer, with a nearest-screen fallback at exact display boundaries.

## Menu Vault

Menu Vault deliberately scans only `AXExtrasMenuBar`, which represents status-item extras. It does **not** fall back to the normal `AXMenuBar` because that would incorrectly index File/Edit/application menus.

Scanning runs on a serial background queue and applies a short Accessibility messaging timeout per process. Items are represented by a locator made from the owning bundle/process, ordinal and available Accessibility identity fields. Raw Accessibility element references are not kept as long-lived item identity.

When the user selects an item, WinMax resolves the current process and current `AXExtrasMenuBar` again, scores fresh candidates against the stored identity, and only then performs `AXPress`. This handles status items recreated by their owning application.

Items without a visible frame are still indexed when Accessibility exposes them, which is important for crowded/notched menu bars.

## Coordinates and displays

Accessibility window coordinates use a top-origin global space while AppKit screen frames use the Cocoa screen coordinate system. WinMax converts `NSScreen.frame` and `visibleFrame` into Accessibility coordinates before window layout calculations.

`visibleFrame` is used for maximize/Snap destinations so the Dock and menu bar remain respected.

## Security boundaries

WinMax does not open sockets or call remote APIs. Accessibility-derived labels can exist transiently in Menu Vault memory for display/search but are not written to diagnostics/log files or transmitted.

See [SECURITY_MODEL.md](SECURITY_MODEL.md).
