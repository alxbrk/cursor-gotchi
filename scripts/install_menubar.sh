#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_DIR="$HOME/.cursor/token-gotchi"
LABEL="com.cursor.token-gotchi.menubar"
PLIST_PATH="$HOME/Library/LaunchAgents/${LABEL}.plist"
PYTHON3="$(command -v python3)"

pkill -f "$INSTALL_DIR/scripts/menubar.py" 2>/dev/null || true
launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
sleep 0.5

echo "Installing menu bar dependencies..."
python3 -m pip install --user --upgrade rumps

chmod +x "$INSTALL_DIR/scripts/menubar.py"

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${PYTHON3}</string>
    <string>${INSTALL_DIR}/scripts/menubar.py</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${HOME}/.cursor/token-gotchi/menubar.log</string>
  <key>StandardErrorPath</key>
  <string>${HOME}/.cursor/token-gotchi/menubar.log</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"

echo ""
echo "Menu bar pet installed."
echo "  LaunchAgent: $PLIST_PATH"
echo "  Logs:        ~/.cursor/token-gotchi/menubar.log"
echo ""
echo "Your gotchi should appear in the menu bar now (species emoji)."
echo "It starts automatically at login."
echo ""
echo "Manual run: python3 $INSTALL_DIR/scripts/menubar.py"
echo "Stop:       launchctl bootout gui/\$(id -u)/${LABEL}"
