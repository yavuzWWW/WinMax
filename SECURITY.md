# Security Policy

## Supported versions

Security fixes are provided for the latest WinMax release. Users should reproduce security issues against the latest version before reporting them.

## Security model

WinMax requires macOS Accessibility permission because changing another application's window geometry is an Accessibility operation. It does not bypass the permission system and does not transmit Accessibility data or logs over the network. See [docs/SECURITY_MODEL.md](docs/SECURITY_MODEL.md).

## Reporting a vulnerability

Do not publish exploit details, private information or sensitive proof-of-concept material in a public issue. Use GitHub's private security-reporting feature if it is enabled for this repository. If private reporting is unavailable, open a minimal issue asking a maintainer for a private reporting channel without including vulnerability details.

Reports should include the affected WinMax version, macOS version, impact, reproduction conditions and any mitigations already tested.
