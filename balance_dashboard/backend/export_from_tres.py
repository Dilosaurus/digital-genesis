#!/usr/bin/env python3
"""Export Godot game data from .tres files to JSON for the balance dashboard.

Runs standalone — no Godot required. Call with:
    py export_from_tres.py
from any working directory.
"""

import json
import os
import re
import glob
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

_SCRIPT_DIR = Path(__file__).resolve().parent
CARD_GAME_DIR = _SCRIPT_DIR.parent.parent / "card_game"
DATA_DIR = CARD_GAME_DIR / "data"
OUTPUT_DIR = _SCRIPT_DIR.parent / "data"

# ---------------------------------------------------------------------------
# Enum mappings (from enums.gd)
# ---------------------------------------------------------------------------

CARD_TYPE_NAMES = ["ATTACK", "SKILL", "POWER", "STATUS", "CURSE"]

TARGET_TYPE_NAMES = ["ENEMY", "SELF", "ALL_ENEMIES", "ALL_PLAYERS", "NONE"]

CARD_TAG_NAMES = ["MELEE", "RANGED", "FIRE", "ICE", "HOLY", "SHADOW", "TECH", "EXPLOIT", "CURSE"]

STAT_NAMES = [
    "DAMAGE", "BLOCK", "HEALING", "MAX_HP", "MAX_ENERGY",
    "DRAW_PER_TURN", "ENERGY_COST", "CORRUPTION_GAIN", "CORRUPTION_RESIST",
]

MOD_OP_NAMES = ["FLAT_ADD", "PERCENT_ADD", "PERCENT_MULT", "OVERRIDE"]

MOD_LIFECYCLE_NAMES = ["PERMANENT", "COMBAT", "TURN", "CARD_PLAY", "CONDITIONAL"]

EQUIP_SLOT_NAMES = ["HEAD", "CHEST", "WEAPON", "ACCESSORY"]

ENEMY_INTENT_NAMES = ["ATTACK", "DEFEND", "BUFF", "DEBUFF", "UNKNOWN", "HACK"]

RARITY_NAMES = ["COMMON", "UNCOMMON", "RARE"]


def _enum_name(names: list, index: int, fallback_prefix: str = "UNKNOWN") -> str:
    """Return the string name for an enum integer, or a fallback."""
    if 0 <= index < len(names):
        return names[index]
    return f"{fallback_prefix}_{index}"


# ---------------------------------------------------------------------------
# .tres parser
# ---------------------------------------------------------------------------

def parse_tres_file(filepath: str) -> dict:
    """Parse a Godot 4 .tres file.

    Returns a dict with:
        "resource"      -> dict of the [resource] section properties
        "sub_resources" -> dict mapping sub-resource id -> dict of its properties
        "script_class"  -> str, the script_class from the [gd_resource] header line
    """
    try:
        text = Path(filepath).read_text(encoding="utf-8")
    except OSError as exc:
        raise OSError(f"Cannot read {filepath}: {exc}") from exc

    result = {
        "resource": {},
        "sub_resources": {},
        "script_class": "",
    }

    # Extract script_class from the header
    header_match = re.search(r'script_class="([^"]+)"', text)
    if header_match:
        result["script_class"] = header_match.group(1)

    # Split into sections.  Each section starts with a [...] line.
    # We collect (section_header, properties_block) pairs.
    section_pattern = re.compile(r"^\[(.+?)\]", re.MULTILINE)
    section_starts = [m.start() for m in section_pattern.finditer(text)]
    sections = []
    for i, start in enumerate(section_starts):
        end = section_starts[i + 1] if i + 1 < len(section_starts) else len(text)
        header_end = text.index("]", start) + 1
        header = text[start + 1 : header_end - 1]  # text between [ and ]
        body = text[header_end:end]
        sections.append((header, body))

    for header, body in sections:
        props = _parse_properties(body)

        if header == "resource":
            result["resource"] = props
        elif header.startswith("sub_resource"):
            # Extract the id="..." from the header
            id_match = re.search(r'id="([^"]+)"', header)
            if id_match:
                sub_id = id_match.group(1)
                result["sub_resources"][sub_id] = props
        # ext_resource and gd_resource headers are skipped intentionally

    return result


