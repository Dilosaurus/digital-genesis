"""
deus.exe Character Art Generator
Generates character puppet parts via ComfyUI for the puppet rig system.

Usage:
    python generate_characters.py --character netrunner     # Full portrait + all parts
    python generate_characters.py --character netrunner --portrait-only  # Just the full portrait
    python generate_characters.py --character netrunner --parts-only     # Just body parts
    python generate_characters.py --all                     # All characters + enemies
    python generate_characters.py --all-players             # Just 5 player characters
    python generate_characters.py --all-enemies             # Just enemies
    python generate_characters.py --list                    # List all character/enemy IDs
    python generate_characters.py --dry-run --all           # Preview without generating

    # Character Expansion (poses, turnarounds, animation)
    python generate_characters.py --character metatron --poses           # All pose variants
    python generate_characters.py --character metatron --pose attack     # Single pose
    python generate_characters.py --character metatron --turnaround      # 8-angle turnaround
    python generate_characters.py --character metatron --animate idle    # Single animation
    python generate_characters.py --character metatron --animate-all     # All animations
    python generate_characters.py --character metatron --sheet idle      # Assemble sprite sheet
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from comfyui_api import ComfyUIClient
from card_art_workflows import (
    load_config, resolve_lora_stack, load_card_prompts, card_art_base_workflow,
    stage_image_for_comfyui,
)
from workflows import (
    character_poses_workflow, character_turnaround_workflow,
    character_animation_workflow, _load_pose_prompts, _load_animation_prompts,
)
from postprocess import assemble_sprite_sheet


def load_character_prompts():
    path = Path(__file__).parent / "character_prompts.json"
    with open(path) as f:
        return json.load(f)



def resolve_character_loras(lora_keys: list, prompts_data: dict, config: dict) -> list:
    """Resolve LoRA stack from character's lora key list."""
    lora_library = prompts_data.get("lora_library", {})
    comfyui_lora_dir = Path(config.get("comfyui_path", "E:/ComfyUI")) / "models" / "loras"

    resolved = []
    for key in lora_keys:
        if key not in lora_library:
            continue
        info = lora_library[key]
        filename = info["filename"]
        if not (comfyui_lora_dir / filename).exists():
            continue
        resolved.append({
            "key": key,
            "filename": filename,
            "strength": info.get("default_strength", 0.4),
            "trigger": info.get("trigger", ""),
        })
    return resolved[:3]


def generate_character(char_id: str, char_data: dict, char_prompts: dict,
                       card_prompts_data: dict, config: dict, client: ComfyUIClient,
                       output_base: Path, seed: int, dry_run: bool,
                       portrait_only: bool = False, parts_only: bool = False) -> int:
    """Generate art for one character. Returns number of images generated."""
    meta = char_prompts["meta"]
    style_prefix = char_prompts["style_prefix"]
    style_suffix = char_prompts["style_suffix"]
    negative = char_prompts["negative"]
    count = 0

    lora_stack = resolve_character_loras(
        char_data.get("loras", []), card_prompts_data, config)

    # All characters (players + enemies) go under assets/characters/{id}/ so the
    # puppet system and enemy_display can find them at a single consistent path.
    out_dir = output_base / "characters" / char_id

    # Full portrait (also saved as fullbody.png for the puppet system)
    if not parts_only:
        portrait_prompt = style_prefix + char_data["full_portrait"] + style_suffix
        out_path = out_dir / "portrait.png"
        fullbody_path = out_dir / "fullbody.png"
        out_dir.mkdir(parents=True, exist_ok=True)

        if dry_run:
            print(f"  [DRY RUN] characters/{char_id}/portrait.png + fullbody.png")
        else:
            print(f"  Generating: characters/{char_id}/portrait.png (seed={seed})")
            workflow = card_art_base_workflow(
                positive_prompt=portrait_prompt,
                negative_prompt=negative,
                filename_prefix=f"characters/{char_id}/portrait",
                seed=seed,
                width=meta["resolution"]["width"],
                height=meta["resolution"]["height"],
                lora_stack=lora_stack,
            )
            try:
                saved = client.generate_and_save(workflow, str(out_dir), timeout=300)
                if saved:
                    src = Path(saved[0])
                    if src.exists() and src != out_path:
                        if out_path.exists():
                            out_path.unlink()
                        src.rename(out_path)
                    import shutil
                    if out_path.exists():
                        shutil.copy2(str(out_path), str(fullbody_path))
                    print(f"    -> Saved: {out_path} + {fullbody_path}")
            except Exception as e:
                print(f"    -> ERROR: {e}")
        count += 1

    # Body parts
    if not portrait_only and "parts" in char_data:
        parts_dir = out_dir / "parts"
        parts_dir.mkdir(parents=True, exist_ok=True)
        pw = meta["part_resolution"]["width"]
        ph = meta["part_resolution"]["height"]

        for part_name, part_prompt_text in char_data["parts"].items():
            full_prompt = style_prefix + part_prompt_text + ", isolated body part on black background, clean edges, no other body parts visible" + style_suffix
            part_path = parts_dir / f"{part_name}.png"

            if dry_run:
                print(f"  [DRY RUN] characters/{char_id}/parts/{part_name}.png")
            else:
                print(f"  Generating: characters/{char_id}/parts/{part_name}.png (seed={seed})")
                part_seed = seed + hash(part_name) % 10000
                workflow = card_art_base_workflow(
                    positive_prompt=full_prompt,
                    negative_prompt=negative + ", multiple body parts, full body, other limbs visible",
                    filename_prefix=f"characters/{char_id}/parts/{part_name}",
                    seed=part_seed,
                    width=pw,
                    height=ph,
                    lora_stack=lora_stack,
                )
                try:
                    saved = client.generate_and_save(workflow, str(parts_dir), timeout=300)
                    if saved:
                        src = Path(saved[0])
                        if src.exists() and src != part_path:
                            if part_path.exists():
                                part_path.unlink()
                            src.rename(part_path)
                        print(f"    -> Saved: {part_path}")
                except Exception as e:
                    print(f"    -> ERROR: {e}")
            count += 1

    return count


