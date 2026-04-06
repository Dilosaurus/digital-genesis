"""
Post-processing utilities for generated art assets.
Handles background removal, resizing, and segmentation prep.

Requires: pip install rembg Pillow
"""

import sys
import os
from pathlib import Path

try:
    from PIL import Image
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

try:
    from rembg import remove
    HAS_REMBG = True
except ImportError:
    HAS_REMBG = False


def check_deps():
    missing = []
    if not HAS_PIL:
        missing.append("Pillow")
    if not HAS_REMBG:
        missing.append("rembg")
    if missing:
        print(f"Missing dependencies: {', '.join(missing)}")
        print(f"Install with: pip install {' '.join(missing)}")
        return False
    return True


def remove_background(input_path, output_path=None):
    """Remove background from an image, output as transparent PNG."""
    if not check_deps():
        return None

    input_path = Path(input_path)
    if output_path is None:
        output_path = input_path.parent / f"{input_path.stem}_nobg.png"
    else:
        output_path = Path(output_path)

    with open(input_path, "rb") as f:
        input_data = f.read()

    output_data = remove(input_data)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "wb") as f:
        f.write(output_data)

    print(f"  Background removed: {output_path}")
    return str(output_path)


def resize_image(input_path, output_path=None, width=None, height=None, maintain_aspect=True):
    """Resize an image to target dimensions."""
    if not HAS_PIL:
        print("Missing Pillow. Install with: pip install Pillow")
        return None

    input_path = Path(input_path)
    img = Image.open(input_path)

    if width and height and maintain_aspect:
        img.thumbnail((width, height), Image.LANCZOS)
    elif width and height:
        img = img.resize((width, height), Image.LANCZOS)
    elif width:
        ratio = width / img.width
        img = img.resize((width, int(img.height * ratio)), Image.LANCZOS)
    elif height:
        ratio = height / img.height
        img = img.resize((int(img.width * ratio), height), Image.LANCZOS)

    if output_path is None:
        output_path = input_path.parent / f"{input_path.stem}_{img.width}x{img.height}.png"
    else:
        output_path = Path(output_path)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(output_path, "PNG")
    print(f"  Resized to {img.width}x{img.height}: {output_path}")
    return str(output_path)


def process_character(input_path, output_dir, target_height=512):
    """Full character processing: remove BG, resize, save as game-ready PNG."""
    input_path = Path(input_path)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Remove background
    nobg_path = output_dir / f"{input_path.stem}_nobg.png"
    remove_background(input_path, nobg_path)

    # Resize for game
    final_path = output_dir / f"{input_path.stem}_final.png"
    resize_image(nobg_path, final_path, height=target_height)

    return str(final_path)


def process_icon(input_path, output_dir, target_size=64):
    """Process an icon: remove BG, resize to square."""
    input_path = Path(input_path)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    nobg_path = output_dir / f"{input_path.stem}_nobg.png"
    remove_background(input_path, nobg_path)

    final_path = output_dir / f"{input_path.stem}_final.png"
    resize_image(nobg_path, final_path, width=target_size, height=target_size, maintain_aspect=False)

    return str(final_path)


def process_card_art(input_path, output_dir, target_width=256, target_height=256):
    """Process card illustration: remove BG, crop to square, resize."""
    input_path = Path(input_path)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    nobg_path = output_dir / f"{input_path.stem}_nobg.png"
    remove_background(input_path, nobg_path)

    final_path = output_dir / f"{input_path.stem}_final.png"
    resize_image(nobg_path, final_path, width=target_width, height=target_height, maintain_aspect=False)

    return str(final_path)


def process_item_icon(input_path, output_dir, target_size=128):
    """Process an item icon: remove BG, resize to square for game use."""
    input_path = Path(input_path)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    nobg_path = output_dir / f"{input_path.stem}_nobg.png"
    remove_background(input_path, nobg_path)

    final_path = output_dir / f"{input_path.stem}_final.png"
    resize_image(nobg_path, final_path, width=target_size, height=target_size,
                 maintain_aspect=False)

    return str(final_path)


