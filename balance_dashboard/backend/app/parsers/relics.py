"""Relic parser. Reads card_game/data/relics/*.tres."""

from __future__ import annotations

import glob
from pathlib import Path
from typing import Any, Dict, List, Optional

from app.config import DATA_DIR
from app.parsers.enums import enum_name
from app.parsers.tres import parse_tres_file, resolve_ext_path


def load_relics() -> List[Dict[str, Any]]:
    pattern = str(DATA_DIR / "relics" / "*.tres")
    relics: List[Dict[str, Any]] = []
    for filepath in sorted(glob.glob(pattern)):
        try:
            parsed = parse_tres_file(filepath)
        except Exception as exc:
            print(f"  WARN: skipping relic {filepath} — {exc}")
            continue

        props = parsed["resource"]
        if not props:
            continue

        relic: Dict[str, Any] = {
            "id": props.get("id", Path(filepath).stem),
            "display_name": props.get("display_name", ""),
            "description": props.get("description", ""),
            "rarity": enum_name("Rarity", int(props.get("rarity", 0)), "RARITY"),
            "icon": resolve_ext_path(props.get("icon"), parsed["ext_resources"]),
            # Combat-start bonuses
            "start_combat_strength": int(props.get("start_combat_strength", 0)),
            "start_combat_dexterity": int(props.get("start_combat_dexterity", 0)),
            "start_combat_block": int(props.get("start_combat_block", 0)),
            # Run-wide bonuses
            "bonus_draw": int(props.get("bonus_draw", 0)),
            "bonus_max_energy": int(props.get("bonus_max_energy", 0)),
            "bonus_max_hp": int(props.get("bonus_max_hp", 0)),
            "heal_on_combat_end": int(props.get("heal_on_combat_end", 0)),
            "corruption_resistance": int(props.get("corruption_resistance", 0)),
            "auto_revive": bool(props.get("auto_revive", False)),
        }
        relics.append(relic)

    return relics


def load_relic(relic_id: str) -> Optional[Dict[str, Any]]:
    for relic in load_relics():
        if relic["id"] == relic_id:
            return relic
    return None
