"""
Puppet Part Splitter — Automated character decomposition for cutout animation.

Uses rembg for background removal and SAM (Segment Anything) for intelligent
body part segmentation. Outputs transparent PNG parts ready for Godot puppet rigs.

Usage:
    python split_puppet.py azrael
    python split_puppet.py michael
    python split_puppet.py azrael --preview   # show preview without saving
"""
import argparse
import json
import os
import sys

import cv2
import numpy as np
from PIL import Image
from rembg import remove

# ── Configuration ─────────────────────────────────────────────────────────
ASSETS_BASE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "enemies", "boss"))

# SAM model path
SAM_MODEL_PATH = "E:/ComfyUI/models/sam/sam_vit_h_4b8939.pth"
SAM_MODEL_TYPE = "vit_h"

# Part definitions per character — each part has a name, approximate region
# (as fraction of image: [x_min, y_min, x_max, y_max]), and point prompts
# (as fraction of image: [[x, y], ...]) for SAM segmentation.
# Point prompts tell SAM "this pixel belongs to this part."

BOSS_PARTS = {
    "azrael": {
        "source": "azrael/output.png",
        "parts": [
            {
                "name": "skull_head",
                "points": [[0.50, 0.14]],
                "neg_points": [[0.50, 0.30], [0.35, 0.15], [0.65, 0.15]],
                "crop_region": [0.35, 0.02, 0.65, 0.25],
                "expand": 20,
            },
            {
                "name": "torso",
                "points": [[0.50, 0.32], [0.48, 0.38]],
                "neg_points": [[0.50, 0.14], [0.50, 0.58], [0.25, 0.35], [0.75, 0.35]],
                "crop_region": [0.32, 0.18, 0.68, 0.52],
                "expand": 15,
            },
            {
                "name": "wing_left",
                "points": [[0.28, 0.15], [0.22, 0.22]],
                "neg_points": [[0.50, 0.30], [0.50, 0.14]],
                "crop_region": [0.05, 0.0, 0.45, 0.45],
                "expand": 10,
            },
            {
                "name": "wing_right",
                "points": [[0.72, 0.15], [0.78, 0.22]],
                "neg_points": [[0.50, 0.30], [0.50, 0.14]],
                "crop_region": [0.55, 0.0, 0.95, 0.45],
                "expand": 10,
            },
            {
                "name": "upper_arm_left",
                "points": [[0.38, 0.38]],
                "neg_points": [[0.50, 0.35], [0.25, 0.55]],
                "crop_region": [0.28, 0.28, 0.48, 0.50],
                "expand": 15,
            },
            {
                "name": "upper_arm_right",
                "points": [[0.62, 0.38]],
                "neg_points": [[0.50, 0.35], [0.75, 0.55]],
                "crop_region": [0.52, 0.28, 0.72, 0.50],
                "expand": 15,
            },
            {
                "name": "lower_arm_left",
                "points": [[0.32, 0.52], [0.28, 0.58]],
                "neg_points": [[0.38, 0.38], [0.22, 0.68]],
                "crop_region": [0.18, 0.42, 0.45, 0.65],
                "expand": 15,
            },
            {
                "name": "lower_arm_right",
                "points": [[0.63, 0.50], [0.67, 0.55]],
                "neg_points": [[0.60, 0.38], [0.70, 0.65]],
                "crop_region": [0.52, 0.42, 0.78, 0.62],
                "expand": 15,
            },
            {
                "name": "scythe",
                "points": [[0.22, 0.55], [0.18, 0.70], [0.25, 0.40]],
                "neg_points": [[0.40, 0.50], [0.50, 0.30]],
                "crop_region": [0.02, 0.25, 0.42, 0.90],
                "expand": 10,
            },
            {
                "name": "robe",
                "points": [[0.48, 0.55], [0.52, 0.62]],
                "neg_points": [[0.50, 0.35], [0.50, 0.80]],
                "crop_region": [0.30, 0.48, 0.70, 0.72],
                "expand": 15,
            },
            {
                "name": "legs",
                "points": [[0.48, 0.72], [0.52, 0.78], [0.50, 0.85]],
                "neg_points": [[0.50, 0.55], [0.30, 0.75], [0.70, 0.75]],
                "crop_region": [0.32, 0.65, 0.68, 0.98],
                "expand": 15,
            },
        ]
    },
    "michael": {
        "source": "michael/output.png",
        "parts": [
            {
                "name": "head",
                "points": [[0.50, 0.10], [0.50, 0.13]],
                "neg_points": [[0.50, 0.22], [0.40, 0.10], [0.60, 0.10]],
                "crop_region": [0.38, 0.0, 0.62, 0.20],
                "expand": 20,
            },
            {
                "name": "torso",
                "points": [[0.50, 0.28], [0.50, 0.35], [0.50, 0.42]],
                "neg_points": [[0.50, 0.12], [0.50, 0.58], [0.28, 0.30], [0.72, 0.30]],
                "crop_region": [0.30, 0.15, 0.70, 0.50],
                "expand": 15,
            },
            {
                "name": "shoulder_left",
                "points": [[0.36, 0.20]],
                "neg_points": [[0.50, 0.25], [0.30, 0.30]],
                "crop_region": [0.28, 0.14, 0.45, 0.28],
                "expand": 15,
            },
            {
                "name": "shoulder_right",
                "points": [[0.64, 0.20]],
                "neg_points": [[0.50, 0.25], [0.70, 0.30]],
                "crop_region": [0.55, 0.14, 0.72, 0.28],
                "expand": 15,
            },
            {
                "name": "upper_arm_left",
                "points": [[0.32, 0.33]],
                "neg_points": [[0.40, 0.25], [0.25, 0.45]],
                "crop_region": [0.22, 0.24, 0.42, 0.42],
                "expand": 15,
            },
            {
                "name": "upper_arm_right",
                "points": [[0.68, 0.33]],
                "neg_points": [[0.60, 0.25], [0.75, 0.45]],
                "crop_region": [0.58, 0.24, 0.78, 0.42],
                "expand": 15,
            },
            {
                "name": "lower_arm_left",
                "points": [[0.28, 0.48], [0.25, 0.53]],
                "neg_points": [[0.35, 0.38], [0.20, 0.60]],
                "crop_region": [0.15, 0.38, 0.38, 0.58],
                "expand": 15,
            },
            {
                "name": "lower_arm_right",
                "points": [[0.72, 0.48], [0.75, 0.53]],
                "neg_points": [[0.65, 0.38], [0.80, 0.60]],
                "crop_region": [0.62, 0.38, 0.85, 0.58],
                "expand": 15,
            },
            {
                "name": "sword_left",
                "points": [[0.22, 0.58], [0.20, 0.68]],
                "neg_points": [[0.30, 0.50], [0.35, 0.60]],
                "crop_region": [0.08, 0.45, 0.35, 0.85],
                "expand": 10,
            },
            {
                "name": "sword_right",
                "points": [[0.78, 0.58], [0.80, 0.68]],
                "neg_points": [[0.70, 0.50], [0.65, 0.60]],
                "crop_region": [0.65, 0.45, 0.92, 0.85],
                "expand": 10,
            },
            {
                "name": "wing_left",
                "points": [[0.22, 0.15], [0.15, 0.25]],
                "neg_points": [[0.40, 0.20], [0.50, 0.30]],
                "crop_region": [0.0, 0.0, 0.42, 0.50],
                "expand": 10,
            },
            {
                "name": "wing_right",
                "points": [[0.78, 0.15], [0.85, 0.25]],
                "neg_points": [[0.60, 0.20], [0.50, 0.30]],
                "crop_region": [0.58, 0.0, 1.0, 0.50],
                "expand": 10,
            },
            {
                "name": "leg_skirt",
                "points": [[0.50, 0.60], [0.48, 0.70], [0.52, 0.75]],
                "neg_points": [[0.50, 0.45], [0.25, 0.65], [0.75, 0.65]],
                "crop_region": [0.30, 0.52, 0.70, 0.95],
                "expand": 15,
            },
        ]
    }
}


