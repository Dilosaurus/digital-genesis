"""
deus.exe Art Asset Generator
Main CLI tool for generating game art via ComfyUI.

Usage:
    python generate.py enemy corrupted_crawler
    python generate.py card strike
    python generate.py icon status_strength
    python generate.py player protagonist
    python generate.py background combat_act1
    python generate.py batch enemies
    python generate.py batch cards
    python generate.py batch icons
    python generate.py batch all
"""

import sys
import json
import os
from pathlib import Path

from comfyui_api import ComfyUIClient
from workflows import (
    character_sheet_workflow,
    enemy_character_workflow,
    card_illustration_workflow,
    icon_workflow,
    background_workflow,
    battle_background_workflow,
    corruption_variant_workflow,
    load_config,
)

# ── Asset Definitions ──────────────────────────────────────────────────────

ENEMIES = {
    "corrupted_crawler": {
        "name": "Corrupted Crawler",
        "description": "a grotesque biomechanical insect-like creature with exposed wiring and corrupted flesh, multiple legs, glowing red eyes, segmented body",
        "type": "common",
    },
    "malware_drone": {
        "name": "Malware Drone",
        "description": "a small hovering mechanical drone with a cracked screen face displaying static, sparking wires, dark metal body with red warning lights",
        "type": "common",
    },
    "rogue_process": {
        "name": "Rogue Process",
        "description": "a hooded cultist figure made of glitching digital code, robes of cascading text and symbols, faceless void beneath hood with glowing runes",
        "type": "common",
    },
    "hex_phantom": {
        "name": "Hex Phantom",
        "description": "a massive spectral hexagonal entity with six ghostly faces, translucent crystalline body, chains of corrupted data orbiting around it, ethereal dark energy",
        "type": "elite",
    },
    "gabriel": {
        "name": "Gabriel — Herald of Annihilation",
        "description": "a fallen angel with tattered dark wings, cracked golden armor revealing void beneath, wielding a corrupted trumpet that drips black ichor, stern face with blind white eyes",
        "type": "elite",
    },
    "raphael": {
        "name": "Raphael — Warden of the Rift",
        "description": "a towering angelic figure in ornate dark robes with chains, holding a staff that tears reality around it, four wings two broken two intact, serene yet menacing expression",
        "type": "elite",
    },
    "uriel": {
        "name": "Uriel — Flame of the Void",
        "description": "an angel engulfed in dark fire, blackened armor with molten cracks, wielding a sword of black flame, wings of pure fire, intense burning eyes",
        "type": "elite",
    },
    "azrael": {
        "name": "Azrael — Angel of Oblivion",
        "description": "the angel of death in flowing tattered black robes, skeletal hands holding a massive dark scythe, a halo of broken light, empty eye sockets radiating darkness",
        "type": "boss",
    },
    "michael": {
        "name": "Michael — Archangel of War",
        "description": "a massive armored archangel in blood-stained golden plate armor, six wings three pristine three corrupted, wielding a greatsword crackling with holy and dark energy, stern commanding presence, battle-scarred",
        "type": "boss",
    },
    "metatron": {
        "name": "Metatron — Voice of the Absolute",
        "description": "an incomprehensible eldritch angelic entity, geometric impossible form of nested rotating rings and eyes, blinding light mixed with absolute darkness, reality warps around it, crown of infinite eyes, the most powerful being",
        "type": "boss",
    },
}

