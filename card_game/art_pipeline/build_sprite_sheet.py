"""
Convert a Veo 3.1 MP4 clip into a chroma-keyed sprite sheet for Godot.

Usage:
    python build_sprite_sheet.py <callsign> <pose>

Reads:
    animations/raw_video/<callsign>_<pose>.mp4
Writes:
    animations/frames/<callsign>_<pose>/frame_NN.png   (chroma-keyed individual frames)
    animations/sheets/<callsign>_<pose>.png            (horizontal sprite sheet)
    animations/sheets/<callsign>_<pose>.json           (frame_count, fps, loop, frame_w, frame_h)

The chroma-key step uses the same approach as postprocess.py: pixels close to
the dominant green of the source PNG are made transparent, with edge feathering.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).parent
ANIM = ROOT / "animations"
RAW = ANIM / "raw_video"
FRAMES = ANIM / "frames"
SHEETS = ANIM / "sheets"

# Idle is a seamless breath loop. Other poses keep more frames so the
# motion reads cleanly. Tune per pose if needed.
POSE_SETTINGS = {
    # Idle plays at 12 fps over 48 frames = 4-second loop. Source is 8 seconds
    # at 24 fps natively, so this still plays at 2x source speed; if we want
    # native speed we'd bump target_frames to 96 and keep fps at 12.
    "idle":         {"target_frames": 48, "loop": True,  "fps": 12},
    "attack_melee": {"target_frames": 48, "loop": False, "fps": 12},
    # 192 frames @ 24 fps = 8-second cast played at 1:1 source speed.
    # Veo 3.1 source clips are 8 seconds at 24 fps natively, so this
    # keeps every frame with zero resampling — smoother motion at the
    # original ritualistic pacing. ~13MB GIF vs. 3.3MB at 48 @ 12fps.
    "attack_cast":       {"target_frames": 192, "loop": False, "fps": 24},
    # Heavier version of attack_cast — bigger gestures, both hands. Same
    # native 8s pacing as the basic cast.
    "attack_cast_heavy": {"target_frames": 192, "loop": False, "fps": 24},
    # Quick snappy attack — 24 fps for the snappier feel that fits a fast
    # melee-style lunge or quick spell. Half the duration of the cast.
    "attack_quick":      {"target_frames": 48, "loop": False, "fps": 24},
    # Ultimate / finisher attack — mouth open, dramatic peak. Slow ritual
    # pacing like the cast so the player can feel the weight of it.
    "attack_ultimate":   {"target_frames": 48, "loop": False, "fps": 12},
    # Warding / defensive gesture — both hands rise to a ward-off position and
    # hold. Seamless 2-second loop so it reads as a sustained guard when Defend
    # and BLOCK skills resolve.
    "skill_block":       {"target_frames": 24, "loop": True,  "fps": 12},
    # Receiving / offering gesture — cupped hands rise palm-up to chest, hold,
    # lower. One-shot 4-second play for DRAW and ADVANCE utility cards.
    "skill_draw":        {"target_frames": 48, "loop": False, "fps": 12},
    # Claim / transform gesture — arms raised in invocation (cruciform,
    # cross-arm seal, hand-on-heart). One-shot 4-second play for POWER cards
    # and self-buffs.
    "skill_buff":        {"target_frames": 48, "loop": False, "fps": 12},
    # Silence / stealth / setup gesture — finger to lips, head tilt, hand
    # drawn back to chest. One-shot 4-second play for stealth/silence skills
    # (ghost-affine, but any character with a setup-oriented skill can use it).
    "skill_stealth":     {"target_frames": 48, "loop": False, "fps": 12},
    "hurt":         {"target_frames": 24, "loop": False, "fps": 12},
    "block":        {"target_frames": 24, "loop": True,  "fps": 12},
    "defeated":     {"target_frames": 48, "loop": False, "fps": 12},
}

# Every output frame is a FRAME_DIM x FRAME_DIM square. Source clips are 4K
# (3840 tall) which would produce >100MB sheets at full resolution. 720 is
# plenty for in-game card-portrait playback. Square frames mean every animation
# has the same aspect ratio in the UI regardless of how wide the pose is —
# wide attacks (sideways lunges) and narrow idles all crop into the same panel.
#
# The character itself is scaled so its longest edge equals FRAME_INNER, then
# padded into the FRAME_DIM canvas. This leaves a margin around every character
# so wide attack poses don't extend past the panel border in the dashboard,
# and so the character has consistent breathing room across poses.
FRAME_DIM = 720
FRAME_INNER = 600


def read_frames(mp4_path: Path) -> list[np.ndarray]:
    cap = cv2.VideoCapture(str(mp4_path))
    if not cap.isOpened():
        raise RuntimeError(f"could not open {mp4_path}")
    out: list[np.ndarray] = []
    while True:
        ok, frame_bgr = cap.read()
        if not ok:
            break
        # cv2 reads BGR; convert to RGB so PIL is happy
        out.append(cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB))
    cap.release()
    if not out:
        raise RuntimeError(f"no frames decoded from {mp4_path}")
    return out


def downsample(frames: list[np.ndarray], target: int) -> list[np.ndarray]:
    """Pick `target` frames spaced evenly across the clip."""
    if len(frames) <= target:
        return frames
    indices = np.linspace(0, len(frames) - 1, target, dtype=int)
    return [frames[i] for i in indices]


def chroma_key(rgb: np.ndarray) -> Image.Image:
    """
    Knock out the bright-green chroma background.
    Returns a PIL RGBA image.
    """
    arr = rgb.astype(np.int16)
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]

    # A pixel is "green screen" when green dominates and red/blue are low-ish.
    is_green = (g > 100) & (g > r + 25) & (g > b + 25)

    # Soft edge feather: pixels that are *somewhat* greenish get partial alpha.
    greenness = np.clip((g - np.maximum(r, b)) / 80.0, 0.0, 1.0)
    alpha = (1.0 - greenness) * 255.0
    alpha[is_green] = 0
    alpha = alpha.astype(np.uint8)

    # De-spill: where the pixel still has a green tint after keying, push green
    # down toward the average of red and blue so the silhouette doesn't glow.
    spill = (g.astype(np.int16) - ((r + b) // 2)).clip(min=0)
    g_fixed = (g - spill).clip(0, 255).astype(np.uint8)

    rgba = np.dstack(
        [r.astype(np.uint8), g_fixed, b.astype(np.uint8), alpha]
    )
    return Image.fromarray(rgba, mode="RGBA")


def union_bbox(frames: list[Image.Image], padding: int = 16) -> tuple[int, int, int, int]:
    """
    Compute the UNION of every frame's alpha bbox plus a small padding.
    Cropping every frame to the SAME bbox is what kills the lateral-jitter
    bug — if you crop each frame to its own tight bbox, drifting elements
    (like floating particles) shift the bbox and the character appears to
    jump around when the cropped frames are re-centered for packing.
    """
    x0 = y0 = 10**9
    x1 = y1 = -1
    for f in frames:
        bb = f.getbbox()
        if bb is None:
            continue
        x0 = min(x0, bb[0])
        y0 = min(y0, bb[1])
        x1 = max(x1, bb[2])
        y1 = max(y1, bb[3])
    if x1 < 0:
        return (0, 0, frames[0].width, frames[0].height)
    w0, h0 = frames[0].width, frames[0].height
    return (
        max(0, x0 - padding),
        max(0, y0 - padding),
        min(w0, x1 + padding),
        min(h0, y1 + padding),
    )


def downscale_to_max_dim(img: Image.Image, max_dim: int) -> Image.Image:
    """Scale so max(width, height) == max_dim, preserving aspect ratio."""
    longest = max(img.width, img.height)
    if longest <= max_dim:
        return img
    scale = max_dim / longest
    new_w = round(img.width * scale)
    new_h = round(img.height * scale)
    return img.resize((new_w, new_h), Image.LANCZOS)


def pad_to_square(img: Image.Image, dim: int) -> Image.Image:
    """
    Pad an image into a transparent dim x dim square. The character is
    horizontally centered and bottom-aligned (feet sit on the bottom edge),
    so wide attacks and narrow idles all share the same canvas footprint.
    """
    canvas = Image.new("RGBA", (dim, dim), (0, 0, 0, 0))
    x = (dim - img.width) // 2
    y = dim - img.height
    canvas.paste(img, (x, y), img)
    return canvas


def pack_horizontal(frames: list[Image.Image]) -> tuple[Image.Image, int, int]:
    """
    Pack frames left-to-right. All frames must already be the same size
    (we crop them to the union bbox upstream so they are).
    """
    cell_w = frames[0].width
    cell_h = frames[0].height
    sheet = Image.new("RGBA", (cell_w * len(frames), cell_h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * cell_w, 0), f)
    return sheet, cell_w, cell_h


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 1

    callsign = sys.argv[1].lower()
    pose = sys.argv[2].lower()

    if pose not in POSE_SETTINGS:
        print(f"unknown pose '{pose}', expected one of: {', '.join(POSE_SETTINGS)}")
        return 1

    cfg = POSE_SETTINGS[pose]
    mp4 = RAW / f"{callsign}_{pose}.mp4"
    if not mp4.exists():
        print(f"missing source clip: {mp4}")
        print("Drop the Veo 3.1 download in animations/raw_video/ first.")
        return 1

    print(f"reading {mp4}")
    raw = read_frames(mp4)
    print(f"  decoded {len(raw)} raw frames")

    picked = downsample(raw, cfg["target_frames"])
    print(f"  keeping {len(picked)} frames (target {cfg['target_frames']})")

    frames_dir = FRAMES / f"{callsign}_{pose}"
    frames_dir.mkdir(parents=True, exist_ok=True)

    # Step 1: chroma-key every frame at full source resolution.
    keyed_full: list[Image.Image] = [chroma_key(rgb) for rgb in picked]

    # Step 2: compute the UNION bbox across all frames and crop every frame
    # to that single bbox. This is what eliminates the lateral-jump bug.
    bbox = union_bbox(keyed_full)
    print(f"  union bbox: {bbox} ({bbox[2]-bbox[0]}x{bbox[3]-bbox[1]})")
    cropped = [f.crop(bbox) for f in keyed_full]

    # Step 3: downscale so the longest edge is FRAME_INNER, then pad each
    # frame into a FRAME_DIM x FRAME_DIM square. The (FRAME_DIM - FRAME_INNER)
    # margin guarantees every character has breathing room inside the panel
    # even when the pose is wider than it is tall.
    scaled = [downscale_to_max_dim(f, FRAME_INNER) for f in cropped]
    keyed = [pad_to_square(f, FRAME_DIM) for f in scaled]
    print(f"  scaled+padded to {keyed[0].width}x{keyed[0].height}"
          f" (inner {scaled[0].width}x{scaled[0].height})")

    for i, img in enumerate(keyed):
        out = frames_dir / f"frame_{i:02d}.png"
        img.save(out)
    print(f"  wrote {len(keyed)} keyed frames to {frames_dir}")

    sheet, cell_w, cell_h = pack_horizontal(keyed)
    SHEETS.mkdir(parents=True, exist_ok=True)
    sheet_png = SHEETS / f"{callsign}_{pose}.png"
    sheet.save(sheet_png)
    print(f"  wrote sprite sheet {sheet_png}  ({sheet.width}x{sheet.height})")

    # Build a preview animated GIF as well — composited onto a dark slate
    # background so the user can see the loop without needing the sprite-sheet
    # CSS scaffold.
    bg = (32, 36, 44)
    gif_frames: list[Image.Image] = []
    gif_w, gif_h = cell_w, cell_h
    if gif_h > 600:
        scale = 600 / gif_h
        gif_w = round(cell_w * scale)
        gif_h = 600
    for f in keyed:
        canvas = Image.new("RGB", (cell_w, cell_h), bg)
        canvas.paste(f, (0, 0), f)
        if (gif_w, gif_h) != (cell_w, cell_h):
            canvas = canvas.resize((gif_w, gif_h), Image.LANCZOS)
        gif_frames.append(canvas)
    duration_ms = max(1, round(1000 / cfg["fps"]))
    gif_path = SHEETS / f"{callsign}_{pose}_loop.gif"
    # Preview GIF always loops forever — the in-game loop behavior is encoded
    # in the JSON metadata, not the GIF. A play-once GIF would freeze on the
    # last frame in the browser, making evaluation harder.
    gif_frames[0].save(
        gif_path,
        save_all=True,
        append_images=gif_frames[1:],
        duration=duration_ms,
        loop=0,
        optimize=True,
        disposal=2,
    )
    print(f"  wrote loop GIF {gif_path}  ({gif_w}x{gif_h}, {duration_ms}ms/frame)")

    meta = {
        "callsign": callsign,
        "pose": pose,
        "frame_count": len(keyed),
        "fps": cfg["fps"],
        "loop": cfg["loop"],
        "frame_w": cell_w,
        "frame_h": cell_h,
        "sheet_w": sheet.width,
        "sheet_h": sheet.height,
    }
    sheet_json = SHEETS / f"{callsign}_{pose}.json"
    sheet_json.write_text(json.dumps(meta, indent=2))
    print(f"  wrote sheet metadata {sheet_json}")
    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
