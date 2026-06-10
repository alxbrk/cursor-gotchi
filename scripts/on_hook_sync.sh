#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$HOME/.cursor/token-gotchi"
python3 "$INSTALL_DIR/scripts/sync_canvas.py"
