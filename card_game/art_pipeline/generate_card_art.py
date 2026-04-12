"""
Batch card art generator for deus.exe using Nano Banana 2.

Reads hand-written prompts from card_art_prompts.json, generates base card
illustrations and 3 corruption variants (tainted, corrupted, demonic) per card
via Google's gemini-3.1-flash-image-preview model.

Uses the 3 locked anchor images as style references so all output matches the
painted horror realism art direction.

Inputs:
    art_pipeline/card_art_prompts.json   — 225 hand-written visual prompts
    art_pipeline/anchors/*.png           — 3 locked style reference images

Outputs:
    assets/cards/illustrations/{card_id}/{card_id}_base.png
    assets/cards/illustrations/{card_id}/{card_id}_corrupt_t1.png
    assets/cards/illustrations/{card_id}/{card_id}_corrupt_t2.png
    assets/cards/illustrations/{card_id}/{card_id}_corrupt_t3.png
    assets/cards/illustrations/_generation_report.txt

Run:
    # Requires: pip install google-genai pillow
    # Requires: GEMINI_API_KEY env var set
    python generate_card_art.py                          # all cards
    python generate_card_art.py --only strike            # one card
    python generate_card_art.py --character ghost         # one character's pool
    python generate_card_art.py --skip-variants           # base only, no corruption
    python generate_card_art.py --force                   # regenerate existing
    python generate_card_art.py --dry-run                 # show what would generate
    python generate_card_art.py --base-only-missing       # only gen base for cards missing it
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
PROMPTS_FILE = ART_PIPELINE_DIR / "card_art_prompts.json"
ILLUSTRATIONS_DIR = CARD_GAME_DIR / "assets" / "cards" / "illustrations"

ANCHOR_IMAGES = [
    ART_PIPELINE_DIR / "anchors" / "character_anchor.png",
    ART_PIPELINE_DIR / "anchors" / "background_anchor.png",
    ART_PIPELINE_DIR / "anchors" / "prop_anchor.png",
]

# Corruption variant modifiers — applied on top of the base image as a
# style-transfer pass. Each tier progressively destroys the original painting.
CORRUPTION_MODIFIERS = {
    "t1": (
        "The painting is beginning to rot. Faint bile-green veins creep into the "
        "edges of the composition. The sacred colors are slightly desaturated, as "
        "if moisture has seeped behind the varnish. A thin film of tarnish dulls "
        "any gold or amber accents. The subject is still recognizable but something "
        "feels wrong — like a prayer recited with one syllable changed. Subtle "
        "chromatic aberration at the margins. The brushwork looks slightly smeared "
        "in the shadows, as if unseen fingers dragged across wet paint."
    ),
    "t2": (
        "The painting is deeply corrupted. Purple-void cracks split the surface "
        "like shattered stained glass, revealing darkness underneath. Bile-green "
        "corrosion eats through the lower third. The original subject is still "
        "visible but distorted — stretched, smeared, partially dissolved. Sacred "
        "gold leaf has blackened and peeled. The chiaroscuro has inverted in "
        "patches: shadows glow faintly, highlights have gone dark. Tendrils of "
        "ink-black corruption wind through the composition like parasitic roots. "
        "The painting looks like it was pulled from a flooded crypt."
    ),
    "t3": (
        "The painting has become an abomination. The original subject is barely "
        "visible beneath layers of corruption — dissolved, reassembled wrong, "
        "fused with something else. The entire palette has shifted to arterial "
        "red, void violet, and gangrene green over charcoal black. The surface "
        "is cracked, blistered, weeping dark ichor. What was once sacred geometry "
        "has become organic — ribs, teeth, eye-sockets emerging from the painted "
        "surface as if the canvas itself is transforming into flesh. The painting "
        "looks alive and in pain. This is scripture rewritten by a daemon."
    ),
}

# Rate limiting
API_DELAY_SECONDS = 2.0          # minimum delay between API calls
MAX_RETRIES = 3
RETRY_BACKOFF_BASE = 5.0         # seconds; doubles each retry


# ── Utilities ─────────────────────────────────────────────────────────────


def save_genai_image_as_png(genai_image, out_path: Path) -> tuple[int, int]:
    """Save a google.genai image as a PROPER PNG.

    Nano Banana 2 returns JPEG bytes. Writing them with a .png extension
    produces files Godot's PNG decoder can't parse. Re-encoding via PIL
    guarantees a real PNG.

    Returns (width, height) of the saved image.
    """
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
    for save_attempt in range(3):
        try:
            pil_img.save(str(out_path), format="PNG", optimize=False, compress_level=6)
            break
        except OSError:
            if save_attempt < 2:
                time.sleep(1)
            else:
                raise
    return pil_img.size


def load_prompts() -> dict:
    """Load and validate card_art_prompts.json."""
    if not PROMPTS_FILE.exists():
        print(f"ERROR: prompts file missing: {PROMPTS_FILE}", file=sys.stderr)
        sys.exit(1)
    with open(PROMPTS_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)
    if "cards" not in data:
        print("ERROR: prompts file missing 'cards' key", file=sys.stderr)
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
    """Call the API with retry + exponential backoff.

    Returns (genai_image_or_None, text_response, elapsed_seconds).
    """
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
            # Quota / rate limit errors are retryable
            if "429" in err_str or "quota" in err_str.lower() or "rate" in err_str.lower():
                print(f"rate limited ({elapsed:.1f}s)")
                continue
            # Server errors are retryable
            if "500" in err_str or "503" in err_str:
                print(f"server error ({elapsed:.1f}s)")
                continue
            # Everything else is fatal for this card
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


def build_base_prompt(card_entry: dict, style_guide: dict) -> str:
    """Assemble the full text prompt for a base card image."""
    parts = []

    # Style prefix
    if "prefix" in style_guide:
        parts.append(style_guide["prefix"])

    # Card-specific prompt (the hand-written visual description)
    parts.append(card_entry["prompt"])

    # Palette rule
    if "palette_rule" in style_guide:
        parts.append(f"PALETTE: {style_guide['palette_rule']}")

    # Negative constraints
    if "negative" in style_guide:
        parts.append(f"CONSTRAINTS: {style_guide['negative']}")

    return " ".join(parts)


def build_variant_prompt(card_entry: dict, style_guide: dict, tier: str) -> str:
    """Assemble the prompt for a corruption variant.

    Uses the base prompt + corruption modifier so the model understands
    what it's corrupting.
    """
    base_desc = card_entry["prompt"]
    modifier = CORRUPTION_MODIFIERS[tier]

    return (
        f"{style_guide.get('prefix', '')} "
        f"Original subject: {base_desc}. "
        f"CORRUPTION: {modifier} "
        f"PALETTE: {style_guide.get('palette_rule', '')} "
        f"CONSTRAINTS: {style_guide.get('negative', '')}"
    )


def build_contents_base(
    prompt: str, anchors: list[Image.Image]
) -> list:
    """Build multimodal contents for base image generation."""
    instruction = (
        f"Generate a single card illustration for a dark fantasy deck-builder game. "
        f"Match the artistic style, painted horror realism feel, color palette, and lighting "
        f"of the reference images provided. "
        f"{prompt} "
        f"COMPOSITION: centered subject, fills the ENTIRE canvas edge-to-edge, square 1:1 aspect ratio. "
        f"CRITICAL: The painting must extend to ALL four edges of the image with NO margins, "
        f"NO borders, NO white space, NO frame, NO padding, NO mat. The art bleeds off every edge. "
        f"Do NOT paint this as a picture-within-a-picture. Do NOT add any border or surround."
    )
    return [instruction, *anchors]


def build_contents_variant(
    prompt: str, anchors: list[Image.Image], base_image: Image.Image
) -> list:
    """Build multimodal contents for corruption variant generation.

    Includes the base image as an additional reference so the corruption
    is applied to the right subject.
    """
    instruction = (
        f"Take the card illustration provided and apply corruption to it. "
        f"The result should still be a vertical card illustration in painted horror realism style, "
        f"matching the style references. "
        f"{prompt} "
        f"COMPOSITION: same as original — centered subject, square 1:1 aspect ratio. "
        f"CRITICAL: The painting must extend to ALL four edges with NO margins, NO borders, NO white space, NO frame."
    )
    return [instruction, *anchors, base_image]


def generate_base(
    client, card_id: str, card_entry: dict, style_guide: dict,
    anchors: list[Image.Image], out_dir: Path
) -> tuple[bool, str, float]:
    """Generate the base card image. Returns (ok, message, elapsed)."""
    prompt = build_base_prompt(card_entry, style_guide)
    contents = build_contents_base(prompt, anchors)
    config = types.GenerateContentConfig(
        response_modalities=["TEXT", "IMAGE"],
        image_config=types.ImageConfig(
            aspect_ratio=ASPECT_RATIO,
            image_size=IMAGE_SIZE,
        ),
    )

    image, text, elapsed = api_call_with_retry(client, contents, config, card_id)
    if image is None:
        return False, text, elapsed

    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{card_id}_base.png"
    w, h = save_genai_image_as_png(image, out_path)
    return True, f"{w}x{h}", elapsed


def generate_variant(
    client, card_id: str, card_entry: dict, style_guide: dict,
    anchors: list[Image.Image], base_image: Image.Image,
    tier: str, out_dir: Path
) -> tuple[bool, str, float]:
    """Generate one corruption variant. Returns (ok, message, elapsed)."""
    prompt = build_variant_prompt(card_entry, style_guide, tier)
    contents = build_contents_variant(prompt, anchors, base_image)
    config = types.GenerateContentConfig(
        response_modalities=["TEXT", "IMAGE"],
        image_config=types.ImageConfig(
            aspect_ratio=ASPECT_RATIO,
            image_size=IMAGE_SIZE,
        ),
    )

    image, text, elapsed = api_call_with_retry(client, contents, config, f"{card_id}_{tier}")
    if image is None:
        return False, text, elapsed

    out_path = out_dir / f"{card_id}_corrupt_{tier}.png"
    w, h = save_genai_image_as_png(image, out_path)
    return True, f"{w}x{h}", elapsed


# ── CLI ───────────────────────────────────────────────────────────────────


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Batch card art generator for deus.exe (Nano Banana 2).",
    )
    parser.add_argument(
        "--only", type=str, default=None,
        help="Generate only this card ID (e.g. --only strike)",
    )
    parser.add_argument(
        "--character", type=str, default=None,
        help="Generate only cards for this character (e.g. --character ghost)",
    )
    parser.add_argument(
        "--skip-variants", action="store_true",
        help="Generate base images only, skip corruption variants",
    )
    parser.add_argument(
        "--force", action="store_true",
        help="Regenerate even if output files already exist",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Show what would be generated without calling the API",
    )
    parser.add_argument(
        "--base-only-missing", action="store_true",
        help="Only generate base images for cards that don't have one yet",
    )
    args = parser.parse_args()

    # Load prompts
    data = load_prompts()
    style_guide = data["style_guide"]
    all_cards = data["cards"]

    # Filter cards
    cards = {}
    for card_id, entry in all_cards.items():
        if args.only and card_id != args.only:
            continue
        if args.character and entry.get("character", "shared") != args.character:
            continue
        cards[card_id] = entry

    if not cards:
        if args.only:
            print(f"ERROR: card '{args.only}' not found in prompts file", file=sys.stderr)
        elif args.character:
            print(f"ERROR: no cards found for character '{args.character}'", file=sys.stderr)
        else:
            print("ERROR: no cards found in prompts file", file=sys.stderr)
        return 1

    # Count what needs generating
    images_per_card = 1 if args.skip_variants else 4
    total_images = len(cards) * images_per_card

    print(f"Model:       {MODEL_ID}")
    print(f"Cards:       {len(cards)} of {len(all_cards)}")
    print(f"Images:      {total_images} ({images_per_card} per card)")
    print(f"Output:      {ILLUSTRATIONS_DIR}")
    print(f"Force:       {args.force}")
    print(f"Dry run:     {args.dry_run}")
    print()

    if args.dry_run:
        for card_id, entry in sorted(cards.items()):
            out_dir = ILLUSTRATIONS_DIR / card_id
            base_exists = (out_dir / f"{card_id}_base.png").exists()
            status = "EXISTS" if base_exists and not args.force else "GENERATE"
            char = entry.get("character", "shared")
            print(f"  [{status:8s}]  {card_id:30s}  ({char})")
            print(f"             {entry['prompt'][:100]}...")
            if not args.skip_variants:
                for tier in ["t1", "t2", "t3"]:
                    v_exists = (out_dir / f"{card_id}_corrupt_{tier}.png").exists()
                    v_status = "EXISTS" if v_exists and not args.force else "GENERATE"
                    print(f"  [{v_status:8s}]    -> {card_id}_corrupt_{tier}.png")
        print()
        to_gen = sum(
            1 for cid in cards
            if args.force or not (ILLUSTRATIONS_DIR / cid / f"{cid}_base.png").exists()
        )
        print(f"Would generate: {to_gen} base images", end="")
        if not args.skip_variants:
            print(f" + up to {to_gen * 3} corruption variants")
        else:
            print()
        return 0

    # Validate env
    if not os.environ.get("GEMINI_API_KEY"):
        print("ERROR: GEMINI_API_KEY env var not set.", file=sys.stderr)
        return 1

    # Load anchors
    print("Loading anchor images... ", end="", flush=True)
    anchors = load_anchor_images()
    print(f"{len(anchors)} loaded")

    # Init client
    client = genai.Client()

    # Report
    report_lines = [
        "Card art generation report",
        f"Model: {MODEL_ID}",
        f"Aspect: {ASPECT_RATIO} | Size: {IMAGE_SIZE}",
        f"Cards: {len(cards)} | Variants: {'no' if args.skip_variants else 'yes'}",
        "",
    ]

    total_start = time.time()
    stats = {"base_ok": 0, "base_skip": 0, "base_fail": 0,
             "variant_ok": 0, "variant_skip": 0, "variant_fail": 0}

    for i, (card_id, entry) in enumerate(sorted(cards.items()), 1):
        out_dir = ILLUSTRATIONS_DIR / card_id
        base_path = out_dir / f"{card_id}_base.png"
        char = entry.get("character", "shared")

        print(f"[{i}/{len(cards)}] {card_id} ({char})")

        # --- Base image ---
        if base_path.exists() and not args.force:
            if args.base_only_missing:
                print(f"   base: SKIP (exists)")
                stats["base_skip"] += 1
            else:
                print(f"   base: SKIP (exists)")
                stats["base_skip"] += 1
        else:
            print(f"   base: generating... ", end="", flush=True)
            ok, msg, elapsed = generate_base(
                client, card_id, entry, style_guide, anchors, out_dir
            )
            if ok:
                print(f"OK ({elapsed:.1f}s, {msg})")
                report_lines.append(f"{card_id} base: OK  {elapsed:.1f}s  {msg}")
                stats["base_ok"] += 1
            else:
                print(f"FAILED ({elapsed:.1f}s): {msg}")
                report_lines.append(f"{card_id} base: FAILED — {msg}")
                stats["base_fail"] += 1
            time.sleep(API_DELAY_SECONDS)

        # --- Corruption variants ---
        if args.skip_variants or args.base_only_missing:
            continue

        # Need the base image as reference for variants
        if not base_path.exists():
            print(f"   variants: SKIP (no base image)")
            stats["variant_skip"] += 3
            continue

        base_pil = Image.open(base_path)

        for tier in ["t1", "t2", "t3"]:
            variant_path = out_dir / f"{card_id}_corrupt_{tier}.png"
            if variant_path.exists() and not args.force:
                print(f"   {tier}: SKIP (exists)")
                stats["variant_skip"] += 1
                continue

            print(f"   {tier}: generating... ", end="", flush=True)
            ok, msg, elapsed = generate_variant(
                client, card_id, entry, style_guide, anchors, base_pil, tier, out_dir
            )
            if ok:
                print(f"OK ({elapsed:.1f}s, {msg})")
                report_lines.append(f"{card_id} {tier}: OK  {elapsed:.1f}s  {msg}")
                stats["variant_ok"] += 1
            else:
                print(f"FAILED ({elapsed:.1f}s): {msg}")
                report_lines.append(f"{card_id} {tier}: FAILED — {msg}")
                stats["variant_fail"] += 1
            time.sleep(API_DELAY_SECONDS)

        base_pil.close()

    total_elapsed = time.time() - total_start

    # Summary
    print()
    print("=" * 60)
    print(f"Done in {total_elapsed:.1f}s ({total_elapsed / 60:.1f}m)")
    print(f"  Base:     {stats['base_ok']} ok, {stats['base_skip']} skipped, {stats['base_fail']} failed")
    if not args.skip_variants and not args.base_only_missing:
        print(f"  Variants: {stats['variant_ok']} ok, {stats['variant_skip']} skipped, {stats['variant_fail']} failed")
    total_ok = stats["base_ok"] + stats["variant_ok"]
    total_fail = stats["base_fail"] + stats["variant_fail"]
    print(f"  Total:    {total_ok} generated, {total_fail} failed")

    report_lines.extend([
        "",
        f"Total: {total_elapsed:.1f}s ({total_elapsed / 60:.1f}m)",
        f"Base: {stats['base_ok']} ok, {stats['base_skip']} skipped, {stats['base_fail']} failed",
        f"Variants: {stats['variant_ok']} ok, {stats['variant_skip']} skipped, {stats['variant_fail']} failed",
    ])
    report_path = ILLUSTRATIONS_DIR / "_generation_report.txt"
    report_path.write_text("\n".join(report_lines), encoding="utf-8")
    print(f"\nReport: {report_path}")

    return 0 if total_fail == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
