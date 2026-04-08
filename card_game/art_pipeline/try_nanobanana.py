"""
Nano Banana 2 (Gemini 3.1 Flash Image) prototype for deus.exe card art.

Goal: validate whether Google's gemini-3.1-flash-image-preview can replace
the ComfyUI + SDXL + LoRA pipeline by generating 3 test cards in the same
style as the existing illustrations, using real card art as reference images
for style consistency.

Run:
    # Requires: pip install google-genai pillow
    # Requires: GEMINI_API_KEY env var set
    python try_nanobanana.py

Output:
    assets/cards/illustrations/_nanobanana_test/<card>_nb2.png
    assets/cards/illustrations/_nanobanana_test/_report.txt
"""

import os
import sys
import time
import json
from pathlib import Path

from google import genai
from google.genai import types
from PIL import Image

# ── Config ────────────────────────────────────────────────────────────────

MODEL_ID = "gemini-3.1-flash-image-preview"

ART_PIPELINE_DIR = Path(__file__).parent
CARD_GAME_DIR = ART_PIPELINE_DIR.parent
ILLUSTRATIONS_DIR = CARD_GAME_DIR / "assets" / "cards" / "illustrations"
OUTPUT_DIR = ILLUSTRATIONS_DIR / "_nanobanana_test"

# Style reference images — 2 existing finished cards whose look we want to match.
# Nano Banana 2 accepts up to 14 reference images; 2-3 strong ones is usually enough.
STYLE_REFERENCES = [
    ILLUSTRATIONS_DIR / "bash" / "bash_base.png",
    ILLUSTRATIONS_DIR / "cleave" / "cleave_base.png",
]

# Style context — copied verbatim from art_pipeline/config.json "card_art_style_prefix"
# so the prototype uses the same visual direction the ComfyUI pipeline does.
STYLE_PREFIX = (
    "cyberpunk digital realm, neon glow, circuit patterns, holographic, "
    "dark background, detailed illustration, card game art, centered composition, "
    "Tron Legacy aesthetic, data streams, glowing edges"
)
STYLE_NEGATIVE = (
    "No text, no words, no letters, no numbers, no borders, no frames, "
    "no UI elements, no watermarks, no signatures. Do not crop the subject."
)

# Three test cards, each with a real prompt pulled from card_prompts.json.
# Picked to cover different mechanics (attack / AoE / heal) so we can see
# if Nano Banana 2 handles stylistic range at a consistent quality.
TEST_CARDS = [
    {
        "id": "strike",
        "display_name": "System Strike",
        "prompt": (
            "cyberpunk warrior slashing with glowing energy blade, close combat strike, "
            "red energy trail, neon-lit dark environment"
        ),
    },
    {
        "id": "body_slam",
        "display_name": "Body Slam",
        "prompt": (
            "heavy cybernetic warrior crashing shoulder-first into an enemy, "
            "bone-cracking impact, kinetic energy ripple, shattered circuit debris"
        ),
    },
    {
        "id": "bandage",
        "display_name": "Bandage",
        "prompt": (
            "glowing digital healing bandages wrapping around wounds, "
            "soft green restoration energy, simple repair routine, "
            "basic system patch being applied"
        ),
    },
]

ASPECT_RATIO = "2:3"       # matches existing 512x768 portrait cards
IMAGE_SIZE = "2K"           # upscale for future use; downsample in-game


# ── Main ──────────────────────────────────────────────────────────────────


def build_contents(card: dict, references: list[Image.Image]) -> list:
    """Build the multimodal contents list for one card generation call.

    Order matters: the text instruction should reference the images that
    follow it, so we put style context first, references second, then the
    card-specific prompt.
    """
    instruction = (
        f"Generate a single vertical card illustration for a cyberpunk deck-builder game. "
        f"STYLE: {STYLE_PREFIX}. "
        f"Match the artistic style, color palette, and lighting of the reference images provided. "
        f"SUBJECT: {card['prompt']}. "
        f"COMPOSITION: centered subject, fills the frame, portrait 2:3 aspect. "
        f"CONSTRAINTS: {STYLE_NEGATIVE}"
    )
    return [instruction, *references]