def _parse_properties(body: str) -> dict:
    """Parse a block of Godot .tres property assignments into a Python dict."""
    props = {}
    # Process line by line, but handle values that continue on the same line only.
    # Godot .tres properties are always single-line assignments.
    for line in body.splitlines():
        line = line.strip()
        if not line or line.startswith(";") or line.startswith("#"):
            continue
        # property = value
        eq_pos = line.find(" = ")
        if eq_pos == -1:
            continue
        key = line[:eq_pos].strip()
        raw_value = line[eq_pos + 3:].strip()
        props[key] = _parse_value(raw_value)
    return props


def _parse_value(raw: str):
    """Convert a raw .tres value string to a Python value."""
    raw = raw.strip()

    # Quoted string
    if raw.startswith('"') and raw.endswith('"'):
        return raw[1:-1]

    # Boolean
    if raw == "true":
        return True
    if raw == "false":
        return False

    # null
    if raw == "null":
        return None

    # SubResource("id") reference — return a marker dict
    sub_match = re.fullmatch(r'SubResource\("([^"]+)"\)', raw)
    if sub_match:
        return {"__subresource__": sub_match.group(1)}

    # ExtResource("id") reference
    ext_match = re.fullmatch(r'ExtResource\("([^"]+)"\)', raw)
    if ext_match:
        return {"__extresource__": ext_match.group(1)}

    # Array[int]([...]) or Array[Type]([...])
    typed_array_match = re.fullmatch(r'Array\[[^\]]*\]\((\[.*\])\)', raw, re.DOTALL)
    if typed_array_match:
        return _parse_array(typed_array_match.group(1))

    # Plain array [...]
    if raw.startswith("[") and raw.endswith("]"):
        return _parse_array(raw)

    # Float
    try:
        if "." in raw or "e" in raw.lower():
            return float(raw)
    except ValueError:
        pass

    # Integer
    try:
        return int(raw)
    except ValueError:
        pass

    # Fallback: return as string
    return raw


def _parse_array(raw: str):
    """Parse a Godot array literal like [item1, item2, ...] or [{...}, {...}]."""
    inner = raw.strip()[1:-1].strip()
    if not inner:
        return []

    # Check if contents look like dictionaries (intent pools, etc.)
    if inner.lstrip().startswith("{"):
        return _parse_dict_array(inner)

    # Split on commas that are not inside {} or ()
    items = _split_top_level(inner)
    return [_parse_value(item.strip()) for item in items if item.strip()]


def _parse_dict_array(inner: str) -> list:
    """Parse an array whose elements are dict literals: [{...}, {...}]."""
    results = []
    depth = 0
    current = []
    for ch in inner:
        if ch == "{":
            depth += 1
            current.append(ch)
        elif ch == "}":
            depth -= 1
            current.append(ch)
            if depth == 0:
                results.append(_parse_gdscript_dict("".join(current).strip()))
                current = []
        elif depth == 0 and ch in (",", " ", "\n", "\t"):
            pass  # skip separators between dicts
        else:
            current.append(ch)
    return results


def _parse_gdscript_dict(raw: str) -> dict:
    """Parse a simple single-level GDScript dict literal like {"key": val, "key2": val2}."""
    result = {}
    inner = raw.strip()
    if inner.startswith("{"):
        inner = inner[1:]
    if inner.endswith("}"):
        inner = inner[:-1]
    for part in _split_top_level(inner):
        part = part.strip()
        if not part:
            continue
        colon = part.find(": ")
        if colon == -1:
            continue
        k = _parse_value(part[:colon].strip())
        v = _parse_value(part[colon + 2:].strip())
        result[str(k)] = v
    return result


def _split_top_level(s: str) -> list:
    """Split s on commas that are not nested inside brackets/braces/parens/quotes."""
    parts = []
    depth = 0
    in_string = False
    escape_next = False
    current = []
    for ch in s:
        if escape_next:
            current.append(ch)
            escape_next = False
            continue
        if ch == "\\" and in_string:
            escape_next = True
            current.append(ch)
            continue
        if ch == '"' and depth == 0:
            in_string = not in_string
            current.append(ch)
            continue
        if in_string:
            current.append(ch)
            continue
        if ch in ("{", "[", "("):
            depth += 1
            current.append(ch)
        elif ch in ("}", "]", ")"):
            depth -= 1
            current.append(ch)
        elif ch == "," and depth == 0:
            parts.append("".join(current))
            current = []
        else:
            current.append(ch)
    if current:
        parts.append("".join(current))
    return parts


