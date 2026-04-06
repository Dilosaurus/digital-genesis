"""
Download and generate OpenPose skeleton reference images for animation frames.

This script creates skeleton reference images programmatically using PIL,
drawing OpenPose-style stick figures for common game character poses.

Usage:
    python download_pose_skeletons.py           # Generate all skeletons
    python download_pose_skeletons.py --preview  # Show preview of each pose
"""

import argparse
import math
from pathlib import Path

try:
    from PIL import Image, ImageDraw
    HAS_PIL = True
except ImportError:
    HAS_PIL = False
    print("Requires Pillow: pip install Pillow")


# OpenPose 18-keypoint body model
# Indices: 0=nose, 1=neck, 2=r_shoulder, 3=r_elbow, 4=r_wrist,
#          5=l_shoulder, 6=l_elbow, 7=l_wrist, 8=r_hip, 9=r_knee,
#          10=r_ankle, 11=l_hip, 12=l_knee, 13=l_ankle, 14=r_eye,
#          15=l_eye, 16=r_ear, 17=l_ear

SKELETON_CONNECTIONS = [
    (0, 1),   # nose -> neck
    (1, 2),   # neck -> r_shoulder
    (1, 5),   # neck -> l_shoulder
    (2, 3),   # r_shoulder -> r_elbow
    (3, 4),   # r_elbow -> r_wrist
    (5, 6),   # l_shoulder -> l_elbow
    (6, 7),   # l_elbow -> l_wrist
    (1, 8),   # neck -> r_hip (via mid-spine approximation)
    (1, 11),  # neck -> l_hip
    (8, 9),   # r_hip -> r_knee
    (9, 10),  # r_knee -> r_ankle
    (11, 12), # l_hip -> l_knee
    (12, 13), # l_knee -> l_ankle
    (0, 14),  # nose -> r_eye
    (0, 15),  # nose -> l_eye
    (14, 16), # r_eye -> r_ear
    (15, 17), # l_eye -> l_ear
]

LIMB_COLORS = [
    (255, 0, 0),     # nose-neck: red
    (255, 85, 0),    # neck-r_shoulder
    (255, 170, 0),   # neck-l_shoulder
    (255, 255, 0),   # r_shoulder-r_elbow
    (170, 255, 0),   # r_elbow-r_wrist
    (85, 255, 0),    # l_shoulder-l_elbow
    (0, 255, 0),     # l_elbow-l_wrist
    (0, 255, 85),    # neck-r_hip
    (0, 255, 170),   # neck-l_hip
    (0, 255, 255),   # r_hip-r_knee
    (0, 170, 255),   # r_knee-r_ankle
    (0, 85, 255),    # l_hip-l_knee
    (0, 0, 255),     # l_knee-l_ankle
    (85, 0, 255),    # nose-r_eye
    (170, 0, 255),   # nose-l_eye
    (255, 0, 255),   # r_eye-r_ear
    (255, 0, 170),   # l_eye-l_ear
]


