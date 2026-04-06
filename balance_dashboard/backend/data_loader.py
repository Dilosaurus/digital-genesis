"""
data_loader.py — Reads and caches all JSON data files from ../data/.

Files loaded:
  cards.json, relics.json, equipment.json, gems.json,
  skill_tree.json, enemies.json, corruption.json
"""

import json
import os

_DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "data")

_DATA_FILES = [
    "cards",
    "relics",
    "equipment",
    "gems",
    "skill_tree",
    "enemies",
    "corruption",
]

_cache: dict | None = None


def _load_file(name: str) -> list | dict:
    """Load a single JSON file by name (without extension). Returns [] on failure."""
    path = os.path.join(_DATA_DIR, f"{name}.json")
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return []
    except json.JSONDecodeError as exc:
        print(f"[data_loader] WARNING: Could not parse {path}: {exc}")
        return []


def load_all() -> dict:
    """Return a dict with all data, loading from disk on first call then caching."""
    global _cache
    if _cache is not None:
        return _cache

    _cache = {name: _load_file(name) for name in _DATA_FILES}
    return _cache


def reload() -> dict:
    """Clear the cache and re-read all JSON files from disk."""
    global _cache
    _cache = None
    return load_all()


def get_by_id(collection: list, item_id: str) -> dict | None:
    """Helper: find a dict with matching 'id' key in a list."""
    for item in collection:
        if item.get("id") == item_id:
            return item
    return None
