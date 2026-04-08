# deus.exe Art Pipeline

> **Source of aesthetic truth:** `ART_DIRECTION.md`
> Read that first. This file is just the mechanics.

---

## Tools

| Role | Tool |
|---|---|
| Image generation | **Nano Banana 2** (`gemini-3.1-flash-image-preview`) via `google-genai` SDK, reads `GEMINI_API_KEY` from env |
| Chroma key / compositing | Python + Pillow (no heavy dependencies) |
| Final scene composition | Godot 4 — layer parallax, card rendering, runtime effects |
| Pipeline scripting, prompt iteration | Claude Code (Opus 4.6) |

**Not using:** ComfyUI, SDXL, LoRAs, Flux, any local GPU inference. The legacy `comfyui_api.py` / old `generate.py` / LoRA-tag-stack system is **deprecated but not yet deleted**. Will be removed once the new pipeline produces one full character cast.

---

## The 6 phases

### Phase 1 — Art Direction Anchors &nbsp; *(gate: everything else depends on these)*

Generate 3 locked visual references that embody the direction. **Every future generation passes the relevant anchor(s) as reference image inputs.** If the anchors are wrong, everything downstream is wrong.

- `anchors/character_anchor.png` — Zephyr as a painted horror figure on green screen with EMPTY HANDS, locking painted-realism technique, palette, proportion, and reverent stance for the whole character cast
- `anchors/background_anchor.png` — an empty desecrated cathedral nave painted as an ultrawide backdrop, NO set dressing (no altar, no pews, no candles), locking the painted-backdrop style for every Phase 3A environment
- `anchors/prop_anchor.png` — a broken altar as a single hero prop on green screen, locking the canonical UPPER-LEFT sun lighting direction and painted-prop technique for every Phase 3B prop in the library

**Gate:** do not proceed past Phase 1 until all three anchors visually match the direction. Iterate prompts in `anchors/prompts/` until they do.

### Phase 2 — Character Cast

6 characters. Each generated using the Phase 1 character anchor as a style reference for line weight, palette, and proportion consistency.

Per character, ~5 flat sprite poses on green screen:
- Idle (combat stance)
- Attack (signature action)
- Cast (skill / ability use)
- Hurt (damage taken)
- Defeated (defeat pose)

→ `characters/<id>/<pose>.png` on green screen.

### Phase 3A — Backdrop Library (the empty stage sets)

10–15 painted backdrops. Each is an empty architectural shell — walls, floor, ceiling, distant window, distant architecture — painted as a full ultrawide image but **prop-empty**. Every backdrop uses the Phase 1 background anchor as a style reference so painterly technique, lighting direction, and palette stay coherent.

Categories:
- Act 1: corrupted kernel chamber, broken server nave, crashed boot loader hall
- Act 2: data cathedral, altar chamber, reliquary crypt, cache scriptorium
- Act 3: the Core, the Judgment chamber, the Final Compile
- Meta-rooms: shop (broken confessional), rest site (side chapel), elite encounter, boss arena
- Character select / title screen

→ `backdrops/<scene_id>.png` — ultrawide 21:9, character-free and prop-free, ready to have prop sprites and characters composited on top in Phase 5A.

### Phase 3B — Prop Library (the composable objects)

~50 painted props, each generated in isolation on green screen, each using the Phase 1 prop anchor (broken altar) as a style reference so every prop shares the same painted technique, upper-left sun direction, and palette.

Prop categories:
- **Sacred furniture:** altars (broken, intact, blood-soaked), pews, lecterns, pulpits, choir stalls, confessionals, prayer-kneelers
- **Desecrated tech:** rusted server racks (as pews), dead monitors, cable bundles, exposed power conduits, broken terminals, fiber-optic censers, CRT reliquaries
- **Relic objects:** tarnished-gold reliquary boxes, iron rosary-chains, black-wax candles in iron holders, thuribles (rusted, leaking, intact), burnt codex pages, crucifixes (bent, upside-down, circuit-embedded), bone fragments in glass cases
- **Mundane dressing:** barrels, crates, sacks, broken pottery, puddles, torn banners, loose chains
- **Atmosphere objects:** dust-mote volumetric beams, smoke plumes, bile-green seepage patches, arterial-red cable-bleed stains (painted as separable atmospheric sprites, not bound to any backdrop)

Each prop is a single painted asset on green screen, lit from upper-left with baked chiaroscuro, with a small implied footprint (a few inches of ground under freestanding props) but no surrounding environment.

→ `props/<category>/<id>.png` — square or portrait aspect depending on prop shape, keyable chroma-green background, ready for Phase 4 chroma key.

### Phase 4 — Chroma Key

One Python pass: chroma-key every green-screen asset into a clean PNG with alpha. Backdrops are already painted with their own backgrounds (no keying needed).