# ---------------------------------------------------------------------------
# Sub-resource resolution helpers
# ---------------------------------------------------------------------------

def _resolve_modifiers(mod_refs: list, sub_resources: dict) -> list:
    """Expand a list of SubResource marker dicts into modifier dicts."""
    result = []
    for ref in mod_refs:
        if not isinstance(ref, dict) or "__subresource__" not in ref:
            continue
        sub_id = ref["__subresource__"]
        props = sub_resources.get(sub_id, {})
        if not props:
            continue
        result.append(_build_modifier_dict(props))
    return result


def _build_modifier_dict(props: dict) -> dict:
    """Convert raw sub-resource properties into a clean modifier dict."""
    stat_idx = props.get("stat", 0)
    op_idx = props.get("operation", 0)
    lifecycle_idx = props.get("lifecycle", 0)

    mod = {
        "id": props.get("id", ""),
        "stat": _enum_name(STAT_NAMES, stat_idx, "STAT"),
        "operation": _enum_name(MOD_OP_NAMES, op_idx, "OP"),
        "value": props.get("value", 0.0),
        "lifecycle": _enum_name(MOD_LIFECYCLE_NAMES, lifecycle_idx, "LIFECYCLE"),
        "duration": props.get("duration", -1),
    }

    # Conditional fields — only include when set
    req_tags_raw = props.get("required_card_tags", [])
    if req_tags_raw:
        mod["required_card_tags"] = [
            _enum_name(CARD_TAG_NAMES, t, "TAG") for t in req_tags_raw
        ]

    req_card_type = props.get("required_card_type", -1)
    if req_card_type != -1:
        mod["required_card_type"] = _enum_name(CARD_TYPE_NAMES, req_card_type, "TYPE")

    if props.get("only_vs_vulnerable", False):
        mod["only_vs_vulnerable"] = True

    hp_below = props.get("only_when_hp_below_pct", -1.0)
    if isinstance(hp_below, (int, float)) and hp_below >= 0.0:
        mod["only_when_hp_below_pct"] = hp_below

    return mod


# ---------------------------------------------------------------------------
# Export functions
# ---------------------------------------------------------------------------

def export_cards() -> list:
    """Parse all card .tres files and return a list of card dicts."""
    pattern = str(DATA_DIR / "cards" / "*.tres")
    cards = []
    for filepath in sorted(glob.glob(pattern)):
        try:
            parsed = parse_tres_file(filepath)
        except Exception as exc:
            print(f"  WARNING: skipping {filepath} — {exc}")
            continue

        props = parsed["resource"]
        if not props:
            print(f"  WARNING: no [resource] section in {filepath}")
            continue

        card_type_idx = props.get("card_type", 0)
        target_type_idx = props.get("target_type", 0)

        # tags is Array[int]([...]) in the .tres — already a list of ints
        raw_tags = props.get("tags", [])
        if isinstance(raw_tags, list):
            tag_names = [_enum_name(CARD_TAG_NAMES, t, "TAG") for t in raw_tags]
        else:
            tag_names = []

        card = {
            "id": props.get("id", ""),
            "display_name": props.get("display_name", ""),
            "description": props.get("description", ""),
            "energy_cost": props.get("energy_cost", 1),
            "card_type": _enum_name(CARD_TYPE_NAMES, card_type_idx, "TYPE"),
            "target_type": _enum_name(TARGET_TYPE_NAMES, target_type_idx, "TARGET"),
            "damage": props.get("damage", 0),
            "block": props.get("block", 0),
            "heal": props.get("heal", 0),
            "draw": props.get("draw", 0),
            "hits": props.get("hits", 1),
            "apply_vulnerable": props.get("apply_vulnerable", 0),
            "apply_weak": props.get("apply_weak", 0),
            "corruption_gain": props.get("corruption_gain", 0),
            "exhaust": props.get("exhaust", False),
            "gain_strength": props.get("gain_strength", 0),
            "gain_dexterity": props.get("gain_dexterity", 0),
            "upgraded": props.get("upgraded", False),
            "upgrade_id": props.get("upgrade_id", ""),
            "tags": tag_names,
            "gem_sockets": props.get("gem_sockets", 0),
        }
        cards.append(card)

    return cards


