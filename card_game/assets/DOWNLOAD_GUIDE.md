# Card Game Assets — Download Guide

This file documents every UI/font asset pack available for this project, their licenses,
what was auto-downloaded versus what requires a manual browser visit, and where each
piece should live inside the project tree.

---

## Status Summary

| Pack | License | Auto-Downloaded | Location |
|------|---------|----------------|----------|
| Kenney UI Pack | CC0 | YES — zip extracted | `assets/ui/kenney/kenney_ui_pack/` |
| Kenney RPG Expansion | CC0 | YES — zip extracted | `assets/ui/kenney/kenney_rpg_expansion/` |
| Foozle RPG UI Set 1 | CC0 | NO — manual download needed | `assets/ui/dark_fantasy/` |
| OpenGameArt Health Orb 1.1 | CC0 | YES — zip extracted | `assets/ui/orb_frames/health_orb/` |
| OpenGameArt RPG Inventory | CC0 | YES — zip extracted | `assets/ui/inventory/rpg_inventory/` |
| MedievalSharp | OFL | YES — TTF downloaded | `assets/fonts/MedievalSharp.ttf` |
| Cinzel Decorative | OFL | YES — TTF downloaded | `assets/fonts/CinzelDecorative-Regular.ttf` |
| Share Tech Mono | OFL | YES — TTF downloaded | `assets/fonts/ShareTechMono-Regular.ttf` |
| Lato | OFL | YES — Regular + Bold | `assets/fonts/Lato-Regular.ttf`, `Lato-Bold.ttf` |

---

## Asset Pack Details

---

### 1. Kenney UI Pack (v2.0)

**URL:** https://kenney.nl/assets/ui-pack
**Direct ZIP:** https://kenney.nl/media/pages/assets/ui-pack/af874291da-1718203990/kenney_ui-pack.zip
**License:** Creative Commons CC0 — Public Domain, no attribution required
**Status:** DOWNLOADED AND EXTRACTED

**What's included:**
- 868 PNG files (counted post-extraction)
- Color variants: Blue, Green, Grey, Red, Yellow, Extra
- Each color has Default and Double (outlined) sub-variants
- Arrows (all 8 directions, decorative and basic)
- Buttons (round, square, flat, long variants)
- Checkboxes, radio buttons, toggles
- Panel frames and backgrounds
- Sliders (horizontal and vertical)
- Progress bar components
- Icons (settings, close, minimize, lock, etc.)
- Spritesheet + Font (bitmap font included)

**Where to use in this project:**
- `PNG/Grey/Default/` — panel backgrounds, tooltips, deck viewer chrome
- `PNG/Blue/Default/` — primary action buttons (End Turn, Play Card)
- `PNG/Red/Default/` — danger/cancel buttons (Abandon Run)
- Spritesheet → useful for TextureAtlas in Godot for batching
- Bitmap font → can supplement or replace TTF for small UI labels

**Godot usage notes:**
- Import PNGs as `Texture2D`, use `NinePatchRect` for resizable panels
- The spritesheet (`Spritesheet/` folder) is ideal for `AtlasTexture` slices
- Already contains `.import` files — these are stale from a different project,
  delete them and let your Godot project re-import

---

### 2. Kenney UI Pack — RPG Expansion

**URL:** https://kenney.nl/assets/ui-pack-rpg-expansion
**Direct ZIP:** https://kenney.nl/media/pages/assets/ui-pack-rpg-expansion/b1e1f298c6-1677661824/kenney_ui-pack-rpg-expansion.zip
**License:** Creative Commons CC0 — Public Domain, no attribution required
**Status:** DOWNLOADED AND EXTRACTED

**What's included (85 files):**
- Directional arrows in Beige, Blue, Brown, Silver variants
- Health/mana bar components: back panels, fill bars in Blue, Green, Red, Yellow
  - Each bar has Left, Mid, Right (horizontal) and Top, Mid, Bottom (vertical) slices
- Sliders in multiple color variants
- Buttons in RPG-appropriate earthy tones (Beige, Brown styles)

**Where to use in this project:**
- `barRed_*` files → player HP bar in combat (top of screen)
- `barBlue_*` files → enemy HP bar or energy/mana display
- `barGreen_*` files → shield/block display
- `barBack_*` files → bar background behind health fills
- Arrows → card targeting indicators, map navigation

**Godot usage notes:**
- Use `TextureProgressBar` with the bar pieces as fill/background textures
- The horizontal left/mid/right triplet maps to a 9-slice progress bar
- Mid piece should be stretched; left/right are fixed-size end caps

---

### 3. Foozle RPG UI Set 1 (Diablo-style)

