"""
deus.exe Card Art Workflow Builder
Generates ComfyUI API-format workflows for card art with:
- Multi-LoRA tag-based style stacking
- Tag-based prompt injection
- Card type border accents
- Corruption tier overlays
- KomikoAI layer splitting
- Batch processing support
"""

import json
import os
import random
from pathlib import Path
from typing import Optional


def load_config():
    config_path = Path(__file__).parent / "config.json"
    with open(config_path) as f:
        return json.load(f)


def load_card_prompts():
    prompts_path = Path(__file__).parent / "card_prompts.json"
    with open(prompts_path) as f:
        return json.load(f)


# ── LoRA Resolution ──────────────────────────────────────────────────────────

def resolve_lora_stack(card: dict, prompts_data: dict, config: dict) -> list[dict]:
    """Resolve which LoRAs to apply for a card based on its tags and type.

    Returns a list of {"filename": str, "strength": float, "trigger": str} dicts,
    ordered by strength (strongest first), capped at max_loras.
    Only includes LoRAs whose files actually exist on disk.
    """
    lora_library = prompts_data.get("lora_library", {})
    tag_mapping = prompts_data.get("tag_lora_mapping", {})
    type_overrides = prompts_data.get("type_lora_overrides", {})
    max_loras = tag_mapping.get("max_loras", 3)

    # Collect all LoRA entries: {lora_key: strength}
    # Later entries override earlier ones (so tag-specific beats base)
    lora_strengths = {}

    # 1. Base LoRAs (apply to every card)
    for lora_key, strength in tag_mapping.get("base", []):
        lora_strengths[lora_key] = strength

    # 2. Tag-specific LoRAs
    for tag in card.get("tags", []):
        tag_upper = tag.upper()
        for lora_key, strength in tag_mapping.get(tag_upper, []):
            # If this LoRA is already in the stack, use the higher strength
            if lora_key in lora_strengths:
                lora_strengths[lora_key] = max(lora_strengths[lora_key], strength)
            else:
                lora_strengths[lora_key] = strength

    # 3. Type overrides (adjust specific LoRA strengths per card type)
    card_type = card.get("card_type", "")
    if card_type in type_overrides:
        for lora_key, strength in type_overrides[card_type].items():
            if lora_key in lora_strengths:
                lora_strengths[lora_key] = strength

    # 4. Resolve to actual LoRA info, filtering by what's installed
    comfyui_lora_dir = Path(config.get("comfyui_path", "E:/ComfyUI")) / "models" / "loras"
    resolved = []

    for lora_key, strength in lora_strengths.items():
        if lora_key not in lora_library:
            continue
        lora_info = lora_library[lora_key]
        filename = lora_info["filename"]

        # Check if LoRA file exists
        if not (comfyui_lora_dir / filename).exists():
            continue

        resolved.append({
            "key": lora_key,
            "filename": filename,
            "strength": strength,
            "trigger": lora_info.get("trigger", ""),
        })

    # Sort by strength descending, cap at max
    resolved.sort(key=lambda x: x["strength"], reverse=True)
    return resolved[:max_loras]


def get_lora_triggers(lora_stack: list[dict]) -> str:
    """Extract trigger words from the LoRA stack to prepend to the prompt."""
    triggers = [l["trigger"] for l in lora_stack if l.get("trigger")]
    return ", ".join(triggers)


# ── Prompt Assembly ──────────────────────────────────────────────────────────

def build_tag_keywords(tags: list[str], tag_styles: dict) -> str:
    """Combine tag-specific style keywords for multi-tag cards."""
    keywords = []
    for tag in tags:
        tag_upper = tag.upper()
        if tag_upper in tag_styles:
            keywords.append(tag_styles[tag_upper]["keywords"])
    return ", ".join(keywords)


def build_positive_prompt(card: dict, tag_styles: dict, type_styles: dict,
                          config: dict, corruption_tier: int = 0,
                          corruption_tiers: Optional[dict] = None,
                          lora_stack: Optional[list[dict]] = None) -> str:
    """Assemble the full positive prompt for a card, including LoRA triggers."""
    card_prompt = card["prompt"]
    tag_keywords = build_tag_keywords(card["tags"], tag_styles)
    type_style = type_styles.get(card["card_type"], {})
    type_mood = type_style.get("mood", "")
    type_accent = type_style.get("accent_keywords", "")

    # LoRA trigger words go first (some LoRAs need their trigger early in prompt)
    lora_triggers = ""
    if lora_stack:
        lora_triggers = get_lora_triggers(lora_stack)

    # Core cyberpunk-digital style prefix
    style_prefix = config.get("card_art_style_prefix",
        "cyberpunk digital realm, neon glow, circuit patterns, holographic, "
        "dark background, detailed illustration, card game art, centered composition"
    )

    parts = [
        lora_triggers,
        card_prompt,
        style_prefix,
        tag_keywords,
        type_mood,
        type_accent,
    ]

    # Add corruption overlay keywords
    if corruption_tier > 0 and corruption_tiers:
        tier_key = str(corruption_tier)
        if tier_key in corruption_tiers:
            tier_data = corruption_tiers[tier_key]
            if tier_data["prompt_addition"]:
                parts.append(tier_data["prompt_addition"])

    return ", ".join(p for p in parts if p)