def export_relics() -> list:
    """Parse all relic .tres files and return a list of relic dicts."""
    pattern = str(DATA_DIR / "relics" / "*.tres")
    relics = []
    for filepath in sorted(glob.glob(pattern)):
        try:
            parsed = parse_tres_file(filepath)
        except Exception as exc:
            print(f"  WARNING: skipping {filepath} — {exc}")
            continue

        props = parsed["resource"]
        if not props:
            print(f"  WARNING: no [resource] section in {filepath}")
            continue

        # Collect all non-script properties dynamically — relic fields vary widely
        relic = {
            "id": props.get("id", ""),
            "display_name": props.get("display_name", ""),
            "description": props.get("description", ""),
            "rarity": _enum_name(RARITY_NAMES, int(props.get("rarity", 0))),
        }

        # Include all other numeric/bool fields that are not structural overhead
        _skip = {"id", "display_name", "description", "rarity", "script"}
        for key, value in props.items():
            if key not in _skip and not isinstance(value, dict):
                relic[key] = value

        relics.append(relic)

    return relics


def export_equipment() -> list:
    """Parse all equipment .tres files and expand modifier sub-resources."""
    pattern = str(DATA_DIR / "equipment" / "*.tres")
    equipment_list = []
    for filepath in sorted(glob.glob(pattern)):
        try:
            parsed = parse_tres_file(filepath)
        except Exception as exc:
            print(f"  WARNING: skipping {filepath} — {exc}")
            continue

        props = parsed["resource"]
        sub_resources = parsed["sub_resources"]
        if not props:
            print(f"  WARNING: no [resource] section in {filepath}")
            continue

        slot_idx = props.get("slot", 0)
        mod_refs = props.get("modifiers", [])
        modifiers = _resolve_modifiers(
            mod_refs if isinstance(mod_refs, list) else [],
            sub_resources,
        )

        equip = {
            "id": props.get("id", ""),
            "display_name": props.get("display_name", ""),
            "description": props.get("description", ""),
            "slot": _enum_name(EQUIP_SLOT_NAMES, slot_idx, "SLOT"),
            "rarity": _enum_name(RARITY_NAMES, int(props.get("rarity", 0))),
            "modifiers": modifiers,
        }
        equipment_list.append(equip)

    return equipment_list


def export_gems() -> list:
    """Parse all gem .tres files and expand on_play_modifiers sub-resources."""
    pattern = str(DATA_DIR / "gems" / "*.tres")
    gems = []
    for filepath in sorted(glob.glob(pattern)):
        try:
            parsed = parse_tres_file(filepath)
        except Exception as exc:
            print(f"  WARNING: skipping {filepath} — {exc}")
            continue

        props = parsed["resource"]
        sub_resources = parsed["sub_resources"]
        if not props:
            print(f"  WARNING: no [resource] section in {filepath}")
            continue

        mod_refs = props.get("on_play_modifiers", [])
        modifiers = _resolve_modifiers(
            mod_refs if isinstance(mod_refs, list) else [],
            sub_resources,
        )

        gem = {
            "id": props.get("id", ""),
            "display_name": props.get("display_name", ""),
            "description": props.get("description", ""),
            "rarity": _enum_name(RARITY_NAMES, int(props.get("rarity", 0))),
            "on_play_modifiers": modifiers,
        }
        gems.append(gem)

    return gems


def export_enemies() -> list:
    """Parse all enemy .tres files and expand intent_pool arrays."""
    pattern = str(DATA_DIR / "enemies" / "*.tres")
    enemies = []
    for filepath in sorted(glob.glob(pattern)):
        try:
            parsed = parse_tres_file(filepath)
        except Exception as exc:
            print(f"  WARNING: skipping {filepath} — {exc}")
            continue

        props = parsed["resource"]
        if not props:
            print(f"  WARNING: no [resource] section in {filepath}")
            continue

        raw_pool = props.get("intent_pool", [])
        intent_pool = []
        for entry in raw_pool:
            if isinstance(entry, dict):
                # Already parsed as a dict from the .tres {"type": 0, "value": 11} literal
                type_idx = entry.get("type", 0)
                intent_pool.append({
                    "intent": _enum_name(ENEMY_INTENT_NAMES, type_idx, "INTENT"),
                    "value": entry.get("value", 0),
                })

        enemy = {
            "id": props.get("id", ""),
            "display_name": props.get("display_name", ""),
            "max_hp": props.get("max_hp", 0),
            "intent_pool": intent_pool,
        }
        enemies.append(enemy)

    return enemies


