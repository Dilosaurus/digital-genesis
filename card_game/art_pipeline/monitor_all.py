"""
Combined live monitor for all art generation (cards + items).

Run in a separate terminal:
    python monitor_all.py
"""

import json
import sys
import time
from pathlib import Path

ART_PIPELINE_DIR = Path(__file__).parent
CARD_GAME_DIR = ART_PIPELINE_DIR.parent
CARD_ILLUSTRATIONS = CARD_GAME_DIR / "assets" / "cards" / "illustrations"
ITEM_ILLUSTRATIONS = CARD_GAME_DIR / "assets" / "items" / "illustrations"
CARD_PROMPTS = ART_PIPELINE_DIR / "card_art_prompts.json"
ITEM_PROMPTS = ART_PIPELINE_DIR / "item_art_prompts.json"

RESET = "\033[0m"
DIM = "\033[2m"
BOLD = "\033[1m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
RED = "\033[91m"
CYAN = "\033[96m"
MAGENTA = "\033[95m"
CLEAR = "\033[2J\033[H"

CHAR_COLORS = {
    "ghost": "\033[96m", "aegis": "\033[32m", "abyss": "\033[35m",
    "paladin": "\033[33m", "flux": "\033[95m", "corsayre": "\033[91m",
    "shared": "\033[37m",
}
CAT_COLORS = {
    "gem": "\033[93m", "relic": "\033[96m", "equipment": "\033[91m",
}
CAT_ICONS = {"gem": "◆", "relic": "✦", "equipment": "⚔"}


def bar(done, total, width=30):
    if total == 0:
        return " " * width
    f = int(width * done / total)
    return "█" * f + "░" * (width - f)


