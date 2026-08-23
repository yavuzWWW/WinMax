#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "${WINMAX_SKIP_BUILD:-0}" != "1" ]]; then
  "$ROOT/scripts/build.sh"
fi

APP="$ROOT/build/WinMax.app"
[[ -d "$APP" ]] || { echo "WinMax.app not found. Build the app first." >&2; exit 1; }

DIST="$ROOT/dist"
STAGE="$ROOT/build/dmg"
WORK="$ROOT/build/dmg-work"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$DIST/WinMax-$VERSION.dmg"
ZIP="$DIST/WinMax-$VERSION.zip"
RW_DMG="$WORK/WinMax-rw.dmg"
BACKGROUND="$WORK/WinMax-DMG.png"
STYLE_SCRIPT="$WORK/style-dmg.applescript"
VOLUME="WinMax $VERSION"

rm -rf "$DIST" "$STAGE" "$WORK"
mkdir -p "$DIST" "$STAGE" "$WORK"
cp -R "$APP" "$STAGE/WinMax.app"
ln -s /Applications "$STAGE/Applications"
mkdir -p "$STAGE/.background"
xcrun swift "$ROOT/scripts/generate-dmg-background.swift" "$BACKGROUND"
cp "$BACKGROUND" "$STAGE/.background/background.png"

hdiutil create \
  -volname "$VOLUME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDRW \
  "$RW_DMG" >/dev/null

MOUNT_POINT="$(hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen | awk '/\/Volumes\// {sub(/^.*\/Volumes\//, "/Volumes/"); print; exit}')"

if [[ -n "$MOUNT_POINT" && -d "$MOUNT_POINT" ]]; then
  cat > "$STYLE_SCRIPT" <<EOF
tell application "Finder"
  tell disk "$VOLUME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {100, 100, 820, 530}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 92
    set text size of viewOptions to 13
    set background picture of viewOptions to file ".background:background.png"
    set position of item "WinMax.app" of container window to {220, 235}
    set position of item "Applications" of container window to {500, 235}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
EOF

  /usr/bin/osascript "$STYLE_SCRIPT" &
  STYLE_PID=$!
  (
    sleep 8
    if kill -0 "$STYLE_PID" 2>/dev/null; then
      echo "Warning: Finder styling timed out; using standard DMG layout." >&2
      kill -TERM "$STYLE_PID" 2>/dev/null || true
    fi
  ) &
  WATCHDOG_PID=$!

  if wait "$STYLE_PID"; then
    :
  else
    echo "Warning: Finder styling was unavailable; using standard DMG layout." >&2
  fi
  kill "$WATCHDOG_PID" 2>/dev/null || true
  wait "$WATCHDOG_PID" 2>/dev/null || true

  sync
  hdiutil detach "$MOUNT_POINT" -quiet || hdiutil detach "$MOUNT_POINT" -force -quiet
else
  echo "Warning: could not mount writable DMG for Finder styling; continuing with standard layout." >&2
fi

hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
hdiutil verify "$DMG"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
shasum -a 256 "$DMG" "$ZIP" > "$DIST/SHA256SUMS.txt"

printf '\nRelease files:\n%s\n%s\n%s\n' "$DMG" "$ZIP" "$DIST/SHA256SUMS.txt"
