"""
Phase 2 of the deus.exe art pipeline: per-character anchor generation with
optional visual reference image, using Nano Banana 2 (Gemini 3.1 Flash Image).

Each character (playable operator or enemy) gets its own directory under
art_pipeline/characters/<tier>/<id>/ containing:

    prompt.txt       (required) — Nano Banana 2 prompt in house style
    reference.png    (optional) — visual reference image passed to the model
    anchor.png       (output)   — generated character anchor, chroma-key green
    _report.txt      (output)   — per-run log

The reference image is treated as the visual ground truth for silhouette,
pose, palette, and distinctive features. The prompt describes what the
reference depicts in the game's locked art direction. Together, they give
Nano Banana 2 both "what this character looks like" (image) and "how to
render it" (house style prompt).

This is distinct from Phase 1 (`generate_anchors.py`) which generates the
three global locked anchors (character / background / prop) that define the
house style and must stay stable. Phase 2 generates everything downstream.

Run (from art_pipeline/):
    # Requires: pip install google-genai pillow
    # Requires: GEMINI_API_KEY env var set
    python generate_character_anchor.py --char-dir characters/enemies/effigy
    python generate_character_anchor.py --char-dir characters/enemies/effigy --no-reference
    python generate_character_anchor.py --char-dir characters/enemies/effigy --out variant_b.png
"""

from __future__ import annotations

import argparse
import io
import os
import sys
import time
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

# Default aspect/size for character anchors. Matches Phase 1 character_anchor
# so Phase 2 outputs composite with Phase 1 references at the same resolution.
ASPECT_RATIO = "3:4"
IMAGE_SIZE = "2K"

# Name of the expected prompt/reference files inside a character directory.
PROMPT_FILENAME = "prompt.txt"
REFERENCE_FILENAME = "reference.png"


# ── IO ────────────────────────────────────────────────────────────────────


def load_prompt(char_dir: Path) -> str:
    path = char_dir / PROMPT_FILENAME
    if not path.exists():
        raise FileNotFoundError(f"missing prompt file: {path}")
    return path.read_text(encoding="utf-8").strip()


def load_reference(char_dir: Path) -> Image.Image | None:
    """Return the loaded PIL reference image, or None if not present."""
    path = char_dir / REFERENCE_FILENAME
    if not path.exists():
        return None
    return Image.open(path)


# ── Generation ────────────────────────────────────────────────────────────


def generate_anchor(
    client: genai.Client,
    prompt: str,
    reference: Image.Image | None,
) -> tuple[object | None, str, float, str | None]:
    """Call Nano Banana 2. Returns (image, text, elapsed_seconds, error_or_None).

    The returned image is a google.genai image object with .save(); reopen
    the saved file with PIL if you need its dimensions.
    """
    # Order: text instruction first, then any reference images the
    # instruction references. This matches the pattern from try_nanobanana.py
    # and is what the Gemini docs recommend for image-conditioned generation.
    contents: list = [prompt]
    if reference is not None:
        contents.append(reference)

    start = time.time()
    try:
        response = client.models.generate_content(
            model=MODEL_ID,
            contents=contents,
            config=types.GenerateContentConfig(
                response_modalities=["TEXT", "IMAGE"],
                image_config=types.ImageConfig(
                    aspect_ratio=ASPECT_RATIO,
                    image_size=IMAGE_SIZE,
                ),
            ),
        )
    except Exception as exc:
        return None, "", time.time() - start, str(exc)

    elapsed = time.time() - start

    image = None
    text = ""
    for part in response.parts:
        if part.text is not None:
            text += part.text
        elif (img := part.as_image()) is not None:
            image = img

    if image is None:
        return None, text, elapsed, "model returned text only, no image"

    return image, text, elapsed, None


# ── Reporting ─────────────────────────────────────────────────────────────


def write_report(
    char_dir: Path,
    ok: bool,
    elapsed: float,
    reference_status: str,
    out_name: str,
    text: str,
    err: str | None,
    dims: tuple[int, int] | None,
) -> None:
    lines = [
        "Phase 2 character anchor report",
        f"Model:     {MODEL_ID}",
        f"Char dir:  {char_dir}",
        f"Reference: {reference_status}",
        f"Aspect:    {ASPECT_RATIO} ({IMAGE_SIZE})",
        f"Output:    {out_name}",
        f"Elapsed:   {elapsed:.1f}s",
        f"Status:    {'OK' if ok else 'FAILED'}",
    ]
    if dims is not None:
        lines.append(f"Size:      {dims[0]}x{dims[1]}")
    if err:
        lines.append(f"Error:     {err}")
    if text:
        lines.append("")
        lines.append("Model text response:")
        lines.append(text[:2000])
    (char_dir / "_report.txt").write_text("\n".join(lines), encoding="utf-8")


# ── Main ──────────────────────────────────────────────────────────────────


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Phase 2 per-character anchor generator for deus.exe.",
    )
    parser.add_argument(
        "--char-dir",
        required=True,
        help=(
            "Path to the character directory. Absolute, or relative to "
            f"{ART_PIPELINE_DIR}. Must contain {PROMPT_FILENAME}; may "
            f"contain {REFERENCE_FILENAME}."
        ),
    )
    parser.add_argument(
        "--no-reference",
        action="store_true",
        help=f"Ignore {REFERENCE_FILENAME} even if it exists (text-only generation).",
    )
    parser.add_argument(
        "--out",
        default="anchor.png",
        help="Filename for the generated anchor image (default: anchor.png).",
    )
    args = parser.parse_args()

    if not os.environ.get("GEMINI_API_KEY"):
        print("ERROR: GEMINI_API_KEY env var not set.", file=sys.stderr)
        return 1

    # Resolve char_dir — absolute, or relative to art_pipeline/
    char_dir = Path(args.char_dir)
    if not char_dir.is_absolute():
        char_dir = ART_PIPELINE_DIR / char_dir
    char_dir = char_dir.resolve()

    if not char_dir.is_dir():
        print(f"ERROR: character directory not found: {char_dir}", file=sys.stderr)
        return 1

    try:
        prompt = load_prompt(char_dir)
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    reference = None if args.no_reference else load_reference(char_dir)
    reference_status = "(none)" if reference is None else f"loaded {REFERENCE_FILENAME}"

    out_path = char_dir / args.out

    print(f"Model:      {MODEL_ID}")
    print(f"Char dir:   {char_dir}")
    print(f"Prompt:     {PROMPT_FILENAME} ({len(prompt)} chars)")
    print(f"Reference:  {reference_status}")
    print(f"Aspect:     {ASPECT_RATIO}  ({IMAGE_SIZE})")
    print(f"Output:     {out_path.name}")
    print()

    client = genai.Client()

    print("-> Generating anchor ... ", end="", flush=True)
    image, text, elapsed, err = generate_anchor(client, prompt, reference)

    if err is not None or image is None:
        print(f"FAILED ({elapsed:.1f}s): {err}")
        if text:
            print(f"   model text: {text[:500]}")
        write_report(char_dir, False, elapsed, reference_status, args.out, text, err, None)
        return 2

    # Re-encode via PIL to guarantee a real PNG (Nano Banana returns JPEG
    # bytes; writing them with a .png extension produces files Godot can't
    # parse). See save_genai_image_as_png docstring above.
    w, h = save_genai_image_as_png(image, out_path)

    print(f"OK ({elapsed:.1f}s, {w}x{h})  ->  {out_path.name}")
    if text:
        print(f"   model text: {text[:200]}")

    write_report(char_dir, True, elapsed, reference_status, args.out, text, None, (w, h))
    return 0


if __name__ == "__main__":
    sys.exit(main())