def build_negative_prompt(config: dict) -> str:
    """Build the negative prompt for card art generation."""
    return config.get("card_art_negative",
        "text, words, letters, numbers, frame, border, card border, card frame, "
        "UI elements, HUD, watermark, signature, blurry, low quality, "
        "deformed hands, extra fingers, mutated, disfigured, bad anatomy, "
        "3d render, photo, photorealistic, out of frame, cropped, "
        "multiple views, split image, collage"
    )


# ── Base Card Art Workflow ───────────────────────────────────────────────────

def card_art_base_workflow(
    positive_prompt: str,
    negative_prompt: str,
    filename_prefix: str = "card",
    seed: Optional[int] = None,
    width: int = 512,
    height: int = 768,
    steps: int = 35,
    cfg: float = 7.5,
    model: Optional[str] = None,
    lora_stack: Optional[list[dict]] = None,
    # Legacy single-LoRA fallback
    lora: Optional[str] = None,
    lora_strength: float = 0.7,
) -> dict:
    """Build the base txt2img SDXL workflow for card art generation.

    Supports multi-LoRA stacking via lora_stack parameter.
    Falls back to single lora/lora_strength if lora_stack is not provided.
    """
    config = load_config()

    if seed is None:
        seed = random.randint(0, 2**32 - 1)
    if model is None:
        model = config["default_model"]

    # Legacy fallback: convert single LoRA to stack format
    if lora_stack is None:
        if lora is None:
            lora = config.get("card_art_lora", config.get("style_lora", ""))
        if lora:
            lora_strength = config.get("card_art_lora_strength", lora_strength)
            lora_stack = [{"filename": lora, "strength": lora_strength, "trigger": ""}]
        else:
            lora_stack = []

    # Node IDs follow ComfyUI convention
    workflow = {}

    # 1. Checkpoint Loader
    workflow["4"] = {
        "class_type": "CheckpointLoaderSimple",
        "inputs": {
            "ckpt_name": model,
        },
    }

    # Track model/clip sources (chained through LoRA loaders)
    model_source = ["4", 0]
    clip_source = ["4", 1]

    # 2. LoRA Chain — each LoRA feeds into the next
    # Node IDs: 100, 101, 102, ... for up to N LoRAs
    for i, lora_entry in enumerate(lora_stack):
        node_id = str(100 + i)
        workflow[node_id] = {
            "class_type": "LoraLoader",
            "inputs": {
                "lora_name": lora_entry["filename"],
                "strength_model": lora_entry["strength"],
                "strength_clip": lora_entry["strength"],
                "model": model_source,
                "clip": clip_source,
            },
        }
        model_source = [node_id, 0]
        clip_source = [node_id, 1]

    # 3. CLIP Text Encode — Positive
    workflow["6"] = {
        "class_type": "CLIPTextEncode",
        "inputs": {
            "text": positive_prompt,
            "clip": clip_source,
        },
    }

    # 4. CLIP Text Encode — Negative
    workflow["7"] = {
        "class_type": "CLIPTextEncode",
        "inputs": {
            "text": negative_prompt,
            "clip": clip_source,
        },
    }

    # 5. Empty Latent Image
    workflow["5"] = {
        "class_type": "EmptyLatentImage",
        "inputs": {
            "width": width,
            "height": height,
            "batch_size": 1,
        },
    }

    # 6. KSampler
    workflow["3"] = {
        "class_type": "KSampler",
        "inputs": {
            "seed": seed,
            "steps": steps,
            "cfg": cfg,
            "sampler_name": "dpmpp_2m",
            "scheduler": "karras",
            "denoise": 1.0,
            "model": model_source,
            "positive": ["6", 0],
            "negative": ["7", 0],
            "latent_image": ["5", 0],
        },
    }

    # 7. VAE Decode
    workflow["8"] = {
        "class_type": "VAEDecode",
        "inputs": {
            "samples": ["3", 0],
            "vae": ["4", 2],
        },
    }

    # 8. Save Image
    workflow["9"] = {
        "class_type": "SaveImage",
        "inputs": {
            "filename_prefix": filename_prefix,
            "images": ["8", 0],
        },
    }

    return workflow


