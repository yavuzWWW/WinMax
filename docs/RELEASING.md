# Releasing WinMax

## Release requirements

A public production release should satisfy all of the following:

- `./scripts/check.sh` passes.
- The executable contains both `arm64` and `x86_64`.
- The Git tag exactly matches `CFBundleShortVersionString` (`v1.0.0` ↔ `1.0.0`).
- The app and DMG are Developer ID signed and Apple-notarized for warning-free public distribution.
- SHA-256 checksums are published with the release.

## Development release

The repository builds on `macos-15` in GitHub Actions. A tag matching `v*` creates a GitHub Release containing:

- `WinMax-x.y.z.dmg`
- `WinMax-x.y.z.zip`
- `SHA256SUMS.txt`

If no Apple Developer certificate is configured, CI uses ad-hoc signing. That build is useful for testing but should not be described as a notarized production release.

## Signed and notarized production release

Use an Apple Developer account and a **Developer ID Application** certificate. Configure these GitHub repository secrets:

- `MACOS_CERTIFICATE_BASE64` — exported `.p12` certificate encoded with base64
- `MACOS_CERTIFICATE_PASSWORD` — password used when exporting the `.p12`
- `MACOS_KEYCHAIN_PASSWORD` — temporary CI keychain password
- `APPLE_ID` — Apple ID used for notarization
- `APPLE_TEAM_ID` — Apple Developer Team ID
- `APPLE_APP_PASSWORD` — app-specific password for notarization

Then update `Info.plist`, commit the release version and push the matching tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The workflow imports the certificate, builds the Universal executable, signs WinMax with hardened runtime, submits it to Apple's notarization service, staples the ticket, packages the DMG/ZIP and publishes the GitHub Release.

## Local package

```bash
./scripts/package.sh
```

Artifacts are written to `dist/` and the DMG is verified with `hdiutil verify`.
