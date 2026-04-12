"""
Batch item art generator for deus.exe using Nano Banana 2.

Generates icons for gems, relics, and equipment. No corruption variants —
items are single images per item.

Inputs:
    art_pipeline/item_art_prompts.json   — 65 hand-written visual prompts
    art_pipeline/anchors/*.png           — 3 locked style reference images

Outputs:
    assets/items/illustrations/{item_id}/{item_id}.png
    assets/items/illustrations/_generation_report.txt

Run:
    # Requires: pip install google-genai pillow
    # Requires: GEMINI_API_KEY env var set
    python generate_item_art.py                    # all 65 items
    python generate_item_art.py --only ruby_of_fury  # one item
    python generate_item_art.py --category gem       # gems only
    python generate_item_art.py --force              # regenerate existing
    python generate_item_art.py --dry-run            # show what would generate
"""

import argparse
import io
import json
import os
import sys
import time
import random
from pathlib import Path

from google import genai
from google.genai import types
from PIL import Image


# ── Config ────────────────────────────────────────────────────────────────

MODEL_ID = "gemini-3.1-flash-image-preview"
ASPECT_RATIO = "1:1"
IMAGE_SIZE = "2K"

ART_PIPELINE_DIR = Path(__file__).parent
CARD_GAME_DIR = ART_PIPELINE_DIR.parent
PROMPTS_FILE = ART_PIPELINE_DIR / "item_art_prompts.json"
ILLUSTRATIONS_DIR = CARD_GAME_DIR / "assets" / "items" / "illustrations"

ANCHOR_IMAGES = [
    ART_PIPELINE_DIR / "anchors" / "character_anchor.png",
    ART_PIPELINE_DIR / "anchors" / "background_anchor.png",
    ART_PIPELINE_DIR / "anchors" / "prop_anchor.png",
]

# Rate limiting
API_DELAY_SECONDS = 2.0
MAX_RETRIES = 3
RETRY_BACKOFF_BASE = 5.0


# ── Utilities ─────────────────────────────────────────────────────────────


def save_genai_image_as_png(genai_image, out_path: Path) -> tuple[int, int]:
    """Save a google.genai image as a PROPER PNG."""
    raw_bytes = None
    for attr in ("image_bytes", "_image_bytes", "data"):
        if hasattr(genai_image, attr):
            raw_bytes = getattr(genai_image, attr)
            if callable(raw_bytes):
                raw_bytes = raw_bytes()
            if raw_bytes:
                break
    if raw_bytes is None:
        tmp_path = out_path.with_suffix(".genai-tmp")
        genai_image.save(str(tmp_path))
        raw_bytes = tmp_path.read_bytes()
        tmp_path.unlink()

    pil_img = Image.open(io.BytesIO(raw_bytes))
    if pil_img.mode != "RGBA":
        pil_img = pil_img.convert("RGBA")
    pil_img.save(str(out_path), format="PNG", optimize=False, compress_level=6)
    return pil_img.size


def load_prompts() -> dict:
    """Load and validate item_art_prompts.json."""
    if not PROMPTS_FILE.exists():
        print(f"ERROR: prompts file missing: {PROMPTS_FILE}", file=sys.stderr)
        sys.exit(1)
    with open(PROMPTS_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)
    if "items" not in data:
        print("ERROR: prompts file missing 'items' key", file=sys.stderr)
        sys.exit(1)
    if "style_guide" not in data:
        print("ERROR: prompts file missing 'style_guide' key", file=sys.stderr)
        sys.exit(1)
    return data


def load_anchor_images() -> list[Image.Image]:
    """Load the 3 locked anchor images as PIL Images for style reference."""
    images = []
    for path in ANCHOR_IMAGES:
        if not path.exists():
            print(f"WARNING: anchor image missing: {path}", file=sys.stderr)
            continue
        images.append(Image.open(path))
    if not images:
        print("ERROR: no anchor images found", file=sys.stderr)
        sys.exit(1)
    return images