def remove_background(img_path: str) -> np.ndarray:
    """Remove background using rembg, return RGBA numpy array."""
    print(f"  Removing background from {os.path.basename(img_path)}...")
    with open(img_path, "rb") as f:
        input_bytes = f.read()
    output_bytes = remove(input_bytes)
    img = Image.open(__import__("io").BytesIO(output_bytes)).convert("RGBA")
    return np.array(img)


def load_sam(model_path: str, model_type: str):
    """Load SAM model and create predictor."""
    print(f"  Loading SAM ({model_type})...")
    from segment_anything import sam_model_registry, SamPredictor
    import torch

    sam = sam_model_registry[model_type](checkpoint=model_path)
    device = "cuda" if torch.cuda.is_available() else "cpu"
    sam.to(device=device)
    print(f"  SAM loaded on {device}")
    return SamPredictor(sam)


def extract_part_sam(
    predictor,
    rgba_img: np.ndarray,
    points: list,
    neg_points: list,
    crop_region: list,
    expand: int = 15,
    part_name: str = ""
) -> np.ndarray | None:
    """Extract a body part using SAM point prompts within a crop region."""
    h, w = rgba_img.shape[:2]

    # Convert fractional coords to pixel coords
    point_coords = np.array([[int(p[0] * w), int(p[1] * h)] for p in points])
    point_labels = np.ones(len(points), dtype=int)  # 1 = foreground

    if neg_points:
        neg_coords = np.array([[int(p[0] * w), int(p[1] * h)] for p in neg_points])
        neg_labels = np.zeros(len(neg_points), dtype=int)  # 0 = background
        all_coords = np.vstack([point_coords, neg_coords])
        all_labels = np.concatenate([point_labels, neg_labels])
    else:
        all_coords = point_coords
        all_labels = point_labels

    # Get SAM prediction
    masks, scores, logits = predictor.predict(
        point_coords=all_coords,
        point_labels=all_labels,
        multimask_output=True,
    )

    # Pick best mask
    best_idx = np.argmax(scores)
    mask = masks[best_idx].astype(np.uint8)

    # Intersect with crop region to limit mask extent
    cx1 = int(crop_region[0] * w)
    cy1 = int(crop_region[1] * h)
    cx2 = int(crop_region[2] * w)
    cy2 = int(crop_region[3] * h)

    crop_mask = np.zeros_like(mask)
    crop_mask[cy1:cy2, cx1:cx2] = 1
    mask = mask & crop_mask

    # Also mask out transparent areas from the original (no background)
    alpha_mask = (rgba_img[:, :, 3] > 20).astype(np.uint8)
    mask = mask & alpha_mask

    if mask.sum() < 100:
        print(f"    WARNING: {part_name} mask too small ({mask.sum()} px), skipping")
        return None

    # Find bounding box of mask
    ys, xs = np.where(mask > 0)
    y1, y2 = max(0, ys.min() - expand), min(h, ys.max() + expand)
    x1, x2 = max(0, xs.min() - expand), min(w, xs.max() + expand)

    # Extract RGBA part
    part = rgba_img[y1:y2, x1:x2].copy()
    part_mask = mask[y1:y2, x1:x2]

    # Apply mask to alpha channel (keep original alpha where mask is 1, zero elsewhere)
    part[:, :, 3] = part[:, :, 3] * part_mask

    # Smooth mask edges slightly
    kernel = np.ones((3, 3), np.uint8)
    smooth_alpha = cv2.GaussianBlur(part[:, :, 3].astype(np.float32), (5, 5), 1.0)
    # Only smooth the edges, keep interior solid
    edge = cv2.dilate(part_mask, kernel) - cv2.erode(part_mask, kernel)
    part[:, :, 3] = np.where(edge > 0, smooth_alpha.astype(np.uint8), part[:, :, 3])

    print(f"    {part_name}: {part.shape[1]}x{part.shape[0]} px (score: {scores[best_idx]:.3f})")
    return part


