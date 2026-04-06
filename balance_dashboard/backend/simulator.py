"""
simulator.py — Python port of the GDScript modifier pipeline.

Resolution order (mirrors modifier_stack.gd + stat_resolver.gd):
  1. Collect modifiers from all loadout sources.
  2. Pre-stack: apply strength to base damage, dexterity to base block.
  3. Per-stat resolution:
       a. OVERRIDE  — highest value wins, returned immediately.
       b. FLAT_ADD  — sum onto base.
       c. PERCENT_ADD — all stack additively, then one multiply.
       d. PERCENT_MULT — each multiplies independently.
  4. Post-stack: vulnerable (×1.5 damage) and weak (×0.75 damage).
"""

import math
from dataclasses import dataclass, field
from typing import Any

# ---------------------------------------------------------------------------
# Internal modifier representation
# ---------------------------------------------------------------------------

FLAT_ADD = "FLAT_ADD"
PERCENT_ADD = "PERCENT_ADD"
PERCENT_MULT = "PERCENT_MULT"
OVERRIDE = "OVERRIDE"

STAT_DAMAGE = "DAMAGE"
STAT_BLOCK = "BLOCK"
STAT_HEALING = "HEALING"
STAT_MAX_HP = "MAX_HP"
STAT_MAX_ENERGY = "MAX_ENERGY"
STAT_DRAW_PER_TURN = "DRAW_PER_TURN"
STAT_ENERGY_COST = "ENERGY_COST"
STAT_CORRUPTION_GAIN = "CORRUPTION_GAIN"
STAT_CORRUPTION_RESIST = "CORRUPTION_RESIST"

LIFECYCLE_PERMANENT = "PERMANENT"
LIFECYCLE_COMBAT = "COMBAT"
LIFECYCLE_CARD_PLAY = "CARD_PLAY"


@dataclass
class Modifier:
    stat: str
    operation: str
    value: float
    lifecycle: str
    source_type: str   # "relic", "equipment", "gem", "skill_tree", "corruption"
    source_id: str
    source_label: str  # human-readable label for trace output
    # Optional condition tags (from skill_tree conditions)
    conditions: dict = field(default_factory=dict)


# ---------------------------------------------------------------------------
# Modifier collection helpers
# ---------------------------------------------------------------------------

def _collect_relic_modifiers(relic_ids: list[str], relics_data: list[dict]) -> list[Modifier]:
    """
    Translate relic properties into Modifier objects.
    Mirrors modifier_bridge.gd lines 30-49.
      start_combat_strength  -> DAMAGE   FLAT_ADD
      start_combat_dexterity -> BLOCK    FLAT_ADD
      bonus_draw             -> DRAW_PER_TURN FLAT_ADD
      corruption_resistance  -> CORRUPTION_RESIST FLAT_ADD
    """
    mods: list[Modifier] = []
    relic_map = {r["id"]: r for r in relics_data if "id" in r}
    for rid in relic_ids:
        r = relic_map.get(rid)
        if not r:
            continue
        label = f"Relic: {r.get('name', rid)}"
        if r.get("start_combat_strength", 0) > 0:
            mods.append(Modifier(STAT_DAMAGE, FLAT_ADD, float(r["start_combat_strength"]),
                                 LIFECYCLE_COMBAT, "relic", rid, label))
        if r.get("start_combat_dexterity", 0) > 0:
            mods.append(Modifier(STAT_BLOCK, FLAT_ADD, float(r["start_combat_dexterity"]),
                                 LIFECYCLE_COMBAT, "relic", rid, label))
        if r.get("bonus_draw", 0) > 0:
            mods.append(Modifier(STAT_DRAW_PER_TURN, FLAT_ADD, float(r["bonus_draw"]),
                                 LIFECYCLE_COMBAT, "relic", rid, label))
        if r.get("corruption_resistance", 0) > 0:
            mods.append(Modifier(STAT_CORRUPTION_RESIST, FLAT_ADD,
                                 float(r["corruption_resistance"]),
                                 LIFECYCLE_COMBAT, "relic", rid, label))
    return mods


