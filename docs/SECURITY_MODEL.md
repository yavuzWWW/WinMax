# Security and privacy model

WinMax is intentionally small and dependency-light.

## Accessibility permission

macOS Accessibility permission is required to discover standard window controls and change window position/size in other applications. WinMax does not bypass macOS permission prompts.

## Event interception

WinMax installs a CoreGraphics session event tap for left-mouse events and key-down events. It consumes only configured window-control interactions such as the green button and the native fullscreen shortcut. Other events are passed through.

## Network behavior

The application does not contain analytics, telemetry, advertising, an updater, an account system or a network client.

## Logs

Debug logs stay in the user's Library directory. Window titles and document contents are intentionally excluded. Logs rotate locally to prevent unbounded growth.

## Distribution

Production releases should be signed with a Developer ID Application certificate and notarized by Apple. GitHub release artifacts include SHA-256 checksums. Unsigned/ad-hoc development builds are supported for source builds but should not be represented as notarized production releases.