def fallback_crop_extract(
    rgba_img: np.ndarray,
    crop_region: list,
    expand: int = 15,
    part_name: str = ""
) -> np.ndarray | None:
    """Fallback: just crop the region and use existing alpha as mask."""
    h, w = rgba_img.shape[:2]

    cx1 = max(0, int(crop_region[0] * w) - expand)
    cy1 = max(0, int(crop_region[1] * h) - expand)
    cx2 = min(w, int(crop_region[2] * w) + expand)
    cy2 = min(h, int(crop_region[3] * h) + expand)

    part = rgba_img[cy1:cy2, cx1:cx2].copy()

    if part[:, :, 3].sum() < 100:
        print(f"    WARNING: {part_name} fallback crop is mostly transparent, skipping")
        return None

    print(f"    {part_name} (fallback crop): {part.shape[1]}x{part.shape[0]} px")
    return part


def preview_parts(rgba_img: np.ndarray, boss_config: dict):
    """Show a preview with point prompts overlaid."""
    preview = rgba_img[:, :, :3].copy()
    h, w = preview.shape[:2]

    colors = [
        (255, 0, 0), (0, 255, 0), (0, 0, 255), (255, 255, 0),
        (255, 0, 255), (0, 255, 255), (128, 0, 255), (255, 128, 0),
        (0, 128, 255), (128, 255, 0), (255, 0, 128), (0, 255, 128),
        (200, 200, 200),
    ]

    for i, part_def in enumerate(boss_config["parts"]):
        color = colors[i % len(colors)]
        name = part_def["name"]

        # Draw crop region
        cr = part_def["crop_region"]
        x1 = int(cr[0] * w)
        y1 = int(cr[1] * h)
        x2 = int(cr[2] * w)
        y2 = int(cr[3] * h)
        cv2.rectangle(preview, (x1, y1), (x2, y2), color, 2)
        cv2.putText(preview, name, (x1 + 5, y1 + 20), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 1)

        # Draw positive points
        for p in part_def["points"]:
            px, py = int(p[0] * w), int(p[1] * h)
            cv2.circle(preview, (px, py), 6, color, -1)
            cv2.circle(preview, (px, py), 8, (255, 255, 255), 1)

        # Draw negative points
        for p in part_def.get("neg_points", []):
            px, py = int(p[0] * w), int(p[1] * h)
            cv2.drawMarker(preview, (px, py), (0, 0, 200), cv2.MARKER_TILTED_CROSS, 8, 2)

    cv2.imshow(f"Part Regions Preview", preview)
    cv2.waitKey(0)
    cv2.destroyAllWindows()


