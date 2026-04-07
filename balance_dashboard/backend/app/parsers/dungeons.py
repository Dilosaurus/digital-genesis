"""Dungeon variant parser. Reads card_game/resources/dungeons/variants/*.tres.

These are NEW — they were never surfaced by the legacy exporter.
Each variant points to a base PackedScene plus optional decay overlay
and a lighting preset.
"""

from __future__ import annotations

import glob
from pathlib import Path
from typing import Any, Dict, List, Optional

from app.config import RESOURCES_DIR
from app.parsers.tres import parse_tres_file, resolve_ext_path


def load_dungeon_variants() -> List[Dict[str, Any]]:
    pattern = str(RESOURCES_DIR / "dungeons" / "variants" / "*.tres")
    variants: List[Dict[str, Any]] = []
    for filepath in sorted(glob.glob(pattern)):
        try:
            parsed = parse_tres_file(filepath)
        except Exception as exc:
            print(f"  WARN: skipping dungeon {filepath} — {exc}")
            continue

        props = parsed["resource"]
        if not props:
            continue

        ext = parsed["ext_resources"]

        variant: Dict[str, Any] = {
            "id": Path(filepath).stem,
            "display_name": props.get("display_name", "Unknown Dungeon"),
            "lighting_preset": props.get("lighting_preset", "act1"),
            "is_boss_arena": bool(props.get("is_boss_arena", False)),
            "base_dungeon": resolve_ext_path(props.get("base_dungeon"), ext),
            "decay_overlay": resolve_ext_path(props.get("decay_overlay"), ext),
        }
        variants.append(variant)

    return variants


def load_dungeon_variant(variant_id: str) -> Optional[Dict[str, Any]]:
    for v in load_dungeon_variants():
        if v["id"] == variant_id:
            return v
    return None
