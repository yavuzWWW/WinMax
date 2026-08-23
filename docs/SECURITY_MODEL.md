# Security and privacy model

WinMax is a native macOS utility with no third-party runtime dependencies, analytics or telemetry.

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

WinMax does not perform analytics, telemetry, advertising requests, account synchronization or background network polling.

The **Check for Updates…** command is an explicit user-initiated network action. When selected, WinMax sends a single HTTPS request to GitHub's public Releases API for `yavuzWWW/WinMax` to read the latest public release tag and release URL. The request includes a `WinMax/<version>` user-agent. WinMax does not send Accessibility data, window data, Menu Vault labels, diagnostics, identifiers or user content with this request.

WinMax does not automatically download or install an update. If a newer version exists, the user can choose to open the official GitHub Release page in their browser.

## Logs

Logs are stored in:

```text
~/Library/Logs/WinMax/
```

They contain runtime state/errors only. Window titles, document names, Menu Vault item labels and keystroke text are excluded. Failed update checks are logged only as a generic failure event; response contents and user data are not logged. Log rotation prevents unbounded growth.

## Distribution

A warning-free public build requires Developer ID signing and Apple notarization. The release workflow supports this when signing/notarization secrets are configured. Source/development builds fall back to ad-hoc signing and must not be represented as Apple-notarized.

Release artifacts include SHA-256 checksums.
