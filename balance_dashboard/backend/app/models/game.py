"""Pydantic models for the game-data API.

These match the dicts produced by app.parsers.* — they exist to give
FastAPI auto-generated OpenAPI docs and runtime validation. The parser
modules return plain dicts; FastAPI coerces them through these models on
the way out.
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Modifier — shared between gems, equipment, skill tree
# ---------------------------------------------------------------------------


class Modifier(BaseModel):
    id: str = ""
    stat: str = "DAMAGE"
    operation: str = "FLAT_ADD"
    value: float = 0.0
    lifecycle: str = "PERMANENT"
    duration: int = -1
    required_card_tags: Optional[List[str]] = None
    required_card_type: Optional[str] = None
    only_vs_vulnerable: Optional[bool] = None
    only_when_hp_below_pct: Optional[float] = None


# ---------------------------------------------------------------------------
# Card
# ---------------------------------------------------------------------------


class Card(BaseModel):
    """A single card from card_game/data/cards/*.tres."""

    # Core
    id: str
    display_name: str = ""
    description: str = ""
    energy_cost: int = 1
    card_type: str = "ATTACK"
    target_type: str = "ENEMY"
    rarity: str = "COMMON"
    character_class: int = -1  # -1 = shared, 0..5 = exclusive
    tags: List[str] = Field(default_factory=list)
    artwork: str = ""

    # Combat stats
    damage: int = 0
    block: int = 0
    heal: int = 0
    draw: int = 0
    hits: int = 1
    apply_vulnerable: int = 0
    apply_weak: int = 0
    corruption_gain: int = 0
    exhaust: bool = False
    gain_strength: int = 0
    gain_dexterity: int = 0

    # Upgrade chain + sockets
    upgraded: bool = False
    upgrade_id: str = ""
    cooldown_max: int = 0
    gem_sockets: int = 0

    # Co-op / party
    party_heal: int = 0
    party_draw: int = 0
    party_damage: int = 0
    share_block: bool = False
    transfer_mana: int = 0
    mark_target: bool = False

    # Revival
    revive_ally: bool = False
    revive_hp: int = 15

    # Corruption removal
    corruption_remove: int = 0
    party_corruption_remove: int = 0

    # Scourge / PIRACY
    steal_block: int = 0
    steal_all_block: bool = False
    aoe_steal_block: int = 0
    create_contraband: int = 0
    destroy_contraband_for_damage: int = 0
    destroy_contraband_for_block: int = 0
    destroy_contraband_corruption: int = 0
    damage_per_card_played: int = 0
    damage_per_contraband_in_hand: int = 0
    conditional_damage_if_zero_block: int = 0
    aoe_damage: int = 0

    # FLUX / Daemons
    create_daemon_fragment: int = 0
    destroy_daemons_for_damage: int = 0


# ---------------------------------------------------------------------------
# Character
# ---------------------------------------------------------------------------


class Character(BaseModel):
    """A single playable operator from card_game/data/characters/*.tres."""

    id: str
    display_name: str = ""
    title: str = ""
    character_class: str = "NETRUNNER"
    character_class_index: int = 0
    backstory: str = ""
    passive_name: str = ""
    passive_description: str = ""
    starter_deck: List[str] = Field(default_factory=list)
    starting_hp: int = 80
    starting_energy: int = 3
    color_primary: str = "#FFFFFF"
    color_primary_rgba: List[float] = Field(default_factory=lambda: [1.0, 1.0, 1.0, 1.0])
    color_secondary: str = "#888888"
    color_secondary_rgba: List[float] = Field(default_factory=lambda: [0.5, 0.5, 0.5, 1.0])
    icon_text: str = ""


# ---------------------------------------------------------------------------
# Gem
# ---------------------------------------------------------------------------


class Gem(BaseModel):
    id: str
    display_name: str = ""
    description: str = ""
    rarity: str = "COMMON"
    icon: str = ""
    on_play_modifiers: List[Modifier] = Field(default_factory=list)
    trigger_event: str = ""
    trigger_effect: str = ""
    trigger_value: int = 0
    convert_damage_to_heal: bool = False
    extra_hit_percent: float = 0.0
    add_create_contraband: int = 0


# ---------------------------------------------------------------------------
# Relic
# ---------------------------------------------------------------------------


class Relic(BaseModel):
    id: str
    display_name: str = ""
    description: str = ""
    rarity: str = "COMMON"
    icon: str = ""
    start_combat_strength: int = 0
    start_combat_dexterity: int = 0
    start_combat_block: int = 0
    bonus_draw: int = 0
    bonus_max_energy: int = 0
    bonus_max_hp: int = 0
    heal_on_combat_end: int = 0
    corruption_resistance: int = 0
    auto_revive: bool = False


# ---------------------------------------------------------------------------
# Equipment
# ---------------------------------------------------------------------------


class Equipment(BaseModel):
    id: str
    display_name: str = ""
    description: str = ""
    slot: str = "ACCESSORY"
    rarity: str = "COMMON"
    icon: str = ""
    modifiers: List[Modifier] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Enemy
# ---------------------------------------------------------------------------


class EnemyIntent(BaseModel):
    intent: str = "UNKNOWN"
    value: int = 0


class Enemy(BaseModel):
    id: str
    display_name: str = ""
    description: str = ""
    lore: str = ""
    max_hp: int = 0
    artwork: str = ""
    intent_pool: List[EnemyIntent] = Field(default_factory=list)
    phases: List[Dict[str, Any]] = Field(default_factory=list)
    xp_reward: int = 0


# ---------------------------------------------------------------------------
# Dungeon variant
# ---------------------------------------------------------------------------


class DungeonVariant(BaseModel):
    id: str
    display_name: str = "Unknown Dungeon"
    lighting_preset: str = "act1"
    is_boss_arena: bool = False
    base_dungeon: str = ""
    decay_overlay: str = ""


# ---------------------------------------------------------------------------
# Skill tree
# ---------------------------------------------------------------------------


class SkillSpec(BaseModel):
    stat: str
    operation: str
    value: float
    required_card_tags: Optional[List[str]] = None
    only_vs_vulnerable: Optional[bool] = None
    only_when_hp_below_pct: Optional[float] = None


class SkillNode(BaseModel):
    id: str
    display_name: str = ""
    description: str = ""
    tier: int = 0
    cost: int = 1
    prerequisites: List[str] = Field(default_factory=list)
    modifier_specs: List[SkillSpec] = Field(default_factory=list)
    position: Dict[str, float] = Field(default_factory=lambda: {"x": 0.0, "y": 0.0})


class SkillTree(BaseModel):
    id: str
    display_name: str = ""
    nodes: List[SkillNode] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Corruption tables
# ---------------------------------------------------------------------------


class CorruptionEntry(BaseModel):
    """Loose schema for corruption table entries — fields vary widely."""

    card_id: str
    display_name: str = ""
    description: str = ""

    model_config = {"extra": "allow"}


class CorruptionTables(BaseModel):
    corrupted: List[CorruptionEntry] = Field(default_factory=list)
    shrine_corrupted: List[CorruptionEntry] = Field(default_factory=list)
