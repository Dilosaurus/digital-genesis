"""FastAPI application entrypoint for deus.exe // codex.

Run from the backend/ directory:

    py -m uvicorn app.main:app --reload --port 8000

Then visit:

    http://localhost:8000/         — service banner
    http://localhost:8000/api/health
    http://localhost:8000/api/codex/cards
    http://localhost:8000/api/codex/characters
    http://localhost:8000/docs     — auto-generated OpenAPI UI
"""

from __future__ import annotations

from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

from app.config import ANIMATION_DIR, ASSETS_DIR, CARD_GAME_DIR, verify_paths
from app.parsers.enums import all_enums
from app.routers import codex, content, meta, thumb

# Baked frontend dist path — set when running inside the Docker image.
# In local dev this directory doesn't exist and we skip static mounting.
FRONTEND_DIST = Path(__file__).resolve().parent.parent / "frontend_dist"

app = FastAPI(
    title="deus.exe // codex",
    description=(
        "Backend for the deus.exe game bible. Reads .tres files from the "
        "Godot project as the source of truth and serves them as JSON."
    ),
    version="0.1.0",
)

# CORS — needed for dev (Vite on :3001 proxies /api, but direct fetches to
# :8000 from a browser tab would be cross-origin). In production the
# frontend is served same-origin from this same FastAPI process, so CORS
# is effectively unused — but we leave the dev origins allowed.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3001",
        "http://127.0.0.1:3001",
        "http://localhost:5173",
        "http://127.0.0.1:5173",
        "http://localhost:4173",  # vite preview
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(codex.router)
app.include_router(content.router)
app.include_router(meta.router)
app.include_router(thumb.router)


@app.get("/api/health")
def health() -> dict:
    """Verify all critical paths exist and enums load."""
    missing = verify_paths()
    enums = all_enums()
    return {
        "ok": not missing,
        "missing_paths": missing,
        "enums_loaded": list(enums.keys()),
        "enum_count": len(enums),
        "frontend_bundled": FRONTEND_DIST.exists(),
    }


# Card-game asset mount at /media/ (NOT /assets/ because that collides
# with Vite's built JS/CSS). Frontend rewrites res://assets/... to /media/...
if ASSETS_DIR.exists():
    app.mount("/media", StaticFiles(directory=str(ASSETS_DIR)), name="media")

# Animation preview mount — Veo 3.1 sprite-sheet GIFs for the operator
# dossier page. Lives outside /media because the art pipeline isn't part of
# the in-game res:// asset tree.
if ANIMATION_DIR.exists():
    app.mount("/anim", StaticFiles(directory=str(ANIMATION_DIR)), name="anim")


# ─── Frontend serving ─────────────────────────────────────────────────────
# In production (inside the Docker image), frontend_dist/ contains the
# Vite build output: index.html + assets/<hash>.js + assets/<hash>.css.
# We serve it with a SPA fallback: any non-API route that isn't a real
# static file returns index.html so React Router can take over. In dev
# this path doesn't exist and we serve a JSON banner.

if FRONTEND_DIST.exists() and (FRONTEND_DIST / "index.html").exists():
    # Mount Vite's assets/ at its own URL (the index.html references
    # /assets/<hash>.js so the mount point MUST be /assets).
    vite_assets = FRONTEND_DIST / "assets"
    if vite_assets.exists():
        app.mount("/assets", StaticFiles(directory=str(vite_assets)), name="vite_assets")

    @app.get("/", include_in_schema=False)
    async def spa_root() -> FileResponse:
        return FileResponse(str(FRONTEND_DIST / "index.html"))

    @app.get("/{full_path:path}", include_in_schema=False)
    async def spa_fallback(full_path: str, request: Request):
        # API, docs, media — registered routes take precedence, but guard
        # anyway so a mis-spelled API call returns JSON, not HTML.
        if (
            full_path.startswith("api/")
            or full_path.startswith("docs")
            or full_path.startswith("openapi")
            or full_path.startswith("media/")
            or full_path.startswith("anim/")
            or full_path.startswith("assets/")
        ):
            return JSONResponse({"detail": "Not Found"}, status_code=404)

        # Try to serve a real file from frontend_dist first (favicon,
        # manifest.json, robots.txt, etc.).
        candidate = FRONTEND_DIST / full_path
        if candidate.is_file():
            return FileResponse(str(candidate))

        # Fall through to the SPA entry — React Router handles the route.
        return FileResponse(str(FRONTEND_DIST / "index.html"))

else:
    # Dev mode — return a JSON banner at root so it's obvious the backend
    # is up. The frontend dev server on :3001 proxies /api and /media to us.
    @app.get("/", include_in_schema=False)
    def root() -> dict:
        return {
            "service": "deus.exe // codex",
            "version": "0.1.0",
            "docs": "/docs",
            "card_game_dir": str(CARD_GAME_DIR),
            "frontend_bundled": False,
            "hint": "dev mode — run `npm run dev` in balance_dashboard/frontend",
        }
