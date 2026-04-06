# Digital Genesis Card Art Pipeline

Batch-generates card art for all 49 cards using ComfyUI + SDXL, with **multi-LoRA tag-based style stacking**, card-type accent moods, corruption tier overlays, and KomikoAI layer splitting.

## Prerequisites

- **ComfyUI** installed at `E:/ComfyUI` (configured in `config.json`)
- **SDXL base checkpoint** (`sd_xl_base_1.0.safetensors`) in `E:/ComfyUI/models/checkpoints/`
- **Style LoRA** (`dark_gothic_fantasy_xl_3.01.safetensors`) in `E:/ComfyUI/models/loras/` (fallback)
- **Python 3.10+** with access to the art_pipeline scripts

### Optional Custom Nodes

The base workflow uses only standard ComfyUI nodes. For advanced features:

| Node Pack | Purpose | Install |
|---|---|---|
| ComfyUI-Manager | Easy node management | Pre-installed with most ComfyUI setups |
| KomikoAI | Layer splitting (FG/MG/BG) | `pip install komiko` or ComfyUI-Manager |
| ComfyUI-Impact-Pack | Advanced masking for corruption | Install via ComfyUI-Manager |

## Quick Start

```bash
# 1. Start ComfyUI
start_comfyui.bat

# 2. Generate a single card
python generate_cards.py --card strike

# 3. Generate all 49 base cards
python generate_cards.py --all

# 4. Generate everything + corruption variants (49 base + 147 corrupted = 196 images)
python generate_cards.py --all --corrupt

# 5. Preview what would be generated without running
python generate_cards.py --all --corrupt --dry-run
```

## File Structure

```
art_pipeline/
  config.json                    # Pipeline config (paths, models, style settings)
  card_prompts.json              # All 49 card definitions with prompts, tags, types
  card_art_workflows.py          # Workflow builders (tag injection, corruption, batch)
  generate_cards.py              # CLI batch generator
  digital_genesis_card_art.json  # ComfyUI-importable template workflow
  CARD_ART_README.md             # This file

assets/cards/illustrations/      # Output directory
  strike/
    strike_base.png              # Base card art
    strike_corrupt_t1.png        # Tainted variant
    strike_corrupt_t2.png        # Corrupted variant
    strike_corrupt_t3.png        # Demonic variant
  defend/
    defend_base.png
    ...
```

## CLI Reference

### Selection Flags (pick one)

| Flag | Description | Example |
|---|---|---|
| `--all` | All 49 cards | `--all` |
| `--card ID` | Single card by ID | `--card holy_wrath` |
| `--type TYPE` | All cards of a type | `--type ATTACK` |
| `--tag TAG` | All cards with a tag | `--tag HOLY` |
| `--character NAME` | Character-specific cards | `--character Netrunner` |
| `--list` | List all card IDs | `--list` |
| `--export-workflow` | Export ComfyUI JSON | `--export-workflow` |

### Generation Options

| Flag | Description | Default |
|---|---|---|
| `--corrupt` | Generate corruption tiers 1-3 | Off |
| `--tier N` | Only generate specific tier (1/2/3) | All tiers |
| `--seed N` | Fixed seed for reproducibility | Random |
| `--output DIR` | Custom output directory | From config |
| `--dry-run` | Preview without generating | Off |
| `--url URL` | ComfyUI API URL | `http://127.0.0.1:8188` |

### Examples

```bash
# All attack cards only
python generate_cards.py --type ATTACK

# All HOLY-tagged cards with tier 2 corruption
python generate_cards.py --tag HOLY --tier 2

# Netrunner signature cards with fixed seed
python generate_cards.py --character Netrunner --seed 12345

# Single card with all corruption variants
python generate_cards.py --card dark_compile --corrupt
```

## How the Prompt System Works

### Prompt Assembly

Each card's positive prompt is assembled from four layers:

```
{card_specific_prompt}          <- Unique per card (from card_prompts.json)
{cyberpunk_style_prefix}        <- Shared cyberpunk aesthetic keywords
{tag_style_keywords}            <- Combined from card's tags (MELEE, HOLY, etc.)
{type_mood_keywords}            <- Based on card type (ATTACK=aggressive, SKILL=defensive)
```

**Example for `holy_wrath` (ATTACK, tags: FIRE + HOLY):**

```
devastating beam of golden divine light raining down from above, angelic geometry
surrounding the blast, holy fire and sacred energy, wrathful radiance,
cyberpunk digital realm, neon glow, circuit patterns, holographic, dark background,
detailed illustration, card game art, centered composition,
digital fire, burning circuits, thermal overload, flame particles, heat distortion,
golden light, geometric halo, divine radiance, white energy, sacred geometry,
aggressive, violent, dynamic motion, red-orange energy trails, impact moment,
red energy glow, orange sparks, attack motion blur
```

