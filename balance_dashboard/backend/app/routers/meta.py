"""Meta endpoints — changelog, roadmap, decisions.

The routing layer stays thin. Actual work happens in app.services.git (for
the changelog) and app.parsers.content (for roadmap + decisions).
"""

from __future__ import annotations

from typing import Any, Dict, List

from fastapi import APIRouter, HTTPException

from app.services.git import load_changelog
from app.parsers.content import load_section, load_document

router = APIRouter(prefix="/api/meta", tags=["meta"])


@router.get("/changelog")
def changelog(limit: int = 80) -> List[Dict[str, Any]]:
    """Parse the git log into a JSON feed. Capped at 200 commits."""
    try:
        return load_changelog(limit=min(limit, 200))
    except RuntimeError as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.get("/roadmap")
def roadmap() -> List[Dict[str, Any]]:
    """All roadmap entries, sorted by meta.order. Frontmatter status field
    buckets items as: shipped / in-flight / planned / parked."""
    return load_section("roadmap")


@router.get("/decisions")
def decisions() -> List[Dict[str, Any]]:
    """Architecture Decision Records — one per file in content/decisions/."""
    return load_section("decisions")


@router.get("/decisions/{slug}")
def single_decision(slug: str) -> Dict[str, Any]:
    doc = load_document("decisions", slug)
    if doc is None:
        raise HTTPException(status_code=404, detail=f"decision '{slug}' not found")
    return doc