**URL:** https://foozlecc.itch.io/rpg-ui-set-1
**Download page:** https://foozlecc.itch.io/rpg-ui-set-1/purchase
**File:** `Foozle_UI_0001_RPG_Set_1.zip` (1.9 MB)
**License:** Creative Commons Zero (CC0) — Public Domain
  - Free for personal and commercial projects
  - No attribution required
  - Modification allowed
**Price:** Free (name-your-own-price; enter 0 to download at no cost)
**Status:** MANUAL DOWNLOAD REQUIRED

**How to download:**
1. Go to https://foozlecc.itch.io/rpg-ui-set-1
2. Click "Download or claim"
3. Enter $0 in the price field and click "No thanks, just take me to the downloads"
4. Download `Foozle_UI_0001_RPG_Set_1.zip`
5. Extract and place contents into `card_game/assets/ui/dark_fantasy/`

**What's included:**
- Diablo-inspired dark RPG UI elements
- Sliced panel frames with dark stone/metal aesthetic
- Button frames in dark fantasy style
- Inventory slot borders
- Background panels with gothic detailing
- Based on and compatible with other OpenGameArt CC0 assets

**Where to use in this project:**
- Panel frames for the card detail tooltip overlay
- Background frame for the shop screen and event screen
- Inventory slot borders for the relic display area
- Button frames for the map screen node types
- Could replace or supplement Kenney panels for the darker aesthetic

**Why this matters for our game:**
The game's dark fantasy/cyber aesthetic needs something heavier than Kenney's clean vectors.
This pack provides gritty, Diablo-coded chrome that pairs with the corruption/sin system
visually. Kenney handles functional chrome (progress bars, toggles); Foozle handles atmosphere.

---

### 4. Health Orb 1.1 (itsmars)

**URL:** https://opengameart.org/content/health-orb-11
**Direct ZIP:** https://opengameart.org/sites/default/files/itsmars%20Health%20Orb%201.1.zip
**License:** CC0 Public Domain
**Author:** itsmars
**Status:** DOWNLOADED AND EXTRACTED to `assets/ui/orb_frames/health_orb/`

**What's included (extracted):**
- `HealthPanel.png` — Red-tinted health orb/globe frame
- `ManaPanel.png` — Blue-tinted mana orb/globe frame
- `DarkOrbBorder.png` — Dark border ring for orb overlay
- `52x52 SpellSlotBorder.png` — Action slot border frame
- `HealthManaPanels.psd` — Photoshop source for customization

**Where to use in this project:**
- `HealthPanel.png` → player HP display in combat (replace the current bar with an orb)
- `ManaPanel.png` → energy/mana display (or block visualization)
- `DarkOrbBorder.png` → outer ring layer stacked on top of the health fill
- `SpellSlotBorder.png` → card hand slot indicators or quick-use action slots

**Godot usage notes:**
- Stack multiple `TextureRect` nodes: background fill color → orb border PNG → animated
  liquid shader underneath for the "sloshing" health effect
- The white fill version (v1.0) can be tinted dynamically via `modulate` in GDScript:
  `orb_sprite.modulate = Color(1, 0.2, 0.2)` for red health

**Implementation idea for our combat scene:**
```gdscript
# In enemy_display.gd or player HUD
func update_hp_orb(current: int, max_val: int) -> void:
    var pct := float(current) / float(max_val)
    orb_fill.material.set_shader_parameter("fill_amount", pct)
    # Tint shifts from green -> yellow -> red as hp drops
    orb_fill.modulate = Color(1.0 - pct, pct, 0.0).lerp(Color.RED, 1.0 - pct)
```

---

### 5. RPG Inventory (itsmars)

**URL:** https://opengameart.org/content/rpg-inventory
**Direct ZIPs:**
  - https://opengameart.org/sites/default/files/RPG%20Inventory.zip (5.1 MB)
  - https://opengameart.org/sites/default/files/RarityBorders.zip (20.6 KB)
**License:** CC0 Public Domain
**Author:** itsmars
**Status:** DOWNLOADED AND EXTRACTED to `assets/ui/inventory/`

**What's included (extracted):**
- `rpg_inventory/itsmars_Inventory.png` — Full inventory/character sheet background image
  (Diablo/Path of Exile style, with paperdoll area and grid slots)
- `rpg_inventory/64x64 BagSlotBorder.png` — Standard inventory slot border (64x64)
- `rpg_inventory/81x81 EquipSlotBorder.png` — Equipment slot border, larger (81x81)
- `rpg_inventory/itsmars_Inventory.psd` — Photoshop source
- `rarity_borders/MagicBorderV11.png` — Blue magic/uncommon rarity border
- `rarity_borders/RareBorderV11.png` — Yellow rare rarity border
- `rarity_borders/UniqueBorderV11.png` — Orange/gold unique rarity border