- Character sprites → `characters/<id>/<pose>_keyed.png`
- Props → `props/<category>/<id>_keyed.png`
- Effect layer sprites (weapons, shards, spell VFX) → `effects/<id>_keyed.png`
- Backdrops → no keying needed (already opaque architectural paintings)

No parallax splitting is needed — because props are already isolated, every prop is its own parallax layer when arranged in Godot. The legacy `parallax_split.py` can be deleted; we only need a simple `chroma_key.py` that keys the exact green used in the prompts.

### Phase 5 — Godot Composition (scenes AND cards)

Two related composition jobs, both living in Godot.

**5A. Scene composition.** Gameplay scenes are assembled by arranging props from the Phase 3B library on top of a backdrop from the Phase 3A library in a Godot scene tree. Example: `scene_kernel_chamber_01.tscn` stacks the `backdrop_kernel_chamber.png` + `altar_broken.png` + two `server_rack_pew.png` + a `candle_black_wax.png` on the altar + a `rosary_iron.png` draped on a pew + an atmospheric `dust_beam.png` layer on top. One backdrop painting supports many unique scenes because the props are swappable.

Per-scene layout constants live in `scene_layouts/<scene_id>.gd` so scenes can be hand-tuned (prop positions, scales, z-order, tint) without fighting the AI.

**5B. Card composition.** Cards are composed from:

```
{character sprite pose} + {scene crop or prop crop} + {fx layer} + {frame UI}
```

**152 cards → ~40 unique art assets.** Logic lives in `CardArtComposer.tscn` taking card metadata and producing a renderable card face. Per-card layout constants live in `layout_constants.gd` singleton so we can hand-tune offsets/scales/heights without touching agent-generated code. (Lesson from the Street Fighter AI workflow video — stops the AI from fighting you when you want to nudge pixels.)

### Phase 6 — Relics, Icons, Enemies

Same pipeline, different subjects:
- **Relics:** small flat icons on green screen, referencing the character anchor for line weight
- **Icons:** micro-sprites for status effects and keywords
- **Enemies:** flat sprites like characters, but fewer poses per enemy (usually 1–2)

---

## Directory layout

```
art_pipeline/
├── ART_DIRECTION.md              # source of aesthetic truth
├── PIPELINE.md                   # this file
├── anchors/
│   ├── prompts/
│   │   ├── character_anchor.txt  # editable — tweak to iterate
│   │   ├── background_anchor.txt # empty cathedral backdrop
│   │   └── prop_anchor.txt       # broken altar hero prop
│   ├── character_anchor.png      # output of Phase 1
│   ├── background_anchor.png     # output of Phase 1
│   └── prop_anchor.png           # output of Phase 1
├── generate_anchors.py           # Phase 1 runner (supports --only <name>)
├── characters/
│   └── <character_id>/           # Phase 2 output — poses on green screen
├── backdrops/                    # Phase 3A output — empty painted cathedrals
├── props/
│   ├── sacred_furniture/         # altars, pews, lecterns
│   ├── desecrated_tech/          # server racks, monitors, cables
│   ├── relic_objects/            # candles, reliquaries, chains
│   ├── mundane_dressing/         # barrels, crates, banners
│   └── atmosphere/               # light beams, smoke, seepage
├── effects/                      # character effect-layer sprites
└── (legacy ComfyUI stuff)        # to be deleted post-migration
```

---

## Prompt engineering rules (stolen & adapted from the Street Fighter AI workflow video)

1. **Reference images beat words.** Every call after Phase 1 passes anchor image(s) as reference — don't rely purely on prose.
2. **Use the exact phrase `"single solid color code bright green screen background"`** for any sprite that needs keying. Nano Banana 2 reliably produces clean chroma-keyable backgrounds with this exact wording.
3. **Anchor the proportions.** Second and subsequent characters use the *first* character anchor as a reference — this locks scale and line weight across the cast.
4. **Never generate finished scenes.** Backdrops (Phase 3A) are prop-empty architectural shells. Props (Phase 3B) are individually generated on green screen. Scenes are assembled in Godot (Phase 5A) by stacking props on backdrops. If you are tempted to prompt for "a full cathedral scene with an altar and pews and candles," stop and split it into one backdrop + several props.
5. **No text in images, ever.** Any text on a card comes from the Godot runtime, not the AI.
6. **Negative constraints matter.** The rejection list in `ART_DIRECTION.md` should be reflected in every prompt's "do not" section.
7. **Iterate prompts in text files, not Python.** Keeps the knobs separate from the machinery.

---

## Where we are right now

**Phase 1 — in progress.** Running `generate_anchors.py` produces all three anchor images (character, background, prop). Iterate prompts in `anchors/prompts/` until the anchors are right. Use `--only <name>` to regenerate one at a time. Then we gate into Phase 2.
