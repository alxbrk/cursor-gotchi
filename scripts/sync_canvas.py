from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from token_gotchi.pet import PetEngine, PetState, PetStore  # noqa: E402
from token_gotchi.species import SPECIES  # noqa: E402
from token_gotchi.stages import STAGES, next_stage  # noqa: E402
from token_gotchi.usage import sync_usage  # noqa: E402

SPECIES_COLORS = {
    "sparkite": "yellow",
    "deepite": "blue",
    "codite": "purple",
    "shellite": "orange",
    "mcpite": "pink",
}

CANVAS_FILENAME = "token-gotchi.canvas.tsx"


def canvas_data_paths() -> list[Path]:
    """All installed Token-Gotchi canvas data files under ~/.cursor/projects."""
    projects = Path.home() / ".cursor" / "projects"
    if not projects.exists():
        return []
    return [
        path.with_suffix(".canvas.data.json")
        for path in projects.glob(f"*/canvases/{CANVAS_FILENAME}")
    ]


def _format_tokens(count: int) -> str:
    if count >= 1_000_000:
        return f"{count / 1_000_000:.1f}M"
    if count >= 1_000:
        return f"{count / 1_000:.1f}k"
    return str(count)


def build_view_model(state: PetState, engine: PetEngine) -> dict[str, Any]:
    species = state.species_info
    stage = state.stage
    mood = engine.mood_label(state)
    progress, next_target = engine.progress_to_next(state)

    return {
        "name": state.name,
        "speciesId": state.species,
        "speciesName": species.name,
        "speciesColor": SPECIES_COLORS.get(state.species, "blue"),
        "speciesTrait": species.trait,
        "stageName": stage.name,
        "stageLevel": stage.level,
        "lifetimeTokens": state.lifetime_tokens,
        "lifetimeTokensLabel": _format_tokens(state.lifetime_tokens),
        "sessionTokens": state.session_tokens,
        "hunger": round(state.hunger, 1),
        "happiness": round(state.happiness, 1),
        "mood": mood,
        "evolveProgress": progress,
        "evolveTarget": next_target,
        "evolveTargetLabel": _format_tokens(next_target) if next_target else None,
        "mealsServed": state.meals_served,
        "evolutions": state.evolutions,
        "lastFedAt": state.last_fed_at,
        "lastSyncedAt": datetime.now(timezone.utc).isoformat(),
    }


def refresh_usage() -> None:
    try:
        sync_usage()
    except Exception:
        pass


def estimate_transcript_tokens(transcript_path: Path, previous_bytes: int) -> tuple[int, int]:
    if not transcript_path.exists():
        return 0, previous_bytes
    data = transcript_path.read_bytes()
    current_bytes = len(data)
    delta_bytes = max(0, current_bytes - previous_bytes)
    estimated_tokens = int(delta_bytes / 4)
    return estimated_tokens, current_bytes


def apply_payload_updates(
    engine: PetEngine, state: PetState, payload: dict[str, Any]
) -> PetState:
    previous_bytes = state.last_transcript_bytes

    transcript_path = payload.get("transcript_path")
    if transcript_path:
        delta, current_bytes = estimate_transcript_tokens(
            Path(transcript_path), previous_bytes
        )
        if delta > 0:
            state, _ = engine.feed_tokens(state, delta)
        state.last_transcript_bytes = current_bytes

    context = payload.get("context_window")
    if context:
        current_total = engine._extract_session_tokens(context)
        delta = max(0, current_total - state.last_session_token_total)
        state.last_session_token_total = current_total
        if delta > 0:
            state, _ = engine.feed_tokens(state, delta)

    return state


def sync_from_hook_payload(payload: dict[str, Any] | None = None) -> dict[str, Any]:
    engine = PetEngine()
    store = engine.store
    state = store.load()
    state = engine.apply_time_decay(state)

    if payload:
        state = apply_payload_updates(engine, state, payload)

    store.save(state)
    refresh_usage()
    view = build_view_model(state, engine)
    write_canvas_data(view)
    return view


def write_canvas_data(view: dict[str, Any]) -> None:
    body = json.dumps({"pet": view}, indent=2) + "\n"
    for path in canvas_data_paths():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(body, encoding="utf-8")


def sync_from_state_file() -> dict[str, Any]:
    engine = PetEngine()
    state = engine.store.load()
    state = engine.apply_time_decay(state)
    engine.store.save(state)
    refresh_usage()
    view = build_view_model(state, engine)
    write_canvas_data(view)
    return view


def main() -> int:
    raw = sys.stdin.read().strip()
    payload = json.loads(raw) if raw else None
    view = sync_from_hook_payload(payload)
    print(json.dumps(view, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