# ── Corruption Overlay Workflow ──────────────────────────────────────────────

def stage_image_for_comfyui(source_path: str) -> str:
    """Copy an image into ComfyUI's input directory so LoadImage can find it.

    Args:
        source_path: Absolute path to the source image file.

    Returns:
        The filename (no path) to use in the LoadImage node.
    """
    import shutil
    config = load_config()
    comfyui_input = Path(config["comfyui_path"]) / "input"
    comfyui_input.mkdir(parents=True, exist_ok=True)

    src = Path(source_path)
    # Use a namespaced filename to avoid collisions
    staged_name = f"genesis_{src.stem}{src.suffix}"
    dst = comfyui_input / staged_name
    shutil.copy2(str(src), str(dst))
    return staged_name


def corruption_overlay_workflow(
    base_image_name: str,
    corruption_prompt_addition: str,
    negative_prompt: str,
    denoise_strength: float = 0.3,
    filename_prefix: str = "card_corrupt",
    seed: Optional[int] = None,
    steps: int = 30,
    cfg: float = 7.0,
    model: Optional[str] = None,
    lora_stack: Optional[list[dict]] = None,
) -> dict:
    """Build an img2img workflow that applies corruption overlay to existing card art.

    Uses the base card image as input and applies progressive corruption
    via img2img with increasing denoise strength per tier.
    Supports multi-LoRA stacking via lora_stack parameter.

    Args:
        base_image_name: Filename in ComfyUI's input/ directory (use stage_image_for_comfyui first).
        lora_stack: List of {"filename", "strength", "trigger"} dicts for LoRA chaining.
    """
    config = load_config()

    if seed is None:
        seed = random.randint(0, 2**32 - 1)
    if model is None:
        model = config["default_model"]
    if lora_stack is None:
        lora_stack = []

    workflow = {}

    # 1. Load the base card image (must be in ComfyUI/input/)
    workflow["20"] = {
        "class_type": "LoadImage",
        "inputs": {
            "image": base_image_name,
        },
    }

    # 2. Checkpoint Loader
    workflow["4"] = {
        "class_type": "CheckpointLoaderSimple",
        "inputs": {
            "ckpt_name": model,
        },
    }

    model_source = ["4", 0]
    clip_source = ["4", 1]

    # 3. LoRA Chain
    for i, lora_entry in enumerate(lora_stack):
        node_id = str(100 + i)
        workflow[node_id] = {
            "class_type": "LoraLoader",
            "inputs": {
                "lora_name": lora_entry["filename"],
                "strength_model": lora_entry["strength"],
                "strength_clip": lora_entry["strength"],
                "model": model_source,
                "clip": clip_source,
            },
        }
        model_source = [node_id, 0]
        clip_source = [node_id, 1]

    # 4. VAE Encode the base image to latent
    workflow["21"] = {
        "class_type": "VAEEncode",
        "inputs": {
            "pixels": ["20", 0],
            "vae": ["4", 2],
        },
    }

    # 5. Corruption prompt
    workflow["6"] = {
        "class_type": "CLIPTextEncode",
        "inputs": {
            "text": corruption_prompt_addition,
            "clip": clip_source,
        },
    }

    workflow["7"] = {
        "class_type": "CLIPTextEncode",
        "inputs": {
            "text": negative_prompt,
            "clip": clip_source,
        },
    }

    # 6. KSampler with denoise < 1.0 for img2img
    workflow["3"] = {
        "class_type": "KSampler",
        "inputs": {
            "seed": seed,
            "steps": steps,
            "cfg": cfg,
            "sampler_name": "dpmpp_2m",
            "scheduler": "karras",
            "denoise": denoise_strength,
            "model": model_source,
            "positive": ["6", 0],
            "negative": ["7", 0],
            "latent_image": ["21", 0],
        },
    }

    # 7. VAE Decode
    workflow["8"] = {
        "class_type": "VAEDecode",
        "inputs": {
            "samples": ["3", 0],
            "vae": ["4", 2],
        },
    }

    # 8. Save
    workflow["9"] = {
        "class_type": "SaveImage",
        "inputs": {
            "filename_prefix": filename_prefix,
            "images": ["8", 0],
        },
    }

    return workflow


# ── Card Frame Generation ───────────────────────────────────────────────────