**Where to use in this project:**
- `itsmars_Inventory.png` → background for the equipment screen (equipment_screen.gd)
- `64x64 BagSlotBorder.png` → relic display slots in combat and shop
- `81x81 EquipSlotBorder.png` → equipment slot borders in the equipment screen
- Rarity borders → overlay on cards or relics to show rarity tier
  - Magic (blue) → uncommon cards
  - Rare (yellow) → rare cards
  - Unique (orange) → boss relics or cursed items

**Implementation idea:**
```gdscript
# In card_visual.gd, overlay a rarity border based on card rarity
func apply_rarity_border(rarity: Enums.CardRarity) -> void:
    match rarity:
        Enums.CardRarity.COMMON:
            rarity_border.texture = null
        Enums.CardRarity.UNCOMMON:
            rarity_border.texture = preload("res://assets/ui/inventory/rarity_borders/MagicBorderV11.png")
        Enums.CardRarity.RARE:
            rarity_border.texture = preload("res://assets/ui/inventory/rarity_borders/RareBorderV11.png")
```

---

## Font Details

All fonts are SIL Open Font License (OFL) — free for personal and commercial use,
embedding in games permitted, redistribution allowed.

---

### MedievalSharp

**File:** `assets/fonts/MedievalSharp.ttf`
**Source:** Google Fonts / https://fonts.google.com/specimen/MedievalSharp
**Designer:** Wojciech Kalinowski
**License:** SIL OFL 1.1
**Status:** DOWNLOADED

**Style:** Gothic blackletter-influenced display font with sharp angular serifs.
Clean enough to be legible at large sizes while carrying strong medieval character.

**Use in this project:**
- Boss name displays in combat (Metatron, Hexaghost, etc.)
- Chapter/Act title cards between map sections
- Major event screen headings
- Win/lose screen large text

**Godot import:**
```gdscript
var font = preload("res://assets/fonts/MedievalSharp.ttf")
label.add_theme_font_override("font", font)
label.add_theme_font_size_override("font_size", 48)
```

---

### Cinzel Decorative

**File:** `assets/fonts/CinzelDecorative-Regular.ttf`
**Source:** Google Fonts / https://fonts.google.com/specimen/Cinzel+Decorative
**Designer:** Natanael Gama
**License:** SIL OFL 1.1
**Status:** DOWNLOADED

**Style:** Roman inscription-inspired with decorative flourishes. Elegant, ancient,
slightly ornate. All-caps is its strongest form. Works well gold-tinted.

**Use in this project:**
- Game title on the main menu
- "VICTORY" / "DEFEAT" overlays
- Relic names in the relic tooltip
- Section headers (e.g., "THE MAP", "YOUR DECK")
- Epilogue screen chapter text

**Pairing note:** Works beautifully with Lato body text — the contrast between
the ornate caps and clean sans is the core of Diablo-style UI typography.

---

### Share Tech Mono

**File:** `assets/fonts/ShareTechMono-Regular.ttf`
**Source:** Google Fonts / https://fonts.google.com/specimen/Share+Tech+Mono
**License:** SIL OFL 1.1
**Status:** DOWNLOADED

**Style:** Clean monospace sans-serif with a slight technical/digital feel.
Highly legible at small sizes. Perfect for numbers and code-like UI.

**Use in this project:**
- HP/block/energy numbers in combat HUD
- Card cost numbers
- Damage/shield values in enemy intent display
- Balance dashboard F12 overlay (already fits the debug aesthetic)
- Card descriptions (monospace reads well for short stat lines)
- Run summary stats screen (numbers, turn counts, damage dealt)

---

### Lato

**Files:** `assets/fonts/Lato-Regular.ttf`, `assets/fonts/Lato-Bold.ttf`
**Source:** Google Fonts / https://fonts.google.com/specimen/Lato
**Designer:** Lukasz Dziedzic
**License:** SIL OFL 1.1
**Status:** DOWNLOADED (Regular + Bold)

**Style:** Humanist sans-serif. Extremely legible at body text sizes.
Warm but professional. Industry-standard choice for game UI body copy.

**Use in this project:**
- Card description body text (the effect explanation paragraph)
- Tooltip body text
- Shop item descriptions
- Event screen story text (the narrative paragraphs)
- Menu button labels
- Settings/options screen text

**Sizing guide:**
- 12–14px: stat labels, small UI chrome
- 16–18px: card body text, button text
- 20–24px: section headers (use Bold variant)
- Bold at 16px: keyword highlights within card descriptions

