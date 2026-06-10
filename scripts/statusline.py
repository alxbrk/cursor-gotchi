#!/usr/bin/env python3
"""Cursor CLI status line hook for Cursor Gotchi."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from token_gotchi.pet import PetEngine  # noqa: E402
from token_gotchi.render import render_status_line  # noqa: E402

from sync_canvas import build_view_model, write_canvas_data  # noqa: E402

from token_gotchi.usage import sync_usage  # noqa: E402


def main() -> int:
    raw = sys.stdin.read()
    if not raw.strip():
        return 1

    payload = json.loads(raw)
    engine = PetEngine()
    state, _ = engine.sync_from_status_payload(payload)
    try:
        sync_usage()
    except Exception:
        pass
    write_canvas_data(build_view_model(state, engine))
    print(render_status_line(state, payload))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
