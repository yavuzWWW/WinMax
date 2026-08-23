#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/WinMax.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
TEMP="$BUILD_DIR/universal"

VERSION="${WINMAX_VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Info.plist")}"
BUILD_NUMBER="${WINMAX_BUILD:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT/Info.plist")}"
IDENTITY="${CODE_SIGN_IDENTITY:--}"
SDK="$(xcrun --sdk macosx --show-sdk-path)"

rm -rf "$APP" "$TEMP"
mkdir -p "$MACOS" "$RESOURCES" "$TEMP"
cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"
ICONSET="$TEMP/WinMax.iconset"
xcrun swift "$ROOT/scripts/generate-icon.swift" "$ICONSET"
iconutil -c icns "$ICONSET" -o "$RESOURCES/WinMax.icns"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$CONTENTS/Info.plist"

SOURCE_FILES=("$ROOT"/Sources/*.swift)

for ARCH in arm64 x86_64; do
  echo "Building $ARCH…"
  xcrun swiftc \
    -swift-version 5 \
    -O \
    -whole-module-optimization \
    -target "$ARCH-apple-macos13.0" \
    -sdk "$SDK" \
    "${SOURCE_FILES[@]}" \
    -framework Cocoa \
    -framework ApplicationServices \
    -framework CoreGraphics \
    -framework ServiceManagement \
    -o "$TEMP/WinMax-$ARCH"
done

lipo -create \
  "$TEMP/WinMax-arm64" \
  "$TEMP/WinMax-x86_64" \
  -output "$MACOS/WinMax"

if [[ "$IDENTITY" == "-" ]]; then
  codesign --force --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
fi

codesign --verify --deep --strict --verbose=2 "$APP"
ARCHS="$(lipo -archs "$MACOS/WinMax")"
[[ "$ARCHS" == *arm64* && "$ARCHS" == *x86_64* ]] || { echo "Universal build verification failed: $ARCHS" >&2; exit 1; }

printf '\nBuilt WinMax %s (%s) [%s]\n%s\n' "$VERSION" "$BUILD_NUMBER" "$ARCHS" "$APP"
