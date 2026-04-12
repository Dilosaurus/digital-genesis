"""On-the-fly thumbnail generator for card art.

GET /media/thumb/<path>
    → returns a 280px-wide WebP (quality 78) cached on disk.

The source images are full-res 2048×2048 RGBA PNGs (~6 MB each).
A 280px WebP thumbnail is typically 8–15 KB — a ~500× reduction.
"""

from __future__ import annotations

import hashlib
from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse

from app.config import ASSETS_DIR

router = APIRouter(prefix="/media/thumb", tags=["thumb"])

THUMB_DIR = ASSETS_DIR / ".thumbs"
THUMB_WIDTH = 280
WEBP_QUALITY = 78


def _thumb_path(rel: str) -> Path:
    """Deterministic cache path for a given relative asset path."""
    h = hashlib.md5(rel.encode()).hexdigest()[:12]
    stem = Path(rel).stem
    return THUMB_DIR / f"{stem}_{h}.webp"


@router.get("/{path:path}")
async def get_thumb(path: str) -> FileResponse:
    source = ASSETS_DIR / path
    if not source.is_file():
        raise HTTPException(404, f"source not found: {path}")

    # Resolve to prevent path traversal
    try:
        source = source.resolve()
        if not str(source).startswith(str(ASSETS_DIR.resolve())):
            raise HTTPException(403)
    except (OSError, ValueError):
        raise HTTPException(400)

    thumb = _thumb_path(path)

    # Serve cached thumbnail if it's newer than the source
    if thumb.is_file() and thumb.stat().st_mtime >= source.stat().st_mtime:
        return FileResponse(str(thumb), media_type="image/webp")

    # Generate thumbnail
    try:
        from PIL import Image

        THUMB_DIR.mkdir(parents=True, exist_ok=True)
        with Image.open(source) as img:
            img = img.convert("RGB")
            ratio = THUMB_WIDTH / img.width
            h = int(img.height * ratio)
            img = img.resize((THUMB_WIDTH, h), Image.LANCZOS)
            img.save(str(thumb), "WEBP", quality=WEBP_QUALITY)
    except Exception as exc:
        raise HTTPException(500, f"thumbnail generation failed: {exc}")

    return FileResponse(str(thumb), media_type="image/webp")
