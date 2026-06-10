from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Species:
    id: str
    name: str
    emoji: str
    trait: str


SPECIES = {
    "sparkite": Species("sparkite", "Sparkite", "⚡", "Loves fast completions"),
    "deepite": Species("deepite", "Deepite", "🌊", "Thrives on long context"),
    "codite": Species("codite", "Codite", "💎", "Evolves through edits"),
    "shellite": Species("shellite", "Shellite", "🔥", "Powered by terminal runs"),
    "mcpite": Species("mcpite", "MCPite", "🔗", "Connects to everything"),
}

DEFAULT_SPECIES = "sparkite"
