#!/usr/bin/env python3
"""Inspect or manually feed your Cursor Gotchi."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from token_gotchi.pet import PetEngine, PetStore  # noqa: E402
from token_gotchi.render import render_status_line  # noqa: E402
from token_gotchi.species import SPECIES  # noqa: E402


def cmd_show(_: argparse.Namespace) -> int:
    engine = PetEngine()
    state = engine.store.load()
    state = engine.apply_time_decay(state)
    engine.store.save(state)
    print(render_status_line(state))
    return 0


def cmd_feed(args: argparse.Namespace) -> int:
    engine = PetEngine()
    state = engine.store.load()
    state, message = engine.feed_tokens(state, args.tokens)
    engine.store.save(state)
    print(render_status_line(state))
    if message:
        print(f"\n✨ {message}")
    return 0


def cmd_rename(args: argparse.Namespace) -> int:
    store = PetStore()
    state = store.load()
    state.name = args.name
    store.save(state)
    print(f"Renamed to {args.name}")
    return 0


def cmd_species(args: argparse.Namespace) -> int:
    if args.species not in SPECIES:
        print(f"Unknown species. Choose from: {', '.join(SPECIES)}", file=sys.stderr)
        return 1
    store = PetStore()
    state = store.load()
    state.species = args.species
    store.save(state)
    info = SPECIES[args.species]
    print(f"Species set to {info.name} {info.emoji}")
    return 0


def cmd_reset(_: argparse.Namespace) -> int:
    store = PetStore()
    store.save(store.load().__class__())
    print("Cursor Gotchi reset. A fresh egg awaits.")
    return 0


def cmd_state(_: argparse.Namespace) -> int:
    store = PetStore()
    print(json.dumps(store.load().to_dict(), indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Cursor Gotchi CLI")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("show", help="Show current pet status").set_defaults(func=cmd_show)
    sub.add_parser("state", help="Print raw JSON state").set_defaults(func=cmd_state)
    sub.add_parser("reset", help="Reset pet to a new egg").set_defaults(func=cmd_reset)

    feed = sub.add_parser("feed", help="Manually feed tokens (for testing)")
    feed.add_argument("tokens", type=int)
    feed.set_defaults(func=cmd_feed)

    rename = sub.add_parser("rename", help="Rename your gotchi")
    rename.add_argument("name")
    rename.set_defaults(func=cmd_rename)

    species = sub.add_parser("species", help="Pick a species")
    species.add_argument("species", choices=sorted(SPECIES))
    species.set_defaults(func=cmd_species)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