# ---------------------------------------------------------------------------
# Skill tree extractor (parses GDScript source)
# ---------------------------------------------------------------------------

def export_skill_tree() -> list:
    """Extract skill node definitions from skill_tree_system.gd source.

    Parses every _node(...) call inside _create_default_trees() and returns
    a list of node dicts.  Also resolves nested _spec(...) calls inline.
    """
    source_path = CARD_GAME_DIR / "scripts" / "systems" / "skill_tree_system.gd"
    try:
        source = source_path.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"  WARNING: cannot read skill_tree_system.gd — {exc}")
        return []

    nodes = []

    # First resolve _spec(...) helper calls so they appear as plain dict literals.
    # Pattern: _spec("stat", "op", value [, [tags], vs_vuln, hp_below])
    # We do a two-pass approach: find all _node(…) blocks, then extract _spec(…) inside them.

    # Find the _create_default_trees function body.
    # The function may extend to end-of-file, so we match from the def line
    # until the next top-level (un-indented) "static func" or end of string.
    func_match = re.search(
        r"static func _create_default_trees\(\) -> void:(.*?)(?=\nstatic func |\Z)",
        source,
        re.DOTALL,
    )
    if not func_match:
        print("  WARNING: could not locate _create_default_trees in skill_tree_system.gd")
        return []

    func_body = func_match.group(1)

    # Extract individual _node(...) calls — they span multiple lines.
    # Strategy: find "tree.nodes.append(_node(" and capture until matching closing "))"
    node_calls = _extract_node_calls(func_body)
    for raw_call in node_calls:
        node_dict = _parse_node_call(raw_call)
        if node_dict:
            nodes.append(node_dict)

    return nodes


def _extract_node_calls(func_body: str) -> list:
    """Find all tree.nodes.append(_node(...)) call bodies in func_body."""
    results = []
    pattern = re.compile(r"tree\.nodes\.append\(_node\(")
    for match in pattern.finditer(func_body):
        start = match.end()  # position after "_node("
        depth = 1
        i = start
        while i < len(func_body) and depth > 0:
            if func_body[i] == "(":
                depth += 1
            elif func_body[i] == ")":
                depth -= 1
            i += 1
        # func_body[start:i-1] is the args to _node(...)
        results.append(func_body[start : i - 1])
    return results


def _parse_node_call(args_text: str) -> dict:
    """Parse the arguments of a _node(...) call into a dict.

    _node(id, name, desc, tier, cost, prereqs_array, specs_array, pos)
    """
    # Normalise whitespace
    args_text = re.sub(r"\s+", " ", args_text).strip()

    # Split top-level arguments
    parts = _split_top_level(args_text)
    if len(parts) < 7:
        return {}

    def unquote(s: str) -> str:
        s = s.strip()
        if s.startswith('"') and s.endswith('"'):
            return s[1:-1]
        return s

    node_id = unquote(parts[0])
    name = unquote(parts[1])
    desc = unquote(parts[2])
    tier = int(parts[3].strip())
    cost = int(parts[4].strip())

    # prereqs: ["id1", "id2"] or []
    prereqs = _parse_string_array(parts[5].strip())

    # specs: [_spec(...), _spec(...)] or [...]
    specs = _parse_specs_array(parts[6].strip())

    # position: Vector2(x, y) — extract x, y
    pos_match = re.search(r"Vector2\(([^,]+),\s*([^)]+)\)", parts[7].strip() if len(parts) > 7 else "")
    position = {"x": 0, "y": 0}
    if pos_match:
        position = {
            "x": float(pos_match.group(1).strip()),
            "y": float(pos_match.group(2).strip()),
        }

    return {
        "id": node_id,
        "display_name": name,
        "description": desc,
        "tier": tier,
        "cost": cost,
        "prerequisites": prereqs,
        "modifier_specs": specs,
        "position": position,
    }


