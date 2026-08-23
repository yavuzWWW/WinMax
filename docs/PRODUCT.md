# WinMax product model

WinMax is a native macOS desktop utility built around a small number of high-quality desktop-control capabilities rather than a large collection of unrelated tweaks.

## Product promise

**Make macOS work more like a traditional desktop without replacing macOS.**

The product should stay:

- native Swift/AppKit/CoreGraphics/Accessibility
- fast while idle
- understandable from one Settings window
- privacy-first
- dependency-light
- reversible: window operations should preserve a sensible way back to the user's previous layout
- honest about macOS limitations

## Current capabilities

The current public product is one edition. No existing feature is paywalled.

- Desktop Maximize
- Aero Snap
- Menu Vault
- Launch at Login
- Diagnostics and permission recovery

`WinMaxFeatureCatalog` is metadata, not an authorization system. It exists so UI, documentation, a future website and a future licensing layer can refer to stable feature identifiers without scattering product names or entitlement checks through window-control code.

## Future editions

If a paid WinMax edition is introduced later:

1. Existing core behavior should not silently disappear from already released versions.
2. Licensing must sit behind a dedicated entitlement service, not direct `if pro` checks across controllers.
3. Window-control engines must remain usable and testable independently of licensing.
4. The app must have a useful free/core experience.
5. Purchase/account networking must be documented separately from local desktop functionality.

Potential advanced capabilities include custom snap zones, saved layouts, per-app rules, multi-display profiles and advanced Menu Vault organization. These are product candidates, not commitments.

## Product identity

Canonical product metadata lives in `Sources/ProductInfo.swift`.

Do not duplicate official URLs, product/company names or feature identifiers throughout controllers when they can be referenced centrally.

The current relationship is:

- Product: **WinMax**
- Publisher/brand: **Vast Hosting**
- Repository: `yavuzWWW/WinMax`

A future dedicated WinMax website can replace the product website URL centrally without changing window-control logic.

## Network policy

Core window management and Menu Vault must not depend on a network connection.

Any network capability must be:

- explicit about what it contacts
- isolated from Accessibility/window data
- documented in the security model
- non-blocking for core features

The current update check is user initiated and queries only the official GitHub Releases API.

## Release quality

A production WinMax release requires:

- warnings-as-errors Swift build
- deterministic pure-logic regression tests
- Universal `arm64 + x86_64` bundle
- code-signature validation
- no unexpected user/Homebrew runtime dependencies
- validated DMG/ZIP/checksums
- matching release tag and app version
- Developer ID signing and Apple notarization before calling a build warning-free for normal public distribution

## Website readiness

The future website should consume the same stable product concepts used by the app:

- WinMax name/tagline
- current release/version
- Desktop Maximize
- Aero Snap
- Menu Vault
- privacy/security model
- compatibility
- release notes

The website should describe real shipped behavior. Marketing must not claim access to every macOS menu-bar item, universal app compatibility, Apple notarization, or paid features unless those claims are true for the current release.
