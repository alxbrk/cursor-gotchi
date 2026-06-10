#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Cursor Gotchi"
APP_DIR="/Applications/${APP_NAME}.app"
LABEL="com.cursor.token-gotchi.menubar"
PLIST_PATH="$HOME/Library/LaunchAgents/${LABEL}.plist"
INSTALL_DIR="$HOME/.cursor/token-gotchi"

# Stop the old Python menu bar.
pkill -f "$INSTALL_DIR/scripts/menubar.py" 2>/dev/null || true
launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
pkill -f "Cursor Gotchi.app/Contents/MacOS/CursorGotchi" 2>/dev/null || true
rm -f "$INSTALL_DIR/app.lock"
sleep 0.5

# Remove old installs.
rm -rf "$HOME/Applications/Token Gotchi.app" "$HOME/Applications/Cursor Gotchi.app" "/Applications/Token Gotchi.app"

"$REPO_ROOT/scripts/build_mac_app.sh"

# Allow opening unsigned local builds without Gatekeeper blocking.
xattr -cr "$APP_DIR" 2>/dev/null || true

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${APP_DIR}/Contents/MacOS/CursorGotchi</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <dict>
    <key>SuccessfulExit</key>
    <false/>
  </dict>
</dict>
</plist>
EOF

launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null || launchctl kickstart -k "gui/$(id -u)/${LABEL}"

sleep 1
if pgrep -f "Cursor Gotchi.app/Contents/MacOS/CursorGotchi" >/dev/null; then
  echo "Running."
else
  open -a "$APP_DIR"
  sleep 1
  pgrep -f "Cursor Gotchi.app/Contents/MacOS/CursorGotchi" >/dev/null \
    && echo "Running." \
    || echo "Warning: try manually: open -a \"$APP_DIR\""
fi

echo ""
echo "Native Cursor Gotchi installed."
echo "  App:         $APP_DIR"
echo "  (Finder → Applications → Cursor Gotchi)"
echo "  LaunchAgent: $PLIST_PATH"
echo ""
echo "Look for **Gotchi** in the menu bar (top-right), or open from Applications."
echo "A floating pet window opens automatically when you launch the app."
echo ""
echo "No Python process — this is a real macOS app."
echo "Open from Spotlight anytime: Cursor Gotchi"
echo ""
echo "Stop: launchctl bootout gui/\$(id -u)/${LABEL}"
