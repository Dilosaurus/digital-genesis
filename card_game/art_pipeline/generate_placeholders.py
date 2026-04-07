#!/usr/bin/env python3
"""Generate stylized character placeholder sprites for deus.exe.

Creates full-body silhouette sprites with glow effects, energy auras,
and character-specific color themes. These serve as temporary placeholders
until real character art is generated via the ComfyUI pipeline.

Output: res://assets/characters/{id}/fullbody.png (256x512 transparent PNG)
"""

import os
import math
import random
from PIL import Image, ImageDraw, ImageFilter, ImageFont

# Character definitions: id -> (name, primary_color_rgb, silhouette_style, glow_color_rgb)
PLAYERS = {
    "netrunner": {
        "name": "Zephyr",
        "color": (77, 230, 255),      # cyan
        "glow": (40, 180, 255),
        "style": "slim",               # hooded hacker
        "accent": (0, 120, 200),
    },
    "sysadmin": {
        "name": "Bastion",
        "color": (51, 179, 77),        # green
        "glow": (30, 200, 80),
        "style": "bulky",              # armored tank
        "accent": (20, 100, 50),
    },
    "cryptomancer": {
        "name": "Cipher",
        "color": (204, 102, 255),      # purple
        "glow": (180, 80, 255),
        "style": "robed",              # mystic caster
        "accent": (120, 40, 180),
    },
    "white_hat": {
        "name": "Sentinel",
        "color": (255, 242, 204),      # warm white
        "glow": (255, 220, 150),
        "style": "slim",               # precise agent
        "accent": (200, 180, 120),
    },
    "technomancer": {
        "name": "FLUX",
        "color": (230, 51, 204),       # magenta
        "glow": (255, 60, 200),
        "style": "robed",              # chaotic summoner
        "accent": (180, 30, 150),
    },
}

ENEMIES = {
    "cultist": {
        "name": "Cultist",
        "color": (140, 60, 60),
        "glow": (180, 40, 40),
        "style": "robed",
        "accent": (100, 30, 30),
    },
    "jaw_worm": {
        "name": "Jaw Worm",
        "color": (100, 140, 80),
        "glow": (80, 160, 60),
        "style": "beast",
        "accent": (60, 100, 40),
    },
    "louse_red": {
        "name": "Red Louse",
        "color": (200, 60, 50),
        "glow": (220, 40, 30),
        "style": "beast",
        "accent": (150, 30, 20),
    },
    "gabriel": {
        "name": "Gabriel",
        "color": (220, 200, 255),
        "glow": (180, 160, 255),
        "style": "angelic",
        "accent": (140, 120, 220),
    },
    "michael": {
        "name": "Michael",
        "color": (255, 215, 100),
        "glow": (255, 200, 50),
        "style": "angelic",
        "accent": (200, 160, 40),
    },
    "raphael": {
        "name": "Raphael",
        "color": (100, 220, 180),
        "glow": (60, 200, 160),
        "style": "angelic",
        "accent": (40, 160, 120),
    },
    "uriel": {
        "name": "Uriel",
        "color": (255, 140, 60),
        "glow": (255, 120, 30),
        "style": "angelic",
        "accent": (200, 100, 20),
    },
    "azrael": {
        "name": "Azrael",
        "color": (80, 80, 120),
        "glow": (100, 80, 160),
        "style": "angelic",
        "accent": (60, 50, 100),
    },
    "metatron": {
        "name": "Metatron",
        "color": (255, 255, 220),
        "glow": (255, 255, 180),
        "style": "angelic",
        "accent": (200, 200, 160),
    },
    "hexaghost": {
        "name": "Hexaghost",
        "color": (60, 200, 160),
        "glow": (40, 255, 180),
        "style": "spectral",
        "accent": (20, 150, 120),
    },
}

W, H = 256, 512


