"""Shared modifier resolution.

Gems, equipment, and skill tree nodes all carry ModifierData entries.
This module turns the parsed sub-resource property dicts into clean
modifier dicts ready for the API.
"""

from __future__ import annotations

from typing import Any, Dict, List

from app.parsers.enums import enum_name


def resolve_modifiers(mod_refs: Any, sub_resources: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Expand a list of SubResource markers into modifier dicts.

    Returns [] for anything that isn't a list of subresource markers.
    """
    if not isinstance(mod_refs, list):
        return []
    out: List[Dict[str, Any]] = []
    for ref in mod_refs:
        if not isinstance(ref, dict):
            continue
        sub_id = ref.get("__subresource__")
        if not sub_id:
            continue
        props = sub_resources.get(sub_id)
        if not props:
            continue
        out.append(build_modifier(props))
    return out


def build_modifier(props: Dict[str, Any]) -> Dict[str, Any]:
    """Convert raw sub-resource modifier props into a clean dict."""
    stat_idx = int(props.get("stat", 0))
    op_idx = int(props.get("operation", 0))
    lifecycle_idx = int(props.get("lifecycle", 0))

    mod: Dict[str, Any] = {
        "id": props.get("id", ""),
        "stat": enum_name("Stat", stat_idx, "STAT"),
        "operation": enum_name("ModOp", op_idx, "OP"),
        "value": float(props.get("value", 0.0)),
        "lifecycle": enum_name("ModLifecycle", lifecycle_idx, "LIFECYCLE"),
        "duration": int(props.get("duration", -1)),
    }

    raw_tags = props.get("required_card_tags", []) or []
    if isinstance(raw_tags, list) and raw_tags:
        mod["required_card_tags"] = [
            enum_name("CardTag", int(t), "TAG") for t in raw_tags if isinstance(t, int)
        ]

    req_card_type = int(props.get("required_card_type", -1))
    if req_card_type != -1:
        mod["required_card_type"] = enum_name("CardType", req_card_type, "TYPE")

    if props.get("only_vs_vulnerable", False):
        mod["only_vs_vulnerable"] = True

    hp_below = props.get("only_when_hp_below_pct", -1.0)
    if isinstance(hp_below, (int, float)) and hp_below >= 0.0:
        mod["only_when_hp_below_pct"] = float(hp_below)

    return mod
