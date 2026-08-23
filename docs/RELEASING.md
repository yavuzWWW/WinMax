# Releasing WinMax

## Release gate

A public release must satisfy:

- `./scripts/check.sh` passes on the repository's macOS CI runner.
- Swift warnings are treated as errors.
- deterministic Snap geometry tests pass.
- executable contains both `arm64` and `x86_64`.
- no unexpected Homebrew/user-directory dynamic libraries are linked.
- bundle identifier/minimum macOS checks pass.
- DMG verifies with `hdiutil verify`.
- ZIP extracts to a valid signed WinMax app.
- generated SHA-256 checksums validate.
- Git tag exactly matches `CFBundleShortVersionString` (`v1.1.0` ↔ `1.1.0`).

Because GitHub Actions cannot grant macOS Accessibility permission interactively, CI validates compilation, packaging and pure logic. Accessibility-driven behavior should also receive manual smoke testing on a Mac before calling a build broadly verified at runtime.

## Signed and notarized release

For warning-free distribution configure:

- `MACOS_CERTIFICATE_BASE64`
- `MACOS_CERTIFICATE_PASSWORD`
- `MACOS_KEYCHAIN_PASSWORD`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_PASSWORD`

The release workflow imports a **Developer ID Application** identity, builds with hardened runtime, notarizes/staples the app, packages it, notarizes/staples the DMG, then publishes:

- `WinMax-x.y.z.dmg`
- `WinMax-x.y.z.zip`
- `SHA256SUMS.txt`

If signing credentials are absent, CI intentionally falls back to ad-hoc signing for testing. Such a release must not be described as Apple-notarized.

## Normal release flow

1. Finish changes on a PR.
2. Require green `Build` CI.
3. Update `Info.plist`, `CHANGELOG.md`, README/docs.
4. Run CI again on the exact release candidate.
5. Merge to `main`.
6. Verify the `main` build.
7. Create/push the matching `vX.Y.Z` tag.
8. Verify GitHub Release assets and signing/notarization job steps.

## Local validation

```bash
./scripts/check.sh
./scripts/package.sh
```

Artifacts are written to `dist/`.
