"""
Digital Genesis Card Art Batch Generator
CLI tool for generating all card art via ComfyUI API.

Usage:
    python generate_cards.py --all                     # Generate all 49 base cards
    python generate_cards.py --card strike             # Generate single card
    python generate_cards.py --card strike --corrupt    # Base + all corruption tiers
    python generate_cards.py --all --corrupt           # All cards + corruption variants
    python generate_cards.py --all --tier 1            # All cards + only tier 1 corruption
    python generate_cards.py --type ATTACK             # All attack cards
    python generate_cards.py --tag HOLY                # All cards with HOLY tag
    python generate_cards.py --character Netrunner     # Character-specific cards
    python generate_cards.py --list                    # List all card IDs
    python generate_cards.py --card strike --seed 42   # Fixed seed for reproducibility
    python generate_cards.py --export-workflow          # Export ComfyUI template JSON
    python generate_cards.py --dry-run --all           # Preview what would be generated
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path

# Add parent dir to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from comfyui_api import ComfyUIClient
from card_art_workflows import (
    build_card_workflow,
    build_batch_manifest,
    export_comfyui_workflow_json,
    load_card_prompts,
    load_config,
    build_positive_prompt,
    build_negative_prompt,
    resolve_lora_stack,
    card_frame_workflow,
)


def get_output_dir(config):
    """Get the card art output directory."""
    base = config.get("output_base", "E:/godot_games/card_game/assets")
    return Path(base) / "cards" / "illustrations"


def filter_cards_by_type(cards: dict, card_type: str) -> list[str]:
    """Filter card IDs by card type (ATTACK, SKILL, POWER, CURSE)."""
    return [cid for cid, data in cards.items()
            if data["card_type"].upper() == card_type.upper()]


def filter_cards_by_tag(cards: dict, tag: str) -> list[str]:
    """Filter card IDs that have a specific tag."""
    return [cid for cid, data in cards.items()
            if tag.upper() in [t.upper() for t in data["tags"]]]


def filter_cards_by_character(cards: dict, character: str) -> list[str]:
    """Filter card IDs by character class."""
    return [cid for cid, data in cards.items()
            if data.get("character", "").lower() == character.lower()]


def list_cards(prompts_data: dict):
    """Print all available cards grouped by type."""
    cards = prompts_data["cards"]

    # Group by type
    by_type = {}
    for cid, data in cards.items():
        ctype = data["card_type"]
        if ctype not in by_type:
            by_type[ctype] = []
        by_type[ctype].append((cid, data))

    print(f"\n{'='*60}")
    print(f"  Digital Genesis Card Art — {len(cards)} Cards")
    print(f"{'='*60}\n")

    for ctype in ["ATTACK", "SKILL", "POWER", "CURSE"]:
        if ctype not in by_type:
            continue
        entries = by_type[ctype]
        print(f"  {ctype} ({len(entries)} cards)")
        print(f"  {'-'*40}")
        for cid, data in sorted(entries, key=lambda x: x[0]):
            tags = ", ".join(data["tags"])
            char = f"  [{data['character']}]" if "character" in data else ""
            print(f"    {cid:<25} [{tags}]{char}")
        print()


def generate_card(client, card_id: str, corruption_tier: int, seed: int,
                  output_dir: Path, dry_run: bool = False):
    """Generate a single card image."""
    prompts_data = load_card_prompts()
    corruption_tiers = prompts_data["corruption_tiers"]
    tier_data = corruption_tiers.get(str(corruption_tier), corruption_tiers["0"])

    suffix = tier_data["suffix"]
    tier_name = tier_data["name"]
    card_name = prompts_data["cards"][card_id]["display_name"]

    if dry_run:
        print(f"  [DRY RUN] {card_id}{suffix}.png  "
              f"({card_name}, {tier_name}, seed={seed})")
        return

    print(f"  Generating: {card_id}{suffix}.png  "
          f"({card_name}, {tier_name}, seed={seed})")

    # For corruption tiers, we need the base image path
    base_image_path = None
    if corruption_tier > 0:
        base_image_path = str(output_dir / card_id / f"{card_id}_base.png")
        if not Path(base_image_path).exists():
            print(f"    -> SKIPPED: Base image not found at {base_image_path}")
            print(f"       Generate base art first: --card {card_id}")
            return

    # Build workflow
    workflow = build_card_workflow(card_id, corruption_tier, seed,
                                   base_image_abs_path=base_image_path)

    # Output path for this card
    card_dir = output_dir / card_id
    card_dir.mkdir(parents=True, exist_ok=True)

    # Queue, wait, and save via ComfyUI API
    try:
        saved = client.generate_and_save(workflow, str(card_dir), timeout=300)
        # Rename the generic "output.png" to our naming convention
        if saved:
            src = Path(saved[0])
            dst = card_dir / f"{card_id}{suffix}.png"
            if src.exists() and src != dst:
                if dst.exists():
                    dst.unlink()
                src.rename(dst)
            print(f"    -> Saved: {dst}")
        else:
            print(f"    -> WARNING: No images returned for {card_id}")
    except Exception as e:
        print(f"    -> ERROR: {e}")


def main():
    parser = argparse.ArgumentParser(
        description="Digital Genesis Card Art Batch Generator",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )

    # Selection options (mutually exclusive group for primary selection)
    select = parser.add_mutually_exclusive_group()
    select.add_argument("--all", action="store_true",
                        help="Generate all 49 cards")
    select.add_argument("--card", type=str,
                        help="Generate a specific card by ID")
    select.add_argument("--type", type=str,
                        help="Generate all cards of a type (ATTACK/SKILL/POWER/CURSE)")
    select.add_argument("--tag", type=str,
                        help="Generate all cards with a specific tag")
    select.add_argument("--character", type=str,
                        help="Generate character-specific cards (Netrunner/Sysadmin/Cryptomancer/WhiteHat)")
    select.add_argument("--list", action="store_true",
                        help="List all available cards")
    select.add_argument("--export-workflow", action="store_true",
                        help="Export the ComfyUI template workflow JSON")
    select.add_argument("--frames", action="store_true",
                        help="Generate card frame textures (attack/skill/power/curse)")
    select.add_argument("--lora-check", action="store_true",
                        help="Check which LoRAs are installed and show per-card LoRA assignments")

    # Generation options
    parser.add_argument("--corrupt", action="store_true",
                        help="Also generate corruption variants (tiers 1-3)")
    parser.add_argument("--tier", type=int, choices=[1, 2, 3],
                        help="Generate only a specific corruption tier")
    parser.add_argument("--seed", type=int, default=None,
                        help="Fixed seed for reproducibility")
    parser.add_argument("--dry-run", action="store_true",
                        help="Preview what would be generated without running")
    parser.add_argument("--output", type=str, default=None,
                        help="Custom output directory")

    # ComfyUI connection
    parser.add_argument("--url", type=str, default=None,
                        help="ComfyUI API URL (default from config.json)")

    args = parser.parse_args()

    # Load data
    config = load_config()
    prompts_data = load_card_prompts()
    cards = prompts_data["cards"]

    # Handle --list
    if args.list:
        list_cards(prompts_data)
        return

    # Handle --lora-check
    if args.lora_check:
        lora_library = prompts_data.get("lora_library", {})
        comfyui_lora_dir = Path(config.get("comfyui_path", "E:/ComfyUI")) / "models" / "loras"

        print(f"\n{'='*60}")
        print(f"  LoRA Library Status")
        print(f"  Directory: {comfyui_lora_dir}")
        print(f"{'='*60}\n")

        installed = 0
        missing = 0
        for key, info in lora_library.items():
            exists = (comfyui_lora_dir / info["filename"]).exists()
            status = "INSTALLED" if exists else "MISSING"
            icon = "+" if exists else "-"
            if exists:
                installed += 1
            else:
                missing += 1
            print(f"  [{icon}] {key:<25} {status}")
            print(f"      File: {info['filename']}")
            if info.get("source") and info["source"] != "local":
                print(f"      Download: {info['source']}")
            print()

        print(f"  {installed} installed, {missing} missing\n")

        if missing > 0:
            print("  Download missing LoRAs from the URLs above and place")
            print(f"  .safetensors files in: {comfyui_lora_dir}\n")

        # Show per-card LoRA assignments for first 10 cards
        print(f"{'='*60}")
        print(f"  Per-Card LoRA Assignments (sample)")
        print(f"{'='*60}\n")

        sample_cards = ["strike", "holy_wrath", "dark_compile", "net_spike",
                        "firewall_protocol", "curse_glitch", "divine_shield",
                        "backdoor", "sanctify", "berserker_virus"]
        for cid in sample_cards:
            if cid not in cards:
                continue
            card = cards[cid]
            stack = resolve_lora_stack(card, prompts_data, config)
            tags = ", ".join(card["tags"])
            loras = ", ".join(f"{l['key']}({l['strength']})" for l in stack) if stack else "(none installed)"
            print(f"  {cid:<22} [{tags}]")
            print(f"    -> {loras}")
        print()
        return

    # Handle --frames
    if args.frames:
        frame_types = ["attack", "skill", "power", "curse"]
        output_dir = Path(args.output) if args.output else Path(config.get("card_art_output", "E:/godot_games/card_game/assets/cards/illustrations"))
        frames_dir = output_dir.parent / "frames"

        print(f"\n{'='*60}")
        print(f"  Card Frame Generator — {len(frame_types)} frames")
        print(f"  Output: {frames_dir}")
        print(f"{'='*60}\n")

        if args.dry_run:
            for ft in frame_types:
                print(f"  [DRY RUN] frame_{ft}.png")
            return

        api_url = args.url or config.get("comfyui_url", "http://127.0.0.1:8188")
        client = ComfyUIClient(api_url)
        if not client.is_running():
            print(f"  ERROR: ComfyUI is not running at {api_url}")
            sys.exit(1)
        print(f"  Connected to ComfyUI at {api_url}\n")

        frames_dir.mkdir(parents=True, exist_ok=True)

        for ft in frame_types:
            seed = args.seed if args.seed else None
            print(f"  Generating: frame_{ft}.png (seed={seed or 'random'})")
            workflow = card_frame_workflow(ft, seed=seed)
            try:
                saved = client.generate_and_save(workflow, str(frames_dir), timeout=300)
                if saved:
                    src = Path(saved[0])
                    dst = frames_dir / f"frame_{ft}.png"
                    if src.exists() and src != dst:
                        if dst.exists():
                            dst.unlink()
                        src.rename(dst)
                    print(f"    -> Saved: {dst}")
                else:
                    print(f"    -> WARNING: No image returned for frame_{ft}")
            except Exception as e:
                print(f"    -> ERROR: {e}")

        print(f"\n  Done! Frames saved to {frames_dir}")
        print(f"  Copy to res://assets/cards/frames/ for Godot\n")
        return

    # Handle --export-workflow
    if args.export_workflow:
        out = Path(__file__).parent / "digital_genesis_card_art.json"
        export_comfyui_workflow_json(str(out))
        print(f"Exported ComfyUI workflow template to: {out}")
        return

    # Determine which cards to generate
    card_ids = []
    if args.all:
        card_ids = list(cards.keys())
    elif args.card:
        if args.card not in cards:
            print(f"ERROR: Unknown card '{args.card}'")
            print(f"Available: {', '.join(sorted(cards.keys()))}")
            sys.exit(1)
        card_ids = [args.card]
    elif args.type:
        card_ids = filter_cards_by_type(cards, args.type)
        if not card_ids:
            print(f"ERROR: No cards found with type '{args.type}'")
            sys.exit(1)
    elif args.tag:
        card_ids = filter_cards_by_tag(cards, args.tag)
        if not card_ids:
            print(f"ERROR: No cards found with tag '{args.tag}'")
            sys.exit(1)
    elif args.character:
        card_ids = filter_cards_by_character(cards, args.character)
        if not card_ids:
            print(f"ERROR: No cards found for character '{args.character}'")
            sys.exit(1)
    else:
        parser.print_help()
        return

    # Determine corruption tiers
    corruption_tiers = []
    if args.tier:
        corruption_tiers = [args.tier]
    elif args.corrupt:
        corruption_tiers = [1, 2, 3]

    # Build manifest
    manifest = build_batch_manifest(card_ids, include_corruption=bool(corruption_tiers),
                                     corruption_tiers=corruption_tiers or None)

    # Output dir
    output_dir = Path(args.output) if args.output else get_output_dir(config)

    # Summary
    base_count = len(card_ids)
    corrupt_count = len(card_ids) * len(corruption_tiers)
    total = base_count + corrupt_count

    print(f"\n{'='*60}")
    print(f"  Digital Genesis Card Art Generator")
    print(f"{'='*60}")
    print(f"  Cards:      {base_count} base images")
    if corruption_tiers:
        print(f"  Corruption: {corrupt_count} variants (tiers {corruption_tiers})")
    print(f"  Total:      {total} images")
    print(f"  Output:     {output_dir}")
    if args.seed:
        print(f"  Seed:       {args.seed} (fixed)")
    print(f"{'='*60}\n")

    if args.dry_run:
        print("  [DRY RUN MODE — no images will be generated]\n")

    # Connect to ComfyUI
    client = None
    if not args.dry_run:
        api_url = args.url or config.get("comfyui_url", "http://127.0.0.1:8188")
        client = ComfyUIClient(api_url)
        if not client.is_running():
            print(f"  ERROR: ComfyUI is not running at {api_url}")
            print(f"  Start it with: start_comfyui.bat")
            sys.exit(1)
        print(f"  Connected to ComfyUI at {api_url}\n")

    # Generate
    start_time = time.time()
    generated = 0
    errors = 0

    for item in manifest:
        card_id = item["card_id"]
        tier = item["corruption_tier"]
        seed = args.seed if args.seed else item["seed"]

        try:
            generate_card(client, card_id, tier, seed, output_dir, args.dry_run)
            generated += 1
        except Exception as e:
            print(f"  ERROR generating {card_id} tier {tier}: {e}")
            errors += 1

    elapsed = time.time() - start_time

    print(f"\n{'='*60}")
    print(f"  Complete: {generated}/{total} images in {elapsed:.1f}s")
    if errors:
        print(f"  Errors: {errors}")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    main()
