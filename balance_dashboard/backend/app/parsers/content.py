"""Markdown content parser with frontmatter support.

Reads .md files from app/content/{section}/*.md where each file has an
optional YAML-like frontmatter block at the top:

    ---
    title: The Nexus
    chapter: I
    subtitle: a cathedral of servers
    order: 1
    ---

    # Main heading

    Body content...

We hand-roll the frontmatter parser to avoid pulling in PyYAML for such
a tiny feature. The format is restricted to flat key:value pairs and
optional list values ([a, b, c] or indented "- " lines). Nested objects
are not supported — this is metadata, not a config file.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, List, Optional
import re

from app.config import CONTENT_DIR


def _parse_value(raw: str) -> Any:
    """Parse a frontmatter value. Handles numbers, booleans, inline lists, strings."""
    s = raw.strip()
    if not s:
        return ""
    # Quoted string
    if (s.startswith('"') and s.endswith('"')) or (s.startswith("'") and s.endswith("'")):
        return s[1:-1]
    # Inline list: [a, b, c]
    if s.startswith("[") and s.endswith("]"):
        inner = s[1:-1].strip()
        if not inner:
            return []
        return [_parse_value(item) for item in inner.split(",")]
    # Booleans
    if s.lower() in ("true", "yes"):
        return True
    if s.lower() in ("false", "no"):
        return False
    # Numbers
    if re.fullmatch(r"-?\d+", s):
        return int(s)
    if re.fullmatch(r"-?\d+\.\d+", s):
        return float(s)
    # Bare string
    return s


def parse_frontmatter(raw: str) -> tuple[Dict[str, Any], str]:
    """Split frontmatter + body. Returns (metadata, body_markdown)."""
    if not raw.startswith("---"):
        return {}, raw

    lines = raw.splitlines(keepends=True)
    if not lines:
        return {}, raw

    # Find the closing ---
    end_idx = None
    for i, line in enumerate(lines[1:], start=1):
        if line.strip() == "---":
            end_idx = i
            break
    if end_idx is None:
        return {}, raw  # unterminated — treat as body

    meta_lines = lines[1:end_idx]
    body = "".join(lines[end_idx + 1 :]).lstrip("\n")

    meta: Dict[str, Any] = {}
    for line in meta_lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if ":" not in stripped:
            continue
        key, _, value = stripped.partition(":")
        meta[key.strip()] = _parse_value(value)

    return meta, body


def load_document(section: str, slug: str) -> Optional[Dict[str, Any]]:
    """Read a single markdown document. Returns None if not found."""
    path = CONTENT_DIR / section / f"{slug}.md"
    if not path.exists():
        return None
    raw = path.read_text(encoding="utf-8")
    meta, body = parse_frontmatter(raw)
    return {
        "section": section,
        "slug": slug,
        "meta": meta,
        "body": body,
    }


def load_section(section: str) -> List[Dict[str, Any]]:
    """Read every .md in a section directory, sorted by meta.order then slug."""
    dir_path = CONTENT_DIR / section
    if not dir_path.exists():
        return []
    docs: List[Dict[str, Any]] = []
    for md_file in sorted(dir_path.glob("*.md")):
        raw = md_file.read_text(encoding="utf-8")
        meta, body = parse_frontmatter(raw)
        docs.append({
            "section": section,
            "slug": md_file.stem,
            "meta": meta,
            "body": body,
        })
    # Sort by meta.order if present, else stable by slug
    docs.sort(key=lambda d: (d["meta"].get("order", 999), d["slug"]))
    return docs


def list_sections() -> List[str]:
    """Return all section directories under content/."""
    if not CONTENT_DIR.exists():
        return []
    return sorted([p.name for p in CONTENT_DIR.iterdir() if p.is_dir()])
