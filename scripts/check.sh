#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

plutil -lint "$ROOT/Info.plist"
for file in "$ROOT"/Sources/*.swift; do
  xcrun swiftc -swift-version 5 -parse "$file"
done

"$ROOT/scripts/build.sh"

APP="$ROOT/build/WinMax.app"
EXECUTABLE="$APP/Contents/MacOS/WinMax"
ARCHS="$(lipo -archs "$EXECUTABLE")"
[[ "$ARCHS" == *arm64* && "$ARCHS" == *x86_64* ]]
codesign --verify --deep --strict "$APP"

echo "All checks passed. Universal architectures: $ARCHS"
