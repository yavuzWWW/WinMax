# Contributing to WinMax

Focused bug fixes and improvements are welcome. WinMax should remain a lightweight native macOS utility with no unnecessary runtime dependencies.

## Development

Requirements:

- macOS 13 or newer
- Xcode Command Line Tools or Xcode

Run the full validation before opening a pull request:

```bash
./scripts/check.sh
```

The build must remain Universal (`arm64` + `x86_64`).

## Pull requests

- Keep changes small and readable.
- Explain observable behavior changes.
- Include the macOS version used for manual testing.
- For window-management bugs, name the affected application and attach **Copy diagnostics** output when useful.
- Do not add telemetry.
- Do not log window titles, document contents or keystroke text.
- Avoid new dependencies unless they clearly reduce risk or maintenance burden.

## Security

Do not file sensitive vulnerability details publicly. Follow [SECURITY.md](SECURITY.md).
