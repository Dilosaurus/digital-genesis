"""Enemy parser. Reads card_game/data/enemies/*.tres."""

from __future__ import annotations

import glob
from pathlib import Path
from typing import Any, Dict, List, Optional

from app.config import DATA_DIR
from app.parsers.enums import enum_name
from app.parsers.tres import parse_tres_file, resolve_ext_path


def load_enemies() -> List[Dict[str, Any]]:
    pattern = str(DATA_DIR / "enemies" / "*.tres")
    enemies: List[Dict[str, Any]] = []
    for filepath in sorted(glob.glob(pattern)):
        try:
            parsed = parse_tres_file(filepath)
        except Exception as exc:
            print(f"  WARN: skipping enemy {filepath} — {exc}")
            continue

        props = parsed["resource"]
        if not props:
            continue

        intent_pool = []
        raw_pool = props.get("intent_pool", []) or []
        for entry in raw_pool:
            if not isinstance(entry, dict):
                continue
            intent_pool.append(
                {
                    "intent": enum_name("EnemyIntent", int(entry.get("type", 0)), "INTENT"),
                    "value": int(entry.get("value", 0)),
                }
            )

        # Boss phases — keep as-is, just translate the intent type if present
        phases = []
        for phase in props.get("phases", []) or []:
            if not isinstance(phase, dict):
                continue
            cleaned_phase: Dict[str, Any] = dict(phase)
            phase_pool = []
            for entry in phase.get("intent_pool", []) or []:
                if isinstance(entry, dict):
                    phase_pool.append(
                        {
                            "intent": enum_name(
                                "EnemyIntent", int(entry.get("type", 0)), "INTENT"
                            ),
                            "value": int(entry.get("value", 0)),
                        }
                    )
            cleaned_phase["intent_pool"] = phase_pool
            phases.append(cleaned_phase)

        enemy: Dict[str, Any] = {
            "id": props.get("id", Path(filepath).stem),
            "display_name": props.get("display_name", ""),
            "description": props.get("description", ""),
            "lore": props.get("lore", ""),
            "max_hp": int(props.get("max_hp", 0)),
            "artwork": resolve_ext_path(props.get("artwork"), parsed["ext_resources"]),
            "intent_pool": intent_pool,
            "phases": phases,
            "xp_reward": int(props.get("xp_reward", 0)),
        }
        enemies.append(enemy)

    return enemies


def load_enemy(enemy_id: str) -> Optional[Dict[str, Any]]:
    for enemy in load_enemies():
        if enemy["id"] == enemy_id:
            return enemy
    return None
