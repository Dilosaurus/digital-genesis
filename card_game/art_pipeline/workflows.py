"""
ComfyUI Workflow builders for Digital Genesis art pipeline.
Each function returns a workflow dict ready to queue via the API.
"""

import json
import random
from pathlib import Path


def load_config():
    config_path = Path(__file__).parent / "config.json"
    with open(config_path) as f:
        return json.load(f)


def _base_workflow(positive_prompt, negative_prompt=None, width=1024, height=1024,
                   seed=None, steps=None, cfg=None, model=None):
    """Build a standard txt2img SDXL workflow."""
    config = load_config()
    defaults = config["generation_defaults"]

    if seed is None:
        seed = random.randint(0, 2**32 - 1)
    if steps is None:
        steps = defaults["steps"]
    if cfg is None:
        cfg = defaults["cfg"]
    if model is None:
        model = config["default_model"]
    if negative_prompt is None:
        negative_prompt = config["style_negative"]

    # Determine LoRA config
    style_lora = config.get("style_lora", "")
    lora_strength = config.get("style_lora_strength", 0.7)

    # Model source: either direct checkpoint or checkpoint -> LoRA
    model_source = ["4", 0]
    clip_source = ["4", 1]

    workflow = {}

    workflow["4"] = {
        "class_type": "CheckpointLoaderSimple",
        "inputs": {
            "ckpt_name": model,
        },
    }

    # Add LoRA loader if configured
    if style_lora:
        workflow["10"] = {
            "class_type": "LoraLoader",
            "inputs": {
                "lora_name": style_lora,
                "strength_model": lora_strength,
                "strength_clip": lora_strength,
                "model": ["4", 0],
                "clip": ["4", 1],
            },
        }
        model_source = ["10", 0]
        clip_source = ["10", 1]

    workflow["3"] = {
        "class_type": "KSampler",
        "inputs": {
            "seed": seed,
            "steps": steps,
            "cfg": cfg,
            "sampler_name": defaults["sampler"],
            "scheduler": defaults["scheduler"],
            "denoise": defaults["denoise"],
            "model": model_source,
            "positive": ["6", 0],
            "negative": ["7", 0],
            "latent_image": ["5", 0],
        },
    }

    workflow["5"] = {
        "class_type": "EmptyLatentImage",
        "inputs": {
            "width": width,
            "height": height,
            "batch_size": defaults["batch_size"],
        },
    }

    workflow["6"] = {
        "class_type": "CLIPTextEncode",
        "inputs": {
            "text": positive_prompt,
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

    workflow["8"] = {
        "class_type": "VAEDecode",
        "inputs": {
            "samples": ["3", 0],
            "vae": ["4", 2],
        },
    }

    workflow["9"] = {
        "class_type": "SaveImage",
        "inputs": {
            "filename_prefix": "genesis",
            "images": ["8", 0],
        },
    }

    return workflow


def character_sheet_workflow(character_name, character_description, pose="front facing, full body"):
    """Generate a character sheet for a game character."""
    config = load_config()
    prompt = (
        f"{config['style_prefix']}"
        f"character design sheet, {character_description}, "
        f"{pose}, isolated on white background, "
        f"clearly separated limbs, puppet-ready, "
        f"flat 2D character, paper cutout style, "
        f"detailed character art, concept art, clean lines"
    )
    return _base_workflow(prompt)


def enemy_character_workflow(enemy_name, enemy_description, enemy_type="common"):
    """Generate an enemy character illustration."""
    config = load_config()
    size_hint = {
        "common": "medium-sized creature",
        "elite": "large imposing figure",
        "boss": "massive towering entity, intimidating presence",
    }.get(enemy_type, "creature")

    prompt = (
        f"{config['style_prefix']}"
        f"{enemy_description}, {size_hint}, "
        f"front facing, full body, isolated on white background, "
        f"flat 2D character, paper cutout style, menacing, "
        f"game enemy design, dark fantasy monster, detailed character art"
    )
    return _base_workflow(prompt)


def card_illustration_workflow(card_name, card_description, card_type="attack"):
    """Generate a card illustration."""
    config = load_config()
    type_mood = {
        "attack": "aggressive, violent, red energy",
        "skill": "defensive, mystical, blue energy",
        "power": "powerful, glowing, golden energy",
        "curse": "dark, corrupted, purple miasma",
    }.get(card_type, "mystical")

    prompt = (
        f"{config['style_prefix']}"
        f"game card illustration, {card_description}, "
        f"{type_mood}, "
        f"centered composition, square format, "
        f"dark fantasy game art, detailed illustration, "
        f"no text, no border, no frame"
    )
    return _base_workflow(prompt, width=1024, height=1024)


def icon_workflow(icon_name, icon_description, size_category="small"):
    """Generate an icon (status effect, relic, etc.)."""
    config = load_config()
    prompt = (
        f"{config['style_prefix']}"
        f"game icon, {icon_description}, "
        f"simple clear design, centered, "
        f"isolated on dark background, "
        f"detailed icon art, RPG game UI icon"
    )
    return _base_workflow(prompt, width=512, height=512, steps=25)


def background_workflow(scene_name, scene_description):
    """Generate a scene background at 1920x1080 (will be upscaled to 3440x1440)."""
    config = load_config()
    prompt = (
        f"{config['style_prefix']}"
        f"game background, {scene_description}, "
        f"wide angle, atmospheric, moody lighting, "
        f"dark fantasy environment, detailed background art, "
        f"no characters, empty scene"
    )
    return _base_workflow(prompt, width=1920, height=1080, steps=35)


def battle_background_workflow(arena_name, arena_description, boss_name=None):
    """Generate a widescreen battle background for combat encounters.
    Generates at 1344x768 (SDXL-friendly 16:9), intended for upscale to 3440x1440.
    """
    config = load_config()

    boss_hint = ""
    if boss_name:
        boss_hint = f"arena suited for {boss_name}, "

    prompt = (
        f"{config['style_prefix']}"
        f"battle arena background, {arena_description}, "
        f"{boss_hint}"
        f"wide panoramic view, symmetrical composition, "
        f"atmospheric depth, volumetric lighting, fog, particles in air, "
        f"dark fantasy environment, epic scale, towering architecture, "
        f"ominous mood, dramatic shadows, "
        f"no characters, no figures, no creatures, empty arena, "
        f"detailed environment concept art, matte painting style"
    )

    negative = (
        f"{config['style_negative']}, "
        f"people, characters, figures, creatures, monsters, "
        f"text, UI elements, HUD, border, frame, "
        f"cropped, split image, multiple panels"
    )

    return _base_workflow(prompt, negative_prompt=negative,
                          width=1344, height=768, steps=40, cfg=7.5)


def corruption_variant_workflow(base_description, corruption_tier):
    """Generate a corruption variant of a character."""
    config = load_config()
    tier_mods = {
        "tainted": "slightly darker skin, faint dark veins visible, amber tinted",
        "corrupted": "cracked skin with purple glow beneath, dark aura, purple energy leaking",
        "demonic": "fully transformed demonic appearance, red glowing eyes, flames, horns, dark red skin",
    }
    mod = tier_mods.get(corruption_tier, "")

    prompt = (
        f"{config['style_prefix']}"
        f"{base_description}, {mod}, "
        f"front facing, full body, isolated on white background, "
        f"flat 2D character, paper cutout style, detailed character art"
    )
    return _base_workflow(prompt)


# ── Character Expansion Workflows ──────────────────────────────────────────


def _load_pose_prompts():
    """Load pose prompt definitions."""
    path = Path(__file__).parent / "pose_prompts.json"
    with open(path) as f:
        return json.load(f)


def _load_animation_prompts():
    """Load animation frame definitions."""
    path = Path(__file__).parent / "animation_prompts.json"
    with open(path) as f:
        return json.load(f)


def _load_character_prompts():
    """Load character prompt definitions."""
    path = Path(__file__).parent / "character_prompts.json"
    with open(path) as f:
        return json.load(f)


def character_poses_workflow(
    character_id: str,
    pose_name: str,
    reference_image: str = None,
    seed: int = None,
    width: int = 512,
    height: int = 768,
    steps: int = 35,
    cfg: float = 7.5,
    ipadapter_strength: float = 0.45,
    model: str = None,
    lora_stack: list = None,
):
    """Build a txt2img workflow for generating a character in a specific pose.

    Uses action-first prompt structure: pose/action description comes FIRST,
    character details come SECOND. This ensures SDXL prioritizes the pose.
    The same LoRA stack as the original portrait maintains visual consistency.

    IPAdapter is NOT used — it overpowers pose prompts and locks characters
    into their reference pose. LoRA consistency is sufficient.

    Args:
        character_id: Character identifier (e.g., 'metatron', 'netrunner')
        pose_name: Pose from pose_prompts.json (e.g., 'attack', 'idle', 'death')
        reference_image: Unused (kept for API compat), was for IPAdapter
        lora_stack: List of {"filename", "strength", "trigger"} dicts
    """
    from card_art_workflows import card_art_base_workflow

    config = load_config()
    pose_data = _load_pose_prompts()
    char_prompts = _load_character_prompts()

    if seed is None:
        seed = random.randint(0, 2**32 - 1)
    if lora_stack is None:
        lora_stack = []

    # Build pose prompt
    common_pose = pose_data["common_poses"].get(pose_name, {})
    pose_suffix = common_pose.get("prompt_suffix", "")
    negative_extra = common_pose.get("negative_extra", "")

    # Check for character-specific pose override
    char_overrides = pose_data.get("character_overrides", {}).get(character_id, {})
    if pose_name in char_overrides:
        pose_suffix = char_overrides[pose_name]

    # Get character base description
    char_data = None
    for group in ["characters", "enemies"]:
        if character_id in char_prompts.get(group, {}):
            char_data = char_prompts[group][character_id]
            break

    if char_data is None:
        raise ValueError(f"Unknown character: {character_id}")

    style_prefix = char_prompts.get("style_prefix", "")
    style_suffix = char_prompts.get("style_suffix", "")
    base_negative = char_prompts.get("negative", "")

    # ACTION-FIRST prompt: pose description dominates, character details support
    # This is critical — putting the action first makes SDXL prioritize it
    positive_prompt = (
        f"{pose_suffix}, "
        f"dynamic action pose, dramatic angle, "
        f"{style_prefix}"
        f"{char_data['full_portrait']}, "
        f"isolated on dark background, clean edges{style_suffix}"
    )

    # Add anti-static terms to negative
    negative_prompt = base_negative
    if negative_extra:
        negative_prompt += f", {negative_extra}"
    negative_prompt += ", standing still, static pose, T-pose, symmetrical front-facing, stiff, mannequin pose"

    return card_art_base_workflow(
        positive_prompt=positive_prompt,
        negative_prompt=negative_prompt,
        filename_prefix=f"characters/{character_id}/poses/{pose_name}",
        seed=seed,
        width=width,
        height=height,
        steps=steps,
        cfg=cfg,
        model=model,
        lora_stack=lora_stack,
    )


def character_turnaround_workflow(
    reference_image: str,
    character_id: str,
    seed: int = None,
):
    """Build a Qwen Image Edit workflow that generates 8 camera angles from a single portrait.

    Uses the Qwen Image Edit model with the Multiple-angles LoRA to re-render
    the character from different viewpoints while maintaining consistency.

    Args:
        reference_image: Filename of the character portrait in ComfyUI's input/ directory
        character_id: Character identifier for output naming
        seed: Optional fixed seed

    Returns:
        ComfyUI API-format workflow dict with 8 output branches
    """
    if seed is None:
        seed = random.randint(0, 2**32 - 1)

    workflow = {}

    # 1. Load Qwen diffusion model
    workflow["10"] = {
        "class_type": "UNETLoader",
        "inputs": {
            "unet_name": "qwen_image_edit_2509_fp8_e4m3fn.safetensors",
            "weight_dtype": "default",
        },
    }

    # 2. Load CLIP text encoder
    workflow["11"] = {
        "class_type": "CLIPLoader",
        "inputs": {
            "clip_name": "qwen_2.5_vl_7b_fp8_scaled.safetensors",
            "type": "qwen2_vl",
        },
    }

    # 3. Load VAE
    workflow["12"] = {
        "class_type": "VAELoader",
        "inputs": {"vae_name": "qwen_image_vae.safetensors"},
    }

    # 4. LoRA: Multi-angle
    workflow["13"] = {
        "class_type": "LoraLoaderModelOnly",
        "inputs": {
            "lora_name": "Qwen-Edit-2509-Multiple-angles.safetensors",
            "strength_model": 1.0,
            "model": ["10", 0],
        },
    }

    # 5. LoRA: Lightning (4-step acceleration)
    workflow["14"] = {
        "class_type": "LoraLoaderModelOnly",
        "inputs": {
            "lora_name": "Qwen-Image-Edit-2509-Lightning-4steps-V1.0-bf16.safetensors",
            "strength_model": 1.0,
            "model": ["13", 0],
        },
    }

    # 6. Load character reference image
    workflow["20"] = {
        "class_type": "LoadImage",
        "inputs": {"image": reference_image},
    }

    # 7. Define angle prompts
    angles = [
        ("close_up", "Turn the camera to a close-up lens."),
        ("wide_shot", "Turn the camera to a wide-angle lens."),
        ("45_right", "Rotate the camera 45 degrees to the right."),
        ("90_right", "Rotate the camera 90 degrees to the right."),
        ("aerial_view", "Turn the camera to an aerial view."),
        ("low_angle", "Turn the camera to a low-angle view."),
        ("45_left", "Rotate the camera 45 degrees to the left."),
        ("90_left", "Rotate the camera 90 degrees to the left."),
    ]

    # 8. Create prompt nodes for each angle
    for i, (angle_name, angle_prompt) in enumerate(angles):
        prompt_node_id = str(50 + i)
        workflow[prompt_node_id] = {
            "class_type": "CLIPTextEncode",
            "inputs": {
                "text": angle_prompt,
                "clip": ["11", 0],
            },
        }

    # 9. Generate node (Qwen uses a custom generation node)
    # The Qwen workflow uses QwenImageEditGenerate which takes all prompts
    # We build one generation per angle for API compatibility
    for i, (angle_name, _) in enumerate(angles):
        prompt_node_id = str(50 + i)
        gen_node_id = str(60 + i)
        decode_node_id = str(70 + i)
        save_node_id = str(80 + i)

        # Qwen sampler
        workflow[gen_node_id] = {
            "class_type": "KSampler",
            "inputs": {
                "seed": seed + i,
                "steps": 4,
                "cfg": 1.0,
                "sampler_name": "euler",
                "scheduler": "normal",
                "denoise": 1.0,
                "model": ["14", 0],
                "positive": [prompt_node_id, 0],
                "negative": [prompt_node_id, 0],  # Qwen doesn't use separate negative
                "latent_image": ["20", 0],  # Reference image as latent source
            },
        }

        # VAE Decode
        workflow[decode_node_id] = {
            "class_type": "VAEDecode",
            "inputs": {
                "samples": [gen_node_id, 0],
                "vae": ["12", 0],
            },
        }

        # Save Image
        workflow[save_node_id] = {
            "class_type": "SaveImage",
            "inputs": {
                "filename_prefix": f"characters/{character_id}/turnaround/{angle_name}",
                "images": [decode_node_id, 0],
            },
        }

    return workflow


def character_animation_workflow(
    character_id: str,
    animation_name: str,
    frame_index: int,
    reference_image: str,
    skeleton_image: str,
    seed: int = None,
    width: int = 512,
    height: int = 768,
    steps: int = 35,
    cfg: float = 7.5,
    ipadapter_strength: float = 0.8,
    controlnet_strength: float = 0.85,
    model: str = None,
    lora_stack: list = None,
):
    """Build an IPAdapter + ControlNet OpenPose workflow for a single animation frame.

    Combines IPAdapter (character consistency from reference portrait) with
    ControlNet OpenPose (exact pose control from skeleton image) to generate
    precise animation frames.

    Args:
        character_id: Character identifier
        animation_name: Animation from animation_prompts.json (e.g., 'idle', 'attack_melee')
        frame_index: Which frame in the animation sequence (0-based)
        reference_image: Character portrait filename in ComfyUI's input/ directory
        skeleton_image: OpenPose skeleton filename in ComfyUI's input/ directory
        ipadapter_strength: Character likeness enforcement (0.0-1.0)
        controlnet_strength: Pose adherence (0.0-1.0)
        lora_stack: List of {"filename", "strength", "trigger"} dicts
    """
    config = load_config()
    anim_data = _load_animation_prompts()
    char_prompts = _load_character_prompts()
    pose_data = _load_pose_prompts()

    if seed is None:
        seed = random.randint(0, 2**32 - 1)
    if model is None:
        model = config["default_model"]
    if lora_stack is None:
        lora_stack = []

    # Get animation definition
    animation = anim_data["animations"].get(animation_name)
    if animation is None:
        raise ValueError(f"Unknown animation: {animation_name}")

    if frame_index >= len(animation["frames"]):
        raise ValueError(f"Frame {frame_index} out of range for {animation_name} "
                         f"(has {len(animation['frames'])} frames)")

    frame = animation["frames"][frame_index]

    # Get character description
    char_data = None
    for group in ["characters", "enemies"]:
        if character_id in char_prompts.get(group, {}):
            char_data = char_prompts[group][character_id]
            break
    if char_data is None:
        raise ValueError(f"Unknown character: {character_id}")

    style_prefix = char_prompts.get("style_prefix", "")
    style_suffix = char_prompts.get("style_suffix", "")
    base_negative = char_prompts.get("negative", "")

    # Build prompt with frame-specific hints
    positive_prompt = (
        f"{style_prefix}{char_data['full_portrait']}, "
        f"{frame['prompt_hint']}, "
        f"full body, isolated on dark background, clean edges{style_suffix}"
    )

    workflow = {}

    # 1. Checkpoint
    workflow["4"] = {
        "class_type": "CheckpointLoaderSimple",
        "inputs": {"ckpt_name": model},
    }

    model_source = ["4", 0]
    clip_source = ["4", 1]

    # 2. LoRA chain
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

    # 3. Load reference image for IPAdapter
    workflow["30"] = {
        "class_type": "LoadImage",
        "inputs": {"image": reference_image},
    }

    # 4. IPAdapter Unified Loader
    workflow["33"] = {
        "class_type": "IPAdapterUnifiedLoader",
        "inputs": {
            "model": model_source,
            "preset": "PLUS (high strength)",
        },
    }

    # 5. IPAdapter Apply
    workflow["34"] = {
        "class_type": "IPAdapter",
        "inputs": {
            "ipadapter": ["33", 1],
            "image": ["30", 0],
            "model": ["33", 0],
            "weight": ipadapter_strength,
            "weight_type": "standard",
            "start_at": 0.0,
            "end_at": 1.0,
        },
    }
    model_source = ["34", 0]

    # 6. Load skeleton image for ControlNet
    workflow["40"] = {
        "class_type": "LoadImage",
        "inputs": {"image": skeleton_image},
    }

    # 7. ControlNet OpenPose
    workflow["41"] = {
        "class_type": "ControlNetLoader",
        "inputs": {"control_net_name": "OpenPoseXL2.safetensors"},
    }
    workflow["42"] = {
        "class_type": "ControlNetApplyAdvanced",
        "inputs": {
            "positive": ["6", 0],
            "negative": ["7", 0],
            "control_net": ["41", 0],
            "image": ["40", 0],
            "strength": controlnet_strength,
            "start_percent": 0.0,
            "end_percent": 1.0,
        },
    }

    # 8. CLIP Text Encode
    workflow["6"] = {
        "class_type": "CLIPTextEncode",
        "inputs": {"text": positive_prompt, "clip": clip_source},
    }
    workflow["7"] = {
        "class_type": "CLIPTextEncode",
        "inputs": {"text": base_negative, "clip": clip_source},
    }

    # 9. Empty Latent
    workflow["5"] = {
        "class_type": "EmptyLatentImage",
        "inputs": {"width": width, "height": height, "batch_size": 1},
    }

    # 10. KSampler — uses ControlNet-modified conditioning
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
            "positive": ["42", 0],  # ControlNet-modified positive
            "negative": ["42", 1],  # ControlNet-modified negative
            "latent_image": ["5", 0],
        },
    }

    # 11. VAE Decode
    workflow["8"] = {
        "class_type": "VAEDecode",
        "inputs": {"samples": ["3", 0], "vae": ["4", 2]},
    }

    # 12. Save
    workflow["9"] = {
        "class_type": "SaveImage",
        "inputs": {
            "filename_prefix": f"characters/{character_id}/animations/{animation_name}/frame_{frame_index:02d}",
            "images": ["8", 0],
        },
    }

    return workflow
