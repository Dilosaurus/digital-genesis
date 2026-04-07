"""Character parser. Reads card_game/data/characters/*.tres.

The legacy exporter never surfaced character data — this is new.
"""

from __future__ import annotations

import glob
from pathlib import Path
from typing import Any, Dict, List

from app.config import DATA_DIR
from app.parsers.enums import enum_name
from app.parsers.tres import parse_tres_file


def load_characters() -> List[Dict[str, Any]]:
    """Parse every character .tres file."""
    pattern = str(DATA_DIR / "characters" / "*.tres")
    characters: List[Dict[str, Any]] = []
    for filepath in sorted(glob.glob(pattern)):
        try:
            parsed = parse_tres_file(filepath)
        except Exception as exc:
            print(f"  WARN: skipping {filepath} — {exc}")
            continue

        props = parsed["resource"]
        if not props:
            continue

        char_class_idx = int(props.get("character_class", 0))
        starter_deck = props.get("starter_deck", []) or []

        # Color(r, g, b, a) is parsed by tres.py into a list of floats
        color_primary = props.get("color_primary", [1.0, 1.0, 1.0, 1.0])
        color_secondary = props.get("color_secondary", [0.5, 0.5, 0.5, 1.0])

        character: Dict[str, Any] = {
            "id": props.get("id", Path(filepath).stem),
            "display_name": props.get("display_name", ""),
            "title": props.get("title", ""),
            "character_class": enum_name("CharacterClass", char_class_idx, "CLASS"),
            "character_class_index": char_class_idx,
            "backstory": props.get("backstory", ""),
            "passive_name": props.get("passive_name", ""),
            "passive_description": props.get("passive_description", ""),
            "starter_deck": list(starter_deck),
            "starting_hp": int(props.get("starting_hp", 80)),
            "starting_energy": int(props.get("starting_energy", 3)),
            "color_primary": _color_to_hex(color_primary),
            "color_primary_rgba": list(color_primary) if isinstance(color_primary, list) else [1.0, 1.0, 1.0, 1.0],
            "color_secondary": _color_to_hex(color_secondary),
            "color_secondary_rgba": list(color_secondary) if isinstance(color_secondary, list) else [0.5, 0.5, 0.5, 1.0],
            "icon_text": props.get("icon_text", ""),
        }
        characters.append(character)

    # Sort by character class index for stable display order
    characters.sort(key=lambda c: c["character_class_index"])
    return characters


def load_character(character_id: str) -> Dict[str, Any] | None:
    for character in load_characters():
        if character["id"] == character_id:
            return character
    return None


def _color_to_hex(color: Any) -> str:
    """Convert a [r, g, b, a] float list to a #RRGGBB hex string."""
    if not isinstance(color, list) or len(color) < 3:
        return "#FFFFFF"
    r = max(0, min(255, int(round(color[0] * 255))))
    g = max(0, min(255, int(round(color[1] * 255))))
    b = max(0, min(255, int(round(color[2] * 255))))
    return f"#{r:02X}{g:02X}{b:02X}"
