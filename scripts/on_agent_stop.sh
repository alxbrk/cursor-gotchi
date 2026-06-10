#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$HOME/.cursor/token-gotchi"
exec "$INSTALL_DIR/scripts/on_hook_sync.sh"