def main():
    cards_data = json.load(open(CARD_PROMPTS, encoding="utf-8"))["cards"]
    items_data = json.load(open(ITEM_PROMPTS, encoding="utf-8"))["items"]

    # Group cards by character
    cards_by_char = {}
    for cid, entry in cards_data.items():
        ch = entry.get("character", "shared")
        cards_by_char.setdefault(ch, []).append(cid)
    char_order = ["shared", "ghost", "aegis", "abyss", "paladin", "flux", "corsayre"]

    # Group items by category
    items_by_cat = {}
    for iid, entry in items_data.items():
        cat = entry.get("category", "unknown")
        items_by_cat.setdefault(cat, []).append(iid)
    cat_order = ["gem", "relic", "equipment"]

    start_time = time.time()
    last_total = 0
    speed_samples = []

    try:
        while True:
            # Card status
            card_done = 0
            card_total = len(cards_data)
            card_latest = ("", 0)
            char_counts = {}
            for ch in char_order:
                if ch not in cards_by_char:
                    continue
                d = 0
                for cid in cards_by_char[ch]:
                    p = CARD_ILLUSTRATIONS / cid / f"{cid}_base.png"
                    if p.exists():
                        d += 1
                        mt = p.stat().st_mtime
                        if mt > card_latest[1]:
                            card_latest = (cid, mt)
                char_counts[ch] = (d, len(cards_by_char[ch]))
                card_done += d

            # Item status
            item_done = 0
            item_total = len(items_data)
            item_latest = ("", 0)
            cat_counts = {}
            for cat in cat_order:
                if cat not in items_by_cat:
                    continue
                d = 0
                for iid in items_by_cat[cat]:
                    p = ITEM_ILLUSTRATIONS / iid / f"{iid}.png"
                    if p.exists():
                        d += 1
                        mt = p.stat().st_mtime
                        if mt > item_latest[1]:
                            item_latest = (iid, mt)
                cat_counts[cat] = (d, len(items_by_cat[cat]))
                item_done += d

            total_done = card_done + item_done
            total_all = card_total + item_total
            elapsed = time.time() - start_time

            if total_done != last_total:
                speed_samples.append((time.time(), total_done))
                if len(speed_samples) > 20:
                    speed_samples.pop(0)
                last_total = total_done

            eta_str = "—"
            if len(speed_samples) >= 2:
                t0, n0 = speed_samples[0]
                t1, n1 = speed_samples[-1]
                dt, dn = t1 - t0, n1 - n0
                if dn > 0 and dt > 0:
                    remaining = total_all - total_done
                    eta_s = remaining / (dn / dt)
                    eta_str = f"{int(eta_s // 60)}m {int(eta_s % 60)}s"

            # Find overall latest
            latest_name = ""
            latest_type = ""
            if card_latest[1] > item_latest[1]:
                latest_name = card_latest[0]
                latest_type = "card"
            elif item_latest[0]:
                latest_name = item_latest[0]
                latest_type = "item"

            # Render
            sys.stdout.write(CLEAR)
            print(f"{BOLD}  deus.exe Art Generation Monitor{RESET}")
            print(f"  {'━' * 56}")
            print()

            # Overall
            pct = (total_done / total_all * 100) if total_all else 0
            c = GREEN if total_done == total_all else YELLOW
            print(f"  {BOLD}OVERALL{RESET}    {c}{bar(total_done, total_all, 35)}{RESET}  {total_done}/{total_all} ({pct:.0f}%)")
            print(f"  {DIM}Elapsed:{RESET} {int(elapsed//60)}m {int(elapsed%60)}s  {DIM}ETA:{RESET} {eta_str}")
            if latest_name:
                print(f"  {DIM}Latest:{RESET}  {latest_name} ({latest_type})")
            print()

            # ── Cards ──
            print(f"  {BOLD}CARDS{RESET}      {bar(card_done, card_total, 35)}  {card_done}/{card_total}")
            print(f"  {'─' * 56}")
            for ch in char_order:
                if ch not in char_counts:
                    continue
                d, t = char_counts[ch]
                cc = CHAR_COLORS.get(ch, "")
                mark = f"{GREEN}✓{RESET}" if d == t else " "
                print(f"  {mark} {cc}{ch:10s}{RESET}  {bar(d, t, 20)}  {d}/{t}")
            print()

            # ── Items ──
            print(f"  {BOLD}ITEMS{RESET}      {bar(item_done, item_total, 35)}  {item_done}/{item_total}")
            print(f"  {'─' * 56}")
            for cat in cat_order:
                if cat not in cat_counts:
                    continue
                d, t = cat_counts[cat]
                cc = CAT_COLORS.get(cat, "")
                icon = CAT_ICONS.get(cat, "?")
                mark = f"{GREEN}✓{RESET}" if d == t else " "
                print(f"  {mark} {cc}{icon} {cat:10s}{RESET}  {bar(d, t, 20)}  {d}/{t}")

            # ── Regen tracker ──
            # Items queued for regeneration (old cyberpunk → painted horror)
            regen_items = [
                "crimson_opal", "diamond_of_efficiency", "emerald_of_renewal",
                "flame_gauntlets", "holy_circlet", "horn_cleat", "iron_helm",
                "lantern", "leather_vest", "obsidian_shard", "oddly_smooth_stone",
                "red_skull", "ruby_of_fury", "rusty_blade", "sapphire_of_shielding",
                "shadow_cloak", "tech_visor", "topaz_of_wrath", "vajra", "war_paint",
            ]

            # Cutoff: anything modified after monitor start is "regenerated"
            regen_cutoff = start_time

            print()
            print(f"  {BOLD}REGEN: Items (old → painted){RESET}")
            print(f"  {'─' * 56}")
            regen_item_done = 0
            for iid in regen_items:
                p = ITEM_ILLUSTRATIONS / iid / f"{iid}.png"
                cat = items_data.get(iid, {}).get("category", "?")
                cc = CAT_COLORS.get(cat, "")
                icon_ch = CAT_ICONS.get(cat, "?")
                if p.exists() and p.stat().st_mtime > regen_cutoff:
                    sz = p.stat().st_size
                    sz_str = f"{sz/1024:.0f}KB" if sz < 1024*1024 else f"{sz/(1024*1024):.1f}MB"
                    print(f"    {GREEN}✓{RESET} {cc}{icon_ch}{RESET} {iid:30s}  {DIM}{sz_str}{RESET}")
                    regen_item_done += 1
                else:
                    print(f"    {DIM}· {icon_ch} {iid}{RESET}")
            ri_bar = bar(regen_item_done, len(regen_items), 20)
            c = GREEN if regen_item_done == len(regen_items) else YELLOW
            print(f"  {c}{ri_bar}{RESET}  {regen_item_done}/{len(regen_items)}")

            all_regen_done = regen_item_done == len(regen_items)

            if total_done == total_all and all_regen_done:
                print()
                print(f"  {GREEN}{BOLD}✓ ALL ART COMPLETE! ({total_all} images, all regens done){RESET}")
                break
            elif total_done == total_all:
                print()
                remaining = (len(regen_items) - regen_item_done) + (len(regen_cards) - regen_card_done)
                print(f"  {YELLOW}{BOLD}⏳ {remaining} regenerations pending...{RESET}")

            sys.stdout.flush()
            time.sleep(3)

    except KeyboardInterrupt:
        print(f"\n  {DIM}Monitor stopped.{RESET}")


if __name__ == "__main__":
    main()