# Prompts for each card type frame — generates ornate borders with transparent-friendly center
FRAME_PROMPTS = {
    "attack": {
        "positive": (
            "thin ornate card game border frame only, cyberpunk warrior theme, "
            "glowing red and orange neon trim along outer edges only, "
            "sharp angular metallic corners, dark steel border with crimson energy veins, "
            "LARGE EMPTY BLACK CENTER taking up 80 percent of image, "
            "border details only on the thin outer edge, minimalist frame, "
            "game UI card border asset, red energy corner accents, "
            "battle-worn metal edge plating, thin circuit trace border"
        ),
        "negative": (
            "character, person, figure, face, hand, text, words, letters, numbers, "
            "center content, illustration in center, filled center, solid center, "
            "center design, center pattern, center image, center object, "
            "blurry, low quality, photo, 3d render, thick border, heavy border"
        ),
    },
    "skill": {
        "positive": (
            "thin ornate card game border frame only, cyberpunk tech defense theme, "
            "glowing cyan and blue neon trim along outer edges only, "
            "smooth curved metallic corners, dark steel border with blue energy veins, "
            "LARGE EMPTY BLACK CENTER taking up 80 percent of image, "
            "border details only on the thin outer edge, minimalist frame, "
            "game UI card border asset, blue holographic corner accents, "
            "shield engraved edge, thin data stream border pattern"
        ),
        "negative": (
            "character, person, figure, face, hand, text, words, letters, numbers, "
            "center content, illustration in center, filled center, solid center, "
            "center design, center pattern, center image, center object, "
            "blurry, low quality, photo, 3d render, thick border, heavy border"
        ),
    },
    "power": {
        "positive": (
            "thin ornate card game border frame only, cyberpunk divine power theme, "
            "glowing gold and amber neon trim along outer edges only, "
            "grand ornamental metallic corners, dark steel border with golden energy veins, "
            "LARGE EMPTY BLACK CENTER taking up 80 percent of image, "
            "border details only on the thin outer edge, minimalist frame, "
            "game UI card border asset, gold sacred geometry corner accents, "
            "divine engraved edge, thin radiant border pattern"
        ),
        "negative": (
            "character, person, figure, face, hand, text, words, letters, numbers, "
            "center content, illustration in center, filled center, solid center, "
            "center design, center pattern, center image, center object, "
            "blurry, low quality, photo, 3d render, thick border, heavy border"
        ),
    },
    "curse": {
        "positive": (
            "thin ornate card game border frame only, cyberpunk corruption theme, "
            "glowing purple and magenta neon trim along outer edges only, "
            "jagged corrupted metallic corners, dark steel border with violet energy veins, "
            "LARGE EMPTY BLACK CENTER taking up 80 percent of image, "
            "border details only on the thin outer edge, minimalist frame, "
            "game UI card border asset, purple glitch corner accents, "
            "corruption decay edge, thin void energy border cracks"
        ),
        "negative": (
            "character, person, figure, face, hand, text, words, letters, numbers, "
            "center content, illustration in center, filled center, solid center, "
            "center design, center pattern, center image, center object, "
            "blurry, low quality, photo, 3d render, thick border, heavy border"
        ),
    },
}


def card_frame_workflow(
    card_type: str,
    seed: Optional[int] = None,
    model: Optional[str] = None,
    lora_stack: Optional[list[dict]] = None,
) -> dict:
    """Build a txt2img workflow for generating a card frame texture.

    Generates at 512x768 (same as card art). The frame is designed to be
    overlaid on top of card art in the game engine.
    """
    config = load_config()
    if seed is None:
        seed = random.randint(0, 2**32 - 1)
    if model is None:
        model = config["default_model"]

    frame_data = FRAME_PROMPTS.get(card_type, FRAME_PROMPTS["skill"])
    positive = frame_data["positive"]
    negative = frame_data["negative"]

    # Prepend LoRA triggers if available
    if lora_stack:
        triggers = get_lora_triggers(lora_stack)
        if triggers:
            positive = triggers + ", " + positive

    return card_art_base_workflow(
        positive_prompt=positive,
        negative_prompt=negative,
        filename_prefix=f"frames/frame_{card_type}",
        seed=seed,
        width=512,
        height=768,
        steps=40,
        cfg=8.0,
        model=model,
        lora_stack=lora_stack,
    )


# ── Full Card Art Pipeline ───────────────────────────────────────────────────

