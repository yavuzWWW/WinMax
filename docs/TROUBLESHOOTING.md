# Troubleshooting

## WinMax says Accessibility permission is required

Open **System Settings → Privacy & Security → Accessibility**, enable WinMax, then quit and reopen WinMax. Development/ad-hoc builds can require permission to be granted again after rebuilding because their code signature changes.

## The green button still opens native fullscreen

- Confirm **Green button = maximize** is enabled in WinMax.
- Confirm the menu-bar status says **Active**.
- Quit and reopen both WinMax and the affected application.
- Some applications use custom title bars that do not expose a standard Accessibility zoom button.

## A window will not resize

WinMax only changes windows whose Accessibility size attribute is settable. Fixed-size dialogs, games, protected system surfaces and custom window implementations can reject resizing.

## A window is already in Apple's fullscreen Space

Trigger WinMax maximize on that window. WinMax attempts to leave native fullscreen first, then maximizes the restored window on the normal desktop.

## Multi-monitor behavior

WinMax chooses the display containing the window center. If the center is outside every display, it chooses the display with the largest intersection with the window. The maximize frame respects that display's Dock and menu bar.

## Logs

Logs are stored locally at:

```text
~/Library/Logs/WinMax/winmax.log
```

WinMax does not log window titles or document contents.
