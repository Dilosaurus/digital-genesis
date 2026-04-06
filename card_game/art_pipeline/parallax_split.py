"""
Parallax Layer Splitter for Battle Arenas
Splits a single background image into depth-based layers for parallax scrolling.

Uses MiDaS depth estimation to separate foreground, midground, and background.
Each layer is saved as a transparent PNG ready for Godot ParallaxBackground.

Requirements: pip install torch torchvision timm Pillow opencv-python

Usage:
    python parallax_split.py <input_image> [output_dir] [--layers 3] [--preview]
    python parallax_split.py arena_michael/output.png arena_michael/layers/
    python parallax_split.py arena_azrael/output.png --layers 4 --preview
"""

import sys
import os
import argparse
from pathlib import Path

import numpy as np

try:
    from PIL import Image, ImageFilter
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

try:
    import torch
    HAS_TORCH = True
except ImportError:
    HAS_TORCH = False

try:
    import cv2
    HAS_CV2 = True
except ImportError:
    HAS_CV2 = False


def check_deps():
    missing = []
    if not HAS_PIL:
        missing.append("Pillow")
    if not HAS_TORCH:
        missing.append("torch torchvision timm")
    if not HAS_CV2:
        missing.append("opencv-python")
    if missing:
        print(f"Missing dependencies: {', '.join(missing)}")
        print(f"Install with: pip install {' '.join(missing)}")
        return False
    return True


def estimate_depth(image_path, model_type="DPT_Large"):
    """Estimate depth map using MiDaS."""
    print(f"  Loading MiDaS ({model_type})...")
    midas = torch.hub.load("intel-isl/MiDaS", model_type, trust_repo=True)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    midas.to(device)
    midas.eval()

    midas_transforms = torch.hub.load("intel-isl/MiDaS", "transforms")
    if model_type in ("DPT_Large", "DPT_Hybrid"):
        transform = midas_transforms.dpt_transform
    else:
        transform = midas_transforms.small_transform

    img = cv2.imread(str(image_path))
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    input_batch = transform(img_rgb).to(device)

    print("  Estimating depth...")
    with torch.no_grad():
        prediction = midas(input_batch)
        prediction = torch.nn.functional.interpolate(
            prediction.unsqueeze(1),
            size=img_rgb.shape[:2],
            mode="bicubic",
            align_corners=False,
        ).squeeze()

    depth = prediction.cpu().numpy()

    # Normalize to 0-1 range (higher = closer to camera)
    depth = (depth - depth.min()) / (depth.max() - depth.min())

    return depth


def split_into_layers(image_path, depth_map, num_layers=3, feather_px=20):
    """Split image into depth-based layers with soft edges."""
    img = Image.open(image_path).convert("RGBA")
    width, height = img.size
    img_array = np.array(img)

    layers = []
    layer_names = {
        3: ["bg_far", "bg_mid", "bg_near"],
        4: ["bg_far", "bg_mid_far", "bg_mid_near", "bg_near"],
        5: ["bg_far", "bg_mid_far", "bg_mid", "bg_mid_near", "bg_near"],
    }
    names = layer_names.get(num_layers, [f"layer_{i}" for i in range(num_layers)])

    # Create depth thresholds — evenly spaced
    thresholds = np.linspace(0, 1, num_layers + 1)

    for i in range(num_layers):
        lo = thresholds[i]
        hi = thresholds[i + 1]

        # Create soft mask using sigmoid-like falloff at edges
        # This prevents hard seams between layers
        mask = np.zeros_like(depth_map, dtype=np.float32)

        # Core region (fully opaque)
        core = (depth_map >= lo) & (depth_map < hi)
        mask[core] = 1.0

        # Feathered edges — gradual falloff at boundaries
        feather_range = 0.05  # 5% depth range for feathering
        # Lower edge feather
        lower_band = (depth_map >= lo - feather_range) & (depth_map < lo)
        if np.any(lower_band):
            mask[lower_band] = (depth_map[lower_band] - (lo - feather_range)) / feather_range
        # Upper edge feather
        upper_band = (depth_map >= hi) & (depth_map < hi + feather_range)
        if np.any(upper_band):
            mask[upper_band] = 1.0 - (depth_map[upper_band] - hi) / feather_range

        mask = np.clip(mask, 0, 1)

        # Apply Gaussian blur to the mask for smoother blending
        mask_img = Image.fromarray((mask * 255).astype(np.uint8), mode="L")
        mask_img = mask_img.filter(ImageFilter.GaussianBlur(radius=feather_px))
        mask = np.array(mask_img).astype(np.float32) / 255.0

        # Apply mask to image
        layer_array = img_array.copy()
        layer_array[:, :, 3] = (mask * 255).astype(np.uint8)

        layer_img = Image.fromarray(layer_array, "RGBA")
        layers.append((names[i], layer_img))

        coverage = np.mean(mask > 0.1) * 100
        print(f"  Layer {i} ({names[i]}): depth {lo:.2f}-{hi:.2f}, coverage {coverage:.1f}%")

    return layers


