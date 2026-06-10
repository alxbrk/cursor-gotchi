#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$HOME/.cursor/token-gotchi"
HOOKS_JSON="$HOME/.cursor/hooks.json"
HOOK_CMD="$INSTALL_DIR/scripts/on_hook_sync.sh"

chmod +x "$HOOK_CMD" "$INSTALL_DIR/scripts/on_agent_stop.sh"

python3 "$INSTALL_DIR/scripts/sync_canvas.py" <<< '{}' >/dev/null

python3 - <<PY
import json
from pathlib import Path

hooks_path = Path.home() / ".cursor" / "hooks.json"
hook_cmd = str(Path.home() / ".cursor" / "token-gotchi" / "scripts" / "on_hook_sync.sh")

if hooks_path.exists():
    config = json.loads(hooks_path.read_text())
else:
    config = {"version": 1, "hooks": {}}

hooks = config.setdefault("hooks", {})
hook_events = ("stop", "afterAgentResponse", "sessionStart", "sessionEnd")

for event in hook_events:
    entries = hooks.setdefault(event, [])
    if not any(entry.get("command") == hook_cmd for entry in entries):
        entries.append({"command": hook_cmd})

hooks_path.parent.mkdir(parents=True, exist_ok=True)
hooks_path.write_text(json.dumps(config, indent=2) + "\n")
print(f"Registered Cursor Gotchi hooks in {hooks_path}")
print(f"  Events: {', '.join(hook_events)}")
PY

echo "Canvas synced. Open token-gotchi.canvas.tsx beside chat."