def generate_card(client, card: dict, references: list[Image.Image]):
    """Call Nano Banana 2 for one card.

    Returns (genai_image_or_None, text_response, elapsed_seconds).
    Note: the returned image is a google.genai.types.Image (has .save()),
    not a PIL Image. Reopen the saved file with PIL if you need dimensions.
    """
    start = time.time()
    response = client.models.generate_content(
        model=MODEL_ID,
        contents=build_contents(card, references),
        config=types.GenerateContentConfig(
            response_modalities=["TEXT", "IMAGE"],
            image_config=types.ImageConfig(
                aspect_ratio=ASPECT_RATIO,
                image_size=IMAGE_SIZE,
            ),
        ),
    )
    elapsed = time.time() - start

    image = None
    text = ""
    for part in response.parts:
        if part.text is not None:
            text += part.text
        elif (img := part.as_image()) is not None:
            image = img

    return image, text, elapsed


def main() -> int:
    if not os.environ.get("GEMINI_API_KEY"):
        print("ERROR: GEMINI_API_KEY env var not set.", file=sys.stderr)
        return 1

    # Verify references exist before burning any API credits
    for ref in STYLE_REFERENCES:
        if not ref.exists():
            print(f"ERROR: style reference missing: {ref}", file=sys.stderr)
            return 1

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Model:       {MODEL_ID}")
    print(f"References:  {[r.name for r in STYLE_REFERENCES]}")
    print(f"Output:      {OUTPUT_DIR}")
    print(f"Cards:       {len(TEST_CARDS)}")
    print()

    # Load reference images once; reuse across all calls
    reference_images = [Image.open(r) for r in STYLE_REFERENCES]

    # SDK reads GEMINI_API_KEY from env automatically
    client = genai.Client()

    report_lines = [
        f"Nano Banana 2 prototype report",
        f"Model: {MODEL_ID}",
        f"Aspect: {ASPECT_RATIO} | Size: {IMAGE_SIZE}",
        f"References: {', '.join(r.name for r in STYLE_REFERENCES)}",
        f"",
    ]

    total_start = time.time()
    results = []
    for card in TEST_CARDS:
        print(f"-> {card['id']:12s}  ({card['display_name']}) ... ", end="", flush=True)
        try:
            image, text, elapsed = generate_card(client, card, reference_images)
        except Exception as exc:
            print(f"FAILED ({exc})")
            report_lines.append(f"{card['id']}: FAILED — {exc}")
            results.append((card["id"], "failed", 0.0))
            continue

        if image is None:
            print(f"NO IMAGE (model returned text only)")
            report_lines.append(f"{card['id']}: NO IMAGE — text: {text[:200]}")
            results.append((card["id"], "no_image", elapsed))
            continue

        out_path = OUTPUT_DIR / f"{card['id']}_nb2.png"
        image.save(str(out_path))
        with Image.open(out_path) as saved:
            w, h = saved.size
        print(f"OK  ({elapsed:.1f}s, {w}x{h})  ->  {out_path.name}")
        report_lines.append(
            f"{card['id']}: OK  {elapsed:.1f}s  {w}x{h}  ->  {out_path.name}"
        )
        if text:
            report_lines.append(f"  model text: {text[:200]}")
        results.append((card["id"], "ok", elapsed))

    total_elapsed = time.time() - total_start
    ok_count = sum(1 for _, status, _ in results if status == "ok")

    print()
    print(f"Done: {ok_count}/{len(TEST_CARDS)} cards in {total_elapsed:.1f}s total")

    report_lines.append("")
    report_lines.append(f"Total: {ok_count}/{len(TEST_CARDS)} OK in {total_elapsed:.1f}s")
    (OUTPUT_DIR / "_report.txt").write_text("\n".join(report_lines), encoding="utf-8")

    return 0 if ok_count == len(TEST_CARDS) else 2


if __name__ == "__main__":
    sys.exit(main())
