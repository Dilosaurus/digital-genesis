"""Read-only game data endpoints — the bible's content browser data layer.

All of these are GETs that return JSON. The frontend Codex pages
(/codex/cards, /codex/characters, etc.) consume them.

In a future phase, the overlay service will sit between the parsers and
these routes to merge active draft edits transparently. For now they read
straight from .tres files via the parser modules.
"""

from __future__ import annotations

from typing import List

from fastapi import APIRouter, HTTPException

from app.models.game import (
    Card,
    Character,
    CorruptionTables,
    DungeonVariant,
    Enemy,
    Equipment,
    Gem,
    Relic,
    SkillNode,
    SkillTree,
)
from app.parsers.cards import load_card, load_cards
from app.parsers.characters import load_character, load_characters
from app.parsers.corruption import load_corruption_tables
from app.parsers.dungeons import load_dungeon_variant, load_dungeon_variants
from app.parsers.enemies import load_enemies, load_enemy
from app.parsers.equipment import load_equipment, load_equipment_item
from app.parsers.gems import load_gem, load_gems
from app.parsers.relics import load_relic, load_relics
from app.parsers.skill_tree import load_skill_tree_nodes, load_skill_trees

router = APIRouter(prefix="/api/codex", tags=["codex"])


# ---------------------------------------------------------------------------
# Cards
# ---------------------------------------------------------------------------


@router.get("/cards", response_model=List[Card])
def get_cards() -> List[Card]:
    """Return every card defined in card_game/data/cards/."""
    return [Card(**c) for c in load_cards()]


@router.get("/cards/{card_id}", response_model=Card)
def get_card(card_id: str) -> Card:
    card = load_card(card_id)
    if card is None:
        raise HTTPException(status_code=404, detail=f"Card not found: {card_id}")
    return Card(**card)


# ---------------------------------------------------------------------------
# Characters
# ---------------------------------------------------------------------------


@router.get("/characters", response_model=List[Character])
def get_characters() -> List[Character]:
    """Return all six playable operators."""
    return [Character(**c) for c in load_characters()]


@router.get("/characters/{character_id}", response_model=Character)
def get_character(character_id: str) -> Character:
    character = load_character(character_id)
    if character is None:
        raise HTTPException(status_code=404, detail=f"Character not found: {character_id}")
    return Character(**character)


# ---------------------------------------------------------------------------
# Gems
# ---------------------------------------------------------------------------


@router.get("/gems", response_model=List[Gem])
def get_gems() -> List[Gem]:
    return [Gem(**g) for g in load_gems()]


@router.get("/gems/{gem_id}", response_model=Gem)
def get_gem(gem_id: str) -> Gem:
    gem = load_gem(gem_id)
    if gem is None:
        raise HTTPException(status_code=404, detail=f"Gem not found: {gem_id}")
    return Gem(**gem)


# ---------------------------------------------------------------------------
# Relics
# ---------------------------------------------------------------------------


@router.get("/relics", response_model=List[Relic])
def get_relics() -> List[Relic]:
    return [Relic(**r) for r in load_relics()]


@router.get("/relics/{relic_id}", response_model=Relic)
def get_relic(relic_id: str) -> Relic:
    relic = load_relic(relic_id)
    if relic is None:
        raise HTTPException(status_code=404, detail=f"Relic not found: {relic_id}")
    return Relic(**relic)


# ---------------------------------------------------------------------------
# Equipment
# ---------------------------------------------------------------------------


@router.get("/equipment", response_model=List[Equipment])
def get_equipment() -> List[Equipment]:
    return [Equipment(**e) for e in load_equipment()]


@router.get("/equipment/{equipment_id}", response_model=Equipment)
def get_equipment_item(equipment_id: str) -> Equipment:
    item = load_equipment_item(equipment_id)
    if item is None:
        raise HTTPException(status_code=404, detail=f"Equipment not found: {equipment_id}")
    return Equipment(**item)


# ---------------------------------------------------------------------------
# Enemies
# ---------------------------------------------------------------------------


@router.get("/enemies", response_model=List[Enemy])
def get_enemies() -> List[Enemy]:
    return [Enemy(**e) for e in load_enemies()]


@router.get("/enemies/{enemy_id}", response_model=Enemy)
def get_enemy(enemy_id: str) -> Enemy:
    enemy = load_enemy(enemy_id)
    if enemy is None:
        raise HTTPException(status_code=404, detail=f"Enemy not found: {enemy_id}")
    return Enemy(**enemy)


# ---------------------------------------------------------------------------
# Dungeon variants
# ---------------------------------------------------------------------------


@router.get("/dungeons", response_model=List[DungeonVariant])
def get_dungeon_variants() -> List[DungeonVariant]:
    return [DungeonVariant(**v) for v in load_dungeon_variants()]


@router.get("/dungeons/{variant_id}", response_model=DungeonVariant)
def get_dungeon_variant(variant_id: str) -> DungeonVariant:
    v = load_dungeon_variant(variant_id)
    if v is None:
        raise HTTPException(status_code=404, detail=f"Dungeon variant not found: {variant_id}")
    return DungeonVariant(**v)


# ---------------------------------------------------------------------------
# Skill tree
# ---------------------------------------------------------------------------


@router.get("/skill-trees", response_model=List[SkillTree])
def get_skill_trees() -> List[SkillTree]:
    """All character skill trees with their nodes, parsed from skill_tree_system.gd."""
    return [SkillTree(**t) for t in load_skill_trees()]


@router.get("/skill-tree-nodes", response_model=List[SkillNode])
def get_skill_tree_nodes() -> List[SkillNode]:
    """Flat list of all skill nodes across every tree (legacy shape)."""
    return [SkillNode(**n) for n in load_skill_tree_nodes()]


# ---------------------------------------------------------------------------
# Corruption tables
# ---------------------------------------------------------------------------


@router.get("/corruption", response_model=CorruptionTables)
def get_corruption() -> CorruptionTables:
    """Corruption transform tables parsed from card_corruption.gd source."""
    return CorruptionTables(**load_corruption_tables())
