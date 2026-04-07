"""Content router — serves markdown pages with frontmatter metadata.

Endpoints:
    GET /api/content/                       — list available sections
    GET /api/content/{section}               — all docs in a section
    GET /api/content/{section}/{slug}        — single doc
"""

from __future__ import annotations

from typing import Any, Dict, List

from fastapi import APIRouter, HTTPException

from app.parsers.content import list_sections, load_section, load_document

router = APIRouter(prefix="/api/content", tags=["content"])


@router.get("/")
def all_sections() -> Dict[str, List[str]]:
    return {"sections": list_sections()}


@router.get("/{section}")
def section_docs(section: str) -> List[Dict[str, Any]]:
    docs = load_section(section)
    if not docs:
        raise HTTPException(status_code=404, detail=f"section '{section}' has no documents")
    return docs


@router.get("/{section}/{slug}")
def single_doc(section: str, slug: str) -> Dict[str, Any]:
    doc = load_document(section, slug)
    if doc is None:
        raise HTTPException(status_code=404, detail=f"{section}/{slug}.md not found")
    return doc