def _parse_string_array(raw: str) -> list:
    """Parse ["a", "b"] style array from GDScript source."""
    inner = raw.strip()
    if inner.startswith("["):
        inner = inner[1:]
    if inner.endswith("]"):
        inner = inner[:-1]
    inner = inner.strip()
    if not inner:
        return []
    return [s.strip().strip('"') for s in inner.split(",") if s.strip().strip('"')]


def _parse_specs_array(raw: str) -> list:
    """Parse [ _spec(...), _spec(...) ] from GDScript source."""
    inner = raw.strip()
    if inner.startswith("["):
        inner = inner[1:]
    if inner.endswith("]"):
        inner = inner[:-1]
    inner = inner.strip()
    if not inner:
        return []

    # Find all _spec(...) calls
    specs = []
    spec_pattern = re.compile(r"_spec\(")
    for match in spec_pattern.finditer(inner):
        start = match.end()
        depth = 1
        i = start
        while i < len(inner) and depth > 0:
            if inner[i] == "(":
                depth += 1
            elif inner[i] == ")":
                depth -= 1
            i += 1
        spec_args = inner[start : i - 1]
        spec_dict = _parse_spec_call(spec_args)
        if spec_dict:
            specs.append(spec_dict)
    return specs


def _parse_spec_call(args_text: str) -> dict:
    """Parse _spec(stat, op, value [, req_tags, vs_vuln, hp_below]) into a dict.

    The signature is:
        _spec(stat: String, op: String, value: float,
              req_tags: Array = [], vs_vuln: bool = false, hp_below: float = -1.0)
    """
    parts = _split_top_level(args_text)
    if len(parts) < 3:
        return {}

    def unquote(s: str) -> str:
        s = s.strip()
        if s.startswith('"') and s.endswith('"'):
            return s[1:-1]
        return s

    stat = unquote(parts[0])
    op = unquote(parts[1])
    value = float(parts[2].strip())

    req_tags = []
    vs_vuln = False
    hp_below = -1.0

    if len(parts) > 3:
        req_tags = _parse_string_array(parts[3].strip())
    if len(parts) > 4:
        vs_vuln = parts[4].strip() == "true"
    if len(parts) > 5:
        try:
            hp_below = float(parts[5].strip())
        except ValueError:
            pass

    spec = {
        "stat": stat.upper(),
        "operation": op.upper(),
        "value": value,
    }
    if req_tags:
        spec["required_card_tags"] = [t.upper() for t in req_tags]
    if vs_vuln:
        spec["only_vs_vulnerable"] = True
    if hp_below >= 0.0:
        spec["only_when_hp_below_pct"] = hp_below

    return spec


# ---------------------------------------------------------------------------
# Corruption extractor (parses GDScript source)
# ---------------------------------------------------------------------------

def export_corruption() -> dict:
    """Extract CORRUPTED_CARDS and SHRINE_CORRUPTED_CARDS from card_corruption.gd.

    Returns {"corrupted": [...], "shrine_corrupted": [...]}.
    """
    source_path = CARD_GAME_DIR / "scripts" / "systems" / "card_corruption.gd"
    try:
        source = source_path.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"  WARNING: cannot read card_corruption.gd — {exc}")
        return {"corrupted": [], "shrine_corrupted": []}

    corrupted = _extract_gdscript_const_dict(source, "CORRUPTED_CARDS")
    shrine = _extract_gdscript_const_dict(source, "SHRINE_CORRUPTED_CARDS")

    # Convert dict-of-dicts to list form for uniform JSON output
    corrupted_list = [{"card_id": k, **v} for k, v in corrupted.items()]
    shrine_list = [{"card_id": k, **v} for k, v in shrine.items()]

    return {
        "corrupted": corrupted_list,
        "shrine_corrupted": shrine_list,
    }


