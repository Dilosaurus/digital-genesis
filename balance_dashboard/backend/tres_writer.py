"""
tres_writer.py — In-place .tres file modification engine.

Provides functions to update properties in Godot 4 .tres resource files,
add/remove sub_resources (for modifiers), and handle enum string↔int mapping.

All writes are text-level regex replacements to preserve formatting, comments,
ExtResource references, and other structural elements.
"""

from __future__ import annotations

import os
import re
import shutil
from datetime import datetime
from pathlib import Path
from typing import Any

from export_from_tres import (
    CARD_TYPE_NAMES,
    TARGET_TYPE_NAMES,
    CARD_TAG_NAMES,
    STAT_NAMES,
    MOD_OP_NAMES,
    MOD_LIFECYCLE_NAMES,
    EQUIP_SLOT_NAMES,
    ENEMY_INTENT_NAMES,
    RARITY_NAMES,
    parse_tres_file,
)

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

_SCRIPT_DIR = Path(__file__).resolve().parent
CARD_GAME_DIR = _SCRIPT_DIR.parent.parent / "card_game"
DATA_DIR = CARD_GAME_DIR / "data"
BACKUP_DIR = _SCRIPT_DIR.parent / "backups"

# ---------------------------------------------------------------------------
# Reverse enum mappings (string name → int)
# ---------------------------------------------------------------------------

CARD_TYPE_TO_INT = {name: i for i, name in enumerate(CARD_TYPE_NAMES)}
TARGET_TYPE_TO_INT = {name: i for i, name in enumerate(TARGET_TYPE_NAMES)}
CARD_TAG_TO_INT = {name: i for i, name in enumerate(CARD_TAG_NAMES)}
STAT_TO_INT = {name: i for i, name in enumerate(STAT_NAMES)}
MOD_OP_TO_INT = {name: i for i, name in enumerate(MOD_OP_NAMES)}
MOD_LIFECYCLE_TO_INT = {name: i for i, name in enumerate(MOD_LIFECYCLE_NAMES)}
EQUIP_SLOT_TO_INT = {name: i for i, name in enumerate(EQUIP_SLOT_NAMES)}
ENEMY_INTENT_TO_INT = {name: i for i, name in enumerate(ENEMY_INTENT_NAMES)}
RARITY_TO_INT = {name: i for i, name in enumerate(RARITY_NAMES)}

# Which .tres fields use which enum mapping
ENUM_FIELDS: dict[str, dict[str, int]] = {
    "card_type": CARD_TYPE_TO_INT,
    "target_type": TARGET_TYPE_TO_INT,
    "slot": EQUIP_SLOT_TO_INT,
    "rarity": RARITY_TO_INT,
    "stat": STAT_TO_INT,
    "operation": MOD_OP_TO_INT,
    "lifecycle": MOD_LIFECYCLE_TO_INT,
}

# Fields that are tag arrays (list of enum strings → Array[int]([...]))
TAG_ARRAY_FIELDS = {
    "tags": CARD_TAG_TO_INT,
    "required_card_tags": CARD_TAG_TO_INT,
}

# ---------------------------------------------------------------------------
# Allowed fields per entity type (whitelist for validation)
# ---------------------------------------------------------------------------

CARD_FIELDS = {
    "display_name", "description", "energy_cost", "card_type", "target_type",
    "damage", "block", "heal", "draw", "hits", "apply_vulnerable", "apply_weak",
    "corruption_gain", "exhaust", "gain_strength", "gain_dexterity",
    "upgrade_id", "tags", "gem_sockets",
}

RELIC_FIELDS = {
    "display_name", "description", "rarity",
    "start_combat_strength", "start_combat_dexterity",
    "bonus_draw", "corruption_resistance", "max_hp_bonus",
}

EQUIPMENT_FIELDS = {
    "display_name", "description", "slot", "rarity",
}

GEM_FIELDS = {
    "display_name", "description", "rarity",
}