def draw_silhouette(draw: ImageDraw.Draw, style: str, color: tuple, accent: tuple):
    """Draw a character silhouette shape based on style."""
    cx, cy = W // 2, H // 2

    if style == "slim":
        # Slim humanoid - hooded/agent type
        # Head
        draw.ellipse([cx-28, 60, cx+28, 120], fill=color)
        # Hood/hair detail
        draw.polygon([(cx-32, 80), (cx, 50), (cx+32, 80)], fill=accent)
        # Neck
        draw.rectangle([cx-10, 120, cx+10, 140], fill=color)
        # Torso
        draw.polygon([(cx-40, 140), (cx+40, 140), (cx+35, 280), (cx-35, 280)], fill=color)
        # Belt detail
        draw.rectangle([cx-38, 260, cx+38, 272], fill=accent)
        # Left arm
        draw.polygon([(cx-40, 145), (cx-55, 145), (cx-60, 250), (cx-42, 250)], fill=color)
        # Right arm
        draw.polygon([(cx+40, 145), (cx+55, 145), (cx+60, 250), (cx+42, 250)], fill=color)
        # Legs
        draw.polygon([(cx-30, 280), (cx-5, 280), (cx-8, 420), (cx-35, 420)], fill=color)
        draw.polygon([(cx+30, 280), (cx+5, 280), (cx+8, 420), (cx+35, 420)], fill=color)
        # Boots
        draw.ellipse([cx-40, 405, cx-5, 435], fill=accent)
        draw.ellipse([cx+5, 405, cx+40, 435], fill=accent)

    elif style == "bulky":
        # Heavy armored - tank type
        # Head (smaller relative to body)
        draw.ellipse([cx-25, 65, cx+25, 120], fill=color)
        # Helmet detail
        draw.rectangle([cx-28, 65, cx+28, 85], fill=accent)
        # Neck
        draw.rectangle([cx-15, 120, cx+15, 140], fill=color)
        # Shoulder pads
        draw.ellipse([cx-65, 130, cx-25, 170], fill=accent)
        draw.ellipse([cx+25, 130, cx+65, 170], fill=accent)
        # Torso (wide)
        draw.polygon([(cx-50, 140), (cx+50, 140), (cx+45, 290), (cx-45, 290)], fill=color)
        # Chest plate detail
        draw.polygon([(cx-30, 160), (cx+30, 160), (cx+25, 230), (cx-25, 230)], fill=accent)
        # Arms (thick)
        draw.polygon([(cx-50, 150), (cx-70, 160), (cx-65, 270), (cx-45, 260)], fill=color)
        draw.polygon([(cx+50, 150), (cx+70, 160), (cx+65, 270), (cx+45, 260)], fill=color)
        # Legs (thick)
        draw.polygon([(cx-38, 290), (cx-5, 290), (cx-8, 420), (cx-42, 420)], fill=color)
        draw.polygon([(cx+38, 290), (cx+5, 290), (cx+8, 420), (cx+42, 420)], fill=color)
        # Heavy boots
        draw.rectangle([cx-48, 400, cx-5, 435], fill=accent)
        draw.rectangle([cx+5, 400, cx+48, 435], fill=accent)

    elif style == "robed":
        # Robed mystic - caster type
        # Head
        draw.ellipse([cx-26, 55, cx+26, 115], fill=color)
        # Neck
        draw.rectangle([cx-10, 115, cx+10, 135], fill=color)
        # Robe body (flows wide at bottom)
        draw.polygon([(cx-35, 135), (cx+35, 135), (cx+60, 430), (cx-60, 430)], fill=color)
        # Inner robe detail
        draw.polygon([(cx-15, 160), (cx+15, 160), (cx+25, 420), (cx-25, 420)], fill=accent)
        # Sleeves (wide)
        draw.polygon([(cx-35, 145), (cx-55, 155), (cx-75, 250), (cx-40, 230)], fill=color)
        draw.polygon([(cx+35, 145), (cx+55, 155), (cx+75, 250), (cx+40, 230)], fill=color)
        # Hood shadow
        draw.pieslice([cx-30, 45, cx+30, 95], 200, 340, fill=accent)
        # Floating orb detail
        draw.ellipse([cx+50, 200, cx+72, 222], fill=(*color[:2], min(color[2]+40, 255)))

    elif style == "beast":
        # Monster/beast shape
        # Body (blob-like, wider than tall)
        draw.ellipse([cx-70, 150, cx+70, 400], fill=color)
        # Head (forward-jutting)
        draw.ellipse([cx-40, 110, cx+50, 200], fill=color)
        # Eye
        draw.ellipse([cx+5, 140, cx+25, 158], fill=(255, 255, 200))
        draw.ellipse([cx+10, 144, cx+20, 154], fill=(40, 0, 0))
        # Mouth/jaw
        draw.polygon([(cx+20, 170), (cx+55, 185), (cx+20, 195)], fill=accent)
        # Legs/feet
        draw.ellipse([cx-55, 370, cx-20, 430], fill=accent)
        draw.ellipse([cx+20, 370, cx+55, 430], fill=accent)
        # Spikes on back
        for i in range(4):
            sx = cx - 30 + i * 20
            draw.polygon([(sx, 160 + i*15), (sx+8, 120 + i*10), (sx+16, 165 + i*15)], fill=accent)

    elif style == "angelic":
        # Tall, imposing angelic figure with wings
        # Head (with halo)
        draw.ellipse([cx-24, 60, cx+24, 110], fill=color)
        # Halo
        draw.arc([cx-35, 35, cx+35, 75], 0, 360, fill=(*color[:2], min(color[2]+40, 255)), width=3)
        # Neck
        draw.rectangle([cx-8, 110, cx+8, 130], fill=color)
        # Torso (elegant)
        draw.polygon([(cx-35, 130), (cx+35, 130), (cx+30, 300), (cx-30, 300)], fill=color)
        # Robes flowing
        draw.polygon([(cx-30, 300), (cx+30, 300), (cx+45, 435), (cx-45, 435)], fill=color)
        # Wings (left)
        draw.polygon([(cx-35, 140), (cx-110, 80), (cx-100, 200), (cx-40, 200)], fill=accent)
        draw.polygon([(cx-100, 80), (cx-120, 60), (cx-115, 140), (cx-100, 200)], fill=(*accent[:2], max(accent[2]-30, 0)))
        # Wings (right)
        draw.polygon([(cx+35, 140), (cx+110, 80), (cx+100, 200), (cx+40, 200)], fill=accent)
        draw.polygon([(cx+100, 80), (cx+120, 60), (cx+115, 140), (cx+100, 200)], fill=(*accent[:2], max(accent[2]-30, 0)))
        # Chest detail
        draw.polygon([(cx-15, 150), (cx+15, 150), (cx+10, 210), (cx-10, 210)], fill=accent)

    elif style == "spectral":
        # Ghost/spectral - transparent/wispy
        # Main body (amorphous)
        draw.ellipse([cx-50, 80, cx+50, 280], fill=color)
        # Head area (brighter)
        draw.ellipse([cx-30, 70, cx+30, 140], fill=(*color[:2], min(color[2]+40, 255)))
        # Eyes (glowing)
        draw.ellipse([cx-18, 95, cx-6, 110], fill=(255, 255, 220))
        draw.ellipse([cx+6, 95, cx+18, 110], fill=(255, 255, 220))
        # Wispy tendrils going down
        for i in range(5):
            tx = cx - 40 + i * 20
            points = [(tx, 260), (tx + 10, 260)]
            for j in range(6):
                wave = math.sin(j * 0.8 + i) * 12
                points.append((tx + 10 + wave, 280 + j * 25))
            for j in range(5, -1, -1):
                wave = math.sin(j * 0.8 + i) * 12
                points.append((tx + wave, 280 + j * 25))
            if len(points) >= 3:
                draw.polygon(points, fill=accent)
        # Orbiting fragments
        for i in range(6):
            angle = i * math.pi / 3
            ox = cx + int(math.cos(angle) * 65)
            oy = 180 + int(math.sin(angle) * 65)
            size = random.randint(4, 9)
            draw.ellipse([ox-size, oy-size, ox+size, oy+size], fill=accent)


