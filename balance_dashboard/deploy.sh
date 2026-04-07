#!/usr/bin/env bash
# ===========================================================================
# deus.exe // codex — LOCAL FALLBACK DEPLOY
#
# Primary path is GitHub Actions (.github/workflows/deploy-codex.yml),
# which auto-deploys on every push to master. This script is the manual
# escape hatch for when you want to deploy without pushing — hotfixes,
# broken CI, experiments, etc.
#
# Prereqs:
#   - gcloud CLI installed and authenticated (`gcloud auth login`)
#   - Active project set (`gcloud config set project YOUR_PROJECT`)
#   - Cloud Run, Cloud Build, Artifact Registry APIs enabled
#   - (Optional) The deploy service account from DEPLOY.md
#
# Usage: bash balance_dashboard/deploy.sh
# ===========================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SERVICE_NAME="balance-dashboard"
REGION="us-central1"
MEMORY="1Gi"
CPU="1"

# ---------------------------------------------------------------------------
# 1. Preflight
# ---------------------------------------------------------------------------
if command -v gcloud.cmd >/dev/null 2>&1; then
  GCLOUD=gcloud.cmd
elif command -v gcloud >/dev/null 2>&1; then
  GCLOUD=gcloud
else
  echo "ERROR: gcloud CLI not found on PATH." >&2
  exit 1
fi

ACCOUNT=$($GCLOUD config get-value account 2>/dev/null || true)
PROJECT=$($GCLOUD config get-value project 2>/dev/null || true)

[[ -z "$ACCOUNT" || "$ACCOUNT" == "(unset)" ]] && {
  echo "ERROR: no gcloud account. Run: gcloud auth login" >&2
  exit 1
}
[[ -z "$PROJECT" || "$PROJECT" == "(unset)" ]] && {
  echo "ERROR: no gcloud project. Run: gcloud config set project YOUR_PROJECT" >&2
  exit 1
}

if ! $GCLOUD auth print-identity-token >/dev/null 2>&1; then
  echo "ERROR: gcloud credentials expired. Run: gcloud auth login" >&2
  exit 1
fi

echo "==> Deploying as $ACCOUNT to project $PROJECT"
echo "==> Service: $SERVICE_NAME   Region: $REGION"

cd "$REPO_ROOT"

# ---------------------------------------------------------------------------
# 2. Pre-generate the changelog cache
# ---------------------------------------------------------------------------
CACHE_DIR="balance_dashboard/backend/.cache"
CACHE_FILE="$CACHE_DIR/changelog.txt"
mkdir -p "$CACHE_DIR"

# Must match _LOG_FORMAT in backend/app/services/git.py exactly.
LOG_FMT='%h<<<DEUS_FIELD>>>%H<<<DEUS_FIELD>>>%s<<<DEUS_FIELD>>>%b<<<DEUS_FIELD>>>%an<<<DEUS_FIELD>>>%aI<<<DEUS_FIELD>>>%as<<<DEUS_COMMIT_END>>>'

echo "==> Generating changelog cache..."
git log -200 --format="$LOG_FMT" > "$CACHE_FILE"

# ---------------------------------------------------------------------------
# 3. Back up + rewrite .dockerignore / .gcloudignore
# ---------------------------------------------------------------------------
for f in .dockerignore .gcloudignore; do
  [[ -f "$f" ]] && cp "$f" "${f}.deus-backup"
done

# Single source of truth for both files (identical content)
cat > .dockerignore <<'EOF'
.git
.gitignore
.gitattributes
.claude
.cursor
.vscode
.idea
.github
**/__pycache__
**/*.pyc
**/*.pyo
**/.pytest_cache
**/.venv
**/venv
**/*.egg-info
**/node_modules
balance_dashboard/frontend/dist
balance_dashboard/frontend/.vite
.godot
**/*.import
**/*.tres.uid
**/*.gdshader.uid
**/*.gd.uid
/project.godot
/default_env.tres
/icon.svg
/icon.svg.import
/scenes
/scripts
/sprites
/assets
balance_dashboard/backend/app.py
balance_dashboard/backend/data_loader.py
balance_dashboard/backend/graph_builder.py
balance_dashboard/backend/simulator.py
balance_dashboard/backend/tres_writer.py
balance_dashboard/backend/export_from_tres.py
balance_dashboard/backend/requirements.txt
balance_dashboard/data
balance_dashboard/backups
card_game/art_pipeline
card_game/scenes
card_game/shaders
card_game/tests
card_game/addons
card_game/downloaded-packs
card_game/.godot
card_game/default_bus_layout.tres
card_game/*.png
card_game/*.png.import
card_game/assets/sfx
card_game/assets/music
card_game/assets/models
card_game/assets/backgrounds
card_game/assets/ui
card_game/assets/fonts
card_game/assets/enemies
card_game/assets/characters
card_game/assets/cc0_characters
card_game/assets/generated
card_game/assets/kenney_roguelike
card_game/assets/icons
card_game/assets/player
card_game/assets/relics
card_game/assets/DOWNLOAD_GUIDE.md
/README.md
/CHANGELOG.md
/LICENSE
/LICENSE.md
card_game/*.md
balance_dashboard/*.md
**/.DS_Store
**/Thumbs.db
**/*.swp
**/*.bak
!balance_dashboard/backend/.cache
!balance_dashboard/backend/.cache/changelog.txt
EOF
cp .dockerignore .gcloudignore

# Restore on exit
restore_ignores() {
  rm -f "$REPO_ROOT/.dockerignore" "$REPO_ROOT/.gcloudignore" "$REPO_ROOT/$CACHE_FILE"
  for f in .dockerignore .gcloudignore; do
    [[ -f "${f}.deus-backup" ]] && mv "${f}.deus-backup" "$f"
  done
}
trap restore_ignores EXIT

# ---------------------------------------------------------------------------
# 4. Deploy
# ---------------------------------------------------------------------------
echo "==> Submitting to Cloud Build + Cloud Run..."

$GCLOUD run deploy "$SERVICE_NAME" \
  --source . \
  --region "$REGION" \
  --allow-unauthenticated \
  --port 8080 \
  --memory "$MEMORY" \
  --cpu "$CPU" \
  --min-instances 0 \
  --max-instances 3 \
  --timeout 300

echo ""
echo "==> Deployed. Service URL:"
$GCLOUD run services describe "$SERVICE_NAME" \
  --region "$REGION" \
  --format='value(status.url)'