### Tag Style Keywords

| Tag | Visual Keywords |
|---|---|
| MELEE | close combat, glowing fists, energy blade, cybernetic arms |
| RANGED | data projectiles, laser beam, thrown code construct, trajectory trail |
| FIRE | digital fire, burning circuits, thermal overload, flame particles |
| ICE | crystallized data, frozen process, blue-white shards, cryo energy |
| HOLY | golden light, geometric halo, divine radiance, white energy, sacred geometry |
| SHADOW | void energy, dark tendrils, purple corruption, glitch distortion |
| TECH | circuit board patterns, holographic interface, code terminal, data streams |
| EXPLOIT | broken firewall, injected code, system breach, hack visualization |
| CURSE | visual glitching, chromatic aberration, data decay, corrupted pixels |

Multi-tag cards combine their keywords. For example, a card tagged `[SHADOW, EXPLOIT]` gets both shadow and hacking visual keywords.

### Card Type Moods

| Type | Mood | Border Accent |
|---|---|---|
| ATTACK | aggressive, violent, dynamic motion | Red/orange (#FF3300) |
| SKILL | protective, technical, precise | Cyan/blue (#0088FF) |
| POWER | sustained, powerful, emanating | Gold (#FFD700) |
| CURSE | corrupted, unstable, decaying | Purple (#660099) |

## Corruption Tiers

Cards can have corruption variants generated via img2img from the base art:

| Tier | Name | Denoise | Visual Effect |
|---|---|---|---|
| 0 | Clean | N/A | Base art, no corruption |
| 1 | Tainted | 0.25 | Subtle purple edge glow, minor glitch artifacts |
| 2 | Corrupted | 0.45 | Heavy glitch distortion, purple/black color shift, data decay |
| 3 | Demonic | 0.65 | Full corruption, red-purple energy cracks, reality breaking |

The corruption pass uses img2img with the base card as input. Higher denoise means more deviation from the original. A feathered edge mask keeps the center subject mostly intact while corrupting the edges more heavily.

## Customizing Per-Card Prompts

Edit `card_prompts.json` to customize any card's art:

```json
{
  "strike": {
    "display_name": "System Strike",
    "card_type": "ATTACK",
    "tags": ["MELEE"],
    "prompt": "YOUR CUSTOM PROMPT HERE",
    "has_plus": true
  }
}
```

Key fields:
- **prompt**: The card-specific visual description (most important to customize)
- **tags**: Array of tag names that inject style keywords
- **card_type**: Determines mood/accent keywords (ATTACK/SKILL/POWER/CURSE)
- **character**: Optional, for character-specific filtering

## Using the ComfyUI GUI Workflow

For manual single-card generation in the ComfyUI web interface:

1. Open ComfyUI (`http://127.0.0.1:8188`)
2. Load `digital_genesis_card_art.json` via the Load button
3. Edit the **Positive Prompt** node with your card's assembled prompt
4. Edit the **Save Image** filename prefix (`cards/CARDNAME/CARDNAME_base`)
5. Set the seed (or use randomize for variations)
6. Queue the prompt

The workflow includes reference notes for tag keywords, type moods, and corruption tier settings.

## Multi-LoRA Tag System

The pipeline supports **automatic LoRA stacking** based on card tags. Each tag maps to specific LoRAs, and multi-tag cards get combined stacks (capped at 3 LoRAs max).

### Check LoRA Status

```bash
python generate_cards.py --lora-check
```

This shows which LoRAs are installed, which are missing, and what each card would use.

### Recommended LoRA Downloads

Download these into `E:/ComfyUI/models/loras/`:

| LoRA | Purpose | Tags | Download |
|---|---|---|---|
| **Neon Cyberpunk Splash Art** | Core neon cyberpunk aesthetic | Base (all cards) | [CivitAI #351631](https://civitai.com/models/351631) |
| **Sacred Geometry** | Divine geometric patterns | HOLY | [CivitAI #228907](https://civitai.com/models/228907) |
| **Holographic Style** | Tech holographic shimmer | TECH, ICE | [CivitAI #535934](https://civitai.com/models/535934) |
| **Seraphim Style** | Angelic ethereal aesthetic | HOLY | [CivitAI #238276](https://civitai.com/models/238276) |
| **Eldritch Digital Art** | Dark void corruption | SHADOW, CURSE | [CivitAI #303233](https://civitai.com/models/303233) |
| **Glowing Style XL** | Neon glow effects | MELEE, RANGED, FIRE | [CivitAI #138581](https://civitai.com/models/138581) |
| **Neon Cyberpunk Datastream** | Data stream visualization | TECH, EXPLOIT | [CivitAI #588233](https://civitai.com/models/588233) |

**Important:** The filenames in `card_prompts.json` -> `lora_library` must match exactly. After downloading, rename files to match or update the `filename` field in the JSON.

### Tag -> LoRA Mapping

| Tag | LoRA Stack |
|---|---|
| *(base, all cards)* | Neon Cyberpunk Splash (0.45) |
| MELEE | + Glowing Style (0.25) |
| RANGED | + Glowing Style (0.25) |
| FIRE | + Glowing Style (0.3) |
| ICE | + Holographic Style (0.25) |
| HOLY | + Sacred Geometry (0.4) + Seraphim (0.3) |
| SHADOW | + Eldritch Digital (0.4) |
| TECH | + Datastream (0.3) + Holographic (0.2) |
| EXPLOIT | + Datastream (0.3) |
| CURSE | + Eldritch Digital (0.45) |

**Example: `holy_wrath` (tags: FIRE + HOLY)**
- Base: Neon Cyberpunk Splash (0.45)
- FIRE: Glowing Style (0.3)
- HOLY: Sacred Geometry (0.4) -- strongest, takes priority in top 3

**Example: `dark_compile` (tags: SHADOW + EXPLOIT)**
- Base: Neon Cyberpunk Splash (0.45)
- SHADOW: Eldritch Digital (0.4)
- EXPLOIT: Datastream (0.3)

### Fallback Behavior

When no multi-LoRAs are installed, the pipeline falls back to the single `card_art_lora` from `config.json` (currently `dark_gothic_fantasy_xl_3.01.safetensors`). You can use the system with zero, some, or all LoRAs installed — it only uses what it finds on disk.

### Customizing LoRA Assignments

Edit `card_prompts.json` -> `tag_lora_mapping`:

```json
"HOLY": [
  ["sacred_geometry", 0.4],
  ["seraphim_style", 0.3]
]
```

Each entry is `[lora_key, strength]`. The `lora_key` must exist in `lora_library`.

## Training a Custom LoRA (Alternative)

Instead of the multi-LoRA stack, you can train a single unified LoRA:

1. Collect 20-30 reference images matching the desired cyberpunk-divine aesthetic
   - Mix of: Tron Legacy concept art, Ghost in the Shell UI, Diablo ability icons
   - Focus on: neon glow, circuit patterns, dark backgrounds, holographic effects
2. Caption images with consistent style tags
3. Train with kohya_ss or similar SDXL LoRA trainer
   - Recommended: 1500-2000 steps, learning rate 1e-4, rank 32
4. Save to `E:/ComfyUI/models/loras/`
5. Update `config.json`:
   ```json
   "card_art_lora": "your_custom_cyberpunk_lora.safetensors",
   "card_art_lora_strength": 0.65
   ```

## KomikoAI Layer Splitting (Post-Processing)

After generating base art, you can split layers for Godot animation:

```python
# In Python, or add to generate_cards.py pipeline
from komiko import split_layers

result = split_layers("assets/cards/illustrations/strike/strike_base.png")
# Outputs:
#   strike_base_fg.png  (foreground: character/main effect)
#   strike_base_mg.png  (midground: energy/particles)
#   strike_base_bg.png  (background: environment/atmosphere)
```

This is handled by the existing `parallax_split.py` infrastructure if KomikoAI is installed.

## Output Specifications

| Property | Value |
|---|---|
| Resolution | 512x768 (portrait, card art window) |
| Format | PNG (transparent background supported) |
| Color Space | sRGB |
| Sampler | DPM++ 2M Karras |
| Steps | 35 |
| CFG Scale | 7.5 |
| Total Base Images | 49 |
| Total with Corruption | 196 (49 x 4 tiers) |

## Troubleshooting

**ComfyUI not connecting:**
- Run `start_comfyui.bat` first
- Check that port 8188 is not blocked
- Verify `comfyui_url` in `config.json`

**VRAM errors (512x768 should be fine for most GPUs):**
- SDXL needs ~6GB VRAM at 512x768
- If issues persist, try `--fp16` mode in ComfyUI args

**Inconsistent style across cards:**
- Train a custom LoRA (see above)
- Use a fixed seed range for the batch
- Ensure the style prefix is consistent in config.json

**Card art too dark/bright:**
- Adjust CFG scale in config.json `card_art_defaults`
- Lower CFG (5-6) = more creative, higher (8-9) = more prompt-faithful
