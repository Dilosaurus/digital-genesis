"""Path and environment configuration for the deus.exe codex backend."""

from __future__ import annotations

import os
from pathlib import Path

# ---------------------------------------------------------------------------
# Filesystem layout
# ---------------------------------------------------------------------------

# backend/app/config.py -> backend/app -> backend -> balance_dashboard -> godot_games
_THIS_DIR = Path(__file__).resolve().parent
BACKEND_DIR = _THIS_DIR.parent
DASHBOARD_DIR = BACKEND_DIR.parent
PROJECT_ROOT = DASHBOARD_DIR.parent

# Allow override via env var so we can run in Docker with a mounted volume
_CARD_GAME_OVERRIDE = os.environ.get("DEUS_CARD_GAME_DIR")
CARD_GAME_DIR = Path(_CARD_GAME_OVERRIDE) if _CARD_GAME_OVERRIDE else PROJECT_ROOT / "card_game"

DATA_DIR = CARD_GAME_DIR / "data"
RESOURCES_DIR = CARD_GAME_DIR / "resources"
SCRIPTS_DIR = CARD_GAME_DIR / "scripts"
ASSETS_DIR = CARD_GAME_DIR / "assets"
THEMES_DIR = CARD_GAME_DIR / "themes"

# Generated sprite-sheet GIFs from the Veo 3.1 pipeline. Mounted at
# /anim/ in the backend so the React dashboard can preview character idles
# and attack animations on the operator dossier page. Empty in fresh checkouts
# until the per-character build_sprite_sheet.py runs are complete.
ANIMATION_DIR = CARD_GAME_DIR / "art_pipeline" / "animations" / "sheets"

# Schema source-of-truth — GDScript class definitions and enums
ENUMS_GD = SCRIPTS_DIR / "data" / "enums.gd"
SKILL_TREE_GD = SCRIPTS_DIR / "systems" / "skill_tree_system.gd"
CARD_CORRUPTION_GD = SCRIPTS_DIR / "systems" / "card_corruption.gd"

# Bible markdown content lives inside the backend package itself
CONTENT_DIR = _THIS_DIR / "content"

# Draft database — SQLite file in the dashboard data dir
DRAFT_DB_PATH = Path(
    os.environ.get("DEUS_DRAFT_DB", str(DASHBOARD_DIR / "data" / "drafts.sqlite"))
)

# ---------------------------------------------------------------------------
# Sanity checks (raised at app startup, not import time)
# ---------------------------------------------------------------------------


def verify_paths() -> list[str]:
    """Return a list of missing critical paths. Empty list = OK."""
    missing: list[str] = []
    for label, path in {
        "card_game": CARD_GAME_DIR,
        "card_game/data": DATA_DIR,
        "card_game/scripts/data/enums.gd": ENUMS_GD,
    }.items():
        if not path.exists():
            missing.append(f"{label} -> {path}")
    return missing
