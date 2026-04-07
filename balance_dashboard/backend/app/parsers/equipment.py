"""Equipment parser. Reads card_game/data/equipment/*.tres."""

from __future__ import annotations

import glob
from pathlib import Path
from typing import Any, Dict, List, Optional

from app.config import DATA_DIR
from app.parsers.enums import enum_name
from app.parsers.modifiers import resolve_modifiers
from app.parsers.tres import parse_tres_file, resolve_ext_path


def load_equipment() -> List[Dict[str, Any]]:
    pattern = str(DATA_DIR / "equipment" / "*.tres")
    items: List[Dict[str, Any]] = []
    for filepath in sorted(glob.glob(pattern)):
        try:
            parsed = parse_tres_file(filepath)
        except Exception as exc:
            print(f"  WARN: skipping equipment {filepath} — {exc}")
            continue

        props = parsed["resource"]
        if not props:
            continue

        item: Dict[str, Any] = {
            "id": props.get("id", Path(filepath).stem),
            "display_name": props.get("display_name", ""),
            "description": props.get("description", ""),
            "slot": enum_name("EquipSlot", int(props.get("slot", 3)), "SLOT"),
            "rarity": enum_name("Rarity", int(props.get("rarity", 0)), "RARITY"),
            "icon": resolve_ext_path(props.get("icon"), parsed["ext_resources"]),
            "modifiers": resolve_modifiers(
                props.get("modifiers"), parsed["sub_resources"]
            ),
        }
        items.append(item)

    return items


def load_equipment_item(item_id: str) -> Optional[Dict[str, Any]]:
    for item in load_equipment():
        if item["id"] == item_id:
            return item
    return None
