# Contributing to WinMax

WinMax should remain a lightweight, native and privacy-safe macOS utility. Focused bug fixes and improvements are welcome.

## Requirements

- macOS 13+
- Xcode Command Line Tools or Xcode

Run the production validation before opening a PR:

```bash
./scripts/check.sh
```

The build must stay Universal (`arm64` + `x86_64`) and warning-free.

## Pull requests

- Keep observable behavior changes explicit.
- Include the macOS version and hardware architecture used for manual testing.
- For window-management bugs, identify the affected application and action (green button, Snap zone, restore, etc.).
- For Menu Vault bugs, identify the owning app but do not paste sensitive status-item content unless necessary.
- Include **Copy diagnostics** output when useful.
- Do not add telemetry, tracking or advertising.
- Do not log window titles, document contents, Menu Vault labels or keystroke text.
- Avoid runtime dependencies unless they clearly reduce security or maintenance risk.
- Keep Accessibility scans bounded; do not block the main UI on broad process enumeration.

## Architecture rules

- Keep one CoreGraphics event tap unless there is a demonstrated technical requirement for another.
- Maximize and Snap must share `WindowLayoutStore` restore state.
- Snap target math belongs in `SnapGeometry` so it can be tested without Accessibility.
- Menu Vault must not treat the normal application `AXMenuBar` as status-item overflow.

## Security

Do not file sensitive vulnerability details publicly. Follow [SECURITY.md](SECURITY.md).