def _collect_equipment_modifiers(equipment_slots: dict[str, str],
                                  equipment_data: list[dict]) -> list[Modifier]:
    """
    Equipment items carry a 'modifiers' array directly.
    Each entry is expected to have: stat, operation, value.
    Lifecycle is PERMANENT as per modifier_bridge.gd (stamped as "equipment").
    """
    mods: list[Modifier] = []
    equip_map = {e["id"]: e for e in equipment_data if "id" in e}
    for slot, equip_id in equipment_slots.items():
        if not equip_id:
            continue
        equip = equip_map.get(equip_id)
        if not equip:
            continue
        label = f"Equipment: {equip.get('name', equip_id)}"
        for raw_mod in equip.get("modifiers", []):
            mods.append(Modifier(
                stat=raw_mod.get("stat", ""),
                operation=raw_mod.get("operation", FLAT_ADD),
                value=float(raw_mod.get("value", 0)),
                lifecycle=LIFECYCLE_PERMANENT,
                source_type="equipment",
                source_id=equip_id,
                source_label=label,
            ))
    return mods


def _collect_corruption_modifiers(corruption_tier: int) -> list[Modifier]:
    """
    Corruption tier → DAMAGE PERCENT_MULT.
    Mirrors modifier_bridge.gd _get_corruption_mult logic:
      tier 0 → no modifier
      tier 1 → ×1.1
      tier 2 → ×1.25
      tier 3 → ×1.5
    """
    _MULT_TABLE = {0: None, 1: 1.1, 2: 1.25, 3: 1.5}
    mult = _MULT_TABLE.get(corruption_tier)
    if mult is None:
        return []
    return [Modifier(STAT_DAMAGE, PERCENT_MULT, mult,
                     LIFECYCLE_COMBAT, "corruption", f"tier_{corruption_tier}",
                     f"Corruption Tier {corruption_tier}")]


def _collect_skill_modifiers(skill_ids: list[str], skills_data: list[dict]) -> list[Modifier]:
    """
    Skills carry a 'modifiers' array.  Lifecycle is PERMANENT.
    Skills may have an optional 'conditions' dict passed through.
    """
    mods: list[Modifier] = []
    skill_map = {s["id"]: s for s in skills_data if "id" in s}
    for sid in skill_ids:
        skill = skill_map.get(sid)
        if not skill:
            continue
        label = f"Skill: {skill.get('name', sid)}"
        for raw_mod in skill.get("modifiers", []):
            mods.append(Modifier(
                stat=raw_mod.get("stat", ""),
                operation=raw_mod.get("operation", FLAT_ADD),
                value=float(raw_mod.get("value", 0)),
                lifecycle=LIFECYCLE_PERMANENT,
                source_type="skill_tree",
                source_id=sid,
                source_label=label,
                conditions=raw_mod.get("conditions", {}),
            ))
    return mods


def _collect_gem_modifiers(gems_for_card: list[str], gems_data: list[dict]) -> list[Modifier]:
    """
    Gems carry a 'modifiers' array.  Lifecycle is CARD_PLAY.
    Only applied to the card they are socketed in.
    """
    mods: list[Modifier] = []
    gem_map = {g["id"]: g for g in gems_data if "id" in g}
    for gid in gems_for_card:
        gem = gem_map.get(gid)
        if not gem:
            continue
        label = f"Gem: {gem.get('name', gid)}"
        for raw_mod in gem.get("modifiers", []):
            mods.append(Modifier(
                stat=raw_mod.get("stat", ""),
                operation=raw_mod.get("operation", FLAT_ADD),
                value=float(raw_mod.get("value", 0)),
                lifecycle=LIFECYCLE_CARD_PLAY,
                source_type="gem",
                source_id=gid,
                source_label=label,
            ))
    return mods


