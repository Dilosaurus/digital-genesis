"""
Generate WebP thumbnails from full-res card & item art for dashboard serving.

Creates 512px and 256px WebP thumbnails at quality 80 — typically 20-50KB vs 5MB originals.
Uploads to GCS under /cards/thumb/ and /items/thumb/ prefixes.

Usage:
    python generate_thumbnails.py              # generate + upload all
    python generate_thumbnails.py --local-only # generate only, skip upload
    python generate_thumbnails.py --force      # regenerate even if thumbs exist
"""

import argparse
import subprocess
import sys
from pathlib import Path
from PIL import Image

CARD_GAME_DIR = Path(__file__).parent.parent
CARD_ART_DIR = CARD_GAME_DIR / "assets" / "cards" / "illustrations"
ITEM_ART_DIR = CARD_GAME_DIR / "assets" / "items" / "illustrations"
THUMB_DIR = CARD_GAME_DIR / "assets" / ".thumbnails"

BUCKET = "deus-exe-art"
SIZES = {"thumb": 512, "micro": 256}
WEBP_QUALITY = 80

GCLOUD_CANDIDATES = [
    "gcloud",
    str(Path.home() / "bin" / "gcloud.cmd"),
    r"C:\Users\Chris\bin\gcloud.cmd",
]


def find_gcloud() -> str:
    for candidate in GCLOUD_CANDIDATES:
        try:
            subprocess.run([candidate, "--version"], capture_output=True, timeout=10)
            return candidate
        except (FileNotFoundError, subprocess.TimeoutExpired):
            continue
    return ""


def generate_thumb(src: Path, dst: Path, size: int) -> int:
    """Resize + convert to WebP. Returns file size in bytes."""
    dst.parent.mkdir(parents=True, exist_ok=True)
    img = Image.open(src)
    img.thumbnail((size, size), Image.LANCZOS)
    img.save(str(dst), format="WEBP", quality=WEBP_QUALITY, method=4)
    return dst.stat().st_size


def process_dir(src_dir: Path, category: str, force: bool) -> dict:
    """Generate thumbnails for all PNGs in a directory tree."""
    stats = {"generated": 0, "skipped": 0, "total_bytes": 0}

    for png in sorted(src_dir.rglob("*.png")):
        if png.name.startswith("_"):
            continue

        rel = png.relative_to(src_dir)

        for label, size in SIZES.items():
            dst = THUMB_DIR / category / label / rel.with_suffix(".webp")
            if dst.exists() and not force:
                stats["skipped"] += 1
                continue

            sz = generate_thumb(png, dst, size)
            stats["generated"] += 1
            stats["total_bytes"] += sz

    return stats


def upload_thumbs(gcloud: str):
    """Sync thumbnails to GCS."""
    for category in ["cards", "items"]:
        for label in SIZES:
            local = THUMB_DIR / category / label
            if not local.exists():
                continue
            gcs_path = f"gs://{BUCKET}/{category}/{label}"
            print(f"  Syncing {category}/{label}/ -> {gcs_path}/")
            subprocess.run(
                [gcloud, "storage", "rsync", str(local), gcs_path, "--recursive"],
                timeout=300,
            )


def main():
    parser = argparse.ArgumentParser(description="Generate WebP thumbnails")
    parser.add_argument("--force", action="store_true", help="Regenerate all")
    parser.add_argument("--local-only", action="store_true", help="Skip GCS upload")
    args = parser.parse_args()

    THUMB_DIR.mkdir(parents=True, exist_ok=True)

    print("Generating thumbnails...")
    print(f"  Sizes: {', '.join(f'{k}={v}px' for k, v in SIZES.items())}")
    print(f"  Format: WebP q{WEBP_QUALITY}")
    print()

    for category, src_dir in [("cards", CARD_ART_DIR), ("items", ITEM_ART_DIR)]:
        print(f"  {category}/")
        stats = process_dir(src_dir, category, args.force)
        mb = stats["total_bytes"] / (1024 * 1024)
        print(f"    Generated: {stats['generated']}, Skipped: {stats['skipped']}, Size: {mb:.1f}MB")

    if not args.local_only:
        gcloud = find_gcloud()
        if not gcloud:
            print("\n  WARN: gcloud not found, skipping upload")
            return
        print(f"\nUploading to gs://{BUCKET}/...")
        upload_thumbs(gcloud)
        print("Done.")
    else:
        print("\nLocal only — skipping upload.")


if __name__ == "__main__":
    main()
