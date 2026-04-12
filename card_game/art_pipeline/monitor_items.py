"""
Live generation monitor for item art pipeline (gems, relics, equipment).

Run in a separate terminal:
    python monitor_items.py
"""

import json
import os
import sys
import time
from pathlib import Path

ART_PIPELINE_DIR = Path(__file__).parent
CARD_GAME_DIR = ART_PIPELINE_DIR.parent
ILLUSTRATIONS_DIR = CARD_GAME_DIR / "assets" / "items" / "illustrations"
PROMPTS_FILE = ART_PIPELINE_DIR / "item_art_prompts.json"

# Category display config
CAT_COLORS = {
    "gem":       "\033[93m",   # yellow
    "relic":     "\033[96m",   # cyan
    "equipment": "\033[91m",   # red
}
RESET = "\033[0m"
DIM = "\033[2m"
BOLD = "\033[1m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
CLEAR_SCREEN = "\033[2J\033[H"

CAT_ICONS = {
    "gem": "◆",
    "relic": "✦",
    "equipment": "⚔",
}


def get_status(item_id: str) -> dict:
    item_dir = ILLUSTRATIONS_DIR / item_id
    img = item_dir / f"{item_id}.png"
    img_size = 0
    img_time = 0
    if img.exists():
        stat = img.stat()
        img_size = stat.st_size
        img_time = stat.st_mtime
    return {
        "exists": img.exists(),
        "size": img_size,
        "time": img_time,
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
    return "█" * filled + "░" * (width - filled)


def main():
    if not PROMPTS_FILE.exists():
        print("ERROR: item_art_prompts.json not found")
        return

    data = json.load(open(PROMPTS_FILE, "r", encoding="utf-8"))
    all_items = data["items"]
    total = len(all_items)

    by_cat = {}
    for item_id, entry in all_items.items():
        cat = entry.get("category", "unknown")
        by_cat.setdefault(cat, []).append(item_id)

    cat_order = ["gem", "relic", "equipment"]
    start_time = time.time()
    last_done = 0
    speed_samples = []

    try:
        while True:
            statuses = {}
            for item_id in all_items:
                statuses[item_id] = get_status(item_id)

            done = sum(1 for s in statuses.values() if s["exists"])
            elapsed = time.time() - start_time

            if done != last_done:
                speed_samples.append((time.time(), done))
                if len(speed_samples) > 20:
                    speed_samples.pop(0)
                last_done = done

            eta_str = "calculating..."
            if len(speed_samples) >= 2:
                t0, n0 = speed_samples[0]
                t1, n1 = speed_samples[-1]
                dt = t1 - t0
                dn = n1 - n0
                if dn > 0 and dt > 0:
                    rate = dn / dt
                    remaining = total - done
                    eta_seconds = remaining / rate
                    eta_str = f"{int(eta_seconds // 60)}m {int(eta_seconds % 60)}s"

            latest_item = ""
            latest_time = 0
            for item_id, s in statuses.items():
                if s["exists"] and s["time"] > latest_time:
                    latest_time = s["time"]
                    latest_item = item_id

            sys.stdout.write(CLEAR_SCREEN)

            print(f"{BOLD}  deus.exe Item Art Generation Monitor{RESET}")
            print(f"  {'─' * 50}")
            print()

            pct = (done / total * 100) if total > 0 else 0
            bar = make_bar(done, total)
            color = GREEN if done == total else YELLOW
            print(f"  {BOLD}Progress:{RESET}  {color}{bar}{RESET}  {done}/{total} ({pct:.0f}%)")
            print()
            print(f"  {DIM}ETA:{RESET} {eta_str}  |  {DIM}Elapsed:{RESET} {int(elapsed//60)}m {int(elapsed%60)}s")

            if latest_item:
                cat = all_items[latest_item].get("category", "?")
                cc = CAT_COLORS.get(cat, "")
                icon = CAT_ICONS.get(cat, "?")
                print(f"  {DIM}Latest:{RESET}  {cc}{icon} {latest_item}{RESET} ({cat})")

            print()
            print(f"  {BOLD}By category:{RESET}")
            print(f"  {'─' * 50}")

            for cat in cat_order:
                if cat not in by_cat:
                    continue
                items = by_cat[cat]
                cat_done = sum(1 for c in items if statuses[c]["exists"])
                cat_total = len(items)
                cc = CAT_COLORS.get(cat, "")
                icon = CAT_ICONS.get(cat, "?")
                bar = make_bar(cat_done, cat_total, 25)
                marker = f"{GREEN}✓{RESET}" if cat_done == cat_total else " "
                print(f"  {marker} {cc}{icon} {cat:12s}{RESET}  {bar}  {cat_done}/{cat_total}")

            # Show items as grid per category
            print()
            for cat in cat_order:
                if cat not in by_cat:
                    continue
                cc = CAT_COLORS.get(cat, "")
                icon = CAT_ICONS.get(cat, "?")
                print(f"  {cc}{BOLD}{icon} {cat.upper()}{RESET}")
                items = sorted(by_cat[cat])
                line = "    "
                for item_id in items:
                    s = statuses[item_id]
                    if s["exists"]:
                        short = item_id[:18]
                        line += f"{GREEN}✓{RESET}{DIM}{short}{RESET}  "
                    else:
                        short = item_id[:18]
                        line += f" {DIM}{short}{RESET}  "
                    if len(line) > 100:
                        print(line)
                        line = "    "
                if line.strip():
                    print(line)
                print()

            if done == total:
                print(f"  {GREEN}{BOLD}✓ ALL ITEM ART COMPLETE!{RESET}")
                break

            sys.stdout.flush()
            time.sleep(3)

    except KeyboardInterrupt:
        print(f"\n  {DIM}Monitor stopped.{RESET}")


if __name__ == "__main__":
    main()