ENEMY_FIELDS = {
    "display_name", "description", "max_hp", "lore",
}

MODIFIER_FIELDS = {
    "id", "stat", "operation", "value", "lifecycle", "duration",
    "required_card_tags", "required_card_type", "only_vs_vulnerable",
    "only_when_hp_below_pct",
}

ENTITY_FIELD_MAP = {
    "cards": CARD_FIELDS,
    "relics": RELIC_FIELDS,
    "equipment": EQUIPMENT_FIELDS,
    "gems": GEM_FIELDS,
    "enemies": ENEMY_FIELDS,
}


# ---------------------------------------------------------------------------
# Resolve entity ID → .tres file path
# ---------------------------------------------------------------------------

def resolve_tres_path(entity_type: str, entity_id: str) -> Path:
    """Map (entity_type, entity_id) to the .tres file on disk."""
    type_to_dir = {
        "cards": "cards",
        "relics": "relics",
        "equipment": "equipment",
        "gems": "gems",
        "enemies": "enemies",
    }
    subdir = type_to_dir.get(entity_type)
    if not subdir:
        raise ValueError(f"Unknown entity type: {entity_type}")
    path = DATA_DIR / subdir / f"{entity_id}.tres"
    if not path.exists():
        raise FileNotFoundError(f"No .tres file found: {path}")
    return path


# ---------------------------------------------------------------------------
# Backup
# ---------------------------------------------------------------------------

