"""
Digital Genesis Item Art Batch Generator
CLI tool for generating equipment, gem, and relic art via ComfyUI API.

Usage:
    python generate_items.py --all                      # Generate all 28 items
    python generate_items.py --item iron_helm            # Generate single item
    python generate_items.py --type equipment            # All equipment
    python generate_items.py --type gem                  # All gems
    python generate_items.py --type relic                # All relics
    python generate_items.py --slot HEAD                 # All head equipment
    python generate_items.py --rarity 2                  # All rare items
    python generate_items.py --list                      # List all item IDs
    python generate_items.py --item vajra --seed 42      # Fixed seed
    python generate_items.py --dry-run --all             # Preview without generating
"""

import argparse
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from comfyui_api import ComfyUIClient
from item_art_workflows import (
    build_item_workflow,
    build_item_manifest,
    load_item_prompts,
    load_config,
    build_item_prompt,
    build_item_negative,
    resolve_item_loras,
)


def get_output_dir(config):
    """Get the item art output directory."""
    base = config.get("output_base", "E:/godot_games/card_game/assets")
    return Path(base) / "items" / "illustrations"


def filter_by_type(items: dict, item_type: str) -> list[str]:
    """Filter item IDs by type (equipment, gem, relic)."""
    return [iid for iid, data in items.items()
            if data["type"].lower() == item_type.lower()]


def filter_by_slot(items: dict, slot: str) -> list[str]:
    """Filter equipment item IDs by slot."""
    return [iid for iid, data in items.items()
            if data.get("type") == "equipment"
            and data.get("slot", "").upper() == slot.upper()]


def filter_by_rarity(items: dict, rarity: int) -> list[str]:
    """Filter item IDs by rarity tier."""
    return [iid for iid, data in items.items()
            if data.get("rarity", 0) == rarity]


def list_items(item_prompts: dict):
    """Print all available items grouped by type."""
    items = item_prompts["items"]
    rarity_styles = item_prompts.get("rarity_styles", {})

    by_type = {}
    for iid, data in items.items():
        itype = data["type"]
        if itype not in by_type:
            by_type[itype] = []
        by_type[itype].append((iid, data))

    print(f"\n{'='*60}")
    print(f"  Digital Genesis Item Art — {len(items)} Items")
    print(f"{'='*60}\n")

    for itype in ["equipment", "gem", "relic"]:
        if itype not in by_type:
            continue
        entries = by_type[itype]
        print(f"  {itype.upper()} ({len(entries)} items)")
        print(f"  {'-'*40}")
        for iid, data in sorted(entries, key=lambda x: x[0]):
            rarity = data.get("rarity", 0)
            rarity_label = rarity_styles.get(str(rarity), {}).get("label", "?")
            slot = f"  [{data['slot']}]" if data.get("slot") else ""
            print(f"    {iid:<28} {rarity_label:<10}{slot}")
        print()


def generate_item(client, item_id: str, seed: int,
                  output_dir: Path, dry_run: bool = False):
    """Generate a single item image."""
    item_prompts = load_item_prompts()
    item = item_prompts["items"][item_id]
    display_name = item.get("display_name", item_id)
    rarity_styles = item_prompts.get("rarity_styles", {})
    rarity_label = rarity_styles.get(str(item.get("rarity", 0)), {}).get("label", "?")

    if dry_run:
        print(f"  [DRY RUN] {item_id}.png  "
              f"({display_name}, {item['type']}, {rarity_label}, seed={seed})")
        return

    print(f"  Generating: {item_id}.png  "
          f"({display_name}, {item['type']}, {rarity_label}, seed={seed})")

    workflow = build_item_workflow(item_id, seed)

    item_dir = output_dir / item_id
    item_dir.mkdir(parents=True, exist_ok=True)

    try:
        saved = client.generate_and_save(workflow, str(item_dir), timeout=300)
        if saved:
            src = Path(saved[0])
            dst = item_dir / f"{item_id}.png"
            if src.exists() and src != dst:
                if dst.exists():
                    dst.unlink()
                src.rename(dst)
            print(f"    -> Saved: {dst}")
        else:
            print(f"    -> WARNING: No images returned for {item_id}")
    except Exception as e:
        print(f"    -> ERROR: {e}")


def main():
    parser = argparse.ArgumentParser(
        description="Digital Genesis Item Art Batch Generator",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )

    # Selection options
    select = parser.add_mutually_exclusive_group()
    select.add_argument("--all", action="store_true",
                        help="Generate all 28 items")
    select.add_argument("--item", type=str,
                        help="Generate a specific item by ID")
    select.add_argument("--type", type=str,
                        help="Generate all items of a type (equipment/gem/relic)")
    select.add_argument("--slot", type=str,
                        help="Generate all equipment in a slot (HEAD/CHEST/WEAPON/ACCESSORY)")
    select.add_argument("--rarity", type=int, choices=[0, 1, 2],
                        help="Generate all items of a rarity (0=common/1=uncommon/2=rare)")
    select.add_argument("--list", action="store_true",
                        help="List all available items")

    # Generation options
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
    item_prompts = load_item_prompts()
    items = item_prompts["items"]

    # Handle --list
    if args.list:
        list_items(item_prompts)
        return

    # Determine which items to generate
    item_ids = []
    if args.all:
        item_ids = list(items.keys())
    elif args.item:
        if args.item not in items:
            print(f"ERROR: Unknown item '{args.item}'")
            print(f"Available: {', '.join(sorted(items.keys()))}")
            sys.exit(1)
        item_ids = [args.item]
    elif args.type:
        item_ids = filter_by_type(items, args.type)
        if not item_ids:
            print(f"ERROR: No items found with type '{args.type}'")
            sys.exit(1)
    elif args.slot:
        item_ids = filter_by_slot(items, args.slot)
        if not item_ids:
            print(f"ERROR: No equipment found in slot '{args.slot}'")
            sys.exit(1)
    elif args.rarity is not None:
        item_ids = filter_by_rarity(items, args.rarity)
        if not item_ids:
            print(f"ERROR: No items found with rarity {args.rarity}")
            sys.exit(1)
    else:
        parser.print_help()
        return

    # Build manifest
    manifest = build_item_manifest(item_ids)

    # Output dir
    output_dir = Path(args.output) if args.output else get_output_dir(config)

    # Summary
    print(f"\n{'='*60}")
    print(f"  Digital Genesis Item Art Generator")
    print(f"{'='*60}")
    print(f"  Items:  {len(item_ids)} images")
    print(f"  Output: {output_dir}")
    if args.seed:
        print(f"  Seed:   {args.seed} (fixed)")
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

    for entry in manifest:
        item_id = entry["item_id"]
        seed = args.seed if args.seed else entry["seed"]

        try:
            generate_item(client, item_id, seed, output_dir, args.dry_run)
            generated += 1
        except Exception as e:
            print(f"  ERROR generating {item_id}: {e}")
            errors += 1

    elapsed = time.time() - start_time

    print(f"\n{'='*60}")
    print(f"  Complete: {generated}/{len(manifest)} images in {elapsed:.1f}s")
    if errors:
        print(f"  Errors: {errors}")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    main()