def build_card_workflow(card_id: str, corruption_tier: int = 0,
                        seed: Optional[int] = None,
                        base_image_abs_path: Optional[str] = None) -> dict:
    """Build a complete workflow for a single card at a given corruption tier.

    Args:
        card_id: Card identifier from card_prompts.json
        corruption_tier: 0=clean, 1=tainted, 2=corrupted, 3=demonic
        seed: Optional fixed seed for reproducibility
        base_image_abs_path: Absolute path to the base card art (required for tier > 0).
            The image will be copied into ComfyUI's input/ directory automatically.

    Returns:
        ComfyUI API-format workflow dict
    """
    config = load_config()
    prompts_data = load_card_prompts()

    card = prompts_data["cards"].get(card_id)
    if not card:
        raise ValueError(f"Unknown card_id: {card_id}. "
                         f"Available: {list(prompts_data['cards'].keys())}")

    tag_styles = prompts_data["tag_styles"]
    type_styles = prompts_data["type_styles"]
    corruption_tiers = prompts_data["corruption_tiers"]

    # Resolve LoRA stack for this card's tags
    lora_stack = resolve_lora_stack(card, prompts_data, config)

    # Build prompts (with LoRA trigger words injected)
    positive = build_positive_prompt(
        card, tag_styles, type_styles, config,
        corruption_tier, corruption_tiers,
        lora_stack=lora_stack,
    )
    negative = build_negative_prompt(config)

    # Determine filename
    tier_data = corruption_tiers.get(str(corruption_tier), corruption_tiers["0"])
    suffix = tier_data["suffix"]
    filename_prefix = f"cards/{card_id}/{card_id}{suffix}"

    if corruption_tier == 0:
        # Base generation — txt2img with multi-LoRA
        return card_art_base_workflow(
            positive_prompt=positive,
            negative_prompt=negative,
            filename_prefix=filename_prefix,
            seed=seed,
            lora_stack=lora_stack,
        )
    else:
        # Corruption overlay — img2img from base with multi-LoRA
        if not base_image_abs_path:
            raise ValueError(f"base_image_abs_path required for corruption tier {corruption_tier}")

        # Stage the base image into ComfyUI's input/ directory
        staged_name = stage_image_for_comfyui(base_image_abs_path)

        return corruption_overlay_workflow(
            base_image_name=staged_name,
            corruption_prompt_addition=positive,
            negative_prompt=negative,
            denoise_strength=tier_data["denoise"],
            filename_prefix=filename_prefix,
            seed=seed,
            lora_stack=lora_stack,
        )


def build_batch_manifest(card_ids: Optional[list[str]] = None,
                         include_corruption: bool = False,
                         corruption_tiers: Optional[list[int]] = None) -> list[dict]:
    """Build a batch manifest of all workflows to generate.

    Args:
        card_ids: Specific cards to generate. None = all cards.
        include_corruption: Whether to also generate corruption variants.
        corruption_tiers: Which tiers to generate. Default [1,2,3] if include_corruption.

    Returns:
        List of dicts with {card_id, corruption_tier, seed, workflow}
    """
    prompts_data = load_card_prompts()

    if card_ids is None:
        card_ids = list(prompts_data["cards"].keys())

    if corruption_tiers is None:
        corruption_tiers = [1, 2, 3] if include_corruption else []

    manifest = []

    for card_id in card_ids:
        # Base art (tier 0) — always generated
        seed = random.randint(0, 2**32 - 1)
        manifest.append({
            "card_id": card_id,
            "corruption_tier": 0,
            "seed": seed,
            "filename": f"{card_id}_base.png",
        })

        # Corruption variants — use same seed for consistency
        for tier in corruption_tiers:
            manifest.append({
                "card_id": card_id,
                "corruption_tier": tier,
                "seed": seed,
                "filename": f"{card_id}_corrupt_t{tier}.png",
            })

    return manifest


# ── ComfyUI Importable Workflow Export ───────────────────────────────────────

def export_comfyui_workflow_json(output_path: Optional[str] = None) -> dict:
    """Export a ComfyUI-importable workflow JSON with node groups and defaults.

    This creates a template workflow that can be imported into ComfyUI's UI
    and manually customized. For batch generation, use the Python API instead.
    """
    # Build an example workflow for 'strike' as the template
    config = load_config()
    prompts_data = load_card_prompts()

    example_card = prompts_data["cards"]["strike"]
    tag_styles = prompts_data["tag_styles"]
    type_styles = prompts_data["type_styles"]

    positive = build_positive_prompt(example_card, tag_styles, type_styles, config)
    negative = build_negative_prompt(config)

    workflow = card_art_base_workflow(
        positive_prompt=positive,
        negative_prompt=negative,
        filename_prefix="cards/strike/strike_base",
        seed=42,
    )

    if output_path:
        with open(output_path, "w") as f:
            json.dump(workflow, f, indent=2)

    return workflow