CARDS = {
    # Attack cards
    "strike": {"name": "Strike", "description": "a fist slamming down with crackling energy", "type": "attack"},
    "bash": {"name": "Bash", "description": "a massive hammer strike sending shockwaves", "type": "attack"},
    "twin_strike": {"name": "Twin Strike", "description": "two parallel slashing energy blades", "type": "attack"},
    "pommel_strike": {"name": "Pommel Strike", "description": "a sword pommel smashing through data", "type": "attack"},
    "iron_wave": {"name": "Iron Wave", "description": "a wave of metal shards and energy", "type": "attack"},
    "cleave": {"name": "Cleave", "description": "a wide sweeping blade arc cutting through multiple targets", "type": "attack"},
    "heavy_blade": {"name": "Heavy Blade", "description": "an enormous glowing greatsword being brought down", "type": "attack"},
    "uppercut": {"name": "Uppercut", "description": "a rising fist punch with explosive upward force", "type": "attack"},
    "holy_wrath": {"name": "Holy Wrath", "description": "divine light beams raining down destructively", "type": "attack"},
    "flaming_sword": {"name": "Flaming Sword", "description": "a sword wreathed in hellfire", "type": "attack"},
    "recursive_loop": {"name": "Recursive Loop", "description": "spiraling energy repeating and multiplying", "type": "attack"},
    "infinite_loop": {"name": "Infinite Loop", "description": "an ouroboros of endless striking energy", "type": "attack"},
    "null_pointer": {"name": "Null Pointer", "description": "a void-tipped dagger piercing through reality", "type": "attack"},
    "malware_inject": {"name": "Malware Inject", "description": "a syringe of corrupted code being injected", "type": "attack"},
    "trojan_horse": {"name": "Trojan Horse", "description": "a dark mechanical horse with hidden blades inside", "type": "attack"},
    # Skill cards
    "defend": {"name": "Defend", "description": "a glowing energy shield being raised", "type": "skill"},
    "shrug_it_off": {"name": "Shrug It Off", "description": "a figure brushing off attacks nonchalantly with armor fragments", "type": "skill"},
    "bandage": {"name": "Bandage", "description": "glowing healing bandages wrapping around wounds", "type": "skill"},
    "divine_shield": {"name": "Divine Shield", "description": "a radiant golden barrier with angelic runes", "type": "skill"},
    "data_shield": {"name": "Data Shield", "description": "a wall of protective code and firewalls", "type": "skill"},
    "phantom_firewall": {"name": "Phantom Firewall", "description": "a ghostly transparent barrier of flame", "type": "skill"},
    "full_reboot": {"name": "Full Reboot", "description": "a system restart symbol with surging power", "type": "skill"},
    "memory_leak": {"name": "Memory Leak", "description": "corrupted data dripping and dissolving an enemy", "type": "skill"},
    "system_restore": {"name": "System Restore", "description": "a glowing restoration circle with clockwork gears turning back", "type": "skill"},
    "kernel_panic": {"name": "Kernel Panic", "description": "a system error screen cracking and exploding", "type": "skill"},
    "cache_flush": {"name": "Cache Flush", "description": "a rush of data being cleared in a torrent", "type": "skill"},
    # Power cards
    "power_surge": {"name": "Power Surge", "description": "raw electrical energy overloading a conduit", "type": "power"},
    "adaptive_shield": {"name": "Adaptive Shield", "description": "a morphing shield that reshapes to block threats", "type": "power"},
    "overclock_core": {"name": "Overclock Core", "description": "a glowing processor core pushed beyond limits, sparking", "type": "power"},
    "digital_fortress": {"name": "Digital Fortress", "description": "an imposing castle made of code and data walls", "type": "power"},
    "berserker_virus": {"name": "Berserker Virus", "description": "a raging virus entity tearing through systems", "type": "power"},
    "backdoor": {"name": "Backdoor", "description": "a hidden dark doorway in a wall of code", "type": "power"},
    "body_slam": {"name": "Body Slam", "description": "a full body charge with shield forward", "type": "power"},
    # Curse cards
    "curse_glitch": {"name": "Glitch", "description": "a corrupted glitching void tearing through reality", "type": "curse"},
    "curse_hellfire": {"name": "Hellfire", "description": "demonic flames consuming everything from below", "type": "curse"},
}

