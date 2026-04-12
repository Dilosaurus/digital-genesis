"""
Live generation monitor for card art pipeline.

Run in a separate terminal:
    python monitor.py
"""

import json
import os
import sys
import time
from pathlib import Path

ART_PIPELINE_DIR = Path(__file__).parent
CARD_GAME_DIR = ART_PIPELINE_DIR.parent
ILLUSTRATIONS_DIR = CARD_GAME_DIR / "assets" / "cards" / "illustrations"
PROMPTS_FILE = ART_PIPELINE_DIR / "card_art_prompts.json"

# Character display config
CHAR_COLORS = {
    "ghost":    "\033[96m",   # cyan
    "aegis":    "\033[32m",   # green
    "abyss":    "\033[35m",   # purple
    "paladin":  "\033[33m",   # gold
    "flux":     "\033[95m",   # magenta
    "corsayre": "\033[91m",   # red
    "shared":   "\033[37m",   # white
}
RESET = "\033[0m"
DIM = "\033[2m"
BOLD = "\033[1m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
RED = "\033[91m"
CLEAR_SCREEN = "\033[2J\033[H"


def get_status(card_id: str) -> dict:
    """Check what files exist for a card."""
    card_dir = ILLUSTRATIONS_DIR / card_id
    base = card_dir / f"{card_id}_base.png"
    variants = {
        t: (card_dir / f"{card_id}_corrupt_{t}.png").exists()
        for t in ["t1", "t2", "t3"]
    }
    base_size = 0
    base_time = 0
    if base.exists():
        stat = base.stat()
        base_size = stat.st_size
        base_time = stat.st_mtime
    return {
        "has_base": base.exists(),
        "base_size": base_size,
        "base_time": base_time,
        "variants": variants,
        "variant_count": sum(1 for v in variants.values() if v),
    }


def format_size(size_bytes: int) -> str:
    if size_bytes < 1024:
        return f"{size_bytes}B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.0f}KB"
    else:
        return f"{size_bytes / (1024 * 1024):.1f}MB"


def make_bar(done: int, total: int, width: int = 40) -> str:
    if total == 0:
        return " " * width
    filled = int(width * done / total)
    bar = "█" * filled + "░" * (width - filled)
    return bar


def main():
    # Load card data
    if not PROMPTS_FILE.exists():
        print("ERROR: card_art_prompts.json not found")
        return

    data = json.load(open(PROMPTS_FILE, "r", encoding="utf-8"))
    all_cards = data["cards"]
    total = len(all_cards)

    # Group by character
    by_char = {}
    for card_id, entry in all_cards.items():
        char = entry.get("character", "shared")
        by_char.setdefault(char, []).append(card_id)

    char_order = ["shared", "ghost", "aegis", "abyss", "paladin", "flux", "corsayre"]
    start_time = time.time()
    last_done = 0
    speed_samples = []

    try:
        while True:
            # Gather status
            statuses = {}
            for card_id in all_cards:
                statuses[card_id] = get_status(card_id)

            base_done = sum(1 for s in statuses.values() if s["has_base"])
            variants_done = sum(s["variant_count"] for s in statuses.values())
            total_images = base_done + variants_done

            # Track speed
            elapsed = time.time() - start_time
            if base_done != last_done:
                speed_samples.append((time.time(), base_done))
                if len(speed_samples) > 20:
                    speed_samples.pop(0)
                last_done = base_done

            # Calculate ETA from recent speed
            eta_str = "calculating..."
            if len(speed_samples) >= 2:
                t0, n0 = speed_samples[0]
                t1, n1 = speed_samples[-1]
                dt = t1 - t0
                dn = n1 - n0
                if dn > 0 and dt > 0:
                    rate = dn / dt  # cards per second
                    remaining = total - base_done
                    eta_seconds = remaining / rate
                    eta_min = int(eta_seconds // 60)
                    eta_sec = int(eta_seconds % 60)
                    eta_str = f"{eta_min}m {eta_sec}s"

            # Find most recently generated card
            latest_card = ""
            latest_time = 0
            for card_id, s in statuses.items():
                if s["has_base"] and s["base_time"] > latest_time:
                    latest_time = s["base_time"]
                    latest_card = card_id

            # Render
            sys.stdout.write(CLEAR_SCREEN)

            print(f"{BOLD}  deus.exe Card Art Generation Monitor{RESET}")
            print(f"  {'─' * 50}")
            print()

            # Overall progress
            pct = (base_done / total * 100) if total > 0 else 0
            bar = make_bar(base_done, total)
            color = GREEN if base_done == total else YELLOW
            print(f"  {BOLD}Base images:{RESET}  {color}{bar}{RESET}  {base_done}/{total} ({pct:.0f}%)")

            if variants_done > 0:
                v_total = total * 3
                v_pct = (variants_done / v_total * 100) if v_total > 0 else 0
                v_bar = make_bar(variants_done, v_total)
                print(f"  {BOLD}Variants:  {RESET}  {YELLOW}{v_bar}{RESET}  {variants_done}/{v_total} ({v_pct:.0f}%)")

            print()
            print(f"  {DIM}Total images:{RESET} {total_images}  |  {DIM}ETA:{RESET} {eta_str}  |  {DIM}Elapsed:{RESET} {int(elapsed//60)}m {int(elapsed%60)}s")

            if latest_card:
                char = all_cards[latest_card].get("character", "shared")
                cc = CHAR_COLORS.get(char, "")
                print(f"  {DIM}Latest:{RESET}     {cc}{latest_card}{RESET} ({char})")

            print()
            print(f"  {BOLD}By character:{RESET}")
            print(f"  {'─' * 50}")

            for char in char_order:
                if char not in by_char:
                    continue
                cards = by_char[char]
                done = sum(1 for c in cards if statuses[c]["has_base"])
                char_total = len(cards)
                cc = CHAR_COLORS.get(char, "")
                bar = make_bar(done, char_total, 25)
                marker = f"{GREEN}✓{RESET}" if done == char_total else " "
                print(f"  {marker} {cc}{char:10s}{RESET}  {bar}  {done}/{char_total}")

            # Show last 5 generated
            print()
            print(f"  {BOLD}Recent:{RESET}")
            recent = sorted(
                [(cid, s) for cid, s in statuses.items() if s["has_base"]],
                key=lambda x: x[1]["base_time"],
                reverse=True,
            )[:5]
            for card_id, s in recent:
                char = all_cards[card_id].get("character", "shared")
                cc = CHAR_COLORS.get(char, "")
                size = format_size(s["base_size"])
                print(f"    {cc}●{RESET} {card_id:30s}  {DIM}{size}{RESET}")

            if base_done == total:
                print()
                print(f"  {GREEN}{BOLD}✓ ALL BASE IMAGES COMPLETE!{RESET}")
                if variants_done < total * 3:
                    print(f"  {DIM}Waiting for corruption variants...{RESET}")
                else:
                    print(f"  {GREEN}{BOLD}✓ ALL VARIANTS COMPLETE!{RESET}")
                    break

            sys.stdout.flush()
            time.sleep(3)

    except KeyboardInterrupt:
        print(f"\n  {DIM}Monitor stopped.{RESET}")


if __name__ == "__main__":
    main()