def api_call_with_retry(client, contents, config, label: str) -> tuple:
    """Call the API with retry + exponential backoff."""
    for attempt in range(MAX_RETRIES):
        if attempt > 0:
            wait = RETRY_BACKOFF_BASE * (2 ** (attempt - 1)) + random.uniform(0, 2)
            print(f"      retry {attempt}/{MAX_RETRIES} in {wait:.0f}s... ", end="", flush=True)
            time.sleep(wait)

        start = time.time()
        try:
            response = client.models.generate_content(
                model=MODEL_ID,
                contents=contents,
                config=config,
            )
        except Exception as exc:
            elapsed = time.time() - start
            err_str = str(exc)
            if "429" in err_str or "quota" in err_str.lower() or "rate" in err_str.lower():
                print(f"rate limited ({elapsed:.1f}s)")
                continue
            if "500" in err_str or "503" in err_str:
                print(f"server error ({elapsed:.1f}s)")
                continue
            return None, f"ERROR: {err_str}", elapsed

        elapsed = time.time() - start
        image = None
        text = ""
        for part in response.parts:
            if part.text is not None:
                text += part.text
            elif (img := part.as_image()) is not None:
                image = img
        return image, text, elapsed

    return None, "ERROR: max retries exceeded", 0.0


# ── Generation ────────────────────────────────────────────────────────────


def build_prompt(item_entry: dict, style_guide: dict) -> str:
    """Assemble the full text prompt for an item image."""
    parts = []
    if "prefix" in style_guide:
        parts.append(style_guide["prefix"])
    parts.append(item_entry["prompt"])
    if "palette_rule" in style_guide:
        parts.append(f"PALETTE: {style_guide['palette_rule']}")
    if "negative" in style_guide:
        parts.append(f"CONSTRAINTS: {style_guide['negative']}")
    return " ".join(parts)


def build_contents(prompt: str, anchors: list[Image.Image]) -> list:
    """Build multimodal contents for item image generation."""
    instruction = (
        f"Generate a single item icon illustration for a dark fantasy deck-builder game. "
        f"A single object centered on a near-black background, painted in oil-paint horror realism. "
        f"Match the artistic style, color palette, and lighting of the reference images provided. "
        f"{prompt} "
        f"COMPOSITION: single centered object, square 1:1 aspect ratio, dark background. "
        f"CRITICAL: The painting must extend to ALL four edges of the image with NO margins, "
        f"NO borders, NO white space, NO frame, NO padding, NO mat, NO painted border effect. "
        f"The art bleeds off every edge. Do NOT paint this as a picture-within-a-picture. "
        f"Do NOT add any border, surround, torn edges, or vignette frame."
    )
    return [instruction, *anchors]


def generate_item(
    client, item_id: str, item_entry: dict, style_guide: dict,
    anchors: list[Image.Image], out_dir: Path
) -> tuple[bool, str, float]:
    """Generate one item image. Returns (ok, message, elapsed)."""
    prompt = build_prompt(item_entry, style_guide)
    contents = build_contents(prompt, anchors)
    config = types.GenerateContentConfig(
        response_modalities=["TEXT", "IMAGE"],
        image_config=types.ImageConfig(
            aspect_ratio=ASPECT_RATIO,
            image_size=IMAGE_SIZE,
        ),
    )

    image, text, elapsed = api_call_with_retry(client, contents, config, item_id)
    if image is None:
        return False, text, elapsed

    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{item_id}.png"
    w, h = save_genai_image_as_png(image, out_path)
    return True, f"{w}x{h}", elapsed


