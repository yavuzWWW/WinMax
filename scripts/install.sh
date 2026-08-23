#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build.sh"

APP="$ROOT/build/WinMax.app"
DEST="/Applications/WinMax.app"

osascript <<'APPLESCRIPT'
display dialog "WinMax will be installed in Applications.\n\nAfter launch, macOS will ask for Accessibility permission so WinMax can control window sizes." buttons {"Cancel", "Install"} default button "Install" with title "Install WinMax" with icon note
APPLESCRIPT

pkill -x WinMax 2>/dev/null || true
rm -rf "$DEST"
ditto "$APP" "$DEST"
open "$DEST"

echo "Installed: $DEST"
