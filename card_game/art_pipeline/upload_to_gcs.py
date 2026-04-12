"""
Upload card & item art to Google Cloud Storage.

Syncs local illustration directories to a GCS bucket for CDN serving.
Only uploads files that are new or changed (uses gsutil rsync).

Usage:
    python upload_to_gcs.py                    # sync everything
    python upload_to_gcs.py --cards-only       # sync card art only
    python upload_to_gcs.py --items-only       # sync item art only
    python upload_to_gcs.py --dry-run          # show what would upload
"""

import argparse
import subprocess
import sys
from pathlib import Path

BUCKET = "deus-exe-art"
CARD_GAME_DIR = Path(__file__).parent.parent
CARD_ART_DIR = CARD_GAME_DIR / "assets" / "cards" / "illustrations"
ITEM_ART_DIR = CARD_GAME_DIR / "assets" / "items" / "illustrations"

# Try to find gcloud/gsutil
GCLOUD_CANDIDATES = [
    "gcloud",
    str(Path.home() / "bin" / "gcloud.cmd"),
    r"C:\Users\Chris\bin\gcloud.cmd",
]


def find_gcloud() -> str:
    for candidate in GCLOUD_CANDIDATES:
        try:
            subprocess.run(
                [candidate, "--version"],
                capture_output=True,
                timeout=10,
            )
            return candidate
        except (FileNotFoundError, subprocess.TimeoutExpired):
            continue
    print("ERROR: gcloud CLI not found", file=sys.stderr)
    sys.exit(1)


def sync_dir(gcloud: str, local_dir: Path, gcs_prefix: str, dry_run: bool):
    """Rsync a local directory to GCS."""
    gcs_path = f"gs://{BUCKET}/{gcs_prefix}"
    print(f"\n{'[DRY RUN] ' if dry_run else ''}Syncing {local_dir.name}/ -> {gcs_path}/")
    print(f"  Local:  {local_dir}")
    print(f"  Remote: {gcs_path}")

    # Count local files
    local_pngs = list(local_dir.rglob("*.png"))
    print(f"  Files:  {len(local_pngs)} PNGs")

    cmd = [
        gcloud, "storage", "rsync",
        str(local_dir),
        gcs_path,
        "--recursive",
        "--exclude=_generation_report.txt",
    ]
    if dry_run:
        cmd.append("--dry-run")

    print(f"  Running: {' '.join(cmd)}\n")
    result = subprocess.run(cmd, timeout=600)
    return result.returncode


def main():
    parser = argparse.ArgumentParser(description="Upload art to GCS")
    parser.add_argument("--cards-only", action="store_true")
    parser.add_argument("--items-only", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    gcloud = find_gcloud()
    print(f"Bucket:  gs://{BUCKET}")
    print(f"gcloud:  {gcloud}")

    errors = 0

    if not args.items_only:
        rc = sync_dir(gcloud, CARD_ART_DIR, "cards", args.dry_run)
        if rc != 0:
            errors += 1
            print(f"  WARN: card sync exited with code {rc}")

    if not args.cards_only:
        rc = sync_dir(gcloud, ITEM_ART_DIR, "items", args.dry_run)
        if rc != 0:
            errors += 1
            print(f"  WARN: item sync exited with code {rc}")

    print(f"\n{'[DRY RUN] ' if args.dry_run else ''}Done.")
    if errors:
        print(f"  {errors} sync(s) had errors")
        sys.exit(1)
    else:
        print("  All syncs successful")


if __name__ == "__main__":
    main()
