"""
deus.exe Item Art Workflow Builder
Generates ComfyUI API-format workflows for item icons:
- Equipment (HEAD, CHEST, WEAPON, ACCESSORY)
- Gems (gemstones with inner glow)
- Relics (ancient artifacts)

Uses the same multi-LoRA chain pattern as card_art_workflows.py.
Reuses the LoRA library from card_prompts.json.
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


def load_item_prompts():
    prompts_path = Path(__file__).parent / "item_prompts.json"
    with open(prompts_path) as f:
        return json.load(f)


def load_card_prompts():
    """Load card_prompts.json for LoRA library access."""
    prompts_path = Path(__file__).parent / "card_prompts.json"
    with open(prompts_path) as f:
        return json.load(f)


# -- LoRA Resolution --------------------------------------------------------

def resolve_item_loras(item: dict, item_prompts: dict, config: dict) -> list[dict]:
    """Resolve which LoRAs to apply for an item.

    Uses the LoRA library and tag mapping from card_prompts.json.
    Items get base LoRAs plus any type-specific LoRAs defined in
    item_types[type].lora_tags.
    """
    card_prompts = load_card_prompts()
    lora_library = card_prompts.get("lora_library", {})
    tag_mapping = card_prompts.get("tag_lora_mapping", {})
    max_loras = tag_mapping.get("max_loras", 3)

    lora_strengths = {}

    # 1. Base LoRAs (apply to every item)
    for lora_key, strength in tag_mapping.get("base", []):
        lora_strengths[lora_key] = strength

    # 2. Type-specific LoRA tags
    item_type = item.get("type", "")
    type_config = item_prompts.get("item_types", {}).get(item_type, {})
    lora_tags = type_config.get("lora_tags", [])

    for tag in lora_tags:
        tag_upper = tag.upper()
        for lora_key, strength in tag_mapping.get(tag_upper, []):
            if lora_key in lora_strengths:
                lora_strengths[lora_key] = max(lora_strengths[lora_key], strength)
            else:
                lora_strengths[lora_key] = strength

    # 3. Resolve to actual LoRA info, filtering by installed files
    comfyui_lora_dir = Path(config.get("comfyui_path", "E:/ComfyUI")) / "models" / "loras"
    resolved = []

    for lora_key, strength in lora_strengths.items():
        if lora_key not in lora_library:
            continue
        lora_info = lora_library[lora_key]
        filename = lora_info["filename"]

        if not (comfyui_lora_dir / filename).exists():
            continue

        resolved.append({
            "key": lora_key,
            "filename": filename,
            "strength": strength,
            "trigger": lora_info.get("trigger", ""),
        })

    resolved.sort(key=lambda x: x["strength"], reverse=True)
    return resolved[:max_loras]


def get_lora_triggers(lora_stack: list[dict]) -> str:
    """Extract trigger words from the LoRA stack."""
    triggers = [l["trigger"] for l in lora_stack if l.get("trigger")]
    return ", ".join(triggers)


# -- Prompt Assembly --------------------------------------------------------

def build_item_prompt(item: dict, item_prompts: dict, config: dict,
                      lora_stack: Optional[list[dict]] = None) -> str:
    """Assemble the full positive prompt for an item icon."""
    item_type = item.get("type", "")
    type_config = item_prompts.get("item_types", {}).get(item_type, {})
    rarity = item.get("rarity", 0)
    rarity_style = item_prompts.get("rarity_styles", {}).get(str(rarity), {})

    # LoRA trigger words go first
    lora_triggers = ""
    if lora_stack:
        lora_triggers = get_lora_triggers(lora_stack)

    parts = [lora_triggers]

    # Item-specific prompt
    parts.append(item["prompt"])

    # Style prefix
    parts.append(item_prompts.get("style_prefix", ""))

    # Type keywords
    type_keywords = type_config.get("keywords", "")
    parts.append(type_keywords)

    # Slot keywords (equipment only)
    if item_type == "equipment":
        slot = item.get("slot", "")
        slot_config = type_config.get("slots", {}).get(slot, {})
        parts.append(slot_config.get("keywords", ""))

    # Rarity keywords and glow
    parts.append(rarity_style.get("keywords", ""))
    parts.append(rarity_style.get("glow", ""))

    return ", ".join(p for p in parts if p)


def build_item_negative(item_prompts: dict) -> str:
    """Build the negative prompt for item art generation."""
    return item_prompts.get("style_negative",
        "text, words, letters, numbers, watermark, signature, blurry, "
        "low quality, person, character, hand, fingers, face, body, "
        "multiple objects, cluttered, background scene, landscape, "
        "3d render, photo, photorealistic, out of frame, cropped"
    )


# -- Workflow Builders -------------------------------------------------------

def item_art_workflow(
    positive_prompt: str,
    negative_prompt: str,
    filename_prefix: str = "item",
    seed: Optional[int] = None,
    width: int = 512,
    height: int = 512,
    steps: int = 30,
    cfg: float = 7.5,
    model: Optional[str] = None,
    lora_stack: Optional[list[dict]] = None,
) -> dict:
    """Build a txt2img SDXL workflow for item icon generation.

    Same node pattern as card_art_base_workflow: checkpoint -> LoRA chain ->
    CLIP encode -> KSampler -> VAE decode -> save.
    """
    config = load_config()

    if seed is None:
        seed = random.randint(0, 2**32 - 1)
    if model is None:
        model = config["default_model"]
    if lora_stack is None:
        lora_stack = []

    workflow = {}

    # 1. Checkpoint Loader
    workflow["4"] = {
        "class_type": "CheckpointLoaderSimple",
        "inputs": {
            "ckpt_name": model,
        },
    }

    model_source = ["4", 0]
    clip_source = ["4", 1]

    # 2. LoRA Chain
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

    # 3. CLIP Text Encode -- Positive
    workflow["6"] = {
        "class_type": "CLIPTextEncode",
        "inputs": {
            "text": positive_prompt,
            "clip": clip_source,
        },
    }

    # 4. CLIP Text Encode -- Negative
    workflow["7"] = {
        "class_type": "CLIPTextEncode",
        "inputs": {
            "text": negative_prompt,
            "clip": clip_source,
        },
    }

    # 5. Empty Latent Image (square for icons)
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


# -- Full Item Pipeline ------------------------------------------------------

def build_item_workflow(item_id: str, seed: Optional[int] = None) -> dict:
    """Build a complete workflow for a single item.

    Args:
        item_id: Item identifier from item_prompts.json
        seed: Optional fixed seed for reproducibility

    Returns:
        ComfyUI API-format workflow dict
    """
    config = load_config()
    item_prompts = load_item_prompts()

    item = item_prompts["items"].get(item_id)
    if not item:
        raise ValueError(f"Unknown item_id: {item_id}. "
                         f"Available: {list(item_prompts['items'].keys())}")

    # Resolve LoRA stack
    lora_stack = resolve_item_loras(item, item_prompts, config)

    # Build prompts
    positive = build_item_prompt(item, item_prompts, config, lora_stack=lora_stack)
    negative = build_item_negative(item_prompts)

    filename_prefix = f"items/{item_id}/{item_id}"

    return item_art_workflow(
        positive_prompt=positive,
        negative_prompt=negative,
        filename_prefix=filename_prefix,
        seed=seed,
        lora_stack=lora_stack,
    )


def build_item_manifest(item_ids: Optional[list[str]] = None) -> list[dict]:
    """Build a batch manifest of all item workflows to generate.

    Args:
        item_ids: Specific items to generate. None = all items.

    Returns:
        List of dicts with {item_id, seed, filename}
    """
    item_prompts = load_item_prompts()

    if item_ids is None:
        item_ids = list(item_prompts["items"].keys())

    manifest = []
    for item_id in item_ids:
        seed = random.randint(0, 2**32 - 1)
        manifest.append({
            "item_id": item_id,
            "seed": seed,
            "filename": f"{item_id}.png",
        })

    return manifest
