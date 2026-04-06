"""
change_log.py — Append-only change log for dashboard write-back operations.

Stores entries in balance_dashboard/data/changelog.json.
Each entry records what changed, old/new values, timestamp, and backup path.
"""

from __future__ import annotations

import json
import os
from datetime import datetime
from pathlib import Path
from typing import Any

_SCRIPT_DIR = Path(__file__).resolve().parent
CHANGELOG_PATH = _SCRIPT_DIR.parent / "data" / "changelog.json"


def _load_log() -> list[dict]:
    """Load the changelog from disk."""
    if not CHANGELOG_PATH.exists():
        return []
    try:
        with open(CHANGELOG_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return []


def _save_log(entries: list[dict]) -> None:
    """Write the changelog to disk."""
    os.makedirs(CHANGELOG_PATH.parent, exist_ok=True)
    with open(CHANGELOG_PATH, "w", encoding="utf-8") as f:
        json.dump(entries, f, indent=2)


def log_change(
    entity_type: str,
    entity_id: str,
    field: str,
    old_value: Any,
    new_value: Any,
    backup_path: str | None = None,
) -> dict:
    """Append a change entry to the log. Returns the entry."""
    entry = {
        "timestamp": datetime.now().isoformat(),
        "entity_type": entity_type,
        "entity_id": entity_id,
        "field": field,
        "old_value": old_value,
        "new_value": new_value,
        "backup_path": str(backup_path) if backup_path else None,
    }
    entries = _load_log()
    entries.append(entry)
    _save_log(entries)
    return entry


def log_modifier_change(
    action: str,
    entity_type: str,
    entity_id: str,
    mod_id: str,
    details: dict | None = None,
    backup_path: str | None = None,
) -> dict:
    """Log a modifier add/edit/delete."""
    entry = {
        "timestamp": datetime.now().isoformat(),
        "entity_type": entity_type,
        "entity_id": entity_id,
        "action": action,
        "mod_id": mod_id,
        "details": details or {},
        "backup_path": str(backup_path) if backup_path else None,
    }
    entries = _load_log()
    entries.append(entry)
    _save_log(entries)
    return entry


def log_intent_change(
    entity_id: str,
    old_intents: list[dict],
    new_intents: list[dict],
    backup_path: str | None = None,
) -> dict:
    """Log an enemy intent pool replacement."""
    entry = {
        "timestamp": datetime.now().isoformat(),
        "entity_type": "enemies",
        "entity_id": entity_id,
        "action": "replace_intents",
        "old_value": old_intents,
        "new_value": new_intents,
        "backup_path": str(backup_path) if backup_path else None,
    }
    entries = _load_log()
    entries.append(entry)
    _save_log(entries)
    return entry


def get_recent(limit: int = 100) -> list[dict]:
    """Return the most recent changelog entries (newest first)."""
    entries = _load_log()
    return list(reversed(entries[-limit:]))
