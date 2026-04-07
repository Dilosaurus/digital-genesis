"""Skill tree extractor.

The skill tree isn't stored in .tres files — it's defined in
scripts/systems/skill_tree_system.gd. The structure is:

    static func _create_default_trees() -> void:
        _create_netrunner_tree()
        _create_sysadmin_tree()
        ...

    static func _create_netrunner_tree() -> void:
        var tree := SkillTreeData.new()
        tree.id = "netrunner"
        tree.display_name = "Neural Network"
        tree.nodes.append(_node(
            "nr_rapid_fire", "Rapid Fire", ...
        ))
        ...

We find each `_create_<x>_tree` function, extract its tree.id and
display_name, then parse every `tree.nodes.append(_node(...))` block
and the nested `_spec(...)` calls inside it.
"""

from __future__ import annotations

import re
from typing import Any, Dict, List

from app.config import SKILL_TREE_GD


def load_skill_trees() -> List[Dict[str, Any]]:
    """Return a list of skill trees, each with its nested nodes."""
    if not SKILL_TREE_GD.exists():
        return []

    source = SKILL_TREE_GD.read_text(encoding="utf-8")

    trees: List[Dict[str, Any]] = []
    for func_name, body in _iter_create_tree_functions(source):
        tree_id = _extract_assign(body, "tree.id") or func_name
        display_name = _extract_assign(body, "tree.display_name") or tree_id

        nodes: List[Dict[str, Any]] = []
        for raw_call in _extract_node_calls(body):
            node = _parse_node_call(raw_call)
            if node:
                nodes.append(node)

        trees.append(
            {
                "id": tree_id,
                "display_name": display_name,
                "nodes": nodes,
            }
        )

    return trees


def load_skill_tree_nodes() -> List[Dict[str, Any]]:
    """Backwards-compat: return a flat list of all nodes across all trees,
    each tagged with its tree_id."""
    flat: List[Dict[str, Any]] = []
    for tree in load_skill_trees():
        for node in tree["nodes"]:
            tagged = dict(node)
            tagged["tree_id"] = tree["id"]
            flat.append(tagged)
    return flat


# ---------------------------------------------------------------------------
# Function locators
# ---------------------------------------------------------------------------


def _iter_create_tree_functions(source: str):
    """Yield (func_name, function_body) for every `_create_<x>_tree` function."""
    pattern = re.compile(
        r"static func (_create_\w+_tree)\(\) -> void:(.*?)(?=\nstatic func |\Z)",
        re.DOTALL,
    )
    for match in pattern.finditer(source):
        func_name = match.group(1)
        if func_name == "_create_default_trees":
            continue
        yield func_name, match.group(2)


def _extract_assign(body: str, var_name: str) -> str:
    """Extract a `var_name = "value"` literal from a function body."""
    pattern = re.compile(re.escape(var_name) + r"\s*=\s*\"([^\"]*)\"")
    match = pattern.search(body)
    return match.group(1) if match else ""


def _extract_node_calls(func_body: str) -> List[str]:
    """Find every `tree.nodes.append(_node(...))` call body in func_body."""
    results: List[str] = []
    pattern = re.compile(r"tree\.nodes\.append\(_node\(")
    for match in pattern.finditer(func_body):
        start = match.end()
        depth = 1
        i = start
        while i < len(func_body) and depth > 0:
            if func_body[i] == "(":
                depth += 1
            elif func_body[i] == ")":
                depth -= 1
            i += 1
        results.append(func_body[start : i - 1])
    return results


# ---------------------------------------------------------------------------
# _node(...) parser
# ---------------------------------------------------------------------------


def _parse_node_call(args_text: str) -> Dict[str, Any]:
    """_node(id, name, desc, tier, cost, prereqs, specs, position)"""
    args_text = re.sub(r"\s+", " ", args_text).strip()
    parts = _split_top_level(args_text)
    if len(parts) < 7:
        return {}

    def unquote(s: str) -> str:
        s = s.strip()
        if s.startswith('"') and s.endswith('"'):
            return s[1:-1]
        return s

    try:
        node_id = unquote(parts[0])
        name = unquote(parts[1])
        desc = unquote(parts[2])
        tier = int(parts[3].strip())
        cost = int(parts[4].strip())
    except (IndexError, ValueError):
        return {}

    prereqs = _parse_string_array(parts[5].strip())
    specs = _parse_specs_array(parts[6].strip())

    position = {"x": 0.0, "y": 0.0}
    if len(parts) > 7:
        pos_match = re.search(r"Vector2\(([^,]+),\s*([^)]+)\)", parts[7].strip())
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


def _parse_string_array(raw: str) -> List[str]:
    inner = raw.strip()
    if inner.startswith("["):
        inner = inner[1:]
    if inner.endswith("]"):
        inner = inner[:-1]
    inner = inner.strip()
    if not inner:
        return []
    return [s.strip().strip('"') for s in inner.split(",") if s.strip().strip('"')]


def _parse_specs_array(raw: str) -> List[Dict[str, Any]]:
    inner = raw.strip()
    if inner.startswith("["):
        inner = inner[1:]
    if inner.endswith("]"):
        inner = inner[:-1]
    inner = inner.strip()
    if not inner:
        return []

    specs: List[Dict[str, Any]] = []
    for match in re.finditer(r"_spec\(", inner):
        start = match.end()
        depth = 1
        i = start
        while i < len(inner) and depth > 0:
            if inner[i] == "(":
                depth += 1
            elif inner[i] == ")":
                depth -= 1
            i += 1
        spec = _parse_spec_call(inner[start : i - 1])
        if spec:
            specs.append(spec)
    return specs


def _parse_spec_call(args_text: str) -> Dict[str, Any]:
    """_spec(stat, op, value [, req_tags, vs_vuln, hp_below])"""
    parts = _split_top_level(args_text)
    if len(parts) < 3:
        return {}

    def unquote(s: str) -> str:
        s = s.strip()
        if s.startswith('"') and s.endswith('"'):
            return s[1:-1]
        return s

    try:
        stat = unquote(parts[0])
        op = unquote(parts[1])
        value = float(parts[2].strip())
    except (IndexError, ValueError):
        return {}

    req_tags: List[str] = []
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

    spec: Dict[str, Any] = {
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


def _split_top_level(s: str) -> List[str]:
    """Split on commas not nested inside (), [], {}, or quotes."""
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