def generate_poses(char_id: str, char_data: dict, char_prompts: dict,
                   card_prompts_data: dict, config: dict, client: ComfyUIClient,
                   output_base: Path, seed: int, dry_run: bool,
                   pose_name: str = None) -> int:
    """Generate pose variants for a character using IPAdapter. Returns image count."""
    pose_data = _load_pose_prompts()
    count = 0

    # Determine which poses to generate
    all_chars = {**char_prompts.get("characters", {}), **char_prompts.get("enemies", {})}
    is_player = char_id in char_prompts.get("characters", {})

    if pose_name:
        poses = [pose_name]
    else:
        default_key = "player_default_poses" if is_player else "enemy_default_poses"
        poses = pose_data.get(default_key, ["idle", "attack", "hit", "death"])

    # Resolve LoRAs
    lora_stack = resolve_character_loras(
        char_data.get("loras", []), card_prompts_data, config)

    for p in poses:
        if dry_run:
            print(f"  [DRY RUN] characters/{char_id}/poses/{p}.png")
        else:
            print(f"  Generating: characters/{char_id}/poses/{p}.png (seed={seed})")
            workflow = character_poses_workflow(
                character_id=char_id,
                pose_name=p,
                seed=seed + hash(p) % 10000,
                lora_stack=lora_stack,
            )
            pose_dir = output_base / "characters" / char_id / "poses"
            pose_dir.mkdir(parents=True, exist_ok=True)
            try:
                saved = client.generate_and_save(workflow, str(pose_dir), timeout=300)
                if saved:
                    src = Path(saved[0])
                    dst = pose_dir / f"{p}.png"
                    if src.exists() and src != dst:
                        if dst.exists():
                            dst.unlink()
                        src.rename(dst)
                    print(f"    -> Saved: {dst}")
            except Exception as e:
                print(f"    -> ERROR: {e}")
        count += 1

    return count


def generate_turnaround(char_id: str, config: dict, client: ComfyUIClient,
                        output_base: Path, seed: int, dry_run: bool) -> int:
    """Generate 8-angle turnaround via Qwen Image Edit. Returns image count."""
    portrait_path = output_base / "characters" / char_id / "portrait.png"
    if not portrait_path.exists() and not dry_run:
        print(f"    WARNING: No portrait found at {portrait_path} — generate portrait first")
        return 0

    angles = ["close_up", "wide_shot", "45_right", "90_right",
              "aerial_view", "low_angle", "45_left", "90_left"]

    if dry_run:
        for angle in angles:
            print(f"  [DRY RUN] characters/{char_id}/turnaround/{angle}.png")
        return len(angles)

    # Stage reference
    staged_ref = stage_image_for_comfyui(str(portrait_path))

    print(f"  Generating: {len(angles)} turnaround angles for {char_id} (seed={seed})")
    workflow = character_turnaround_workflow(
        reference_image=staged_ref,
        character_id=char_id,
        seed=seed,
    )

    turnaround_dir = output_base / "characters" / char_id / "turnaround"
    turnaround_dir.mkdir(parents=True, exist_ok=True)

    try:
        saved = client.generate_and_save(workflow, str(turnaround_dir), timeout=600)
        for f in saved:
            print(f"    -> Saved: {f}")
    except Exception as e:
        print(f"    -> ERROR: {e}")

    return len(angles)