def process_battle_arena(input_path, output_dir, target_width=3440, target_height=1440):
    """Process a battle arena: upscale to ultrawide game resolution with high quality.
    Uses LANCZOS resampling. Input should be 1344x768 from SDXL."""
    if not HAS_PIL:
        print("Missing Pillow. Install with: pip install Pillow")
        return None

    input_path = Path(input_path)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    img = Image.open(input_path)
    print(f"  Input: {img.width}x{img.height}")

    # Upscale to target, stretching to fill (backgrounds don't need aspect preservation)
    img_upscaled = img.resize((target_width, target_height), Image.LANCZOS)

    final_path = output_dir / f"{input_path.stem}_3440x1440.png"
    img_upscaled.save(final_path, "PNG")
    print(f"  Upscaled to {target_width}x{target_height}: {final_path}")

    # Also save a 1920x1080 version for lower-res displays
    img_1080 = img.resize((1920, 1080), Image.LANCZOS)
    fallback_path = output_dir / f"{input_path.stem}_1920x1080.png"
    img_1080.save(fallback_path, "PNG")
    print(f"  Fallback: {fallback_path}")

    return str(final_path)


def assemble_sprite_sheet(
    frame_dir,
    output_path,
    frame_width=None,
    frame_height=None,
    columns=None,
    padding=0,
    remove_bg=False,
    generate_metadata=True,
):
    """Assemble individual frame PNGs into a single sprite sheet.

    Args:
        frame_dir: Directory containing frame PNGs (sorted by name)
        output_path: Path for the output sprite sheet PNG
        frame_width: Force all frames to this width (None = use largest)
        frame_height: Force all frames to this height (None = use largest)
        columns: Number of columns in the grid (None = auto based on count)
        padding: Pixels between frames
        remove_bg: Run rembg on each frame before assembly
        generate_metadata: Also output a .json with frame positions

    Returns:
        Path to the sprite sheet, or None on failure
    """
    if not HAS_PIL:
        print("Missing Pillow. Install with: pip install Pillow")
        return None

    frame_dir = Path(frame_dir)
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Collect frame images
    image_extensions = {".png", ".jpg", ".jpeg", ".webp"}
    frame_files = sorted(
        f for f in frame_dir.iterdir()
        if f.suffix.lower() in image_extensions
    )

    if not frame_files:
        print(f"  No frames found in {frame_dir}")
        return None

    print(f"  Assembling {len(frame_files)} frames from {frame_dir}")

    # Load and optionally process frames
    frames = []
    for fp in frame_files:
        if remove_bg and HAS_REMBG:
            with open(fp, "rb") as f:
                img_data = remove(f.read())
            img = Image.open(__import__("io").BytesIO(img_data)).convert("RGBA")
        else:
            img = Image.open(fp).convert("RGBA")
        frames.append((fp.stem, img))

    # Determine frame dimensions
    if frame_width is None:
        frame_width = max(img.width for _, img in frames)
    if frame_height is None:
        frame_height = max(img.height for _, img in frames)

    # Resize frames to uniform size
    uniform_frames = []
    for name, img in frames:
        if img.width != frame_width or img.height != frame_height:
            img = img.resize((frame_width, frame_height), Image.LANCZOS)
        uniform_frames.append((name, img))

    # Calculate grid layout
    count = len(uniform_frames)
    if columns is None:
        # Auto: try to make roughly square grid
        import math
        columns = min(count, max(1, int(math.ceil(math.sqrt(count)))))

    rows = max(1, -(-count // columns))  # ceiling division

    # Create sheet
    sheet_width = columns * frame_width + (columns - 1) * padding
    sheet_height = rows * frame_height + (rows - 1) * padding
    sheet = Image.new("RGBA", (sheet_width, sheet_height), (0, 0, 0, 0))

    # Place frames
    metadata = {
        "frame_width": frame_width,
        "frame_height": frame_height,
        "columns": columns,
        "rows": rows,
        "frame_count": count,
        "padding": padding,
        "frames": [],
    }

    for i, (name, img) in enumerate(uniform_frames):
        col = i % columns
        row = i // columns
        x = col * (frame_width + padding)
        y = row * (frame_height + padding)
        sheet.paste(img, (x, y))
        metadata["frames"].append({
            "name": name,
            "index": i,
            "x": x,
            "y": y,
            "width": frame_width,
            "height": frame_height,
        })

    sheet.save(output_path, "PNG")
    print(f"  Sprite sheet saved: {output_path} ({sheet_width}x{sheet_height}, {count} frames)")

    # Save metadata
    if generate_metadata:
        import json
        meta_path = output_path.with_suffix(".json")
        with open(meta_path, "w") as f:
            json.dump(metadata, f, indent=2)
        print(f"  Metadata saved: {meta_path}")

    return str(output_path)


def batch_process_directory(input_dir, output_dir, process_type="character"):
    """Process all images in a directory."""
    input_dir = Path(input_dir)
    output_dir = Path(output_dir)

    processors = {
        "character": process_character,
        "icon": process_icon,
        "card": process_card_art,
        "item": process_item_icon,
    }

    processor = processors.get(process_type)
    if not processor:
        print(f"Unknown process type: {process_type}. Use: character, icon, card")
        return

    image_extensions = {".png", ".jpg", ".jpeg", ".webp"}
    images = [f for f in input_dir.iterdir() if f.suffix.lower() in image_extensions]

    print(f"Processing {len(images)} images as {process_type}...")
    for img_path in sorted(images):
        print(f"  Processing: {img_path.name}")
        processor(img_path, output_dir)


def main():
    if len(sys.argv) < 3:
        print("Post-Processing Pipeline")
        print("=" * 40)
        print("\nUsage:")
        print("  python postprocess.py rembg <input_image> [output_image]")
        print("  python postprocess.py resize <input_image> <width> [height]")
        print("  python postprocess.py character <input_image> <output_dir>")
        print("  python postprocess.py icon <input_image> <output_dir>")
        print("  python postprocess.py card <input_image> <output_dir>")
        print("  python postprocess.py item <input_image> <output_dir>")
        print("  python postprocess.py arena <input_image> <output_dir>")
        print("  python postprocess.py batch <input_dir> <output_dir> <type>")
        print("  python postprocess.py sheet <frame_dir> <output.png> [columns] [--rembg]")
        return

    cmd = sys.argv[1]

    if cmd == "rembg":
        output = sys.argv[3] if len(sys.argv) > 3 else None
        remove_background(sys.argv[2], output)

    elif cmd == "resize":
        width = int(sys.argv[3])
        height = int(sys.argv[4]) if len(sys.argv) > 4 else None
        resize_image(sys.argv[2], width=width, height=height)

    elif cmd == "arena":
        process_battle_arena(sys.argv[2], sys.argv[3])

    elif cmd in ("character", "icon", "card", "item"):
        if cmd == "character":
            process_character(sys.argv[2], sys.argv[3])
        elif cmd == "icon":
            process_icon(sys.argv[2], sys.argv[3])
        elif cmd == "card":
            process_card_art(sys.argv[2], sys.argv[3])
        elif cmd == "item":
            process_item_icon(sys.argv[2], sys.argv[3])

    elif cmd == "sheet":
        frame_dir = sys.argv[2]
        output_path = sys.argv[3]
        columns = int(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4] != "--rembg" else None
        do_rembg = "--rembg" in sys.argv
        assemble_sprite_sheet(frame_dir, output_path, columns=columns, remove_bg=do_rembg)

    elif cmd == "batch":
        batch_process_directory(sys.argv[2], sys.argv[3], sys.argv[4])


if __name__ == "__main__":
    main()
