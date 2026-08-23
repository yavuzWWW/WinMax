#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
mkdir -p "$BUILD"

plutil -lint "$ROOT/Info.plist"

for file in "$ROOT"/Sources/*.swift; do
  xcrun swiftc -swift-version 5 -warnings-as-errors -parse "$file"
done

xcrun swiftc \
  -swift-version 5 \
  -warnings-as-errors \
  "$ROOT/Sources/SnapGeometry.swift" \
  "$ROOT/scripts/test-snap-geometry.swift" \
  -o "$BUILD/snap-geometry-tests"
"$BUILD/snap-geometry-tests"

"$ROOT/scripts/build.sh"

APP="$BUILD/WinMax.app"
EXECUTABLE="$APP/Contents/MacOS/WinMax"
ARCHS="$(lipo -archs "$EXECUTABLE")"
[[ "$ARCHS" == *arm64* && "$ARCHS" == *x86_64* ]]
codesign --verify --deep --strict "$APP"

# otool prints the executable path as a non-indented architecture header for
# universal binaries. Only indented rows are actual linked dependencies.
if otool -L "$EXECUTABLE" | grep -E '^[[:space:]]+(/usr/local/|/opt/homebrew/|/Users/)' >/dev/null; then
  echo "Unexpected non-system dynamic dependency detected:" >&2
  otool -L "$EXECUTABLE" >&2
  exit 1
fi

[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" == "cloud.vasthosting.winmax" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist")" == "13.0" ]]

echo "All checks passed. Universal architectures: $ARCHS"
