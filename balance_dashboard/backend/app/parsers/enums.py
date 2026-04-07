"""Live enum loader.

Reads card_game/scripts/data/enums.gd and exposes the enum values as
Python lists, so the backend stays automatically in sync with the game's
schema. If a new tag or stat is added to enums.gd, this picks it up
without any code change here.
"""

from __future__ import annotations

import re
from functools import lru_cache
from typing import Dict, List

from app.config import ENUMS_GD


# ---------------------------------------------------------------------------
# Public helpers
# ---------------------------------------------------------------------------


def enum_name(enum_id: str, index: int, fallback_prefix: str = "UNKNOWN") -> str:
    """Return the string name for an enum int, or a UNKNOWN_<n> fallback."""
    values = get_enum(enum_id)
    if 0 <= index < len(values):
        return values[index]
    return f"{fallback_prefix}_{index}"


def get_enum(enum_id: str) -> List[str]:
    """Return the list of value names for an enum, by its GDScript name."""
    enums = _load_enums()
    return enums.get(enum_id, [])


def all_enums() -> Dict[str, List[str]]:
    """Return all enums parsed from enums.gd."""
    return dict(_load_enums())


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------


@lru_cache(maxsize=1)
def _load_enums() -> Dict[str, List[str]]:
    """Parse enums.gd into a {enum_name: [values]} mapping.

    Handles both single-line and multi-line enum declarations:

        enum CardType { ATTACK, SKILL, POWER }
        enum Stat {
            DAMAGE,
            BLOCK,
        }
    """
    if not ENUMS_GD.exists():
        return {}

    text = ENUMS_GD.read_text(encoding="utf-8")

    # Strip line comments first
    text = re.sub(r"#[^\n]*", "", text)

    pattern = re.compile(
        r"enum\s+(\w+)\s*\{([^}]*)\}",
        re.DOTALL,
    )

    result: Dict[str, List[str]] = {}
    for match in pattern.finditer(text):
        name = match.group(1)
        body = match.group(2)
        # Split on commas, strip whitespace, drop empties
        values = [v.strip() for v in body.split(",")]
        values = [v for v in values if v]
        result[name] = values

    return result
