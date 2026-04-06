"""
Find exact positions of each puppet part by template-matching against the full image,
then convert absolute positions into Godot's parent-child relative coordinate system.
Outputs a ready-to-paste .tscn node block.
"""
import cv2
import numpy as np
from pathlib import Path

PARTS_DIR = Path(r"E:\godot_games\card_game\assets\enemies\boss\metatron\parts")
FULL_IMG = Path(r"E:\godot_games\card_game\assets\enemies\boss\metatron\metatron_final.png")

# Load full image
full = cv2.imread(str(FULL_IMG), cv2.IMREAD_UNCHANGED)
# Use RGB channels for matching (ignore alpha)
full_rgb = full[:, :, :3]

# Template match each part to find its absolute top-left position
parts = {}
for png in sorted(PARTS_DIR.glob("*.png")):
    part = cv2.imread(str(png), cv2.IMREAD_UNCHANGED)
    part_rgb = part[:, :, :3]
    part_alpha = part[:, :, 3] if part.shape[2] == 4 else None

    h, w = part_rgb.shape[:2]

    # Use TM_CCOEFF_NORMED for best match
    result = cv2.matchTemplate(full_rgb, part_rgb, cv2.TM_CCOEFF_NORMED)
    _, max_val, _, max_loc = cv2.minMaxLoc(result)

    # max_loc is top-left corner of the match
    tl_x, tl_y = max_loc
    # Center of the part in absolute image coordinates
    cx = tl_x + w / 2.0
    cy = tl_y + h / 2.0

    name = png.stem
    parts[name] = {
        "tl": (tl_x, tl_y),
        "center": (cx, cy),
        "size": (w, h),
        "confidence": max_val
    }
    print(f"{name:20s}  tl=({tl_x:4d},{tl_y:4d})  center=({cx:7.1f},{cy:7.1f})  size=({w:3d}x{h:3d})  conf={max_val:.4f}")

# The full image is 1024x1024. The puppet in Godot is centered at (0,0) in its local space.
# We need to pick a reference center. The torso center will be our puppet origin.
torso = parts["torso"]
# Puppet origin = torso center in image space
origin_x, origin_y = torso["center"]

print(f"\nPuppet origin (torso center): ({origin_x:.1f}, {origin_y:.1f})")
print()

# Convert absolute center to position relative to puppet origin
def abs_to_local(part_name):
    cx, cy = parts[part_name]["center"]
    return (cx - origin_x, cy - origin_y)

# Godot hierarchy:
# Root (MetatronPuppet) at origin
#   RobeLeft - direct child of root
#   RobeRight - direct child of root
#   Torso - direct child of root
#     Neck - child of Torso
#       Head - child of Neck
#         Hood - child of Head
#     ShoulderLeft - child of Torso
#       UpperArmLeft - child of ShoulderLeft
#         LowerArmLeft - child of UpperArmLeft
#           ClawLeft - child of LowerArmLeft
#     ShoulderRight - child of Torso
#       UpperArmRight - child of ShoulderRight
#         LowerArmRight - child of UpperArmRight
#           ClawRight - child of LowerArmRight

# For parent-child: child.position = child_absolute - parent_absolute
# where "absolute" means relative to the puppet origin

# Calculate all absolute positions (relative to puppet origin)
abs_pos = {}
for name in parts:
    abs_pos[name] = abs_to_local(name)

# Define the hierarchy as (node_name, parent_name_or_None)
hierarchy = {
    "torso": None,           # direct child of root, at origin
    "neck": "torso",
    "head": "neck",
    "hood": "head",
    "shoulder_left": "torso",
    "upper_arm_left": "shoulder_left",
    "lower_arm_left": "upper_arm_left",
    "claw_left": "lower_arm_left",
    "shoulder_right": "torso",
    "upper_arm_right": "shoulder_right",
    "lower_arm_right": "upper_arm_right",
    "claw_right": "lower_arm_right",
    "robe_left": None,       # direct child of root
    "robe_right": None,      # direct child of root
}

