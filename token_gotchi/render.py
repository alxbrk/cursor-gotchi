from __future__ import annotations

from typing import Any

from .pet import PetEngine, PetState


def _bar(value: float, width: int = 8) -> str:
    filled = int(round(value / 100.0 * width))
    filled = max(0, min(width, filled))
    return "█" * filled + "░" * (width - filled)


def _format_tokens(count: int) -> str:
    if count >= 1_000_000:
        return f"{count / 1_000_000:.1f}M"
    if count >= 1_000:
        return f"{count / 1_000:.1f}k"
    return str(count)


def render_status_line(state: PetState, payload: dict[str, Any] | None = None) -> str:
    engine = PetEngine()
    species = state.species_info
    stage = state.stage
    mood = engine.mood_label(state)
    progress, next_target = engine.progress_to_next(state)

    sprite = stage.sprite
    name_line = f"{species.emoji} {state.name} · {species.name} · {stage.name}"
    mood_line = f"{mood}  hunger {_bar(state.hunger)}  happy {_bar(state.happiness)}"
    token_line = f"fed {_format_tokens(state.lifetime_tokens)} tokens"

    if next_target is not None:
        token_line += f"  evolve {progress}% → {_format_tokens(next_target)}"
    else:
        token_line += "  max evolution"

    model_line = ""
    if payload:
        model = (payload.get("model") or {}).get("display_name")
        ctx_pct = (payload.get("context_window") or {}).get("used_percentage")
        if model:
            model_line = f"{model}"
            if ctx_pct is not None:
                model_line += f"  ctx {int(float(ctx_pct))}%"

    lines = [name_line, *sprite, mood_line, token_line]
    if model_line:
        lines.append(f"\033[90m{model_line}\033[0m")
    return "\n".join(lines)