def add_glow(img: Image.Image, glow_color: tuple, intensity: int = 12) -> Image.Image:
    """Add an outer glow effect around the character silhouette."""
    # Create glow layer from alpha channel
    alpha = img.split()[3]
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)

    # Expand alpha for glow
    expanded = alpha.filter(ImageFilter.GaussianBlur(radius=intensity))
    glow_layer = Image.new("RGBA", (W, H), (*glow_color, 0))
    glow_layer.putalpha(expanded)

    # Composite: glow behind, character on top
    result = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    result = Image.alpha_composite(result, glow_layer)
    result = Image.alpha_composite(result, img)
    return result


def add_energy_lines(draw: ImageDraw.Draw, color: tuple, count: int = 8):
    """Draw subtle energy/circuit lines on the character."""
    for _ in range(count):
        x = random.randint(80, W - 80)
        y = random.randint(100, 400)
        length = random.randint(15, 50)
        angle = random.uniform(-0.5, 0.5)
        x2 = x + int(math.cos(angle) * length)
        y2 = y + int(math.sin(angle) * length)
        line_color = (*color, 120)
        draw.line([(x, y), (x2, y2)], fill=line_color, width=1)
        # Node dots at endpoints
        draw.ellipse([x-2, y-2, x+2, y+2], fill=(*color, 180))