def split_character(boss_name: str, preview_only: bool = False):
    """Main entry point: split a boss character into puppet parts."""
    if boss_name not in BOSS_PARTS:
        print(f"ERROR: Unknown boss '{boss_name}'. Available: {list(BOSS_PARTS.keys())}")
        sys.exit(1)

    config = BOSS_PARTS[boss_name]
    source_path = os.path.join(ASSETS_BASE, config["source"])

    if not os.path.exists(source_path):
        print(f"ERROR: Source image not found: {source_path}")
        sys.exit(1)

    print(f"\n{'='*60}")
    print(f"  Splitting {boss_name.upper()} into puppet parts")
    print(f"{'='*60}\n")

    # Step 1: Remove background
    rgba = remove_background(source_path)
    print(f"  Image size: {rgba.shape[1]}x{rgba.shape[0]}")

    if preview_only:
        preview_parts(rgba, config)
        return

    # Step 2: Load SAM
    use_sam = os.path.exists(SAM_MODEL_PATH)
    predictor = None
    if use_sam:
        predictor = load_sam(SAM_MODEL_PATH, SAM_MODEL_TYPE)
        # Set image for SAM (needs RGB)
        predictor.set_image(rgba[:, :, :3])
    else:
        print("  WARNING: SAM model not found, using fallback crop method")
        print(f"  Expected at: {SAM_MODEL_PATH}")

    # Step 3: Create output directory
    parts_dir = os.path.join(ASSETS_BASE, boss_name, "parts")
    os.makedirs(parts_dir, exist_ok=True)

    # Step 4: Extract each part
    results = {}
    for part_def in config["parts"]:
        name = part_def["name"]

        if use_sam and predictor:
            part_img = extract_part_sam(
                predictor, rgba,
                points=part_def["points"],
                neg_points=part_def.get("neg_points", []),
                crop_region=part_def["crop_region"],
                expand=part_def.get("expand", 15),
                part_name=name,
            )
        else:
            part_img = None

        # Fallback to simple crop if SAM fails
        if part_img is None:
            part_img = fallback_crop_extract(
                rgba,
                crop_region=part_def["crop_region"],
                expand=part_def.get("expand", 15),
                part_name=name,
            )

        if part_img is not None:
            out_path = os.path.join(parts_dir, f"{name}.png")
            Image.fromarray(part_img).save(out_path)
            results[name] = out_path

    # Step 5: Also save the full no-background version
    nobg_path = os.path.join(ASSETS_BASE, boss_name, f"{boss_name}_nobg.png")
    Image.fromarray(rgba).save(nobg_path)

    print(f"\n  {'='*50}")
    print(f"  Results: {len(results)}/{len(config['parts'])} parts extracted")
    print(f"  Output: {parts_dir}")
    print(f"  No-BG:  {nobg_path}")
    print(f"  {'='*50}\n")

    for name, path in results.items():
        print(f"    OK: {name}.png")

    return results


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Split boss character into puppet parts")
    parser.add_argument("boss", choices=list(BOSS_PARTS.keys()), help="Boss to split")
    parser.add_argument("--preview", action="store_true", help="Show preview without saving")
    args = parser.parse_args()

    split_character(args.boss, preview_only=args.preview)
