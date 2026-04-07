"""Godot 4 .tres file parser.

Lifted (with light cleanup) from the legacy export_from_tres.py.
Reads .tres files into a structured dict with three sections:

    {
        "resource":      dict of [resource] section properties
        "sub_resources": dict mapping sub-resource id -> properties
        "ext_resources": dict mapping ext-resource id -> {type, path, uid}
        "script_class":  the script_class= header value
    }

ExtResource() and SubResource() references in property values are returned
as marker dicts so callers can resolve them later:

    {"__extresource__": "1"}
    {"__subresource__": "mod1"}
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any, Dict, List, Union


# ---------------------------------------------------------------------------
# Public entrypoint
# ---------------------------------------------------------------------------


def parse_tres_file(filepath: Union[str, Path]) -> Dict[str, Any]:
    """Parse a Godot 4 .tres file into a structured dict."""
    text = Path(filepath).read_text(encoding="utf-8")

    result: Dict[str, Any] = {
        "resource": {},
        "sub_resources": {},
        "ext_resources": {},
        "script_class": "",
    }

    header_match = re.search(r'script_class="([^"]+)"', text)
    if header_match:
        result["script_class"] = header_match.group(1)

    # Walk sections. A section starts at a line beginning with [...].
    section_pattern = re.compile(r"^\[(.+?)\]", re.MULTILINE)
    section_starts = [m.start() for m in section_pattern.finditer(text)]

    for i, start in enumerate(section_starts):
        end = section_starts[i + 1] if i + 1 < len(section_starts) else len(text)
        header_end = text.index("]", start) + 1
        header = text[start + 1 : header_end - 1]
        body = text[header_end:end]

        if header == "resource":
            result["resource"] = _parse_properties(body)
        elif header.startswith("sub_resource"):
            sub_id = _attr(header, "id")
            if sub_id:
                result["sub_resources"][sub_id] = _parse_properties(body)
        elif header.startswith("ext_resource"):
            ext_id = _attr(header, "id")
            if ext_id:
                result["ext_resources"][ext_id] = {
                    "type": _attr(header, "type") or "",
                    "path": _attr(header, "path") or "",
                    "uid": _attr(header, "uid") or "",
                }
        # gd_resource header is skipped intentionally

    return result


def resolve_ext_path(value: Any, ext_resources: Dict[str, Any]) -> str:
    """If value is an {"__extresource__": id} marker, return the resource path.

    Returns an empty string if the value isn't an ExtResource ref or the id
    is not in the ext_resources table. The path is the raw `res://...`
    string from the .tres header.
    """
    if not isinstance(value, dict):
        return ""
    ext_id = value.get("__extresource__")
    if not ext_id:
        return ""
    return ext_resources.get(ext_id, {}).get("path", "")


def resolve_subresource(value: Any, sub_resources: Dict[str, Any]) -> Dict[str, Any]:
    """If value is an {"__subresource__": id} marker, return the sub-resource props."""
    if not isinstance(value, dict):
        return {}
    sub_id = value.get("__subresource__")
    if not sub_id:
        return {}
    return sub_resources.get(sub_id, {})


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------


def _attr(header: str, key: str) -> str:
    """Extract a `key="value"` attribute from a section header."""
    match = re.search(rf'{re.escape(key)}="([^"]+)"', header)
    return match.group(1) if match else ""


def _parse_properties(body: str) -> Dict[str, Any]:
    """Parse a block of `key = value` lines into a dict."""
    props: Dict[str, Any] = {}
    for line in body.splitlines():
        line = line.strip()
        if not line or line.startswith(";") or line.startswith("#"):
            continue
        eq_pos = line.find(" = ")
        if eq_pos == -1:
            continue
        key = line[:eq_pos].strip()
        raw_value = line[eq_pos + 3 :].strip()
        props[key] = _parse_value(raw_value)
    return props


def _parse_value(raw: str) -> Any:
    """Convert a raw .tres value string to a Python value."""
    raw = raw.strip()

    if raw.startswith('"') and raw.endswith('"'):
        return raw[1:-1]

    if raw == "true":
        return True
    if raw == "false":
        return False
    if raw == "null":
        return None

    sub_match = re.fullmatch(r'SubResource\("([^"]+)"\)', raw)
    if sub_match:
        return {"__subresource__": sub_match.group(1)}

    ext_match = re.fullmatch(r'ExtResource\("([^"]+)"\)', raw)
    if ext_match:
        return {"__extresource__": ext_match.group(1)}

    typed_array_match = re.fullmatch(r"Array\[[^\]]*\]\((\[.*\])\)", raw, re.DOTALL)
    if typed_array_match:
        return _parse_array(typed_array_match.group(1))

    if raw.startswith("[") and raw.endswith("]"):
        return _parse_array(raw)

    # Color(...) and Vector2(...) — return tuples so they can be JSON-serialized
    color_match = re.fullmatch(r"Color\(([^)]+)\)", raw)
    if color_match:
        return [float(x.strip()) for x in color_match.group(1).split(",")]

    vec_match = re.fullmatch(r"Vector[23]\(([^)]+)\)", raw)
    if vec_match:
        return [float(x.strip()) for x in vec_match.group(1).split(",")]

    try:
        if "." in raw or "e" in raw.lower():
            return float(raw)
    except ValueError:
        pass

    try:
        return int(raw)
    except ValueError:
        pass

    return raw


def _parse_array(raw: str) -> List[Any]:
    """Parse a Godot array literal."""
    inner = raw.strip()[1:-1].strip()
    if not inner:
        return []

    if inner.lstrip().startswith("{"):
        return _parse_dict_array(inner)

    items = _split_top_level(inner)
    return [_parse_value(item.strip()) for item in items if item.strip()]


def _parse_dict_array(inner: str) -> List[Dict[str, Any]]:
    """Parse [{...}, {...}] dict arrays — used for enemy intent_pool."""
    results: List[Dict[str, Any]] = []
    depth = 0
    current: List[str] = []
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
            continue
        else:
            current.append(ch)
    return results


def _parse_gdscript_dict(raw: str) -> Dict[str, Any]:
    """Parse a single-level GDScript dict literal."""
    result: Dict[str, Any] = {}
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
        key = _parse_value(part[:colon].strip())
        value = _parse_value(part[colon + 2 :].strip())
        result[str(key)] = value
    return result


def _split_top_level(s: str) -> List[str]:
    """Split a string on commas not nested inside brackets/quotes."""
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
