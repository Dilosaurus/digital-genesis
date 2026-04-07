# deus.exe // codex — deploy guide

Cloud Run deployment runs automatically on every push to `master` that
touches `balance_dashboard/**` or any of the `card_game/` directories the
parser reads. The workflow lives at `.github/workflows/deploy-codex.yml`.

## One-time setup

You need to do this once to wire up GitHub Actions → Google Cloud.

### 1. Pick a GCP project

```bash
gcloud config set project mercurial-craft-483416-g3
gcloud config set run/region us-central1
```

### 2. Enable the APIs the workflow uses

```bash
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  iamcredentials.googleapis.com
```

### 3. Create a deploy service account

```bash
gcloud iam service-accounts create codex-deployer \
  --display-name="deus.exe codex deployer" \
  --description="Used by GitHub Actions to deploy to Cloud Run"
```

### 4. Grant the deploy account the roles it needs

The service account needs four roles. `gcloud run deploy --source .`
triggers Cloud Build, which writes to Artifact Registry, pulls to Cloud
Run, and sets the Cloud Run service identity.

```bash
PROJECT=$(gcloud config get-value project)
SA="codex-deployer@${PROJECT}.iam.gserviceaccount.com"

for role in \
  roles/run.admin \
  roles/cloudbuild.builds.editor \
  roles/artifactregistry.writer \
  roles/iam.serviceAccountUser \
  roles/storage.admin
do
  gcloud projects add-iam-policy-binding "$PROJECT" \
    --member="serviceAccount:${SA}" \
    --role="$role" \
    --condition=None
done
```

> **Why `storage.admin`?** Cloud Build uploads the build context to a
> staging GCS bucket. Without this role, `gcloud run deploy --source .`
> fails with "permission denied on bucket".

### 5. Create a JSON key and add it as a GitHub secret

```bash
gcloud iam service-accounts keys create ./codex-deployer.key.json \
  --iam-account="$SA"
```

Then in the GitHub repo:

1. Go to **Settings → Secrets and variables → Actions → New repository secret**
2. Name: `GCP_SA_KEY`
3. Value: paste the entire contents of `codex-deployer.key.json`
4. Save

**After saving the secret, DELETE the local key file:**

```bash
rm codex-deployer.key.json
```

The JSON key is now stored encrypted in GitHub and can only be read by
workflow runs. Rotate it every 90 days or so (`gcloud iam service-accounts
keys create` again, update the secret, `gcloud iam service-accounts keys
delete` the old one).

### 6. Trigger the first deploy

Push a commit to `master` that touches `balance_dashboard/**`, or trigger
the workflow manually:

1. Go to **Actions → deploy codex → Run workflow**
2. Pick `master`, click **Run workflow**

The first deploy takes ~4–6 minutes (Cloud Build has to warm up +
build the Docker image + push to Artifact Registry + roll out to Cloud
Run). Subsequent deploys are ~2–3 minutes because Cloud Build caches
layers.

When the deploy finishes, the job summary shows the service URL.

## Verifying the deploy

```bash
# Get the URL
URL=$(gcloud run services describe balance-dashboard \
  --region us-central1 --format='value(status.url)')
echo "$URL"

# Hit the health endpoint
curl -s "$URL/api/health" | python -m json.tool

# Check the codex cards endpoint
curl -s "$URL/api/codex/cards" | python -c "import sys,json; print(len(json.load(sys.stdin)))"
# → 175

# Check the static assets
curl -sI "$URL/media/cards/illustrations/strike/strike_base.png"
# → HTTP/2 200

# Check the bible UI
curl -sI "$URL/"
# → HTTP/2 200, content-type: text/html
```

## Local deploy (fallback)

If the GitHub Actions workflow is broken or you want to deploy without
pushing, run the manual script:

```bash
# Make sure you're authed locally
gcloud auth login
gcloud config set project mercurial-craft-483416-g3

# Run the script from the repo root
bash balance_dashboard/deploy.sh
```

`deploy.sh` does the same work as the GitHub Actions workflow: generates
the changelog cache, writes tailored ignore files, submits to Cloud
Build, restores your ignore files on exit.

## What the build does

1. **Frontend build stage** (Node 22): `npm ci && npm run build` →
   `balance_dashboard/frontend/dist/`.
2. **Runtime stage** (Python 3.12): installs FastAPI + uvicorn + pydantic
   + sqlmodel, copies the new `backend/app/` package, copies the Vite
   build output, copies the `.tres` game data + asset images, copies the
   pre-generated changelog cache.
3. **Container boot**: uvicorn listens on `$PORT` (injected by Cloud Run,
   default 8080). The FastAPI app serves:
   - `/` → the React SPA (with a fallback route for React Router)
   - `/api/*` → JSON endpoints (codex, content, meta, health)
   - `/media/*` → card game asset images
   - `/assets/*` → Vite's hashed JS/CSS
   - `/docs` → auto-generated OpenAPI UI

Final image is around ~400 MB (Python base + 138 MB of card game assets
+ the JS bundle). First boot is a few hundred milliseconds.

## Troubleshooting

### `denied: Permission "storage.buckets.get" denied`

Cloud Build's staging bucket isn't accessible. Re-run step 4 above and
make sure `roles/storage.admin` is bound to the deploy service account.

### `missing required file: balance_dashboard/backend/.cache/changelog.txt`

The changelog cache wasn't generated before the Docker build. Check the
`Generate changelog cache` step of the workflow — it should be running
before the deploy step. For local `deploy.sh`, this is handled
automatically.

### `Cannot read properties of undefined` on the live bible

The frontend couldn't reach `/api/codex/*`. Hit `$URL/api/health` to
confirm the backend is alive. If it's alive but the bible still looks
blank, check the browser console for CORS errors (shouldn't happen since
frontend + backend are same-origin in production, but worth checking).

### The card art is missing but the data loads

The `/media/*` mount didn't find the image files. Check the container
logs: `gcloud run services logs read balance-dashboard --region
us-central1 --limit 50`. If the container has `DEUS_CARD_GAME_DIR=/srv/card_game`
and `ls /srv/card_game/assets/cards/` shows nothing, the `.dockerignore`
is excluding them — check the workflow's `Write tailored ignore files`
step.

## Rolling back

Cloud Run keeps every previous revision. To roll back:

```bash
# List recent revisions
gcloud run revisions list --service balance-dashboard --region us-central1 --limit 10

# Roll traffic back to a specific revision
gcloud run services update-traffic balance-dashboard \
  --region us-central1 \
  --to-revisions=balance-dashboard-00042-abc=100
```

## Cost

- **Min instances**: 0 (scales to zero when idle)
- **Max instances**: 3
- **Cost at zero traffic**: $0 (Cloud Run only bills during request handling)
- **Cost at low traffic (~100 requests/day)**: cents per month
- **Cost during Cloud Build deploys**: ~$0.003 per build (build minutes are generous on the free tier)

Expect single-digit dollars per month of total GCP spend for a design
tool at this scale.
