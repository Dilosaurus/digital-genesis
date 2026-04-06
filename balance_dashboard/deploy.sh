#!/usr/bin/env bash
# Deploy the Balance Dashboard to Google Cloud Run.
# Run from the repo root:  bash balance_dashboard/deploy.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SERVICE_NAME="balance-dashboard"
REGION="us-central1"
MEMORY="512Mi"

cd "$REPO_ROOT"

echo "==> Building and deploying $SERVICE_NAME to Cloud Run ($REGION)..."

# Create a temporary .dockerignore at repo root for the build
cat > .dockerignore <<'EOF'
**/__pycache__
**/*.pyc
**/node_modules
**/.git
**/.claude
**/backups
**/frontend/dist
**/*.import
*.md
card_game/art_pipeline/
card_game/data/
card_game/scenes/
card_game/scripts/
card_game/shaders/
card_game/project.godot
card_game/default_bus_layout.tres
card_game/assets/cards/illustrations/*/*.import
card_game/assets/cards/frames/*.import
card_game/assets/items/illustrations/*/*.import
EOF

gcloud run deploy "$SERVICE_NAME" \
  --source . \
  --dockerfile balance_dashboard/Dockerfile \
  --region "$REGION" \
  --allow-unauthenticated \
  --port 8080 \
  --memory "$MEMORY" \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 3

# Clean up temporary .dockerignore
rm -f .dockerignore

echo "==> Deployed! Service URL:"
gcloud run services describe "$SERVICE_NAME" --region "$REGION" --format='value(status.url)'
