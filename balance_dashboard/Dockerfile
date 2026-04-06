# ===========================================================================
# Stage 1 — Build React frontend
# ===========================================================================
FROM node:22-slim AS frontend-build

WORKDIR /build
COPY balance_dashboard/frontend/package.json balance_dashboard/frontend/package-lock.json ./
RUN npm ci

COPY balance_dashboard/frontend/ ./
RUN npm run build

# ===========================================================================
# Stage 2 — Production image (Flask + built frontend + art assets)
# ===========================================================================
FROM python:3.12-slim

WORKDIR /app

# Install Python dependencies
COPY balance_dashboard/backend/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend code
COPY balance_dashboard/backend/ ./backend/

# Copy JSON data
COPY balance_dashboard/data/ ./data/

# Copy built frontend
COPY --from=frontend-build /build/dist/ ./dist/

# Copy art assets (cards + items)
COPY card_game/assets/cards/illustrations/ ./assets/cards/illustrations/
COPY card_game/assets/cards/frames/ ./assets/cards/frames/
COPY card_game/assets/items/illustrations/ ./assets/items/illustrations/

ENV PORT=8080
ENV CARD_ART_ROOT=/app/assets/cards
ENV ITEM_ART_ROOT=/app/assets/items/illustrations
ENV FRONTEND_DIST=/app/dist

EXPOSE 8080

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--threads", "4", "--chdir", "/app/backend", "app:app"]