def _extract_gdscript_const_dict(source: str, const_name: str) -> dict:
    """Extract a const DICT_NAME = { ... } from GDScript source.

    Returns the parsed dict.  Values are kept as plain Python types.
    Handles nested dicts one level deep (for SHRINE_CORRUPTED_CARDS).
    """
    # Find the const declaration
    pattern = re.compile(
        r"const\s+" + re.escape(const_name) + r"\s*=\s*\{",
    )
    match = pattern.search(source)
    if not match:
        print(f"  WARNING: could not find const {const_name} in source")
        return {}

    # Walk forward to find the matching closing brace of the top-level dict
    start = match.end()  # position after "{"
    depth = 1
    i = start
    while i < len(source) and depth > 0:
        if source[i] == "{":
            depth += 1
        elif source[i] == "}":
            depth -= 1
        i += 1
    raw_dict_body = source[start : i - 1]

    return _parse_gdscript_nested_dict(raw_dict_body)


def _parse_gdscript_nested_dict(body: str) -> dict:
    """Parse the body of a GDScript dict that may contain nested dicts.

    Top-level keys are strings.  Values may be strings, numbers, booleans,
    or nested dict literals.  Comments (# ...) are stripped first.
    """
    # Strip line comments
    body = re.sub(r"#[^\n]*", "", body)

    result = {}

    # Split on top-level commas to get "key: value" pairs, but top-level
    # means not inside a nested {}.  We walk char-by-char.
    entries = _split_top_level(body)
    for entry in entries:
        entry = entry.strip()
        if not entry:
            continue

        # Find the colon separating key from value
        colon_pos = _find_top_level_colon(entry)
        if colon_pos == -1:
            continue

        raw_key = entry[:colon_pos].strip().strip('"')
        raw_val = entry[colon_pos + 1:].strip()

        result[raw_key] = _parse_gdscript_value(raw_val)

    return result


def _find_top_level_colon(s: str) -> int:
    """Return the index of the first colon at brace depth 0."""
    depth = 0
    for i, ch in enumerate(s):
        if ch in ("{", "[", "("):
            depth += 1
        elif ch in ("}", "]", ")"):
            depth -= 1
        elif ch == ":" and depth == 0:
            return i
    return -1


def _parse_gdscript_value(raw: str):
    """Parse a GDScript value — string, number, bool, or nested dict."""
    raw = raw.strip()
    if raw.startswith('"') and raw.endswith('"'):
        return raw[1:-1]
    if raw == "true":
        return True
    if raw == "false":
        return False
    if raw.startswith("{") and raw.endswith("}"):
        return _parse_gdscript_nested_dict(raw[1:-1])
    try:
        if "." in raw:
            return float(raw)
        return int(raw)
    except ValueError:
        return raw


# ---------------------------------------------------------------------------
# Targeted re-export: update a single entity in its JSON file
# ---------------------------------------------------------------------------

_EXPORT_FN = {
    "cards": export_cards,
    "relics": export_relics,
    "equipment": export_equipment,
    "gems": export_gems,
    "enemies": export_enemies,
}


def reexport_entity_type(entity_type: str) -> list:
    """Re-export all entities of a given type and write the JSON file.

    Returns the full list of exported entities.
    """
    export_fn = _EXPORT_FN.get(entity_type)
    if not export_fn:
        raise ValueError(f"Cannot re-export entity type: {entity_type}")

    data = export_fn()
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    out_path = OUTPUT_DIR / f"{entity_type}.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    return data


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"Output directory: {OUTPUT_DIR}")
    print()

    print("Exporting cards...")
    cards = export_cards()

    print("Exporting relics...")
    relics = export_relics()

    print("Exporting equipment...")
    equipment = export_equipment()

    print("Exporting gems...")
    gems = export_gems()

    print("Exporting enemies...")
    enemies = export_enemies()

    print("Exporting skill tree...")
    skill_tree = export_skill_tree()

    print("Exporting corruption tables...")
    corruption = export_corruption()

    exports = [
        ("cards", cards),
        ("relics", relics),
        ("equipment", equipment),
        ("gems", gems),
        ("enemies", enemies),
        ("skill_tree", skill_tree),
        ("corruption", corruption),
    ]

    print()
    for name, data in exports:
        out_path = OUTPUT_DIR / f"{name}.json"
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        count = (
            len(data)
            if isinstance(data, list)
            else (
                len(data.get("corrupted", [])) + len(data.get("shrine_corrupted", []))
                if isinstance(data, dict)
                else 1
            )
        )
        print(f"  {name}.json — {count} entries")

    print()
    print("Export complete.")


if __name__ == "__main__":
    main()