def create_backup(filepath: Path, entity_type: str, entity_id: str) -> Path:
    """Copy the .tres file to the backup directory. Returns backup path."""
    backup_subdir = BACKUP_DIR / entity_type
    os.makedirs(backup_subdir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_name = f"{entity_id}_{timestamp}.tres"
    backup_path = backup_subdir / backup_name
    shutil.copy2(filepath, backup_path)
    return backup_path


# ---------------------------------------------------------------------------
# Value serialization (Python → .tres text)
# ---------------------------------------------------------------------------

def _serialize_value(key: str, value: Any) -> str:
    """Convert a Python value to its .tres text representation.

    Handles enum reverse mapping based on the field name.
    """
    # Enum fields: string name → integer
    if key in ENUM_FIELDS and isinstance(value, str):
        mapping = ENUM_FIELDS[key]
        int_val = mapping.get(value.upper())
        if int_val is None:
            raise ValueError(f"Invalid enum value '{value}' for field '{key}'. "
                             f"Valid: {list(mapping.keys())}")
        return str(int_val)

    # Tag array fields: list of string names → Array[int]([0, 2, 5])
    if key in TAG_ARRAY_FIELDS and isinstance(value, list):
        mapping = TAG_ARRAY_FIELDS[key]
        ints = []
        for tag in value:
            int_val = mapping.get(tag.upper())
            if int_val is None:
                raise ValueError(f"Invalid tag '{tag}' for field '{key}'. "
                                 f"Valid: {list(mapping.keys())}")
            ints.append(str(int_val))
        if key == "required_card_tags":
            # Sub-resource conditional: plain array [2, 5]
            return f"[{', '.join(ints)}]"
        # Card tags: typed array
        return f"Array[int]([{', '.join(ints)}])"

    # String
    if isinstance(value, str):
        return f'"{value}"'

    # Boolean
    if isinstance(value, bool):
        return "true" if value else "false"

    # Float — Godot expects explicit decimal for float fields
    if isinstance(value, float):
        return str(value)

    # Integer
    if isinstance(value, int):
        return str(value)

    # List of dicts (intent_pool)
    if isinstance(value, list) and all(isinstance(v, dict) for v in value):
        entries = []
        for item in value:
            parts = []
            for k, v in item.items():
                parts.append(f'"{k}": {_serialize_value(k, v)}')
            entries.append("{" + ", ".join(parts) + "}")
        return "[" + ", ".join(entries) + "]"

    return str(value)


# ---------------------------------------------------------------------------
# Core text-level property update
# ---------------------------------------------------------------------------

def _update_property_in_section(
    text: str,
    section_header_pattern: str,
    key: str,
    serialized_value: str,
) -> str:
    """Find a property line in a specific section and replace its value.

    section_header_pattern: regex to match the section header line, e.g.
        r'^\[resource\]' or r'^\[sub_resource.*id="mod1".*\]'
    """
    # Find the section start
    section_match = re.search(section_header_pattern, text, re.MULTILINE)
    if section_match is None:
        raise ValueError(f"Section not found: {section_header_pattern}")

    section_start = section_match.end()

    # Find the next section start (or end of file)
    next_section = re.search(r"^\[", text[section_start:], re.MULTILINE)
    section_end = section_start + next_section.start() if next_section else len(text)

    section_text = text[section_start:section_end]

    # Find and replace the property line within this section
    prop_pattern = re.compile(
        rf"^({re.escape(key)}\s*=\s*)(.+)$",
        re.MULTILINE,
    )
    prop_match = prop_pattern.search(section_text)
    if prop_match is None:
        # Property doesn't exist yet — add it before the section ends
        # Insert just before the trailing blank lines
        insert_pos = section_end
        # Walk backwards past blank lines
        while insert_pos > section_start and text[insert_pos - 1] in ("\n", "\r", " "):
            insert_pos -= 1
        new_line = f"\n{key} = {serialized_value}\n"
        return text[:insert_pos] + new_line + text[insert_pos:]

    # Replace the value portion
    abs_start = section_start + prop_match.start()
    abs_end = section_start + prop_match.end()
    replacement = f"{prop_match.group(1)}{serialized_value}"
    return text[:abs_start] + replacement + text[abs_end:]


# ---------------------------------------------------------------------------
# Public API: Update resource properties
# ---------------------------------------------------------------------------

def update_resource_property(filepath: Path, key: str, value: Any) -> None:
    """Update a property in the [resource] section of a .tres file."""
    text = filepath.read_text(encoding="utf-8")
    serialized = _serialize_value(key, value)
    new_text = _update_property_in_section(text, r"^\[resource\]", key, serialized)
    filepath.write_text(new_text, encoding="utf-8")


def update_sub_resource_property(
    filepath: Path, sub_id: str, key: str, value: Any
) -> None:
    """Update a property in a [sub_resource ... id="sub_id"] section."""
    text = filepath.read_text(encoding="utf-8")
    serialized = _serialize_value(key, value)
    pattern = rf'^\[sub_resource\s+type="Resource"\s+id="{re.escape(sub_id)}"\]'
    new_text = _update_property_in_section(text, pattern, key, serialized)
    filepath.write_text(new_text, encoding="utf-8")


# ---------------------------------------------------------------------------
# Public API: Add/remove sub_resources
# ---------------------------------------------------------------------------

def _update_load_steps(text: str) -> str:
    """Recalculate and update load_steps in the [gd_resource] header."""
    ext_count = len(re.findall(r"^\[ext_resource", text, re.MULTILINE))
    sub_count = len(re.findall(r"^\[sub_resource", text, re.MULTILINE))
    new_steps = ext_count + sub_count + 1  # +1 for [resource]
    return re.sub(
        r"(load_steps=)\d+",
        rf"\g<1>{new_steps}",
        text,
        count=1,
    )


def add_sub_resource(
    filepath: Path,
    sub_id: str,
    properties: dict[str, Any],
    array_field: str = "modifiers",
    modifier_ext_id: str = "2",
) -> None:
    """Add a new [sub_resource] block and append its reference to the array field.

    Args:
        filepath: Path to the .tres file
        sub_id: ID for the new sub_resource (e.g. "mod2")
        properties: Dict of property key→value for the sub_resource
        array_field: The [resource] property that references sub_resources
                     ("modifiers" or "on_play_modifiers")
        modifier_ext_id: The ext_resource ID for modifier_data.gd (usually "2")
    """
    text = filepath.read_text(encoding="utf-8")

    # Build the sub_resource block
    lines = [f'\n[sub_resource type="Resource" id="{sub_id}"]']
    lines.append(f'script = ExtResource("{modifier_ext_id}")')
    for k, v in properties.items():
        lines.append(f"{k} = {_serialize_value(k, v)}")
    sub_block = "\n".join(lines) + "\n"

    # Insert before [resource]
    resource_match = re.search(r"^\[resource\]", text, re.MULTILINE)
    if resource_match is None:
        raise ValueError("No [resource] section found")
    insert_pos = resource_match.start()
    text = text[:insert_pos] + sub_block + "\n" + text[insert_pos:]

    # Update the array field in [resource] to include the new SubResource ref
    # Find current array value
    array_pattern = re.compile(
        rf"^({re.escape(array_field)}\s*=\s*)(.+)$",
        re.MULTILINE,
    )
    array_match = array_pattern.search(text)
    new_ref = f'SubResource("{sub_id}")'

    if array_match:
        current = array_match.group(2).strip()
        # Parse existing refs
        if current == "[]":
            new_array = f"[{new_ref}]"
        else:
            # Remove trailing ]
            inner = current.rstrip("]").rstrip()
            new_array = f"{inner}, {new_ref}]"
        text = text[:array_match.start()] + f"{array_match.group(1)}{new_array}" + text[array_match.end():]
    else:
        # Field doesn't exist — add it
        text = _update_property_in_section(
            text, r"^\[resource\]", array_field, f"[{new_ref}]"
        )

    # Update load_steps
    text = _update_load_steps(text)

    filepath.write_text(text, encoding="utf-8")


def remove_sub_resource(
    filepath: Path,
    sub_id: str,
    array_field: str = "modifiers",
) -> None:
    """Remove a [sub_resource] block and its reference from the array field."""
    text = filepath.read_text(encoding="utf-8")

    # Remove the sub_resource block
    # Pattern: from [sub_resource...id="sub_id"...] to the next [ section or EOF
    block_pattern = re.compile(
        rf'^\[sub_resource\s+type="Resource"\s+id="{re.escape(sub_id)}"\].*?(?=^\[|\Z)',
        re.MULTILINE | re.DOTALL,
    )
    block_match = block_pattern.search(text)
    if block_match is None:
        raise ValueError(f"Sub-resource '{sub_id}' not found in {filepath}")
    text = text[:block_match.start()] + text[block_match.end():]

    # Remove the SubResource("sub_id") reference from the array
    # Handle: [SubResource("mod1"), SubResource("mod2")] patterns
    ref_str = f'SubResource("{sub_id}")'
    # Remove ", SubResource(...)" or "SubResource(...), " or standalone
    text = re.sub(rf',\s*{re.escape(ref_str)}', '', text)
    text = re.sub(rf'{re.escape(ref_str)}\s*,\s*', '', text)
    text = re.sub(rf'{re.escape(ref_str)}', '', text)

    # Update load_steps
    text = _update_load_steps(text)

    # Clean up any double blank lines
    text = re.sub(r"\n{3,}", "\n\n", text)

    filepath.write_text(text, encoding="utf-8")


# ---------------------------------------------------------------------------
# Public API: Update enemy intent pool (full replacement)
# ---------------------------------------------------------------------------

def update_intent_pool(filepath: Path, intents: list[dict]) -> None:
    """Replace the entire intent_pool array in an enemy .tres file.

    Args:
        intents: List of dicts like [{"intent": "ATTACK", "value": 11}, ...]
                 Intent names are converted to integer enum values.
    """
    # Convert intent names to int format expected by .tres
    tres_intents = []
    for intent in intents:
        intent_type = intent.get("intent", intent.get("type", "UNKNOWN"))
        int_val = ENEMY_INTENT_TO_INT.get(intent_type.upper(), 4)  # 4 = UNKNOWN
        tres_intents.append({
            "type": int_val,
            "value": intent.get("value", 0),
        })

    # Serialize: [{"type": 0, "value": 11}, {"type": 1, "value": 6}]
    entries = []
    for item in tres_intents:
        entries.append(f'{{"type": {item["type"]}, "value": {item["value"]}}}')
    serialized = "[" + ", ".join(entries) + "]"

    text = filepath.read_text(encoding="utf-8")
    new_text = _update_property_in_section(text, r"^\[resource\]", "intent_pool", serialized)
    filepath.write_text(new_text, encoding="utf-8")


# ---------------------------------------------------------------------------
# High-level update with backup + validation
# ---------------------------------------------------------------------------

def validate_fields(entity_type: str, updates: dict[str, Any]) -> None:
    """Validate that all fields in updates are allowed for this entity type."""
    allowed = ENTITY_FIELD_MAP.get(entity_type)
    if allowed is None:
        raise ValueError(f"Unknown entity type: {entity_type}")
    for key in updates:
        if key not in allowed:
            raise ValueError(
                f"Field '{key}' is not editable for {entity_type}. "
                f"Allowed: {sorted(allowed)}"
            )


def validate_modifier_fields(updates: dict[str, Any]) -> None:
    """Validate modifier field names."""
    for key in updates:
        if key not in MODIFIER_FIELDS:
            raise ValueError(
                f"Field '{key}' is not a valid modifier field. "
                f"Allowed: {sorted(MODIFIER_FIELDS)}"
            )


def update_entity(
    entity_type: str,
    entity_id: str,
    updates: dict[str, Any],
) -> Path:
    """Update one or more properties on an entity's .tres file.

    Returns the backup file path.
    """
    validate_fields(entity_type, updates)
    filepath = resolve_tres_path(entity_type, entity_id)
    backup_path = create_backup(filepath, entity_type, entity_id)

    for key, value in updates.items():
        update_resource_property(filepath, key, value)

    return backup_path


def update_modifier(
    entity_type: str,
    entity_id: str,
    mod_id: str,
    updates: dict[str, Any],
) -> Path:
    """Update properties on a modifier sub_resource within an entity .tres file.

    Returns the backup file path.
    """
    validate_modifier_fields(updates)
    filepath = resolve_tres_path(entity_type, entity_id)
    backup_path = create_backup(filepath, entity_type, entity_id)

    for key, value in updates.items():
        update_sub_resource_property(filepath, mod_id, key, value)

    return backup_path


def add_modifier_to_entity(
    entity_type: str,
    entity_id: str,
    mod_id: str,
    mod_properties: dict[str, Any],
) -> Path:
    """Add a new modifier sub_resource to an entity .tres file.

    Returns the backup file path.
    """
    filepath = resolve_tres_path(entity_type, entity_id)
    backup_path = create_backup(filepath, entity_type, entity_id)

    array_field = "on_play_modifiers" if entity_type == "gems" else "modifiers"
    add_sub_resource(filepath, mod_id, mod_properties, array_field)

    return backup_path


def remove_modifier_from_entity(
    entity_type: str,
    entity_id: str,
    mod_id: str,
) -> Path:
    """Remove a modifier sub_resource from an entity .tres file.

    Returns the backup file path.
    """
    filepath = resolve_tres_path(entity_type, entity_id)
    backup_path = create_backup(filepath, entity_type, entity_id)

    array_field = "on_play_modifiers" if entity_type == "gems" else "modifiers"
    remove_sub_resource(filepath, mod_id, array_field)

    return backup_path


def update_enemy_intents(
    entity_id: str,
    intents: list[dict],
) -> Path:
    """Replace the full intent pool on an enemy .tres file.

    Returns the backup file path.
    """
    filepath = resolve_tres_path("enemies", entity_id)
    backup_path = create_backup(filepath, "enemies", entity_id)
    update_intent_pool(filepath, intents)
    return backup_path
