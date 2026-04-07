"""Git log parser — renders the card_game/ git history as a JSON feed.

The parser shells out to `git log` using subprocess. The CARD_GAME_DIR is the
repo root (same repo that hosts the dashboard), so we run git from there.

Output shape, per commit:
    {
      "sha": "abc1234",
      "short_sha": "abc1234",
      "subject": "Implement Scourge, 84 new cards, 6 new gems, schema extensions",
      "body": "longer body text",
      "author": "Chris",
      "date": "2026-04-05",
      "iso": "2026-04-05T14:23:11-07:00",
      "files_changed": 42,
      "insertions": 1203,
      "deletions": 47,
      "tags": ["scourge", "cards"]   # extracted from subject
    }
"""

from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path
from typing import Any, Dict, List

from app.config import PROJECT_ROOT

# We delimit each commit with a unique separator that's unlikely to appear in
# any subject line, and separate fields within a commit with an equally unique
# field separator.
_COMMIT_DELIM = "<<<DEUS_COMMIT_END>>>"
_FIELD_DELIM = "<<<DEUS_FIELD>>>"

_LOG_FORMAT = _FIELD_DELIM.join([
    "%h",    # short sha
    "%H",    # full sha
    "%s",    # subject
    "%b",    # body
    "%an",   # author name
    "%aI",   # author date ISO 8601
    "%as",   # author date short (YYYY-MM-DD)
]) + _COMMIT_DELIM


# Subjects often follow a loose pattern: "verb Noun, ..., ...". We extract
# high-signal tags (known content areas) to bucket commits thematically.
TAG_PATTERNS: List[tuple[str, re.Pattern[str]]] = [
    ("scourge",       re.compile(r"\bscourge\b", re.I)),
    ("cards",         re.compile(r"\bcard(s)?\b", re.I)),
    ("gems",          re.compile(r"\bgem(s)?\b", re.I)),
    ("relics",        re.compile(r"\brelic(s)?\b", re.I)),
    ("equipment",     re.compile(r"\bequip(ment)?\b", re.I)),
    ("enemies",       re.compile(r"\benemy|enemies\b", re.I)),
    ("bosses",        re.compile(r"\bboss(es)?\b", re.I)),
    ("multiplayer",   re.compile(r"\b(multiplayer|co-?op|enet|party)\b", re.I)),
    ("combat",        re.compile(r"\bcombat\b", re.I)),
    ("corruption",    re.compile(r"\bcorrupt", re.I)),
    ("modifiers",     re.compile(r"\bmodifier(s)?|stat\s+pipeline\b", re.I)),
    ("ui",            re.compile(r"\bui\b|theme|hud", re.I)),
    ("shaders",       re.compile(r"\bshader(s)?\b", re.I)),
    ("dashboard",     re.compile(r"\bdashboard|balance dashboard|deus\.exe\b", re.I)),
    ("art",           re.compile(r"\bart|illustration|sprite\b", re.I)),
    ("3d",            re.compile(r"\b3d|dungeon\b", re.I)),
    ("schema",        re.compile(r"\bschema\b", re.I)),
    ("fix",           re.compile(r"\bfix\b", re.I)),
    ("refactor",      re.compile(r"\brefactor\b", re.I)),
    ("docs",          re.compile(r"\bdoc(s|umentation)?\b", re.I)),
]


def _extract_tags(subject: str) -> List[str]:
    return [tag for tag, pattern in TAG_PATTERNS if pattern.search(subject)]


def _run_git(args: List[str]) -> str:
    try:
        result = subprocess.run(
            ["git", *args],
            cwd=str(PROJECT_ROOT),
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=10,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as exc:
        raise RuntimeError(f"git failed: {exc}") from exc
    if result.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} exited {result.returncode}: {result.stderr}")
    return result.stdout


def _parse_raw(raw: str) -> List[Dict[str, Any]]:
    """Parse the delimited output of `git log --format=_LOG_FORMAT`."""
    commits: List[Dict[str, Any]] = []
    for chunk in raw.split(_COMMIT_DELIM):
        chunk = chunk.strip()
        if not chunk:
            continue
        fields = chunk.split(_FIELD_DELIM)
        if len(fields) < 7:
            continue
        short_sha, sha, subject, body, author, iso, date = fields[:7]
        commits.append({
            "sha": sha.strip(),
            "short_sha": short_sha.strip(),
            "subject": subject.strip(),
            "body": body.strip(),
            "author": author.strip(),
            "iso": iso.strip(),
            "date": date.strip(),
            "tags": _extract_tags(subject),
        })
    return commits


def load_changelog(limit: int = 80) -> List[Dict[str, Any]]:
    """Return the most recent commits from the repo as structured JSON.

    Tries sources in this order:

    1. A pre-generated cache file at ``$DEUS_CHANGELOG_CACHE`` (used in
       production builds where .git is not available in the image).
    2. A live ``git log`` call against ``PROJECT_ROOT`` (used in dev).
    3. An empty list + warning (if both fail).
    """
    cache_path = os.environ.get("DEUS_CHANGELOG_CACHE")
    if cache_path:
        p = Path(cache_path)
        if p.exists():
            try:
                raw = p.read_text(encoding="utf-8", errors="replace")
                return _parse_raw(raw)[:limit]
            except Exception as exc:  # pragma: no cover
                print(f"  WARN: failed to read changelog cache {p}: {exc}")

    try:
        raw = _run_git(["log", f"-{limit}", f"--format={_LOG_FORMAT}"])
    except RuntimeError as exc:
        print(f"  WARN: git log failed and no cache available: {exc}")
        return []
    return _parse_raw(raw)