ICONS = {
    # Status effects
    "status_strength": {"name": "Strength", "description": "a glowing red clenched fist, power icon"},
    "status_dexterity": {"name": "Dexterity", "description": "a swift blue feather or wind symbol, agility icon"},
    "status_vulnerable": {"name": "Vulnerable", "description": "a cracked broken shield, exposed weakness icon"},
    "status_weak": {"name": "Weak", "description": "a broken drooping sword, diminished power icon"},
    "status_block": {"name": "Block", "description": "a solid metal shield with energy glow, defense icon"},
    "status_corruption": {"name": "Corruption", "description": "a purple flame with dark tendrils, corruption icon"},
    # Sin icons
    "sin_wrath": {"name": "Wrath", "description": "a burning red angry eye or flame fist, rage icon"},
    "sin_sloth": {"name": "Sloth", "description": "a blue hourglass with chains, lethargy icon"},
    "sin_pride": {"name": "Pride", "description": "a golden crown or mirror, hubris icon"},
    # Intent icons
    "intent_attack": {"name": "Attack Intent", "description": "a red sword slash mark, incoming attack warning"},
    "intent_defend": {"name": "Defend Intent", "description": "a blue shield being raised, defensive stance"},
    "intent_hack": {"name": "Hack Intent", "description": "a green lightning bolt or circuit symbol, hacking"},
    "intent_buff": {"name": "Buff Intent", "description": "an orange upward arrow with glow, powering up"},
    "intent_unknown": {"name": "Unknown Intent", "description": "a purple question mark with dark swirl, mystery"},
    # Map node icons
    "node_fight": {"name": "Fight Node", "description": "crossed swords, combat encounter"},
    "node_elite": {"name": "Elite Node", "description": "a flaming skull, dangerous elite fight"},
    "node_rest": {"name": "Rest Node", "description": "a campfire with warm glow, rest site"},
    "node_event": {"name": "Event Node", "description": "a mystical glowing scroll, random event"},
    "node_shop": {"name": "Shop Node", "description": "a merchant bag with coins, shop"},
    "node_boss": {"name": "Boss Node", "description": "a crowned skull with dark aura, boss encounter"},
    # Pact icons
    "pact_dark_power": {"name": "Dark Power", "description": "a glowing dark orb of demonic energy"},
    "pact_blood_offering": {"name": "Blood Offering", "description": "bleeding hands offering blood drops"},
    "pact_hellfire": {"name": "Hellfire Pact", "description": "an infernal contract scroll wreathed in flame"},
    "pact_soul_bargain": {"name": "Soul Bargain", "description": "a shadowy demonic handshake"},
    "pact_demons_gift": {"name": "Demon's Gift", "description": "a dark gift box wrapped in chains"},
    # Relic icons
    "relic_burning_blood": {"name": "Burning Blood", "description": "a vial of blood with flames around it"},
    "relic_blood_vial": {"name": "Blood Vial", "description": "a simple glass vial filled with dark blood"},
    "relic_bag_of_prep": {"name": "Bag of Preparation", "description": "a leather satchel with glowing contents"},
    "relic_vajra": {"name": "Vajra", "description": "a diamond thunderbolt weapon, ancient power"},
    "relic_smooth_stone": {"name": "Oddly Smooth Stone", "description": "a perfectly smooth glowing stone"},
    "relic_anchor": {"name": "Anchor", "description": "a heavy ship anchor with energy chains"},
    "relic_horn_cleat": {"name": "Horn Cleat", "description": "a nautical horn cleat made of bone"},
    "relic_war_paint": {"name": "War Paint", "description": "tribal war paint markings in red and black"},
    "relic_lantern": {"name": "Lantern", "description": "an ornate glowing lantern with mysterious light"},
    "relic_red_skull": {"name": "Red Skull", "description": "a crimson skull emanating dark power"},
}

BACKGROUNDS = {
    "combat_act1": {"name": "Act 1 Combat", "description": "a dark corrupted server room with flickering monitors and exposed cables, eerie digital ruins, dim red emergency lighting"},
    "combat_act2": {"name": "Act 2 Combat", "description": "a corrupted angelic fortress, crumbling marble halls with dark energy veins, broken stained glass windows, holy symbols defaced"},
    "combat_act3": {"name": "Act 3 Combat", "description": "a cosmic void throne room, reality breaking apart, floating debris, blinding light mixed with absolute darkness, final confrontation arena"},
    "map_overworld": {"name": "Map Background", "description": "a dark corrupted landscape seen from above, branching paths through digital wasteland, ominous sky"},
    "main_menu": {"name": "Main Menu", "description": "a dark cathedral interior merged with digital circuitry, massive stained glass window with corrupted imagery, dramatic lighting"},
    "shop": {"name": "Shop", "description": "a shady merchant alcove in a dark alley, lantern-lit, mysterious wares on shelves, shadowy merchant silhouette"},
}

