from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .species import DEFAULT_SPECIES, SPECIES
from .stages import STAGES, next_stage, stage_for_lifetime_tokens


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _parse_iso(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


@dataclass
class PetState:
    name: str = "Toko"
    species: str = DEFAULT_SPECIES
    lifetime_tokens: int = 0
    session_tokens: int = 0
    hunger: float = 80.0
    happiness: float = 80.0
    last_fed_at: str = field(default_factory=_now_iso)
    last_seen_at: str = field(default_factory=_now_iso)
    last_session_token_total: int = 0
    meals_served: int = 0
    evolutions: int = 0
    last_transcript_bytes: int = 0

    @property
    def stage(self):
        return stage_for_lifetime_tokens(self.lifetime_tokens)

    @property
    def species_info(self):
        return SPECIES.get(self.species, SPECIES[DEFAULT_SPECIES])

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> PetState:
        known = {f.name for f in cls.__dataclass_fields__.values()}  # type: ignore[attr-defined]
        return cls(**{k: v for k, v in data.items() if k in known})


class PetStore:
    def __init__(self, path: Path | None = None) -> None:
        self.path = path or Path.home() / ".cursor" / "token-gotchi" / "state.json"

    def load(self) -> PetState:
        if not self.path.exists():
            return PetState()
        return PetState.from_dict(json.loads(self.path.read_text(encoding="utf-8")))

    def save(self, state: PetState) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(json.dumps(state.to_dict(), indent=2) + "\n", encoding="utf-8")


class PetEngine:
    HUNGER_DECAY_PER_HOUR = 4.0
    HAPPINESS_DECAY_PER_HOUR = 2.0
    FEED_HUNGER_PER_1K = 3.0
    FEED_HAPPINESS_PER_1K = 1.5
    MAX_STAT = 100.0
    MIN_STAT = 0.0

    def __init__(self, store: PetStore | None = None) -> None:
        self.store = store or PetStore()

    def apply_time_decay(self, state: PetState, now: datetime | None = None) -> PetState:
        now = now or datetime.now(timezone.utc)
        last_seen = _parse_iso(state.last_seen_at)
        hours = max(0.0, (now - last_seen).total_seconds() / 3600.0)

        state.hunger = max(self.MIN_STAT, state.hunger - self.HUNGER_DECAY_PER_HOUR * hours)
        state.happiness = max(self.MIN_STAT, state.happiness - self.HAPPINESS_DECAY_PER_HOUR * hours)
        state.last_seen_at = now.isoformat()
        return state

    def feed_tokens(self, state: PetState, delta: int) -> tuple[PetState, str | None]:
        if delta <= 0:
            return state, None

        state.lifetime_tokens += delta
        state.session_tokens += delta
        state.meals_served += 1
        state.last_fed_at = _now_iso()

        feed_units = delta / 1000.0
        state.hunger = min(self.MAX_STAT, state.hunger + self.FEED_HUNGER_PER_1K * feed_units)
        state.happiness = min(self.MAX_STAT, state.happiness + self.FEED_HAPPINESS_PER_1K * feed_units)

        previous_stage = stage_for_lifetime_tokens(state.lifetime_tokens - delta)
        current_stage = state.stage
        message = None
        if current_stage.level > previous_stage.level:
            state.evolutions += 1
            message = f"Evolved into {current_stage.name}!"
        return state, message

    def sync_from_status_payload(self, payload: dict[str, Any]) -> tuple[PetState, str | None]:
        state = self.store.load()
        state = self.apply_time_decay(state)

        context = payload.get("context_window") or {}
        current_total = self._extract_session_tokens(context)
        delta = max(0, current_total - state.last_session_token_total)
        state.last_session_token_total = current_total

        state, message = self.feed_tokens(state, delta)
        self.store.save(state)
        return state, message

    def _extract_session_tokens(self, context: dict[str, Any]) -> int:
        usage = context.get("current_usage") or {}
        input_tokens = usage.get("input_tokens") or 0
        output_tokens = usage.get("output_tokens") or 0
        if input_tokens or output_tokens:
            return int(input_tokens) + int(output_tokens)

        total_input = context.get("total_input_tokens")
        total_output = context.get("total_output_tokens")
        if total_input is not None or total_output is not None:
            return int(total_input or 0) + int(total_output or 0)

        used_pct = context.get("used_percentage")
        window_size = context.get("context_window_size")
        if used_pct is not None and window_size:
            return int(float(used_pct) / 100.0 * int(window_size))
        return 0

    def mood_label(self, state: PetState) -> str:
        if state.hunger < 20 or state.happiness < 20:
            return "Faint"
        if state.hunger < 40:
            return "Hungry"
        if state.happiness < 40:
            return "Grumpy"
        if state.hunger > 85 and state.happiness > 85:
            return "Thriving"
        return "Content"

    def progress_to_next(self, state: PetState) -> tuple[int, int | None]:
        upcoming = next_stage(state.stage)
        if upcoming is None:
            return 100, None
        current_floor = state.stage.min_tokens
        target = upcoming.min_tokens
        span = max(1, target - current_floor)
        progress = int(((state.lifetime_tokens - current_floor) / span) * 100)
        return min(100, max(0, progress)), target
