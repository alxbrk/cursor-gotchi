#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_DIR="$HOME/.cursor/token-gotchi"
CLI_CONFIG="$HOME/.cursor/cli-config.json"

mkdir -p "$INSTALL_DIR"
rsync -a --delete \
  --exclude '.git' \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  "$REPO_ROOT/token_gotchi" \
  "$REPO_ROOT/scripts" \
  "$REPO_ROOT/mac" \
  "$INSTALL_DIR/"

chmod +x "$INSTALL_DIR/scripts/statusline.py" "$INSTALL_DIR/scripts/fetch_usage.py" "$INSTALL_DIR/scripts/install_mac_app.sh" "$INSTALL_DIR/scripts/build_mac_app.sh" "$INSTALL_DIR/scripts/gotchi.py" "$INSTALL_DIR/scripts/on_agent_stop.sh" "$INSTALL_DIR/scripts/on_hook_sync.sh" "$INSTALL_DIR/scripts/install_canvas.sh" "$INSTALL_DIR/scripts/install_menubar.sh" "$INSTALL_DIR/scripts/restart_menubar.sh" "$INSTALL_DIR/scripts/menubar.py" "$INSTALL_DIR/scripts/device_window.py" "$INSTALL_DIR/scripts/popover_panel.py"

python3 - <<'PY'
import json
from pathlib import Path

config_path = Path.home() / ".cursor" / "cli-config.json"
install_dir = Path.home() / ".cursor" / "token-gotchi"
statusline_cmd = str(install_dir / "scripts" / "statusline.py")

if config_path.exists():
    config = json.loads(config_path.read_text())
else:
    config = {"version": 1}

config.setdefault("statusLine", {})
config["statusLine"] = {
    "type": "command",
    "command": statusline_cmd,
    "padding": 2,
    "updateIntervalMs": 1000,
    "timeoutMs": 3000,
}

config_path.parent.mkdir(parents=True, exist_ok=True)
config_path.write_text(json.dumps(config, indent=2) + "\n")
print(f"Updated {config_path}")
PY

echo ""
echo "Cursor Gotchi installed to $INSTALL_DIR"
echo "CLI status line configured. Open Cursor CLI to see your pet."
echo ""
echo "Try:"
echo "  python3 $INSTALL_DIR/scripts/gotchi.py show"
echo "  python3 $INSTALL_DIR/scripts/gotchi.py rename MyPet"
echo "  python3 $INSTALL_DIR/scripts/gotchi.py species sparkite"
echo ""
"$INSTALL_DIR/scripts/install_canvas.sh"
echo ""
echo "Recommended — native menu bar app (no Python, real .app):"
echo "  $INSTALL_DIR/scripts/install_mac_app.sh"
echo ""
echo "Legacy — Python menu bar pet:"
echo "  $INSTALL_DIR/scripts/install_menubar.sh"