BATTLE_ARENAS = {
    # Boss arenas — unique, epic locations
    "arena_metatron": {
        "name": "Metatron's Throne",
        "description": "a vast impossible geometric void, nested rotating golden rings suspended in absolute darkness, reality fractures and light bends, the floor is a mirror reflecting infinity, impossible architecture of nested cubes and spheres, cosmic scale",
        "boss": "Metatron the Voice of the Absolute",
    },
    "arena_michael": {
        "name": "Michael's War Hall",
        "description": "a massive ruined cathedral war room, crumbling stone pillars draped with torn banners, blood-stained marble floor with angelic sigils, shattered stained glass casting fractured light, weapon racks and broken swords embedded in walls, dust motes in god rays",
        "boss": "Michael the Archangel of War",
    },
    "arena_azrael": {
        "name": "Azrael's Sepulcher",
        "description": "an underground crypt of impossible depth, endless rows of stone sarcophagi stretching into darkness, green ghostly flames in iron braziers, bone pillars and skull mosaics on walls, a thick low-hanging fog, cold blue-green light filtering from above",
        "boss": "Azrael the Angel of Oblivion",
    },
    # Elite arenas
    "arena_gabriel": {
        "name": "Gabriel's Shattered Spire",
        "description": "the top of a broken tower open to a turbulent sky, cracked floor revealing void below, wind-torn dark clouds, lightning in the distance, broken bell hanging from chains, rain-slicked stone",
        "boss": "Gabriel the Herald of Annihilation",
    },
    "arena_raphael": {
        "name": "Raphael's Rift Library",
        "description": "an ancient library where reality is torn open, bookshelves floating at impossible angles, pages swirling in a vortex, a massive rift in the center glowing with otherworldly light, chains trying to hold reality together, ink-like darkness seeping from the rift",
        "boss": "Raphael the Warden of the Rift",
    },
    "arena_uriel": {
        "name": "Uriel's Burning Sanctum",
        "description": "a cathedral engulfed in black flame, molten cracks in the floor revealing magma below, charred pillars still standing, the ceiling has collapsed revealing a hellish red sky, embers and ash constantly falling, heat distortion in the air",
        "boss": "Uriel the Flame of the Void",
    },
    # Common combat arenas (used for regular fights)
    "arena_corrupted_halls": {
        "name": "Corrupted Halls",
        "description": "a decaying stone corridor with dark veins growing along the walls, cracked floor tiles, dim torches with unnatural purple flame, cobwebs and dust, oppressive low ceiling",
    },
    "arena_server_crypt": {
        "name": "Server Crypt",
        "description": "a fusion of ancient crypt and server room, stone walls embedded with glowing circuit traces, humming machinery behind iron grates, flickering fluorescent lights mixed with candles, cables hanging like vines",
    },
    "arena_void_bridge": {
        "name": "Void Bridge",
        "description": "a narrow stone bridge spanning an infinite dark chasm, broken railings, faint blue light from far below, floating debris and rubble, wind-swept, vertigo-inducing depth, stars visible in the void below",
    },
    "arena_defiled_garden": {
        "name": "Defiled Garden",
        "description": "a once-beautiful garden now withered and corrupted, dead trees with dark crystal growths, a cracked dry fountain with black liquid, thorned vines everywhere, pale sickly moonlight, fireflies that glow an unnatural red",
    },
}

PLAYER = {
    "protagonist": {
        "name": "Protagonist",
        "description": "a determined human figure in dark tactical gear with glowing circuit patterns, short hair, confident stance, equipped with a data gauntlet on one arm",
    },
}


def generate_single(client, category, key, output_base, seed=None):
    """Generate a single asset by category and key."""
    import random
    if seed is None:
        seed = random.randint(0, 2**32 - 1)

    if category == "enemy":
        if key not in ENEMIES:
            print(f"Unknown enemy: {key}. Available: {list(ENEMIES.keys())}")
            return
        data = ENEMIES[key]
        workflow = enemy_character_workflow(data["name"], data["description"], data["type"])
        output_dir = f"{output_base}/enemies/{data['type']}/{key}"

    elif category == "card":
        if key not in CARDS:
            print(f"Unknown card: {key}. Available: {list(CARDS.keys())}")
            return
        data = CARDS[key]
        workflow = card_illustration_workflow(data["name"], data["description"], data["type"])
        output_dir = f"{output_base}/cards/illustrations/{key}"

    elif category == "icon":
        if key not in ICONS:
            print(f"Unknown icon: {key}. Available: {list(ICONS.keys())}")
            return
        data = ICONS[key]
        workflow = icon_workflow(data["name"], data["description"])
        output_dir = f"{output_base}/icons/{key}"

    elif category == "background":
        if key not in BACKGROUNDS:
            print(f"Unknown background: {key}. Available: {list(BACKGROUNDS.keys())}")
            return
        data = BACKGROUNDS[key]
        workflow = background_workflow(data["name"], data["description"])
        output_dir = f"{output_base}/backgrounds/{key}"

    elif category == "arena":
        if key not in BATTLE_ARENAS:
            print(f"Unknown arena: {key}. Available: {list(BATTLE_ARENAS.keys())}")
            return
        data = BATTLE_ARENAS[key]
        workflow = battle_background_workflow(
            data["name"], data["description"], data.get("boss")
        )
        output_dir = f"{output_base}/backgrounds/arenas/{key}"

    elif category == "player":
        if key not in PLAYER:
            print(f"Unknown player: {key}. Available: {list(PLAYER.keys())}")
            return
        data = PLAYER[key]
        workflow = character_sheet_workflow(data["name"], data["description"])
        output_dir = f"{output_base}/player/{key}"

    else:
        print(f"Unknown category: {category}. Use: enemy, card, icon, background, player")
        return

    # Override seed in workflow
    workflow["3"]["inputs"]["seed"] = seed

    print(f"Generating {category}/{key} (seed: {seed})...")
    files = client.generate_and_save(workflow, output_dir)
    print(f"  Done! Generated {len(files)} file(s)")
    return files