def generate_animation(char_id: str, char_data: dict, char_prompts: dict,
                       card_prompts_data: dict, config: dict, client: ComfyUIClient,
                       output_base: Path, seed: int, dry_run: bool,
                       animation_name: str = None) -> int:
    """Generate animation frames via IPAdapter + ControlNet OpenPose. Returns frame count."""
    anim_data = _load_animation_prompts()
    count = 0

    # Determine which animations
    if animation_name:
        anims = [animation_name]
    else:
        char_anims = anim_data.get("character_animation_map", {}).get(char_id, [])
        anims = char_anims if char_anims else ["idle", "attack_melee", "hit", "death"]

    portrait_path = output_base / "characters" / char_id / "portrait.png"
    if not portrait_path.exists() and not dry_run:
        print(f"    WARNING: No portrait found at {portrait_path}")
        return 0

    staged_ref = None
    if not dry_run:
        staged_ref = stage_image_for_comfyui(str(portrait_path))

    lora_stack = resolve_character_loras(
        char_data.get("loras", []), card_prompts_data, config)

    skeleton_dir = Path(__file__).parent / "pose_skeletons"

    for anim_name in anims:
        anim_def = anim_data["animations"].get(anim_name)
        if anim_def is None:
            print(f"    WARNING: Unknown animation '{anim_name}' — skipping")
            continue

        anim_out_dir = output_base / "characters" / char_id / "animations" / anim_name
        anim_out_dir.mkdir(parents=True, exist_ok=True)

        for frame_idx, frame_def in enumerate(anim_def["frames"]):
            skeleton_path = skeleton_dir / frame_def["skeleton"]

            if dry_run:
                skel_status = "OK" if skeleton_path.exists() else "MISSING SKELETON"
                print(f"  [DRY RUN] characters/{char_id}/animations/{anim_name}/frame_{frame_idx:02d}.png  [{skel_status}]")
            else:
                if not skeleton_path.exists():
                    print(f"    SKIP frame {frame_idx}: skeleton not found at {skeleton_path}")
                    count += 1
                    continue

                staged_skel = stage_image_for_comfyui(str(skeleton_path))
                print(f"  Generating: {char_id}/animations/{anim_name}/frame_{frame_idx:02d}.png (seed={seed})")

                workflow = character_animation_workflow(
                    character_id=char_id,
                    animation_name=anim_name,
                    frame_index=frame_idx,
                    reference_image=staged_ref,
                    skeleton_image=staged_skel,
                    seed=seed + frame_idx,
                    lora_stack=lora_stack,
                )

                try:
                    saved = client.generate_and_save(workflow, str(anim_out_dir), timeout=300)
                    if saved:
                        src = Path(saved[0])
                        dst = anim_out_dir / f"frame_{frame_idx:02d}.png"
                        if src.exists() and src != dst:
                            if dst.exists():
                                dst.unlink()
                            src.rename(dst)
                        print(f"    -> Saved: {dst}")
                except Exception as e:
                    print(f"    -> ERROR: {e}")

            count += 1

    return count