def add_name_label(draw: ImageDraw.Draw, name: str, color: tuple):
    """Add character name at the bottom."""
    try:
        font = ImageFont.truetype("arial.ttf", 18)
    except (OSError, IOError):
        font = ImageFont.load_default()

    bbox = draw.textbbox((0, 0), name, font=font)
    tw = bbox[2] - bbox[0]
    x = (W - tw) // 2
    y = H - 40

    # Shadow
    draw.text((x+1, y+1), name, fill=(0, 0, 0, 200), font=font)
    # Main text
    draw.text((x, y), name, fill=(*color, 255), font=font)


def generate_character(char_id: str, config: dict, output_dir: str):
    """Generate a single character placeholder sprite."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    color = config["color"]
    accent = config["accent"]
    glow = config["glow"]
    style = config["style"]
    name = config["name"]

    # Draw the silhouette
    draw_silhouette(draw, style, color, accent)

    # Add energy circuit lines
    add_energy_lines(draw, glow, count=12)

    # Add name
    add_name_label(draw, name, color)

    # Add glow effect
    img = add_glow(img, glow, intensity=10)

    # Save
    char_dir = os.path.join(output_dir, char_id)
    os.makedirs(char_dir, exist_ok=True)
    out_path = os.path.join(char_dir, "fullbody.png")
    img.save(out_path, "PNG")
    print(f"  Generated: {out_path}")


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    assets_dir = os.path.join(script_dir, "..", "assets", "characters")
    assets_dir = os.path.normpath(assets_dir)

    print(f"Output directory: {assets_dir}")
    print()

    print("=== Player Characters ===")
    for char_id, config in PLAYERS.items():
        generate_character(char_id, config, assets_dir)

    print()
    print("=== Enemies ===")
    for char_id, config in ENEMIES.items():
        generate_character(char_id, config, assets_dir)

    total = len(PLAYERS) + len(ENEMIES)
    print(f"\nDone! Generated {total} character placeholder sprites.")
    print("These will be loaded automatically as fullbody.png by the puppet system.")


if __name__ == "__main__":
    random.seed(42)  # Reproducible output
    main()