---

## Directory Tree (post-download)

```
card_game/assets/
├── DOWNLOAD_GUIDE.md          (this file)
├── fonts/
│   ├── CinzelDecorative-Regular.ttf   (display — title screens, boss names)
│   ├── Lato-Bold.ttf                   (body — headers, button labels)
│   ├── Lato-Regular.ttf                (body — descriptions, tooltips)
│   ├── MedievalSharp.ttf               (display — gothic headings)
│   └── ShareTechMono-Regular.ttf       (mono — numbers, stats, HUD)
└── ui/
    ├── buttons/                         (empty — populate from Kenney packs)
    ├── dark_fantasy/                    (NEEDS Foozle manual download)
    ├── inventory/
    │   ├── rarity_borders/
    │   │   ├── MagicBorderV11.png
    │   │   ├── RareBorderV11.png
    │   │   └── UniqueBorderV11.png
    │   ├── rpg_inventory/
    │   │   ├── 64x64 BagSlotBorder.png
    │   │   ├── 81x81 EquipSlotBorder.png
    │   │   ├── itsmars_Inventory.png
    │   │   └── itsmars_Inventory.psd
    │   ├── rpg_inventory.zip
    │   └── rarity_borders.zip
    ├── kenney/
    │   ├── kenney_ui_pack/
    │   │   ├── PNG/
    │   │   │   ├── Blue/Default/   (868 PNGs total across all colors)
    │   │   │   ├── Green/
    │   │   │   ├── Grey/           <- Use Grey for neutral panels
    │   │   │   ├── Red/
    │   │   │   └── Yellow/
    │   │   ├── Spritesheet/
    │   │   ├── Font/
    │   │   └── Vector/
    │   ├── kenney_rpg_expansion/
    │   │   ├── PNG/                (87 PNGs — bars, arrows, buttons)
    │   │   └── Spritesheet/
    │   ├── kenney_ui-pack.zip
    │   └── kenney_ui-pack-rpg-expansion.zip
    ├── orb_frames/
    │   ├── health_orb/
    │   │   ├── HealthPanel.png
    │   │   ├── ManaPanel.png
    │   │   ├── DarkOrbBorder.png
    │   │   ├── 52x52 SpellSlotBorder.png
    │   │   └── HealthManaPanels.psd
    │   └── itsmars_health_orb_1.1.zip
    ├── panels/                          (empty — populate from Kenney packs)
    └── tooltips/                        (empty — assemble from Kenney/Foozle)
```

---

## Recommended Next Steps

### Immediate (assets are ready):

1. **Add fonts to Godot project** — Open `project.godot`, go to Project > Project Settings
   > General > Fonts, or just reference the TTF paths via `preload()` in scripts.

2. **Delete stale .import files from Kenney pack** — The zip contained `.import` files
   from a previous Godot project. Run this from the project root:
   ```bash
   find card_game/assets/ui/kenney -name "*.import" -delete
   ```
   Then re-open Godot and let it re-import all textures correctly.

3. **Set up NinePatch rects** — For the Kenney panel PNGs, the nine-patch margins are
   approximately 4px on each side for most panels. In the Godot import dialog, use
   `TextureRect` with `NinePatchRect` mode, or use the `StyleBoxTexture` resource.

4. **Rarity borders on cards** — The rarity border PNGs from itsmars are 64x64 and
   81x81. Scale them to match card size in `card_visual.tscn` as a top-layer `TextureRect`.

### Requires manual download:

5. **Foozle RPG UI Set 1** — Visit https://foozlecc.itch.io/rpg-ui-set-1, download the
   free zip, and extract to `card_game/assets/ui/dark_fantasy/`. This provides the heavy
   gothic panel frames needed for shop, event, and combat backgrounds.

### Optional enhancements:

6. **Additional Kenney packs** (all CC0):
   - UI Pack (Space Expansion): https://kenney.nl/assets/ui-pack-space-expansion — for cyber/tech panels
   - Game Icons: https://kenney.nl/assets/game-icons — status effect icons
   - Input Prompts: https://kenney.nl/assets/input-prompts — controller/keyboard prompts

7. **More gothic fonts** (all OFL):
   - UnifrakturMaguntia: https://fonts.google.com/specimen/UnifrakturMaguntia — heavier blackletter
   - Pirata One: https://fonts.google.com/specimen/Pirata+One — pirate/fantasy style
   - IM Fell English: https://fonts.google.com/specimen/IM+Fell+English — aged book style

---

*Generated 2026-04-03. All CC0/OFL assets may be used without attribution in commercial projects.*
