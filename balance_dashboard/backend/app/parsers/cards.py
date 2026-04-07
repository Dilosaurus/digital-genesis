"""Card parser. Reads card_game/data/cards/*.tres into a list of card dicts.

Surfaces ALL fields from the current CardData GDScript class — the legacy
exporter only covered ~22 fields out of 50+, so this is a substantial
expansion.
"""

from __future__ import annotations

import glob
from pathlib import Path
from typing import Any, Dict, List

from app.config import DATA_DIR
from app.parsers.enums import enum_name
from app.parsers.tres import parse_tres_file, resolve_ext_path


def load_cards() -> List[Dict[str, Any]]:
    """Parse every card .tres file into a list of fully-populated dicts."""
    pattern = str(DATA_DIR / "cards" / "*.tres")
    cards: List[Dict[str, Any]] = []
    for filepath in sorted(glob.glob(pattern)):
        try:
            parsed = parse_tres_file(filepath)
        except Exception as exc:
            print(f"  WARN: skipping {filepath} — {exc}")
            continue

        props = parsed["resource"]
        if not props:
            print(f"  WARN: empty [resource] in {filepath}")
            continue

        ext = parsed["ext_resources"]

        # Resolve enum indices to string names so the JSON is human-readable
        card_type_idx = int(props.get("card_type", 0))
        target_type_idx = int(props.get("target_type", 0))
        rarity_idx = int(props.get("rarity", 0))

        raw_tags = props.get("tags", []) or []
        tag_names = [enum_name("CardTag", int(t), "TAG") for t in raw_tags if isinstance(t, int)]

        # Resolve ExtResource artwork ref to a res:// path so the frontend can map it
        artwork_path = resolve_ext_path(props.get("artwork"), ext)

        card: Dict[str, Any] = {
            # Core identity
            "id": props.get("id", Path(filepath).stem),
            "display_name": props.get("display_name", ""),
            "description": props.get("description", ""),
            "energy_cost": int(props.get("energy_cost", 1)),
            "card_type": enum_name("CardType", card_type_idx, "TYPE"),
            "target_type": enum_name("TargetType", target_type_idx, "TARGET"),
            "rarity": enum_name("Rarity", rarity_idx, "RARITY"),
            "character_class": int(props.get("character_class", -1)),
            "tags": tag_names,
            "artwork": artwork_path,
            # Combat stats
            "damage": int(props.get("damage", 0)),
            "block": int(props.get("block", 0)),
            "heal": int(props.get("heal", 0)),
            "draw": int(props.get("draw", 0)),
            "hits": int(props.get("hits", 1)),
            "apply_vulnerable": int(props.get("apply_vulnerable", 0)),
            "apply_weak": int(props.get("apply_weak", 0)),
            "corruption_gain": int(props.get("corruption_gain", 0)),
            "exhaust": bool(props.get("exhaust", False)),
            "gain_strength": int(props.get("gain_strength", 0)),
            "gain_dexterity": int(props.get("gain_dexterity", 0)),
            # Upgrade chain + sockets
            "upgraded": bool(props.get("upgraded", False)),
            "upgrade_id": props.get("upgrade_id", ""),
            "cooldown_max": int(props.get("cooldown_max", 0)),
            "gem_sockets": int(props.get("gem_sockets", 0)),
            # Co-op / party
            "party_heal": int(props.get("party_heal", 0)),
            "party_draw": int(props.get("party_draw", 0)),
            "party_damage": int(props.get("party_damage", 0)),
            "share_block": bool(props.get("share_block", False)),
            "transfer_mana": int(props.get("transfer_mana", 0)),
            "mark_target": bool(props.get("mark_target", False)),
            # Revival
            "revive_ally": bool(props.get("revive_ally", False)),
            "revive_hp": int(props.get("revive_hp", 15)),
            # Corruption removal
            "corruption_remove": int(props.get("corruption_remove", 0)),
            "party_corruption_remove": int(props.get("party_corruption_remove", 0)),
            # Scourge / PIRACY
            "steal_block": int(props.get("steal_block", 0)),
            "steal_all_block": bool(props.get("steal_all_block", False)),
            "aoe_steal_block": int(props.get("aoe_steal_block", 0)),
            "create_contraband": int(props.get("create_contraband", 0)),
            "destroy_contraband_for_damage": int(props.get("destroy_contraband_for_damage", 0)),
            "destroy_contraband_for_block": int(props.get("destroy_contraband_for_block", 0)),
            "destroy_contraband_corruption": int(props.get("destroy_contraband_corruption", 0)),
            "damage_per_card_played": int(props.get("damage_per_card_played", 0)),
            "damage_per_contraband_in_hand": int(props.get("damage_per_contraband_in_hand", 0)),
            "conditional_damage_if_zero_block": int(props.get("conditional_damage_if_zero_block", 0)),
            "aoe_damage": int(props.get("aoe_damage", 0)),
            # FLUX / Daemons
            "create_daemon_fragment": int(props.get("create_daemon_fragment", 0)),
            "destroy_daemons_for_damage": int(props.get("destroy_daemons_for_damage", 0)),
        }
        cards.append(card)

    return cards


def load_card(card_id: str) -> Dict[str, Any] | None:
    """Load a single card by id."""
    for card in load_cards():
        if card["id"] == card_id:
            return card
    return None