# Map part file names to hierarchy names
name_map = {
    "torso": "torso", "neck": "neck", "head": "head", "hood": "hood",
    "shoulder_left": "shoulder_left", "shoulder_right": "shoulder_right",
    "upper_arm_left": "upper_arm_left", "upper_arm_right": "upper_arm_right",
    "lower_arm_left": "lower_arm_left", "lower_arm_right": "lower_arm_right",
    "claw_left": "claw_left", "claw_right": "claw_right",
    "robe_left": "robe_left", "robe_right": "robe_right",
}

# Compute relative positions for Godot
print("=" * 70)
print("GODOT RELATIVE POSITIONS (paste into .tscn)")
print("=" * 70)

# Accumulate absolute positions accounting for parent chain
def get_absolute(name):
    """Get absolute position of a node (relative to puppet origin)"""
    return abs_pos[name]

def get_parent_absolute(name):
    """Get the absolute position of a node's parent"""
    parent = hierarchy[name]
    if parent is None:
        return (0.0, 0.0)  # root is at origin
    return get_absolute(parent)

# For each joint, define where the pivot/joint point should be
# relative to the part's center (this becomes the offset)
# Positive Y = down in Godot
# The offset shifts the TEXTURE relative to the node origin
# So if joint is at top of texture: offset = (0, +half_height)
# If joint is at bottom: offset = (0, -half_height)

joint_offsets = {}
for name, data in parts.items():
    w, h = data["size"]
    hw, hh = w / 2.0, h / 2.0

    # Default: center (no offset needed, position IS the center)
    # For arms: pivot at the joint connecting to parent
    if name == "torso":
        joint_offsets[name] = (0, 0)
    elif name == "neck":
        # Pivot at bottom (where it connects to torso)
        joint_offsets[name] = (0, -hh * 0.3)
    elif name == "head":
        # Pivot at bottom (where it connects to neck)
        joint_offsets[name] = (0, 0)
    elif name == "hood":
        # Follows head, pivot at bottom center
        joint_offsets[name] = (0, hh * 0.6)
    elif name in ("shoulder_left", "shoulder_right"):
        # Pivot at top-inner (where it connects to torso)
        sign = -1 if "left" in name else 1
        joint_offsets[name] = (sign * -hw * 0.3, hh * 0.3)
    elif name in ("upper_arm_left", "upper_arm_right"):
        # Pivot at top (shoulder joint)
        sign = -1 if "left" in name else 1
        joint_offsets[name] = (sign * -hw * 0.2, -hh * 0.3)
    elif name in ("lower_arm_left", "lower_arm_right"):
        # Pivot at top (elbow joint)
        sign = -1 if "left" in name else 1
        joint_offsets[name] = (sign * -hw * 0.2, -hh * 0.3)
    elif name in ("claw_left", "claw_right"):
        # Pivot at top (wrist joint)
        sign = -1 if "left" in name else 1
        joint_offsets[name] = (sign * -hw * 0.2, -hh * 0.2)
    elif name in ("robe_left", "robe_right"):
        # Pivot at top (where robe attaches to body)
        joint_offsets[name] = (0, -hh * 0.6)
    else:
        joint_offsets[name] = (0, 0)

for name in hierarchy:
    parent = hierarchy[name]
    ax, ay = get_absolute(name)
    pax, pay = get_parent_absolute(name)

    # Relative position = absolute - parent_absolute
    rel_x = ax - pax
    rel_y = ay - pay

    w, h = parts[name]["size"]
    off_x, off_y = joint_offsets[name]

    node_name_map = {
        "torso": "Torso", "neck": "Neck", "head": "Head", "hood": "Hood",
        "shoulder_left": "ShoulderLeft", "shoulder_right": "ShoulderRight",
        "upper_arm_left": "UpperArmLeft", "upper_arm_right": "UpperArmRight",
        "lower_arm_left": "LowerArmLeft", "lower_arm_right": "LowerArmRight",
        "claw_left": "ClawLeft", "claw_right": "ClawRight",
        "robe_left": "RobeLeft", "robe_right": "RobeRight",
    }

    gd_name = node_name_map[name]
    print(f'{gd_name:20s}  position = Vector2({rel_x:.1f}, {rel_y:.1f})    offset = Vector2({off_x:.1f}, {off_y:.1f})')
