"""16×16 pixel sprites for Token-Gotchi device views."""

from __future__ import annotations

from typing import Literal

PixelChar = Literal[".", "O", "B", "E", "H", "M"]

MoodKey = Literal["happy", "neutral", "sad", "faint"]

# O = outline, B = body, E = eye, H = highlight, M = mouth


def mood_key(hunger: float, happiness: float, mood_label: str) -> MoodKey:
    if mood_label == "Faint" or hunger < 20 or happiness < 20:
        return "faint"
    if mood_label in ("Hungry", "Grumpy") or hunger < 40 or happiness < 40:
        return "sad"
    if mood_label == "Thriving":
        return "happy"
    return "neutral"


def _flip_rows(rows: tuple[str, ...]) -> tuple[str, ...]:
    return ("." * 16,) + rows[:-1]


EGG: tuple[str, ...] = (
    "................",
    "......OOOO......",
    ".....OHHHO......",
    "....OHHHHHO.....",
    "...OHHHHHHHO....",
    "...OHHHHHHHO....",
    "...OHHHHHHHO....",
    "...OHHHHHHHO....",
    "...OHHHHHHHO....",
    "...OHHHHHHHO....",
    "....OHHHHHO.....",
    ".....OHHHO......",
    "......OOO.......",
    "................",
    "................",
    "................",
)

HATCHLING_HAPPY: tuple[str, ...] = (
    "................",
    "......OOOO......",
    ".....OBBBBO.....",
    "....OBBBBBBO....",
    "...OBBEBBBEBO...",
    "...OBBBBMBBO....",
    "...OBBBBBBBO....",
    "....OBBBBBBO....",
    ".....OBBBBO.....",
    "......OBBBO.....",
    "......O..O......",
    ".....OO..OO.....",
    "................",
    "................",
    "................",
    "................",
)

HATCHLING_SAD: tuple[str, ...] = (
    "................",
    "......OOOO......",
    ".....OBBBBO.....",
    "....OBBBBBBO....",
    "...OBBEBBBEBO...",
    "...OBBBMMMBBO...",
    "...OBBBBBBBO....",
    "....OBBBBBBO....",
    ".....OBBBBO.....",
    "......OBBBO.....",
    "......O..O......",
    ".....OO..OO.....",
    "................",
    "................",
    "................",
    "................",
)

HATCHLING_FAINT: tuple[str, ...] = (
    "................",
    "................",
    "................",
    "......OOOO......",
    ".....OBBBBO.....",
    "...OBBBBBBBBBO..",
    "..OBBEXXXEBBO...",
    "..OBBBBMBBO.....",
    "...OBBBBBO......",
    "....OBBBBBO.....",
    ".....OO..OO.....",
    "................",
    "................",
    "................",
    "................",
    "................",
)

JUVENILE_HAPPY: tuple[str, ...] = (
    "................",
    "......OOOO......",
    ".....OHHHHO.....",
    "....OBBBBBBO....",
    "...OBBEBBBEBO...",
    "...OBBBBMBBO....",
    "...OBBBBBBBO....",
    "..OBBBBBBBBBO...",
    "..OBBBBBBBBBO...",
    "...OBBBBBBBO....",
    "....OB..BOB.....",
    "....O....O......",
    "...OO....OO.....",
    "................",
    "................",
    "................",
)

JUVENILE_SAD: tuple[str, ...] = (
    "................",
    "......OOOO......",
    ".....OHHHHO.....",
    "....OBBBBBBO....",
    "...OBBEBBBEBO...",
    "...OBBBMMMBBO...",
    "...OBBBBBBBO....",
    "..OBBBBBBBBBO...",
    "..OBBBBBBBBBO...",
    "...OBBBBBBBO....",
    "....OB..BOB.....",
    "....O....O......",
    "...OO....OO.....",
    "................",
    "................",
    "................",
)

ADULT_HAPPY: tuple[str, ...] = (
    ".....OO..OO.....",
    "....OHHHHHHHO...",
    "...OBBBBBBBBO...",
    "..OBBEBBBBEBO...",
    "..OBBBBMBBBBO...",
    "..OBBBBBBBBBO...",
    ".OBBBBBBBBBBBO..",
    ".OBBBBBBBBBBBO..",
    "..OBBBBBBBBBO...",
    "...OBBBBBBBBO...",
    "..OBO.....OBO...",
    "..OOO.....OOO...",
    "................",
    "................",
    "................",
    "................",
)

ADULT_SAD: tuple[str, ...] = (
    ".....OO..OO.....",
    "....OHHHHHHHO...",
    "...OBBBBBBBBO...",
    "..OBBEBBBBEBO...",
    "..OBBBMMMMBBO...",
    "..OBBBBBBBBBO...",
    ".OBBBBBBBBBBBO..",
    ".OBBBBBBBBBBBO..",
    "..OBBBBBBBBBO...",
    "...OBBBBBBBBO...",
    "..OBO.....OBO...",
    "..OOO.....OOO...",
    "................",
    "................",
    "................",
    "................",
)

MEGA_HAPPY: tuple[str, ...] = (
    "....O.HH.HO.....",
    "...OHHHHHHHO....",
    "..OBBBBBBBBBO...",
    ".OBBEBBBBBBEBO..",
    ".OBBBBMMBBBBBO..",
    "OBBBBBBBBBBBBBO.",
    "OBBBBBBBBBBBBBO.",
    ".OBBBBBBBBBBBBO.",
    "..OBBBBBBBBBO...",
    "...OBO...OBO....",
    "..OOO...OOO.....",
    "................",
    "................",
    "................",
    "................",
    "................",
)


def sprite_for(stage_level: int, mood: MoodKey, frame: int) -> tuple[str, ...]:
    if stage_level <= 0:
        rows = EGG
    elif stage_level == 1:
        if mood == "faint":
            rows = HATCHLING_FAINT
        elif mood == "sad":
            rows = HATCHLING_SAD
        else:
            rows = HATCHLING_HAPPY
    elif stage_level == 2:
        rows = JUVENILE_SAD if mood == "sad" else JUVENILE_HAPPY
    elif stage_level == 3:
        rows = ADULT_SAD if mood == "sad" else ADULT_HAPPY
    else:
        rows = MEGA_HAPPY

    if frame % 2 == 1 and mood != "faint" and stage_level > 0:
        rows = _flip_rows(rows)
    return rows


SPECIES_BODY_HEX = {
    "sparkite": "#E5C07B",
    "deepite": "#599CE7",
    "codite": "#9386F2",
    "shellite": "#E3944C",
    "mcpite": "#F28CA6",
}
