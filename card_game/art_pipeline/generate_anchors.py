"""
Phase 1 of the deus.exe art pipeline: generate the three locked art-direction anchors.

These images become the reference inputs for every downstream generation
(characters, backdrops, props, cards, enemies, relics, icons, effects). If the
anchors are wrong, everything downstream is wrong. Iterate the prompts in
anchors/prompts/*.txt until the outputs match ART_DIRECTION.md.

Inputs:
    anchors/prompts/character_anchor.txt
    anchors/prompts/background_anchor.txt
    anchors/prompts/prop_anchor.txt

Outputs:
    anchors/character_anchor.png   (painted horror figure on green, 3:4)
    anchors/background_anchor.png  (empty cathedral backdrop, 21:9)
    anchors/prop_anchor.png        (broken altar hero prop on green, 1:1)
    anchors/_report.txt

Run:
    # Requires: pip install google-genai pillow
    # Requires: GEMINI_API_KEY env var set
    python generate_anchors.py                          # regenerate all anchors
    python generate_anchors.py --only character_anchor  # regenerate one anchor
"""

import argparse
import io
import os
import sys
import time
from dataclasses import dataclass
from pathlib import Path

from google import genai
from google.genai import types
from PIL import Image


def save_genai_image_as_png(genai_image, out_path: Path) -> tuple[int, int]:
    """Save a google.genai image as a PROPER PNG.

    Nano Banana 2 (gemini-3.1-flash-image-preview) returns JPEG bytes. Calling
    ``genai_image.save(path)`` just writes those raw bytes with whatever
    extension the path has, producing JPEG-with-a-.png-extension files that
    Godot's PNG decoder can't parse (err=43 ERR_FILE_CORRUPT). Re-encoding
    via PIL guarantees a real PNG.

    Returns (width, height) of the saved image.
    """
    # Try to get raw bytes directly from the genai object. Fall back to a
    # temp file if the SDK version doesn't expose image_bytes.
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

# ── Config ────────────────────────────────────────────────────────────────

MODEL_ID = "gemini-3.1-flash-image-preview"

ART_PIPELINE_DIR = Path(__file__).parent
ANCHORS_DIR = ART_PIPELINE_DIR / "anchors"
PROMPTS_DIR = ANCHORS_DIR / "prompts"


@dataclass
class AnchorSpec:
    name: str                # filename stem, e.g. "character_anchor"
    prompt_file: str         # filename in prompts dir
    aspect_ratio: str        # Nano Banana 2 aspect string
    image_size: str          # "1K" or "2K"
    description: str         # human-readable label for logs


ANCHORS = [
    AnchorSpec(
        name="character_anchor",
        prompt_file="character_anchor.txt",
        aspect_ratio="3:4",        # portrait — one standing figure
        image_size="2K",
        description="GHOST painted horror figure on green screen",
    ),
    AnchorSpec(
        name="background_anchor",
        prompt_file="background_anchor.txt",
        aspect_ratio="21:9",       # ultrawide — empty cathedral backdrop
        image_size="2K",
        description="Empty desecrated cathedral backdrop (no set dressing)",
    ),
    AnchorSpec(
        name="prop_anchor",
        prompt_file="prop_anchor.txt",
        aspect_ratio="1:1",        # square — single hero prop on green screen
        image_size="2K",
        description="Broken altar hero prop on green screen",
    ),
]


# ── Main ──────────────────────────────────────────────────────────────────


def load_prompt(spec: AnchorSpec) -> str:
    path = PROMPTS_DIR / spec.prompt_file
    return path.read_text(encoding="utf-8").strip()


def generate_anchor(client: genai.Client, spec: AnchorSpec):
    """Generate one anchor. Returns (ok, elapsed_seconds, text_response, error_or_None)."""
    prompt = load_prompt(spec)
    start = time.time()
    try:
        response = client.models.generate_content(
            model=MODEL_ID,
            contents=[prompt],
            config=types.GenerateContentConfig(
                response_modalities=["TEXT", "IMAGE"],
                image_config=types.ImageConfig(
                    aspect_ratio=spec.aspect_ratio,
                    image_size=spec.image_size,
                ),
            ),
        )
    except Exception as exc:
        return False, time.time() - start, "", str(exc)

    elapsed = time.time() - start

    image = None
    text = ""
    for part in response.parts:
        if part.text is not None:
            text += part.text
        elif (img := part.as_image()) is not None:
            image = img

    if image is None:
        return False, elapsed, text, "model returned text only, no image"

    out_path = ANCHORS_DIR / f"{spec.name}.png"
    # Re-encode via PIL to guarantee a real PNG (Nano Banana returns JPEG
    # bytes; writing them with a .png extension produces files Godot can't
    # parse). See save_genai_image_as_png docstring above.
    save_genai_image_as_png(image, out_path)
    return True, elapsed, text, None


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Phase 1 anchor generator for the deus.exe art pipeline.",
    )
    parser.add_argument(
        "--only",
        choices=[s.name for s in ANCHORS],
        help="Regenerate only this one anchor (default: all)",
    )
    args = parser.parse_args()

    if not os.environ.get("GEMINI_API_KEY"):
        print("ERROR: GEMINI_API_KEY env var not set.", file=sys.stderr)
        return 1

    targets = [s for s in ANCHORS if args.only is None or s.name == args.only]

    # Verify prompt files exist before burning credits
    for spec in targets:
        path = PROMPTS_DIR / spec.prompt_file
        if not path.exists():
            print(f"ERROR: prompt file missing: {path}", file=sys.stderr)
            return 1

    ANCHORS_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Model:   {MODEL_ID}")
    print(f"Output:  {ANCHORS_DIR}")
    print(f"Targets: {len(targets)} of {len(ANCHORS)}")
    print()

    client = genai.Client()

    report_lines = [
        "Phase 1 anchor generation report",
        f"Model: {MODEL_ID}",
        "",
    ]

    total_start = time.time()
    all_ok = True
    for spec in targets:
        print(f"-> {spec.name:20s}  ({spec.description})")
        print(f"   aspect={spec.aspect_ratio}  size={spec.image_size}  ... ", end="", flush=True)
        ok, elapsed, text, err = generate_anchor(client, spec)
        if not ok:
            all_ok = False
            print(f"FAILED ({elapsed:.1f}s): {err}")
            report_lines.append(f"{spec.name}: FAILED — {err}")
            if text:
                report_lines.append(f"  model text: {text[:300]}")
            continue

        out_path = ANCHORS_DIR / f"{spec.name}.png"
        with Image.open(out_path) as saved:
            w, h = saved.size
        print(f"OK ({elapsed:.1f}s, {w}x{h})")
        report_lines.append(
            f"{spec.name}: OK  {elapsed:.1f}s  {w}x{h}  aspect={spec.aspect_ratio}  size={spec.image_size}"
        )
        if text:
            report_lines.append(f"  model text: {text[:300]}")

    total_elapsed = time.time() - total_start
    print()
    print(f"Done in {total_elapsed:.1f}s total")

    report_lines.append("")
    report_lines.append(f"Total: {total_elapsed:.1f}s")
    (ANCHORS_DIR / "_report.txt").write_text("\n".join(report_lines), encoding="utf-8")

    return 0 if all_ok else 2


if __name__ == "__main__":
    sys.exit(main())