def main():
    parser = argparse.ArgumentParser(description="Generate character puppet art via ComfyUI")
    parser.add_argument("--character", type=str, help="Generate specific character by ID")
    parser.add_argument("--all", action="store_true", help="Generate all characters + enemies")
    parser.add_argument("--all-players", action="store_true", help="Generate all 5 player characters")
    parser.add_argument("--all-enemies", action="store_true", help="Generate all enemies")
    parser.add_argument("--portrait-only", action="store_true", help="Only generate full portraits")
    parser.add_argument("--parts-only", action="store_true", help="Only generate body parts")
    parser.add_argument("--seed", type=int, default=42, help="Base seed for generation")
    parser.add_argument("--list", action="store_true", help="List all character/enemy IDs")
    parser.add_argument("--dry-run", action="store_true", help="Preview without generating")

    # Character expansion options
    parser.add_argument("--poses", action="store_true",
                        help="Generate all pose variants (IPAdapter)")
    parser.add_argument("--pose", type=str,
                        help="Generate a specific pose (e.g., attack, idle, death)")
    parser.add_argument("--turnaround", action="store_true",
                        help="Generate 8-angle turnaround sheet (Qwen Image Edit)")
    parser.add_argument("--animate", type=str,
                        help="Generate a specific animation (e.g., idle, attack_melee)")
    parser.add_argument("--animate-all", action="store_true",
                        help="Generate all animation frames for the character")
    parser.add_argument("--sheet", type=str,
                        help="Assemble sprite sheet from animation frames (e.g., idle)")

    args = parser.parse_args()
    config = load_config()
    char_prompts = load_character_prompts()
    card_prompts_data = load_card_prompts()

    players = char_prompts.get("characters", {})
    enemies = char_prompts.get("enemies", {})

    if args.list:
        print("\nPlayer Characters:")
        for cid, data in players.items():
            print(f"  {cid:<20} {data.get('display_name', '')} — {data.get('title', '')}")
            parts = list(data.get("parts", {}).keys())
            print(f"    Parts: {', '.join(parts)}")
        print("\nEnemies:")
        for eid, data in enemies.items():
            parts = list(data.get("parts", {}).keys())
            print(f"  {eid:<20} Parts: {', '.join(parts)}")
        return

    # Handle sprite sheet assembly (no ComfyUI needed)
    if args.sheet and args.character:
        output_base = Path(config.get("output_base", "E:/godot_games/card_game/assets"))
        cid = args.character.lower()
        frame_dir = output_base / "characters" / cid / "animations" / args.sheet
        sheet_dir = output_base / "characters" / cid / "sheets"
        sheet_dir.mkdir(parents=True, exist_ok=True)
        sheet_path = sheet_dir / f"{args.sheet}_sheet.png"
        assemble_sprite_sheet(frame_dir, sheet_path, remove_bg=True)
        return

    # Determine expansion mode
    expansion_mode = None
    if args.poses or args.pose:
        expansion_mode = "poses"
    elif args.turnaround:
        expansion_mode = "turnaround"
    elif args.animate or args.animate_all:
        expansion_mode = "animate"

    # Build target list
    targets = {}
    if args.character:
        cid = args.character.lower()
        if cid in players:
            targets[cid] = players[cid]
        elif cid in enemies:
            targets[cid] = enemies[cid]
        else:
            print(f"Error: Unknown character '{cid}'")
            sys.exit(1)
    elif args.all:
        targets.update(players)
        targets.update(enemies)
    elif args.all_players:
        targets.update(players)
    elif args.all_enemies:
        targets.update(enemies)
    else:
        parser.print_help()
        return

    output_base = Path(config.get("output_base", "E:/godot_games/card_game/assets"))

    # Count expected images
    total = 0
    if expansion_mode == "poses":
        pose_data = _load_pose_prompts()
        for cid in targets:
            if args.pose:
                total += 1
            else:
                is_player = cid in players
                key = "player_default_poses" if is_player else "enemy_default_poses"
                total += len(pose_data.get(key, []))
    elif expansion_mode == "turnaround":
        total = len(targets) * 8
    elif expansion_mode == "animate":
        anim_data = _load_animation_prompts()
        for cid in targets:
            if args.animate:
                anim = anim_data["animations"].get(args.animate, {})
                total += len(anim.get("frames", []))
            else:
                char_anims = anim_data.get("character_animation_map", {}).get(cid, [])
                for a in char_anims:
                    total += len(anim_data["animations"].get(a, {}).get("frames", []))
    else:
        for cid, data in targets.items():
            if not args.parts_only:
                total += 1
            if not args.portrait_only and "parts" in data:
                total += len(data["parts"])

    mode_label = expansion_mode or "portrait+parts"
    print(f"\n{'='*60}")
    print(f"  deus.exe Character Art Generator")
    print(f"{'='*60}")
    print(f"  Mode:       {mode_label}")
    print(f"  Characters: {len(targets)}")
    print(f"  Images:     {total}")
    print(f"  Output:     {output_base}")
    print(f"  Seed:       {args.seed}")
    print(f"{'='*60}\n")

    if not args.dry_run:
        client = ComfyUIClient(config.get("comfyui_url", "http://127.0.0.1:8188"))
        if not client.is_running():
            print(f"  ERROR: ComfyUI not running at {client.server_url}")
            print(f"  Start it with: start_comfyui.bat")
            sys.exit(1)
        print(f"  Connected to ComfyUI at {client.server_url}\n")
    else:
        client = None
        print("  [DRY RUN MODE — no images will be generated]\n")

    generated = 0
    start_time = time.time()

    for cid, data in targets.items():
        print(f"\n  === {cid} ===")

        if expansion_mode == "poses":
            n = generate_poses(
                cid, data, char_prompts, card_prompts_data, config, client,
                output_base, args.seed, args.dry_run,
                pose_name=args.pose)
        elif expansion_mode == "turnaround":
            n = generate_turnaround(
                cid, config, client, output_base, args.seed, args.dry_run)
        elif expansion_mode == "animate":
            n = generate_animation(
                cid, data, char_prompts, card_prompts_data, config, client,
                output_base, args.seed, args.dry_run,
                animation_name=args.animate)
        else:
            n = generate_character(
                cid, data, char_prompts, card_prompts_data, config, client,
                output_base, args.seed, args.dry_run,
                args.portrait_only, args.parts_only)
        generated += n

    elapsed = time.time() - start_time
    print(f"\n{'='*60}")
    print(f"  Complete: {generated}/{total} images in {elapsed:.1f}s")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    main()
