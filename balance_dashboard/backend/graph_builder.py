"""
graph_builder.py — Builds a React Flow-compatible dependency graph
from the balance dashboard data.

Node types (for color-coding in the frontend):
  card, stat, relic, equipment, gem, skill, enemy, tag

Edge types describe modifier relationships and data flow.
"""

from __future__ import annotations

# All canonical stat names from enums.gd
_ALL_STATS = [
    "DAMAGE",
    "BLOCK",
    "HEALING",
    "MAX_HP",
    "MAX_ENERGY",
    "DRAW_PER_TURN",
    "ENERGY_COST",
    "CORRUPTION_GAIN",
    "CORRUPTION_RESIST",
]

# All card tag names from enums.gd
_ALL_TAGS = [
    "MELEE",
    "RANGED",
    "FIRE",
    "ICE",
    "HOLY",
    "SHADOW",
    "TECH",
    "EXPLOIT",
    "CURSE",
]


def _node(node_id: str, node_type: str, label: str, data: dict) -> dict:
    return {"id": node_id, "type": node_type, "label": label, "data": data}


def _edge(source: str, target: str, label: str) -> dict:
    edge_id = f"edge_{source}__{target}"
    return {"id": edge_id, "source": source, "target": target, "label": label}


def _mod_label(mod: dict) -> str:
    """Convert a raw modifier dict to a human-readable edge label."""
    op = mod.get("operation", "FLAT_ADD")
    value = mod.get("value", 0)
    stat = mod.get("stat", "?")
    if op == "FLAT_ADD":
        sign = "+" if value >= 0 else ""
        return f"{sign}{value} {stat}"
    if op == "PERCENT_ADD":
        return f"+{int(value * 100)}% {stat}"
    if op == "PERCENT_MULT":
        return f"×{value} {stat}"
    if op == "OVERRIDE":
        return f"{stat} = {value}"
    return f"{op} {value} {stat}"


