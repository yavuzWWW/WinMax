#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build.sh"

APP="$ROOT/build/WinMax.app"
DIST="$ROOT/dist"
STAGE="$ROOT/build/dmg"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$DIST/WinMax-$VERSION.dmg"
ZIP="$DIST/WinMax-$VERSION.zip"

rm -rf "$DIST" "$STAGE"
mkdir -p "$DIST" "$STAGE"
cp -R "$APP" "$STAGE/WinMax.app"
ln -s /Applications "$STAGE/Applications"

hdiutil create \
  -volname "WinMax $VERSION" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

hdiutil verify "$DMG"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
shasum -a 256 "$DMG" "$ZIP" > "$DIST/SHA256SUMS.txt"

printf '\nRelease files:\n%s\n%s\n%s\n' "$DMG" "$ZIP" "$DIST/SHA256SUMS.txt"