def draw_skeleton(keypoints, width=512, height=768, line_width=6, point_radius=4):
    """Draw an OpenPose skeleton from normalized keypoints (0-1 range).

    Args:
        keypoints: List of 18 (x, y) tuples in 0-1 normalized coords.
                   Use None for invisible keypoints.
    """
    img = Image.new("RGB", (width, height), (0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Convert normalized coords to pixel coords
    pts = []
    for kp in keypoints:
        if kp is None:
            pts.append(None)
        else:
            pts.append((int(kp[0] * width), int(kp[1] * height)))

    # Draw limbs
    for i, (a, b) in enumerate(SKELETON_CONNECTIONS):
        if a < len(pts) and b < len(pts) and pts[a] is not None and pts[b] is not None:
            color = LIMB_COLORS[i % len(LIMB_COLORS)]
            draw.line([pts[a], pts[b]], fill=color, width=line_width)

    # Draw keypoints
    for pt in pts:
        if pt is not None:
            x, y = pt
            draw.ellipse(
                [x - point_radius, y - point_radius, x + point_radius, y + point_radius],
                fill=(255, 255, 255),
            )

    return img


# ── Pose Definitions ──────────────────────────────────────────────────────
# Each pose is 18 keypoints as (x, y) normalized 0-1
# x: 0=left, 1=right
# y: 0=top, 1=bottom

POSES = {
    # Idle poses (subtle breathing cycle)
    "idle/idle_01": [
        (0.50, 0.12),  # nose
        (0.50, 0.20),  # neck
        (0.40, 0.22),  # r_shoulder
        (0.35, 0.35),  # r_elbow
        (0.33, 0.45),  # r_wrist
        (0.60, 0.22),  # l_shoulder
        (0.65, 0.35),  # l_elbow
        (0.67, 0.45),  # l_wrist
        (0.43, 0.45),  # r_hip
        (0.42, 0.62),  # r_knee
        (0.41, 0.80),  # r_ankle
        (0.57, 0.45),  # l_hip
        (0.58, 0.62),  # l_knee
        (0.59, 0.80),  # l_ankle
        (0.47, 0.10),  # r_eye
        (0.53, 0.10),  # l_eye
        (0.44, 0.11),  # r_ear
        (0.56, 0.11),  # l_ear
    ],
    "idle/idle_02": [
        (0.50, 0.11),  # nose (slightly raised - inhale)
        (0.50, 0.19),  # neck
        (0.40, 0.21),  # r_shoulder (slightly raised)
        (0.35, 0.34),  # r_elbow
        (0.33, 0.44),  # r_wrist
        (0.60, 0.21),  # l_shoulder
        (0.65, 0.34),  # l_elbow
        (0.67, 0.44),  # l_wrist
        (0.43, 0.45),  # r_hip
        (0.42, 0.62),  # r_knee
        (0.41, 0.80),  # r_ankle
        (0.57, 0.45),  # l_hip
        (0.58, 0.62),  # l_knee
        (0.59, 0.80),  # l_ankle
        (0.47, 0.09),  # r_eye
        (0.53, 0.09),  # l_eye
        (0.44, 0.10),  # r_ear
        (0.56, 0.10),  # l_ear
    ],
    "idle/idle_03": [
        (0.50, 0.12),  # nose
        (0.50, 0.20),  # neck
        (0.40, 0.22),  # r_shoulder
        (0.36, 0.35),  # r_elbow
        (0.34, 0.46),  # r_wrist
        (0.60, 0.22),  # l_shoulder
        (0.64, 0.35),  # l_elbow
        (0.66, 0.46),  # l_wrist
        (0.43, 0.45),  # r_hip
        (0.43, 0.63),  # r_knee
        (0.42, 0.80),  # r_ankle
        (0.57, 0.45),  # l_hip
        (0.57, 0.63),  # l_knee
        (0.58, 0.80),  # l_ankle
        (0.47, 0.10),  # r_eye
        (0.53, 0.10),  # l_eye
        (0.44, 0.11),  # r_ear
        (0.56, 0.11),  # l_ear
    ],
    "idle/idle_04": [
        (0.50, 0.12),  # nose (settling back)
        (0.50, 0.20),  # neck
        (0.40, 0.23),  # r_shoulder (slightly lowered)
        (0.35, 0.36),  # r_elbow
        (0.33, 0.46),  # r_wrist
        (0.60, 0.23),  # l_shoulder
        (0.65, 0.36),  # l_elbow
        (0.67, 0.46),  # l_wrist
        (0.43, 0.45),  # r_hip
        (0.42, 0.62),  # r_knee
        (0.41, 0.80),  # r_ankle
        (0.57, 0.45),  # l_hip
        (0.58, 0.62),  # l_knee
        (0.59, 0.80),  # l_ankle
        (0.47, 0.10),  # r_eye
        (0.53, 0.10),  # l_eye
        (0.44, 0.11),  # r_ear
        (0.56, 0.11),  # l_ear
    ],

    # Melee attack sequence
    "attack/melee_windup_01": [
        (0.45, 0.13),  # nose (turning)
        (0.47, 0.21),  # neck
        (0.37, 0.23),  # r_shoulder
        (0.25, 0.30),  # r_elbow (pulling back)
        (0.18, 0.22),  # r_wrist (weapon back)
        (0.57, 0.23),  # l_shoulder
        (0.60, 0.33),  # l_elbow
        (0.55, 0.40),  # l_wrist
        (0.42, 0.46),  # r_hip
        (0.40, 0.63),  # r_knee
        (0.38, 0.80),  # r_ankle
        (0.55, 0.46),  # l_hip
        (0.58, 0.60),  # l_knee (stepping forward)
        (0.60, 0.78),  # l_ankle
        (0.43, 0.11),  # r_eye
        (0.48, 0.11),  # l_eye
        (0.40, 0.12),  # r_ear
        (0.50, 0.12),  # l_ear
    ],
    "attack/melee_windup_02": [
        (0.42, 0.14),  # nose
        (0.45, 0.22),  # neck
        (0.35, 0.24),  # r_shoulder
        (0.20, 0.25),  # r_elbow (fully back)
        (0.12, 0.18),  # r_wrist (weapon raised high behind)
        (0.55, 0.24),  # l_shoulder
        (0.58, 0.34),  # l_elbow
        (0.52, 0.40),  # l_wrist
        (0.42, 0.47),  # r_hip
        (0.38, 0.63),  # r_knee
        (0.36, 0.80),  # r_ankle
        (0.55, 0.47),  # l_hip
        (0.60, 0.58),  # l_knee
        (0.63, 0.76),  # l_ankle
        (0.40, 0.12),  # r_eye
        (0.45, 0.12),  # l_eye
        (0.37, 0.13),  # r_ear
        (0.47, 0.13),  # l_ear
    ],
    "attack/melee_swing_01": [
        (0.52, 0.13),  # nose (turning forward)
        (0.50, 0.21),  # neck
        (0.40, 0.23),  # r_shoulder
        (0.50, 0.28),  # r_elbow (swinging forward)
        (0.62, 0.22),  # r_wrist (mid-swing)
        (0.58, 0.23),  # l_shoulder
        (0.62, 0.32),  # l_elbow
        (0.58, 0.38),  # l_wrist
        (0.43, 0.46),  # r_hip
        (0.42, 0.63),  # r_knee
        (0.40, 0.80),  # r_ankle
        (0.55, 0.46),  # l_hip
        (0.60, 0.60),  # l_knee
        (0.62, 0.78),  # l_ankle
        (0.50, 0.11),  # r_eye
        (0.55, 0.11),  # l_eye
        (0.47, 0.12),  # r_ear
        (0.57, 0.12),  # l_ear
    ],
    "attack/melee_swing_02": [
        (0.55, 0.13),  # nose
        (0.52, 0.21),  # neck
        (0.42, 0.22),  # r_shoulder
        (0.60, 0.25),  # r_elbow (extended)
        (0.78, 0.20),  # r_wrist (weapon extended forward)
        (0.60, 0.22),  # l_shoulder
        (0.65, 0.30),  # l_elbow
        (0.63, 0.38),  # l_wrist
        (0.44, 0.46),  # r_hip
        (0.44, 0.63),  # r_knee
        (0.42, 0.80),  # r_ankle
        (0.56, 0.46),  # l_hip
        (0.62, 0.60),  # l_knee
        (0.65, 0.78),  # l_ankle
        (0.53, 0.11),  # r_eye
        (0.58, 0.11),  # l_eye
        (0.50, 0.12),  # r_ear
        (0.60, 0.12),  # l_ear
    ],
    "attack/melee_follow_01": [
        (0.55, 0.14),  # nose
        (0.53, 0.22),  # neck
        (0.43, 0.23),  # r_shoulder
        (0.65, 0.28),  # r_elbow (past center)
        (0.82, 0.30),  # r_wrist (follow through)
        (0.62, 0.23),  # l_shoulder
        (0.68, 0.32),  # l_elbow
        (0.65, 0.40),  # l_wrist
        (0.45, 0.46),  # r_hip
        (0.45, 0.63),  # r_knee
        (0.43, 0.80),  # r_ankle
        (0.57, 0.46),  # l_hip
        (0.60, 0.62),  # l_knee
        (0.62, 0.80),  # l_ankle
        (0.53, 0.12),  # r_eye
        (0.58, 0.12),  # l_eye
        (0.50, 0.13),  # r_ear
        (0.60, 0.13),  # l_ear
    ],
    "attack/melee_recover": [
        (0.50, 0.13),  # nose (returning to center)
        (0.50, 0.21),  # neck
        (0.40, 0.23),  # r_shoulder
        (0.45, 0.33),  # r_elbow (returning)
        (0.50, 0.40),  # r_wrist
        (0.60, 0.23),  # l_shoulder
        (0.63, 0.33),  # l_elbow
        (0.60, 0.42),  # l_wrist
        (0.43, 0.46),  # r_hip
        (0.42, 0.63),  # r_knee
        (0.41, 0.80),  # r_ankle
        (0.57, 0.46),  # l_hip
        (0.58, 0.62),  # l_knee
        (0.59, 0.80),  # l_ankle
        (0.48, 0.11),  # r_eye
        (0.53, 0.11),  # l_eye
        (0.45, 0.12),  # r_ear
        (0.55, 0.12),  # l_ear
    ],

    # Ranged/cast attack sequence
    "attack/cast_charge_01": [
        (0.50, 0.12),  # nose
        (0.50, 0.20),  # neck
        (0.40, 0.22),  # r_shoulder
        (0.35, 0.30),  # r_elbow
        (0.40, 0.35),  # r_wrist (hands gathering)
        (0.60, 0.22),  # l_shoulder
        (0.65, 0.30),  # l_elbow
        (0.60, 0.35),  # l_wrist (hands gathering)
        (0.43, 0.45),  # r_hip
        (0.42, 0.62),  # r_knee
        (0.41, 0.80),  # r_ankle
        (0.57, 0.45),  # l_hip
        (0.58, 0.62),  # l_knee
        (0.59, 0.80),  # l_ankle
        (0.47, 0.10),  # r_eye
        (0.53, 0.10),  # l_eye
        (0.44, 0.11),  # r_ear
        (0.56, 0.11),  # l_ear
    ],
    "attack/cast_charge_02": [
        (0.50, 0.11),  # nose (head tilted up)
        (0.50, 0.19),  # neck
        (0.40, 0.21),  # r_shoulder (raised)
        (0.38, 0.28),  # r_elbow
        (0.45, 0.30),  # r_wrist (energy between hands)
        (0.60, 0.21),  # l_shoulder
        (0.62, 0.28),  # l_elbow
        (0.55, 0.30),  # l_wrist
        (0.43, 0.45),  # r_hip
        (0.42, 0.62),  # r_knee
        (0.41, 0.80),  # r_ankle
        (0.57, 0.45),  # l_hip
        (0.58, 0.62),  # l_knee
        (0.59, 0.80),  # l_ankle
        (0.47, 0.09),  # r_eye
        (0.53, 0.09),  # l_eye
        (0.44, 0.10),  # r_ear
        (0.56, 0.10),  # l_ear
    ],
    "attack/cast_release": [
        (0.52, 0.12),  # nose
        (0.50, 0.20),  # neck
        (0.40, 0.22),  # r_shoulder
        (0.42, 0.30),  # r_elbow (thrust forward)
        (0.55, 0.28),  # r_wrist (hands forward)
        (0.60, 0.22),  # l_shoulder
        (0.58, 0.30),  # l_elbow
        (0.65, 0.28),  # l_wrist (hands forward)
        (0.43, 0.46),  # r_hip
        (0.42, 0.63),  # r_knee (slight lean forward)
        (0.40, 0.80),  # r_ankle
        (0.57, 0.46),  # l_hip
        (0.59, 0.62),  # l_knee
        (0.60, 0.80),  # l_ankle
        (0.50, 0.10),  # r_eye
        (0.55, 0.10),  # l_eye
        (0.47, 0.11),  # r_ear
        (0.57, 0.11),  # l_ear
    ],
    "attack/cast_follow": [
        (0.52, 0.13),  # nose
        (0.50, 0.21),  # neck
        (0.40, 0.23),  # r_shoulder
        (0.48, 0.30),  # r_elbow
        (0.60, 0.30),  # r_wrist (extended)
        (0.60, 0.23),  # l_shoulder
        (0.62, 0.30),  # l_elbow
        (0.70, 0.30),  # l_wrist (extended)
        (0.43, 0.46),  # r_hip
        (0.42, 0.63),  # r_knee
        (0.41, 0.80),  # r_ankle
        (0.57, 0.46),  # l_hip
        (0.58, 0.63),  # l_knee
        (0.59, 0.80),  # l_ankle
        (0.50, 0.11),  # r_eye
        (0.55, 0.11),  # l_eye
        (0.47, 0.12),  # r_ear
        (0.57, 0.12),  # l_ear
    ],
    "attack/cast_recover": [
        (0.50, 0.12),  # nose
        (0.50, 0.20),  # neck
        (0.40, 0.22),  # r_shoulder
        (0.37, 0.33),  # r_elbow (lowering)
        (0.38, 0.42),  # r_wrist
        (0.60, 0.22),  # l_shoulder
        (0.63, 0.33),  # l_elbow
        (0.62, 0.42),  # l_wrist
        (0.43, 0.45),  # r_hip
        (0.42, 0.62),  # r_knee
        (0.41, 0.80),  # r_ankle
        (0.57, 0.45),  # l_hip
        (0.58, 0.62),  # l_knee
        (0.59, 0.80),  # l_ankle
        (0.47, 0.10),  # r_eye
        (0.53, 0.10),  # l_eye
        (0.44, 0.11),  # r_ear
        (0.56, 0.11),  # l_ear
    ],

    # Hit reaction
    "hit/hit_impact": [
        (0.55, 0.14),  # nose (jolting back)
        (0.52, 0.22),  # neck
        (0.42, 0.25),  # r_shoulder (flinching)
        (0.38, 0.35),  # r_elbow
        (0.40, 0.42),  # r_wrist
        (0.62, 0.25),  # l_shoulder
        (0.68, 0.33),  # l_elbow
        (0.65, 0.40),  # l_wrist
        (0.44, 0.47),  # r_hip
        (0.45, 0.63),  # r_knee (buckling)
        (0.43, 0.80),  # r_ankle
        (0.58, 0.47),  # l_hip
        (0.60, 0.62),  # l_knee
        (0.62, 0.80),  # l_ankle
        (0.53, 0.12),  # r_eye
        (0.58, 0.12),  # l_eye
        (0.50, 0.13),  # r_ear
        (0.60, 0.13),  # l_ear
    ],
    "hit/hit_recoil": [
        (0.58, 0.16),  # nose (leaning back)
        (0.55, 0.24),  # neck
        (0.45, 0.27),  # r_shoulder
        (0.40, 0.37),  # r_elbow
        (0.42, 0.45),  # r_wrist
        (0.65, 0.27),  # l_shoulder
        (0.70, 0.35),  # l_elbow
        (0.68, 0.43),  # l_wrist
        (0.47, 0.48),  # r_hip
        (0.48, 0.64),  # r_knee
        (0.46, 0.80),  # r_ankle
        (0.60, 0.48),  # l_hip
        (0.62, 0.64),  # l_knee
        (0.63, 0.80),  # l_ankle
        (0.56, 0.14),  # r_eye
        (0.61, 0.14),  # l_eye
        (0.53, 0.15),  # r_ear
        (0.63, 0.15),  # l_ear
    ],
    "hit/hit_recover": [
        (0.52, 0.13),  # nose (recovering)
        (0.51, 0.21),  # neck
        (0.41, 0.23),  # r_shoulder
        (0.37, 0.34),  # r_elbow
        (0.36, 0.44),  # r_wrist
        (0.61, 0.23),  # l_shoulder
        (0.66, 0.34),  # l_elbow
        (0.65, 0.44),  # l_wrist
        (0.44, 0.46),  # r_hip
        (0.43, 0.63),  # r_knee
        (0.42, 0.80),  # r_ankle
        (0.58, 0.46),  # l_hip
        (0.59, 0.63),  # l_knee
        (0.60, 0.80),  # l_ankle
        (0.50, 0.11),  # r_eye
        (0.55, 0.11),  # l_eye
        (0.47, 0.12),  # r_ear
        (0.57, 0.12),  # l_ear
    ],

    # Block
    "block/block_raise": [
        (0.50, 0.12),  # nose
        (0.50, 0.20),  # neck
        (0.40, 0.22),  # r_shoulder
        (0.35, 0.28),  # r_elbow (raising)
        (0.38, 0.22),  # r_wrist (guard coming up)
        (0.60, 0.22),  # l_shoulder
        (0.65, 0.28),  # l_elbow
        (0.62, 0.22),  # l_wrist
        (0.43, 0.46),  # r_hip
        (0.42, 0.63),  # r_knee (bracing)
        (0.40, 0.80),  # r_ankle
        (0.57, 0.46),  # l_hip
        (0.58, 0.63),  # l_knee
        (0.60, 0.80),  # l_ankle
        (0.47, 0.10),  # r_eye
        (0.53, 0.10),  # l_eye
        (0.44, 0.11),  # r_ear
        (0.56, 0.11),  # l_ear
    ],
    "block/block_hold": [
        (0.50, 0.14),  # nose (slightly ducked)
        (0.50, 0.22),  # neck
        (0.40, 0.24),  # r_shoulder
        (0.33, 0.24),  # r_elbow (guard up)
        (0.35, 0.16),  # r_wrist (shield/arms up high)
        (0.60, 0.24),  # l_shoulder
        (0.67, 0.24),  # l_elbow
        (0.65, 0.16),  # l_wrist
        (0.43, 0.47),  # r_hip (crouching slightly)
        (0.42, 0.64),  # r_knee (bent)
        (0.38, 0.80),  # r_ankle (wide stance)
        (0.57, 0.47),  # l_hip
        (0.58, 0.64),  # l_knee
        (0.62, 0.80),  # l_ankle
        (0.47, 0.12),  # r_eye
        (0.53, 0.12),  # l_eye
        (0.44, 0.13),  # r_ear
        (0.56, 0.13),  # l_ear
    ],
    "block/block_lower": [
        (0.50, 0.12),  # nose (rising)
        (0.50, 0.20),  # neck
        (0.40, 0.22),  # r_shoulder
        (0.35, 0.30),  # r_elbow (lowering)
        (0.36, 0.38),  # r_wrist
        (0.60, 0.22),  # l_shoulder
        (0.65, 0.30),  # l_elbow
        (0.64, 0.38),  # l_wrist
        (0.43, 0.46),  # r_hip
        (0.42, 0.63),  # r_knee
        (0.40, 0.80),  # r_ankle
        (0.57, 0.46),  # l_hip
        (0.58, 0.63),  # l_knee
        (0.60, 0.80),  # l_ankle
        (0.47, 0.10),  # r_eye
        (0.53, 0.10),  # l_eye
        (0.44, 0.11),  # r_ear
        (0.56, 0.11),  # l_ear
    ],

    # Death sequence
    "death/death_stagger": [
        (0.55, 0.15),  # nose (staggering)
        (0.53, 0.23),  # neck
        (0.43, 0.26),  # r_shoulder
        (0.38, 0.37),  # r_elbow (limp)
        (0.40, 0.46),  # r_wrist
        (0.63, 0.26),  # l_shoulder
        (0.68, 0.36),  # l_elbow
        (0.66, 0.45),  # l_wrist
        (0.46, 0.48),  # r_hip
        (0.47, 0.64),  # r_knee (buckling)
        (0.45, 0.80),  # r_ankle
        (0.60, 0.48),  # l_hip
        (0.62, 0.63),  # l_knee
        (0.63, 0.80),  # l_ankle
        (0.53, 0.13),  # r_eye
        (0.58, 0.13),  # l_eye
        (0.50, 0.14),  # r_ear
        (0.60, 0.14),  # l_ear
    ],
    "death/death_fall_01": [
        (0.58, 0.25),  # nose (falling)
        (0.55, 0.33),  # neck
        (0.45, 0.36),  # r_shoulder
        (0.40, 0.46),  # r_elbow
        (0.42, 0.55),  # r_wrist
        (0.65, 0.36),  # l_shoulder
        (0.70, 0.44),  # l_elbow
        (0.68, 0.53),  # l_wrist
        (0.48, 0.52),  # r_hip
        (0.50, 0.66),  # r_knee (collapsing)
        (0.48, 0.80),  # r_ankle
        (0.62, 0.52),  # l_hip
        (0.65, 0.65),  # l_knee
        (0.66, 0.78),  # l_ankle
        (0.56, 0.23),  # r_eye
        (0.61, 0.23),  # l_eye
        (0.53, 0.24),  # r_ear
        (0.63, 0.24),  # l_ear
    ],
    "death/death_fall_02": [
        (0.60, 0.45),  # nose (hitting ground)
        (0.57, 0.50),  # neck
        (0.47, 0.53),  # r_shoulder
        (0.42, 0.60),  # r_elbow
        (0.40, 0.67),  # r_wrist
        (0.67, 0.53),  # l_shoulder
        (0.72, 0.58),  # l_elbow
        (0.75, 0.63),  # l_wrist
        (0.50, 0.60),  # r_hip
        (0.48, 0.72),  # r_knee
        (0.46, 0.82),  # r_ankle
        (0.64, 0.60),  # l_hip
        (0.66, 0.72),  # l_knee
        (0.68, 0.82),  # l_ankle
        (0.58, 0.43),  # r_eye
        (0.63, 0.43),  # l_eye
        (0.55, 0.44),  # r_ear
        (0.65, 0.44),  # l_ear
    ],
    "death/death_final": [
        (0.55, 0.60),  # nose (on ground)
        (0.52, 0.63),  # neck
        (0.42, 0.65),  # r_shoulder
        (0.35, 0.68),  # r_elbow (splayed)
        (0.28, 0.70),  # r_wrist
        (0.62, 0.65),  # l_shoulder
        (0.70, 0.67),  # l_elbow
        (0.76, 0.69),  # l_wrist
        (0.47, 0.72),  # r_hip
        (0.42, 0.78),  # r_knee
        (0.38, 0.85),  # r_ankle
        (0.60, 0.72),  # l_hip
        (0.65, 0.78),  # l_knee
        (0.68, 0.85),  # l_ankle
        (0.53, 0.58),  # r_eye
        (0.58, 0.58),  # l_eye
        (0.50, 0.59),  # r_ear
        (0.60, 0.59),  # l_ear
    ],
}


def main():
    parser = argparse.ArgumentParser(description="Generate OpenPose skeleton reference images")
    parser.add_argument("--preview", action="store_true", help="Show preview of each pose")
    parser.add_argument("--output", type=str, default=None,
                        help="Output directory (default: pose_skeletons/ next to this script)")
    args = parser.parse_args()

    if not HAS_PIL:
        print("ERROR: Pillow required. Install with: pip install Pillow")
        return

    output_dir = Path(args.output) if args.output else Path(__file__).parent / "pose_skeletons"

    print(f"\n{'='*60}")
    print(f"  OpenPose Skeleton Generator")
    print(f"{'='*60}")
    print(f"  Poses: {len(POSES)}")
    print(f"  Output: {output_dir}")
    print(f"{'='*60}\n")

    for pose_name, keypoints in POSES.items():
        img = draw_skeleton(keypoints)
        out_path = output_dir / f"{pose_name}.png"
        out_path.parent.mkdir(parents=True, exist_ok=True)
        img.save(out_path, "PNG")
        print(f"  Generated: {pose_name}.png")

        if args.preview:
            img.show(title=pose_name)

    print(f"\n  Done! {len(POSES)} skeleton images generated.\n")


if __name__ == "__main__":
    main()