def save_layers(layers, output_dir):
    """Save layer images as transparent PNGs."""
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    saved = []
    for name, img in layers:
        path = output_dir / f"{name}.png"
        img.save(path, "PNG")
        saved.append(str(path))
        print(f"  Saved: {path}")

    return saved


def save_depth_preview(depth_map, output_path):
    """Save depth map as a grayscale preview image."""
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    depth_vis = (depth_map * 255).astype(np.uint8)
    Image.fromarray(depth_vis, mode="L").save(output_path)
    print(f"  Depth preview: {output_path}")


def generate_godot_scene(layers, arena_name, output_dir, base_resolution=(3440, 1440)):
    """Generate a .tscn file for the parallax background."""
    output_dir = Path(output_dir)
    scene_path = output_dir / f"{arena_name}_parallax.tscn"

    # Parallax motion factors — far layers move less, near layers move more
    num_layers = len(layers)
    motion_factors = np.linspace(0.1, 0.6, num_layers)

    ext_resources = []
    for i, (name, _) in enumerate(layers):
        res_path = f"res://assets/backgrounds/arenas/{arena_name}/layers/{name}.png"
        ext_resources.append(
            f'[ext_resource type="Texture2D" path="{res_path}" id="{name}"]'
        )

    nodes = []
    nodes.append(f'[node name="{arena_name}_bg" type="ParallaxBackground"]')

    for i, (name, _) in enumerate(layers):
        motion = motion_factors[i]
        nodes.append(f'')
        nodes.append(f'[node name="{name}" type="ParallaxLayer" parent="."]')
        nodes.append(f'motion_scale = Vector2({motion:.2f}, {motion:.2f})')
        nodes.append(f'')
        nodes.append(f'[node name="Sprite" type="Sprite2D" parent="{name}"]')
        nodes.append(f'position = Vector2({base_resolution[0] // 2}, {base_resolution[1] // 2})')
        nodes.append(f'texture = ExtResource("{name}")')

    content = "[gd_scene format=3]\n\n"
    content += "\n".join(ext_resources) + "\n\n"
    content += "\n".join(nodes) + "\n"

    with open(scene_path, "w") as f:
        f.write(content)
    print(f"  Godot scene: {scene_path}")
    return str(scene_path)


def main():
    parser = argparse.ArgumentParser(description="Split backgrounds into parallax layers")
    parser.add_argument("input", help="Input image path")
    parser.add_argument("output", nargs="?", help="Output directory (default: input_dir/layers/)")
    parser.add_argument("--layers", type=int, default=3, choices=[3, 4, 5],
                        help="Number of depth layers (default: 3)")
    parser.add_argument("--feather", type=int, default=20,
                        help="Feather radius in pixels for layer blending (default: 20)")
    parser.add_argument("--preview", action="store_true",
                        help="Save depth map preview image")
    parser.add_argument("--scene", action="store_true",
                        help="Generate Godot ParallaxBackground .tscn")
    parser.add_argument("--arena-name", type=str, default=None,
                        help="Arena name for Godot scene generation")

    args = parser.parse_args()

    if not check_deps():
        sys.exit(1)

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Input not found: {input_path}")
        sys.exit(1)

    output_dir = Path(args.output) if args.output else input_path.parent / "layers"

    print(f"Parallax Layer Splitter")
    print(f"  Input: {input_path}")
    print(f"  Output: {output_dir}")
    print(f"  Layers: {args.layers}")
    print()

    # Step 1: Estimate depth
    depth_map = estimate_depth(input_path)

    if args.preview:
        save_depth_preview(depth_map, output_dir / "depth_preview.png")

    # Step 2: Split into layers
    layers = split_into_layers(input_path, depth_map, args.layers, args.feather)

    # Step 3: Save layers
    print()
    saved = save_layers(layers, output_dir)

    # Step 4: Generate Godot scene if requested
    if args.scene:
        arena_name = args.arena_name or input_path.parent.name
        generate_godot_scene(layers, arena_name, output_dir.parent)

    print(f"\nDone! {len(saved)} layers saved to {output_dir}")


if __name__ == "__main__":
    main()
