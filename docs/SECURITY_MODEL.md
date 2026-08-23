# Security and privacy model

WinMax is a local native utility with no runtime dependencies or network client.

## Accessibility permission

macOS Accessibility permission is required to:

- identify standard window controls
- read/set supported window position and size
- discover status items exposed through `AXExtrasMenuBar`
- activate a selected Menu Vault item with `AXPress`

WinMax does not bypass Apple's permission system. Screen Recording is not required.

## Event interception

WinMax uses one CoreGraphics session event tap for left-mouse events and the small set of global shortcuts it implements. It consumes only configured WinMax interactions. Normal input is passed through.

WinMax does **not** log typed text or general key sequences.

## Menu Vault data

Menu Vault can temporarily read Accessibility labels/descriptions needed to show and search status items. The scanner runs locally. Those labels are not written to logs, diagnostics, preferences or network destinations.

WinMax intentionally uses `AXExtrasMenuBar` only and does not crawl ordinary application File/Edit menus.

## Network behavior

The application contains no analytics, advertising, account system, updater or network client.

## Logs

Logs are stored in:

```text
~/Library/Logs/WinMax/
```

They contain runtime state/errors only. Window titles, document names, Menu Vault item labels and keystroke text are excluded. Log rotation prevents unbounded growth.

## Distribution

A warning-free public build requires Developer ID signing and Apple notarization. The release workflow supports this when signing/notarization secrets are configured. Source/development builds fall back to ad-hoc signing and must not be represented as Apple-notarized.

Release artifacts include SHA-256 checksums.
