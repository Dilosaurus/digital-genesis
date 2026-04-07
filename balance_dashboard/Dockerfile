# ===========================================================================
# deus.exe // codex — Docker image for Cloud Run
#
# Stage 1: build the React frontend (npm ci + vite build → dist/)
# Stage 2: FastAPI + uvicorn runtime, serving the built frontend as static
#
# card_game/ data is BAKED INTO the image at build time (Cloud Run does not
# support runtime volume mounts for source files). .tres, scripts/data,
# scripts/systems, themes, and assets/cards + assets/items are copied in.
# We exclude .import metadata via .dockerignore — they're Godot-side and
# useless to the backend parser.
#
# Runtime entrypoint uses $PORT (injected by Cloud Run, default 8080).
# ===========================================================================

# ---------------------------------------------------------------------------
# Stage 1 — Build React frontend
# ---------------------------------------------------------------------------
FROM node:22-slim AS frontend-build

WORKDIR /build

# Install deps first (better layer caching)
COPY balance_dashboard/frontend/package.json balance_dashboard/frontend/package-lock.json ./
RUN npm ci

# Copy sources and build
COPY balance_dashboard/frontend/ ./
RUN npm run build

# ---------------------------------------------------------------------------
# Stage 2 — FastAPI runtime
# ---------------------------------------------------------------------------
FROM python:3.12-slim AS runtime

WORKDIR /srv

# Install Python deps. We don't copy pyproject.toml here — explicit pins
# are clearer and avoid surprises.
RUN pip install --no-cache-dir \
    "fastapi>=0.115.0" \
    "uvicorn[standard]>=0.32.0" \
    "pydantic>=2.9.0" \
    "sqlmodel>=0.0.22" \
    "python-multipart>=0.0.20"

# Copy backend source
COPY balance_dashboard/backend/app ./app

# Copy built frontend (served as static under /)
COPY --from=frontend-build /build/dist ./frontend_dist

# Copy game data. Structure inside the image matches the expected
# CARD_GAME_DIR / DATA_DIR / SCRIPTS_DIR / ASSETS_DIR / THEMES_DIR layout
# so the existing parser code Just Works.
COPY card_game/data                 ./card_game/data
COPY card_game/scripts/data         ./card_game/scripts/data
COPY card_game/scripts/systems      ./card_game/scripts/systems
COPY card_game/themes               ./card_game/themes
COPY card_game/resources            ./card_game/resources
COPY card_game/assets/cards         ./card_game/assets/cards
COPY card_game/assets/items         ./card_game/assets/items

# Copy the pre-generated changelog cache.
# deploy.sh generates this via `git log` locally before invoking Cloud Build,
# and drops it at balance_dashboard/backend/.cache/changelog.txt. We avoid
# shipping the full .git directory (hundreds of MB) or installing git in
# the runtime image.
COPY balance_dashboard/backend/.cache/changelog.txt ./changelog.txt

# Point the backend at the baked-in data
ENV DEUS_CARD_GAME_DIR=/srv/card_game
# Cloud Run filesystem is ephemeral; /tmp is writable per-instance
ENV DEUS_DRAFT_DB=/tmp/drafts.sqlite
# Changelog cache (pre-generated at build time)
ENV DEUS_CHANGELOG_CACHE=/srv/changelog.txt

# Cloud Run injects $PORT (default 8080). Shell form so ${PORT} expands.
CMD uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}