# ---------------------------------------------------------------------------
# Resolution algorithm (modifier_stack.gd lines 40-75)
# ---------------------------------------------------------------------------

@dataclass
class ResolutionTrace:
    """Full breakdown of how a single stat value was resolved."""
    stat: str
    base: float
    flat_adds: list[dict]
    after_flat: float
    pct_adds: list[dict]
    after_pct_add: float
    pct_mults: list[dict]
    after_pct_mult: float
    override_used: bool = False
    override_value: float = 0.0


def _resolve_stat(stat: str, base: float, mods: list[Modifier]) -> ResolutionTrace:
    """
    Run the four-phase resolution for a single stat.
    Mirrors modifier_stack.gd resolve() exactly.
    """
    active = [m for m in mods if m.stat == stat]

    # Phase 1 — OVERRIDE
    overrides = [m for m in active if m.operation == OVERRIDE]
    if overrides:
        best = max(overrides, key=lambda m: m.value)
        return ResolutionTrace(
            stat=stat,
            base=base,
            flat_adds=[],
            after_flat=best.value,
            pct_adds=[],
            after_pct_add=best.value,
            pct_mults=[],
            after_pct_mult=best.value,
            override_used=True,
            override_value=best.value,
        )

    # Phase 2 — FLAT_ADD
    flat_adds = [{"source": m.source_label, "value": m.value}
                 for m in active if m.operation == FLAT_ADD]
    after_flat = base + sum(e["value"] for e in flat_adds)

    # Phase 3 — PERCENT_ADD (all additive, then one multiply)
    pct_adds = [{"source": m.source_label, "value": m.value}
                for m in active if m.operation == PERCENT_ADD]
    pct_add_sum = sum(e["value"] for e in pct_adds)
    after_pct_add = after_flat * (1.0 + pct_add_sum)

    # Phase 4 — PERCENT_MULT (each multiplies independently)
    pct_mults = [{"source": m.source_label, "value": m.value}
                 for m in active if m.operation == PERCENT_MULT]
    result = after_pct_add
    for entry in pct_mults:
        result *= entry["value"]

    return ResolutionTrace(
        stat=stat,
        base=base,
        flat_adds=flat_adds,
        after_flat=after_flat,
        pct_adds=pct_adds,
        after_pct_add=after_pct_add,
        pct_mults=pct_mults,
        after_pct_mult=result,
    )


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def simulate(
    loadout: dict,
    cards: list[dict],
    relics: list[dict],
    equipment: list[dict],
    gems: list[dict],
    skills: list[dict],
) -> list[dict]:
    """
    Run the full modifier pipeline for every card in `cards` given the loadout.

    Parameters
    ----------
    loadout : dict
        {
          "relics": ["relic_id", ...],
          "equipment": {"weapon": "eq_id", "armor": "eq_id", ...},
          "gems": {"card_id": ["gem_id", ...]},
          "skills": ["skill_id", ...],
          "corruption_tier": 0-3,
          "strength": int,
          "dexterity": int,
          "context": {"vulnerable": bool, "weak": bool}
        }
    cards / relics / equipment / gems / skills : list[dict]
        Raw data from data_loader.

    Returns
    -------
    list[dict]  — one entry per card, with full resolution trace.
    """
    selected_relics: list[str] = loadout.get("relics", [])
    equipment_slots: dict[str, str] = loadout.get("equipment", {})
    gems_by_card: dict[str, list[str]] = loadout.get("gems", {})
    selected_skills: list[str] = loadout.get("skills", [])
    corruption_tier: int = int(loadout.get("corruption_tier", 0))
    strength: int = int(loadout.get("strength", 0))
    dexterity: int = int(loadout.get("dexterity", 0))
    context: dict = loadout.get("context", {})
    vulnerable: bool = bool(context.get("vulnerable", False))
    weak: bool = bool(context.get("weak", False))

    # Collect global modifiers (apply to all cards)
    global_mods: list[Modifier] = []
    global_mods.extend(_collect_relic_modifiers(selected_relics, relics))
    global_mods.extend(_collect_equipment_modifiers(equipment_slots, equipment))
    global_mods.extend(_collect_corruption_modifiers(corruption_tier))
    global_mods.extend(_collect_skill_modifiers(selected_skills, skills))

    results = []
    for card in cards:
        card_id: str = card.get("id", "")
        card_name: str = card.get("name", card_id)
        base_damage: int = int(card.get("damage", 0))
        base_block: int = int(card.get("block", 0))
        base_heal: int = int(card.get("heal", 0))

        # Per-card gem modifiers (CARD_PLAY lifecycle)
        card_gem_ids = gems_by_card.get(card_id, [])
        card_mods = global_mods + _collect_gem_modifiers(card_gem_ids, gems)

        # --- Pre-stack (stat_resolver.gd) ---
        # Strength adds to base damage, dexterity adds to base block.
        adj_base_damage = base_damage + strength
        adj_base_block = base_block + dexterity

        # --- Resolution per stat ---
        dmg_trace = _resolve_stat(STAT_DAMAGE, float(adj_base_damage), card_mods)
        blk_trace = _resolve_stat(STAT_BLOCK, float(adj_base_block), card_mods)
        heal_trace = _resolve_stat(STAT_HEALING, float(base_heal), card_mods)

        # --- Post-stack (stat_resolver.gd) ---
        damage_post = dmg_trace.after_pct_mult
        if base_damage > 0:  # only apply to cards that actually deal damage
            if vulnerable:
                damage_post *= 1.5
            if weak:
                damage_post *= 0.75

        final_damage = int(math.floor(damage_post)) if adj_base_damage > 0 else 0
        final_block = int(math.floor(blk_trace.after_pct_mult)) if adj_base_block > 0 else 0
        final_heal = int(math.floor(heal_trace.after_pct_mult)) if base_heal > 0 else 0

        results.append({
            "card_id": card_id,
            "card_name": card_name,
            # Raw bases
            "base_damage": base_damage,
            "base_block": base_block,
            "base_heal": base_heal,
            # Pre-stack bases
            "adjusted_base_damage": adj_base_damage,
            "adjusted_base_block": adj_base_block,
            # Damage trace
            "damage_flat_adds": dmg_trace.flat_adds,
            "damage_after_flat": dmg_trace.after_flat,
            "damage_pct_adds": dmg_trace.pct_adds,
            "damage_after_pct_add": dmg_trace.after_pct_add,
            "damage_pct_mults": dmg_trace.pct_mults,
            "damage_after_pct_mult": dmg_trace.after_pct_mult,
            "damage_post_stack": damage_post,
            "final_damage": final_damage,
            # Block trace
            "block_flat_adds": blk_trace.flat_adds,
            "block_after_flat": blk_trace.after_flat,
            "block_pct_adds": blk_trace.pct_adds,
            "block_after_pct_add": blk_trace.after_pct_add,
            "block_pct_mults": blk_trace.pct_mults,
            "block_after_pct_mult": blk_trace.after_pct_mult,
            "final_block": final_block,
            # Heal trace
            "heal_flat_adds": heal_trace.flat_adds,
            "heal_after_flat": heal_trace.after_flat,
            "heal_pct_adds": heal_trace.pct_adds,
            "heal_after_pct_add": heal_trace.after_pct_add,
            "heal_pct_mults": heal_trace.pct_mults,
            "heal_after_pct_mult": heal_trace.after_pct_mult,
            "final_heal": final_heal,
            # Context flags applied
            "vulnerable_applied": vulnerable and base_damage > 0,
            "weak_applied": weak and base_damage > 0,
            # Gems socketed
            "gems_applied": card_gem_ids,
        })

    return results
