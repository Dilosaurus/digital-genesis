"""Gem parser. Reads card_game/data/gems/*.tres."""

from __future__ import annotations

import glob
from pathlib import Path
from typing import Any, Dict, List, Optional

from app.config import DATA_DIR
from app.parsers.enums import enum_name
from app.parsers.modifiers import resolve_modifiers
from app.parsers.tres import parse_tres_file, resolve_ext_path


def load_gems() -> List[Dict[str, Any]]:
    pattern = str(DATA_DIR / "gems" / "*.tres")
    gems: List[Dict[str, Any]] = []
    for filepath in sorted(glob.glob(pattern)):
        try:
            parsed = parse_tres_file(filepath)
        except Exception as exc:
            print(f"  WARN: skipping gem {filepath} — {exc}")
            continue

        props = parsed["resource"]
        if not props:
            continue

        gem: Dict[str, Any] = {
            "id": props.get("id", Path(filepath).stem),
            "display_name": props.get("display_name", ""),
            "description": props.get("description", ""),
            "rarity": enum_name("Rarity", int(props.get("rarity", 0)), "RARITY"),
            "icon": resolve_ext_path(props.get("icon"), parsed["ext_resources"]),
            "on_play_modifiers": resolve_modifiers(
                props.get("on_play_modifiers"), parsed["sub_resources"]
            ),
            # Trigger / event extension
            "trigger_event": props.get("trigger_event", ""),
            "trigger_effect": props.get("trigger_effect", ""),
            "trigger_value": int(props.get("trigger_value", 0)),
            # Convert flags
            "convert_damage_to_heal": bool(props.get("convert_damage_to_heal", False)),
            "extra_hit_percent": float(props.get("extra_hit_percent", 0.0)),
            "add_create_contraband": int(props.get("add_create_contraband", 0)),
        }
        gems.append(gem)

    return gems


def load_gem(gem_id: str) -> Optional[Dict[str, Any]]:
    for gem in load_gems():
        if gem["id"] == gem_id:
            return gem
    return None
