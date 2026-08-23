# Troubleshooting

## Accessibility is enabled but WinMax still says permission is required

First quit and reopen `/Applications/WinMax.app`. Make sure you are not running a second copy directly from the DMG.

If System Settings visibly shows WinMax enabled but `AXIsProcessTrusted()` still remains false, macOS can have a stale TCC entry. Reset only WinMax's Accessibility record:

```bash
pkill WinMax 2>/dev/null || true
tccutil reset Accessibility cloud.vasthosting.winmax
open /Applications/WinMax.app
```

Then enable WinMax again in **System Settings → Privacy & Security → Accessibility** and reopen it once if macOS requests that.

## Green button still opens native fullscreen

- Confirm **Green button = maximize** is enabled.
- Confirm WinMax shows **Active**.
- Quit/reopen WinMax and the affected app.
- Some apps use custom title bars that do not expose a standard Accessibility zoom button.

## Aero Snap does not trigger

- Confirm **Aero Snap** is enabled in Settings.
- Drag from the actual title-bar region of a resizable window.
- Move the pointer all the way to a display edge/corner before releasing.
- Fixed-size or protected windows can reject geometry changes.

A translucent preview should appear before release. If no preview appears for one specific application, that app may use custom window chrome that WinMax cannot identify as a standard title bar.

## A snapped/maximized window restores to the wrong size

WinMax stores one shared normal frame for maximize and Snap. If a window was manually resized while managed, the stale state should be invalidated automatically. If an app aggressively changes its own geometry, restore it manually once and reproduce the issue with **Copy diagnostics** output.

## Menu Vault is empty

Menu Vault shows only status items exposed by their owning process through macOS Accessibility `AXExtrasMenuBar`.

- Confirm Accessibility is granted.
- Confirm **Menu Vault** is enabled.
- Press **Refresh** in the Vault.
- Try `Control + Option + Command + V` if the Vault icon itself is hard to reach.

Some protected system items and custom third-party menu-bar implementations are not exposed by macOS and therefore cannot be listed safely through public APIs.

## Menu Vault shows an item but it no longer opens

The owning application may have recreated or removed its status item. Menu Vault re-resolves the item before activation; press **Refresh** if the app was just restarted.

## Multi-monitor behavior

Maximize uses the display containing the window center. Aero Snap uses the display containing the pointer while dragging. Target frames respect that display's `visibleFrame`, including menu-bar/Dock reservations.

## Logs

Logs remain local:

```text
~/Library/Logs/WinMax/winmax.log
```

WinMax does not log window titles, document contents, Menu Vault labels or keystroke text.
