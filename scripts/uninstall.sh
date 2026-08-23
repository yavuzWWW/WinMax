#!/bin/zsh
set -euo pipefail

APP="/Applications/WinMax.app"
LOGS="$HOME/Library/Logs/WinMax"
PREFS="$HOME/Library/Preferences/cloud.vasthosting.winmax.plist"

pkill -x WinMax 2>/dev/null || true
rm -rf "$APP"

if [[ "${1:-}" == "--purge" ]]; then
  rm -rf "$LOGS"
  rm -f "$PREFS"
  echo "Removed WinMax, settings and logs."
else
  echo "Removed WinMax. Settings/logs were kept. Use --purge to remove them too."
fi
