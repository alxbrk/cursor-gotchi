#!/usr/bin/env python3
"""Refresh Cursor subscription balance for Cursor Gotchi."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from token_gotchi.usage import sync_usage  # noqa: E402


def main() -> int:
    snapshot = sync_usage()
    print(json.dumps(snapshot.to_dict(), indent=2))
    return 0 if snapshot.error is None else 1


if __name__ == "__main__":
    raise SystemExit(main())
