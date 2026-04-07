"""Card-corruption table extractor.

card_corruption.gd defines two big GDScript const dicts:
    CORRUPTED_CARDS         — automatic transforms triggered by corruption tier
    SHRINE_CORRUPTED_CARDS  — permanent shrine upgrades with deliberate drawbacks

Neither is in a .tres file. We parse the GDScript source.

Lifted (with light cleanup) from the legacy export_from_tres.py.
"""

from __future__ import annotations

import re
from typing import Any, Dict, List

from app.config import CARD_CORRUPTION_GD


def load_corruption_tables() -> Dict[str, List[Dict[str, Any]]]:
    """Return {"corrupted": [...], "shrine_corrupted": [...]}."""
    if not CARD_CORRUPTION_GD.exists():
        return {"corrupted": [], "shrine_corrupted": []}

    source = CARD_CORRUPTION_GD.read_text(encoding="utf-8")
    corrupted = _extract_const_dict(source, "CORRUPTED_CARDS")
    shrine = _extract_const_dict(source, "SHRINE_CORRUPTED_CARDS")
    return {
        "corrupted": [{"card_id": k, **v} for k, v in corrupted.items()],
        "shrine_corrupted": [{"card_id": k, **v} for k, v in shrine.items()],
    }


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------


def _extract_const_dict(source: str, const_name: str) -> Dict[str, Any]:
    pattern = re.compile(r"const\s+" + re.escape(const_name) + r"\s*=\s*\{")
    match = pattern.search(source)
    if not match:
        return {}

    start = match.end()
    depth = 1
    i = start
    while i < len(source) and depth > 0:
        if source[i] == "{":
            depth += 1
        elif source[i] == "}":
            depth -= 1
        i += 1
    return _parse_nested_dict(source[start : i - 1])


def _parse_nested_dict(body: str) -> Dict[str, Any]:
    body = re.sub(r"#[^\n]*", "", body)
    result: Dict[str, Any] = {}
    for entry in _split_top_level(body):
        entry = entry.strip()
        if not entry:
            continue
        colon_pos = _find_top_level_colon(entry)
        if colon_pos == -1:
            continue
        raw_key = entry[:colon_pos].strip().strip('"')
        raw_val = entry[colon_pos + 1 :].strip()
        result[raw_key] = _parse_value(raw_val)
    return result


def _find_top_level_colon(s: str) -> int:
    depth = 0
    for i, ch in enumerate(s):
        if ch in ("{", "[", "("):
            depth += 1
        elif ch in ("}", "]", ")"):
            depth -= 1
        elif ch == ":" and depth == 0:
            return i
    return -1


def _parse_value(raw: str) -> Any:
    raw = raw.strip()
    if raw.startswith('"') and raw.endswith('"'):
        return raw[1:-1]
    if raw == "true":
        return True
    if raw == "false":
        return False
    if raw.startswith("{") and raw.endswith("}"):
        return _parse_nested_dict(raw[1:-1])
    if raw.startswith("[") and raw.endswith("]"):
        inner = raw[1:-1].strip()
        if not inner:
            return []
        return [_parse_value(p.strip()) for p in _split_top_level(inner)]
    try:
        if "." in raw:
            return float(raw)
        return int(raw)
    except ValueError:
        return raw


def _split_top_level(s: str) -> List[str]:
    parts: List[str] = []
    depth = 0
    in_string = False
    escape_next = False
    current: List[str] = []
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
