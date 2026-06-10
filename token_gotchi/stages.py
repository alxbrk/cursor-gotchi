from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Stage:
    level: int
    name: str
    min_tokens: int
    sprite: tuple[str, ...]


STAGES: tuple[Stage, ...] = (
    Stage(
        0,
        "Egg",
        0,
        (
            "  ___  ",
            " /   \\ ",
            "|  o  |",
            " \\___/ ",
        ),
    ),
    Stage(
        1,
        "Hatchling",
        5_000,
        (
            "  (•ᴗ•) ",
            "  /| |\\ ",
            "   | |  ",
        ),
    ),
    Stage(
        2,
        "Juvenile",
        50_000,
        (
            "  (◕‿◕) ",
            "  /|   |\\",
            "   |   | ",
            "  _|   |_",
        ),
    ),
    Stage(
        3,
        "Adult",
        500_000,
        (
            "  ╭(°▽°)╮",
            "  ┃     ┃",
            " ╱┃     ┃╲",
            "   ╰───╯ ",
        ),
    ),
    Stage(
        4,
        "Mega",
        5_000_000,
        (
            " ★(◉◡◉)★",
            " ╱┃   ┃╲",
            "╱ ┃   ┃ ╲",
            "  ╰┬───┬╯",
            "   │   │ ",
        ),
    ),
)


def stage_for_lifetime_tokens(total: int) -> Stage:
    current = STAGES[0]
    for stage in STAGES:
        if total >= stage.min_tokens:
            current = stage
    return current


def next_stage(current: Stage) -> Stage | None:
    for stage in STAGES:
        if stage.level == current.level + 1:
            return stage
    return None