def generate_batch(client, category, output_base):
    """Generate all assets in a category."""
    registry = {
        "enemies": ENEMIES,
        "cards": CARDS,
        "icons": ICONS,
        "backgrounds": BACKGROUNDS,
        "arenas": BATTLE_ARENAS,
        "players": PLAYER,
    }

    if category == "all":
        for cat_name, cat_data in registry.items():
            print(f"\n{'='*60}")
            print(f"Generating all {cat_name} ({len(cat_data)} assets)...")
            print(f"{'='*60}")
            cat_singular = cat_name.rstrip("s")
            if cat_singular == "enemie":
                cat_singular = "enemy"
            elif cat_singular == "player":
                cat_singular = "player"
            for key in cat_data:
                generate_single(client, cat_singular, key, output_base)
        return

    cat_singular = category.rstrip("s")
    if cat_singular == "enemie":
        cat_singular = "enemy"
    elif cat_singular == "arena":
        cat_singular = "arena"

    if category not in registry:
        print(f"Unknown batch category: {category}. Use: enemies, cards, icons, backgrounds, players, all")
        return

    data = registry[category]
    print(f"Generating {len(data)} {category}...")
    for key in data:
        generate_single(client, cat_singular, key, output_base)


def list_assets(category=None):
    """List all defined assets."""
    registries = {
        "enemies": ENEMIES,
        "cards": CARDS,
        "icons": ICONS,
        "backgrounds": BACKGROUNDS,
        "players": PLAYER,
    }

    if category and category in registries:
        registries = {category: registries[category]}

    for cat_name, cat_data in registries.items():
        print(f"\n{cat_name.upper()} ({len(cat_data)}):")
        for key, data in cat_data.items():
            print(f"  {key}: {data['name']}")


def main():
    if len(sys.argv) < 2:
        print("deus.exe Art Pipeline")
        print("=" * 40)
        print("\nUsage:")
        print("  python generate.py <category> <key>     Generate single asset")
        print("  python generate.py batch <category>      Generate all in category")
        print("  python generate.py list [category]       List available assets")
        print("\nCategories: enemy, card, icon, background, arena, player")
        print("Batch categories: enemies, cards, icons, backgrounds, arenas, players, all")
        return

    config = load_config()
    output_base = config["output_base"]

    if sys.argv[1] == "list":
        list_assets(sys.argv[2] if len(sys.argv) > 2 else None)
        return

    client = ComfyUIClient(config["comfyui_url"])

    if not client.is_running():
        print("ComfyUI not running — starting it automatically...")
        import subprocess
        proc = subprocess.Popen(
            [sys.executable, f"{config['comfyui_path']}/main.py", "--listen", "--port", "8188"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if sys.platform == "win32" else 0,
        )
        # Wait for it to come up
        import time
        for i in range(60):
            time.sleep(2)
            if client.is_running():
                print("ComfyUI is ready!")
                break
        else:
            print("ERROR: ComfyUI failed to start after 120s")
            return

    if sys.argv[1] == "batch":
        if len(sys.argv) < 3:
            print("Usage: python generate.py batch <enemies|cards|icons|backgrounds|players|all>")
            return
        generate_batch(client, sys.argv[2], output_base)
    else:
        if len(sys.argv) < 3:
            print("Usage: python generate.py <category> <key>")
            return
        category = sys.argv[1]
        key = sys.argv[2]
        seed = int(sys.argv[3]) if len(sys.argv) > 3 else None
        generate_single(client, category, key, output_base, seed=seed)


if __name__ == "__main__":
    main()