# ── CLI ───────────────────────────────────────────────────────────────────


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Batch item art generator for deus.exe (Nano Banana 2).",
    )
    parser.add_argument(
        "--only", type=str, default=None,
        help="Generate only this item ID (e.g. --only ruby_of_fury)",
    )
    parser.add_argument(
        "--category", type=str, default=None,
        choices=["gem", "relic", "equipment"],
        help="Generate only items in this category",
    )
    parser.add_argument(
        "--force", action="store_true",
        help="Regenerate even if output files already exist",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Show what would be generated without calling the API",
    )
    args = parser.parse_args()

    # Load prompts
    data = load_prompts()
    style_guide = data["style_guide"]
    all_items = data["items"]

    # Filter items
    items = {}
    for item_id, entry in all_items.items():
        if args.only and item_id not in args.only.split(','):
            continue
        if args.category and entry.get("category", "") != args.category:
            continue
        items[item_id] = entry

    if not items:
        if args.only:
            print(f"ERROR: item '{args.only}' not found in prompts file", file=sys.stderr)
        elif args.category:
            print(f"ERROR: no items found for category '{args.category}'", file=sys.stderr)
        else:
            print("ERROR: no items found in prompts file", file=sys.stderr)
        return 1

    print(f"Model:       {MODEL_ID}")
    print(f"Items:       {len(items)} of {len(all_items)}")
    print(f"Output:      {ILLUSTRATIONS_DIR}")
    print(f"Force:       {args.force}")
    print(f"Dry run:     {args.dry_run}")
    print()

    if args.dry_run:
        for item_id, entry in sorted(items.items()):
            out_path = ILLUSTRATIONS_DIR / item_id / f"{item_id}.png"
            exists = out_path.exists()
            status = "EXISTS" if exists and not args.force else "GENERATE"
            cat = entry.get("category", "?")
            print(f"  [{status:8s}]  {item_id:35s}  ({cat})  {entry.get('display_name', '')}")
            print(f"             {entry['prompt'][:100]}...")
        print()
        to_gen = sum(
            1 for iid in items
            if args.force or not (ILLUSTRATIONS_DIR / iid / f"{iid}.png").exists()
        )
        print(f"Would generate: {to_gen} images")
        return 0

    # Validate env
    if not os.environ.get("GEMINI_API_KEY"):
        print("ERROR: GEMINI_API_KEY env var not set.", file=sys.stderr)
        return 1

    # Load anchors
    print("Loading anchor images... ", end="", flush=True)
    anchors = load_anchor_images()
    print(f"{len(anchors)} loaded")

    client = genai.Client()

    report_lines = [
        "Item art generation report",
        f"Model: {MODEL_ID}",
        f"Aspect: {ASPECT_RATIO} | Size: {IMAGE_SIZE}",
        f"Items: {len(items)}",
        "",
    ]

    total_start = time.time()
    ok_count = 0
    skip_count = 0
    fail_count = 0

    for i, (item_id, entry) in enumerate(sorted(items.items()), 1):
        out_dir = ILLUSTRATIONS_DIR / item_id
        out_path = out_dir / f"{item_id}.png"
        cat = entry.get("category", "?")

        print(f"[{i}/{len(items)}] {item_id} ({cat})")

        if out_path.exists() and not args.force:
            print(f"   SKIP (exists)")
            skip_count += 1
            continue

        print(f"   generating... ", end="", flush=True)
        ok, msg, elapsed = generate_item(
            client, item_id, entry, style_guide, anchors, out_dir
        )
        if ok:
            print(f"OK ({elapsed:.1f}s, {msg})")
            report_lines.append(f"{item_id}: OK  {elapsed:.1f}s  {msg}")
            ok_count += 1
        else:
            print(f"FAILED ({elapsed:.1f}s): {msg}")
            report_lines.append(f"{item_id}: FAILED — {msg}")
            fail_count += 1
        time.sleep(API_DELAY_SECONDS)

    total_elapsed = time.time() - total_start

    print()
    print("=" * 60)
    print(f"Done in {total_elapsed:.1f}s ({total_elapsed / 60:.1f}m)")
    print(f"  OK:      {ok_count}")
    print(f"  Skipped: {skip_count}")
    print(f"  Failed:  {fail_count}")

    report_lines.extend([
        "",
        f"Total: {total_elapsed:.1f}s ({total_elapsed / 60:.1f}m)",
        f"OK: {ok_count}, Skipped: {skip_count}, Failed: {fail_count}",
    ])
    report_path = ILLUSTRATIONS_DIR / "_generation_report.txt"
    report_path.write_text("\n".join(report_lines), encoding="utf-8")
    print(f"\nReport: {report_path}")

    return 0 if fail_count == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