def _display_name(item: dict, fallback: str = "") -> str:
    """Get display name from item, trying display_name then name then fallback."""
    return item.get("display_name", item.get("name", fallback))


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def build_graph(
    cards: list[dict],
    relics: list[dict],
    equipment: list[dict],
    gems: list[dict],
    skills: list[dict],
    enemies: list[dict],
) -> dict:
    nodes: list[dict] = []
    edges: list[dict] = []
    seen_edges: set[str] = set()

    def add_edge(source: str, target: str, label: str) -> None:
        e = _edge(source, target, label)
        if e["id"] not in seen_edges:
            seen_edges.add(e["id"])
            edges.append(e)

    # Stat nodes
    for stat in _ALL_STATS:
        nodes.append(_node(f"stat_{stat}", "stat", stat, {"stat": stat}))

    # Tag nodes
    for tag in _ALL_TAGS:
        nodes.append(_node(f"tag_{tag}", "tag", tag, {"tag": tag}))

    # Card nodes
    for card in cards:
        cid = card.get("id", "")
        if not cid:
            continue
        node_id = f"card_{cid}"
        nodes.append(_node(node_id, "card", _display_name(card, cid), {
            "id": cid,
            "type": card.get("card_type", card.get("type", "")),
            "energy_cost": card.get("energy_cost", 0),
            "damage": card.get("damage", 0),
            "block": card.get("block", 0),
            "heal": card.get("heal", 0),
            "tags": card.get("tags", []),
            "description": card.get("description", ""),
        }))

        if card.get("damage", 0):
            add_edge(node_id, "stat_DAMAGE", f"base damage: {card['damage']}")
        if card.get("block", 0):
            add_edge(node_id, "stat_BLOCK", f"base block: {card['block']}")
        if card.get("heal", 0):
            add_edge(node_id, "stat_HEALING", f"base heal: {card['heal']}")

        for tag in card.get("tags", []):
            tag_upper = tag.upper()
            if tag_upper in _ALL_TAGS:
                add_edge(node_id, f"tag_{tag_upper}", "has tag")

    # Relic nodes
    for relic in relics:
        rid = relic.get("id", "")
        if not rid:
            continue
        node_id = f"relic_{rid}"
        nodes.append(_node(node_id, "relic", _display_name(relic, rid), {
            "id": rid,
            "rarity": relic.get("rarity", ""),
            "description": relic.get("description", ""),
        }))

        if relic.get("start_combat_strength", 0) > 0:
            add_edge(node_id, "stat_DAMAGE",
                     f"grants +{relic['start_combat_strength']} DAMAGE")
        if relic.get("start_combat_dexterity", 0) > 0:
            add_edge(node_id, "stat_BLOCK",
                     f"grants +{relic['start_combat_dexterity']} BLOCK")
        if relic.get("bonus_draw", 0) > 0:
            add_edge(node_id, "stat_DRAW_PER_TURN",
                     f"grants +{relic['bonus_draw']} DRAW_PER_TURN")
        if relic.get("corruption_resistance", 0) > 0:
            add_edge(node_id, "stat_CORRUPTION_RESIST",
                     f"grants +{relic['corruption_resistance']} CORRUPTION_RESIST")

    # Equipment nodes
    for equip in equipment:
        eid = equip.get("id", "")
        if not eid:
            continue
        node_id = f"equipment_{eid}"
        nodes.append(_node(node_id, "equipment", _display_name(equip, eid), {
            "id": eid,
            "slot": equip.get("slot", ""),
            "description": equip.get("description", ""),
        }))

        for mod in equip.get("modifiers", []):
            stat = mod.get("stat", "")
            if stat in _ALL_STATS:
                add_edge(node_id, f"stat_{stat}", _mod_label(mod))

    # Gem nodes
    for gem in gems:
        gid = gem.get("id", "")
        if not gid:
            continue
        node_id = f"gem_{gid}"
        nodes.append(_node(node_id, "gem", _display_name(gem, gid), {
            "id": gid,
            "description": gem.get("description", ""),
        }))

        for mod in gem.get("on_play_modifiers", gem.get("modifiers", [])):
            stat = mod.get("stat", "")
            if stat in _ALL_STATS:
                add_edge(node_id, f"stat_{stat}", _mod_label(mod))

    # Skill nodes
    skill_ids = {s["id"] for s in skills if "id" in s}
    for skill in skills:
        sid = skill.get("id", "")
        if not sid:
            continue
        node_id = f"skill_{sid}"
        nodes.append(_node(node_id, "skill", _display_name(skill, sid), {
            "id": sid,
            "tier": skill.get("tier", 0),
            "cost": skill.get("cost", 0),
            "description": skill.get("description", ""),
        }))

        for prereq in skill.get("prerequisites", []):
            if prereq in skill_ids:
                add_edge(f"skill_{prereq}", node_id, "unlocks")

        for mod in skill.get("modifier_specs", skill.get("modifiers", [])):
            stat = mod.get("stat", "")
            if stat in _ALL_STATS:
                add_edge(node_id, f"stat_{stat}", _mod_label(mod))

    # Enemy nodes
    for enemy in enemies:
        eid = enemy.get("id", "")
        if not eid:
            continue
        node_id = f"enemy_{eid}"
        nodes.append(_node(node_id, "enemy", _display_name(enemy, eid), {
            "id": eid,
            "max_hp": enemy.get("max_hp", 0),
            "description": enemy.get("description", ""),
        }))

        for intent in enemy.get("intent_pool", enemy.get("intents", [])):
            intent_type = intent.get("intent", intent.get("type", "")).upper()
            value = intent.get("value", intent.get("damage", 0))
            if intent_type == "ATTACK" and value:
                add_edge(node_id, "stat_DAMAGE", f"intent damage: {value}")
            elif intent_type == "DEFEND" and value:
                add_edge(node_id, "stat_BLOCK", f"intent block: {value}")

    return {"nodes": nodes, "edges": edges}
