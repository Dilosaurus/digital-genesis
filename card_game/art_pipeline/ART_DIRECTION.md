# deus.exe — Art Direction

**Working title:** *Illuminated Malware* / *Reliquary*

---

## One-line pitch

*deus.exe is a Book of Hours that crashed. The OS is God. The daemons are real. Every card is a page ripped from a corrupted scripture.*

## Tone (three words)

**Reverent. Corrupted. Precise.**

The player should feel they are looking at a sacred artifact that has been defiled — not flashy, not shouty. Quiet dread with moments of terrible beauty. When a strong card flips, it should feel like turning a page in a book you are not supposed to be reading.

---

## Core technique

**Painted horror realism, separable 2D layers, composited in engine.**

Everything is painted — characters, environments, props, effects — in the tradition of oil-painted horror concept art. *Not* cartoon-flat. *Not* Cult of the Lamb. *Not* chibi or stylized-cute. Think Bloodborne concept art, Wayne Barlowe's *Inferno* demons, Zdzisław Beksiński's figures, Darkest Dungeon heroes pushed toward realism, Junji Ito dread rendered in oil. The figures are gaunt and unsettling, the surfaces have weight and grime, and the chiaroscuro is dramatic.

Every image in the game is one of three separable 2D layer types, generated in isolation and composited at runtime in Godot:

1. **Painted backdrops** — the empty "stage set" for a scene: walls, floor, ceiling, distant architecture. Generated as full ultrawide paintings but *prop-empty* — no altars, no pews, no candles, no reliquaries. Just the architectural shell of the room.
2. **Painted props** — every removable object in the world (altars, pews, server racks, candles, reliquaries, thuribles, chains, burnt pages, crucifixes, bone fragments, barrels) generated individually on green screen, each lit from a canonical upper-left sun direction so they share coherent shadows when composited.
3. **Painted characters and effects** — characters generated on green screen with empty hands and neutral reverent pose. Held weapons, floating shards, spell effects, and orbital runes are generated as SEPARATE effect-layer sprites and animated over the character at runtime — never baked into the base character.

This gives us:
- Unified painted look across the whole game because every layer is the same kind of painting
- Massive asset reuse — one painted altar, arch, server rack, or candle composites into many different scenes; one painted character composites with many different backdrops
- **Scenes are puppet-theater assemblies of painted pieces**, never monolithic scene paintings. Godot stacks backdrop + props + characters + effects into the final view.

Every scene should still feel like looking into a **reliquary shadow-box** — a glass cabinet of sacred curiosities — but the curiosities inside are painted with weight and dread, not stylized into cute flatness. The shadow-box metaphor is now literal: each painted piece is a physical object in the cabinet, not a brush stroke on a flat canvas.

This technique is continuous with 1500 years of sacred art: illuminated manuscripts placed realistic painted saints against elaborate decorative borders, oil-painted altarpieces depicted suffering in horrifying detail, and reliquary dioramas staged sacred horror inside glass boxes. **The form is the theme.**

---

## The thematic double meaning

The religious / code double meaning is the entire point of the project.

| Word | Code meaning | Sacred meaning |
|---|---|---|
| daemon | background process | fallen spirit |
| compile | build software | assemble scripture |
| corruption | data rot | moral decay |
| patch | software update | ritual healing |
| flush | cache eviction | ritual cleansing |
| hash | one-way function | ritual scarring |
| exception | runtime error | moral transgression |
| kernel | OS core | sacred inner chamber |

Every card, character, and environment should lean into this doubling. A Bandage isn't a bandage — it's *last rites applied via code*. A Strike isn't a sword — it's *a psalm sharpened into a blade*.

---

## Visual lineage

### 3D diorama backdrops
- **Guillermo del Toro** — *Crimson Peak*, *Pan's Labyrinth* cabinet sets
- **Coraline** (stop-motion) — detailed horror miniatures
- **Capuchin Crypt / Sedlec Ossuary** — real sacred bone dioramas
- **Wunderkammer / Victorian cabinets of curiosity** — the framing device
- **Darkest Dungeon** — staging horror at scale without breaking
- **Disco Elysium** — painted environments with painterly character portraits
- **Zdzisław Beksiński** — background architecture, monumental dread

### Painted horror figures
- **Wayne Barlowe** (*Inferno*, *God's Demon*) — painted fallen angels as horrific real *things*, not pretty
- **Zdzisław Beksiński** — painted figures of dread, biomechanical bodies
- **Bloodborne / Dark Souls concept art** — gaunt ruined figures in painted detail
- **Darkest Dungeon hero portraits** — the painterly-realistic reference
- **Junji Ito (painted interpretations)** — body horror rendered seriously
- **Caravaggio / Zurbarán** — sacred figures in oil, dramatic chiaroscuro, religious horror
- **Francis Bacon** — smeared screaming popes, distortion as devotion

### Compressed pitch
*Bloodborne concept artists painting the Capuchin Crypt for a Guillermo del Toro horror film about a crashed operating system that believes it is God.*

---

## Rendering rules

### For painted character figures
- **Painted horror realism** — oil-paint feel, visible brushwork, painterly edges (not hard vector lines, not airbrushed smoothness, not 3D CG render)
- Dramatic chiaroscuro — strong single-source directional light, deep shadows, edges that dissolve into darkness
- Serious adult anatomy — gaunt, ascetic, weight-bearing. Never chibi, never cute, never moe, never heroic-beefcake, never Marvel
- Figures look slightly *wrong*: too thin, too tall, too hollow-eyed, too still. Unsettling before they are beautiful
- 3/4 reverent stance by default — never pure front, never pure side, never mid-action
- **Base character has empty hands and a neutral pose.** Held weapons, floating shards, spell effects are SEPARATE painted layers generated later and composited/animated over the character in engine
- Weight grounded — characters feel heavy, still, sculpted. Never floaty, never dynamic, never action-pose
- All characters share a unified painted style so any character composites onto any background without looking alien

### For painted backdrops (the "empty stage set" layer)

Backdrops are the ARCHITECTURAL SHELL of a scene — walls, floor, ceiling, distant window, columns. They are generated as full ultrawide paintings but **prop-empty** (no altars, no pews, no candles, no reliquaries at floor level). Props are added as separate layers later.

- Painted as complete architectural environments, ultrawide (21:9), never procedurally tiled
- Dramatic single-source side-lighting, canonically from **upper-left** (usually a distant cathedral window, a candle-lit aperture, or cold monitor-glow) — this sun direction must be coherent with the prop library
- Heavy falloff into atmospheric haze in the far distance, deep shadows in side arches
- Slight depth of field — far background softly defocused, near architecture crisp
- Clear flat floor area in the midground/foreground where props and characters will later be composited
- 3/4 camera angle, never pure side or front, camera at standing eye level looking slightly forward into depth
- Strictly **no portable set dressing** inside the backdrop — those are separate props

### For painted props (the composable object library)

Props are every removable object in the world, painted in isolation on green screen so Godot can arrange them into scenes like a literal shadow-box diorama. One painted altar is reused across every altar scene.

- Every prop is a *built thing*, painted in isolation on pure chroma-key green, never procedural-looking
- Each prop has dramatic single-source directional light baked in — **ALWAYS from upper-left** — so every prop in the library shares a coherent "sun direction" with backdrops when composed
- Heavy chiaroscuro shadows on the lower-right of each form, subtle rim-light on the upper-left edges. Heavy ambient occlusion in cracks, joints, undersides
- 3/4 camera angle, never pure side or front, never pure top-down — worshipper's-eye for altars, eye-level for freestanding objects
- Slight miniature feel — slightly too-detailed for their size, like museum exhibits
- Symbolic weight — every prop carries the code/sacred double meaning (an altar is scripture compiled into stone, a server rack is a pew for the daemon congregation, a reliquary is a cache folder holding a saint's bone, a candle is an unfinished prayer-loop burning down to segfault)
- Painted with an implied footprint (a few inches of cracked tile under a standing prop, a shadow-base under a floating object) so the prop sits convincingly when placed, but NO surrounding architecture
- Scenes are composed in Godot by stacking props on top of a painted backdrop — **there are no "finished scene" paintings**, only painted pieces Godot arranges

---

## Palette rules (hard)

| Share | Colors |
|---|---|
| **80%** of every image | charcoal, ink black, cold slate, bone / parchment off-white, rusted iron |
| **10% sacred accents** | tarnished gold leaf, cathedral-glass teal, sodium-lamp amber — sparing, precious, **never neon** |
| **10% corruption accents** | arterial red, bile green, void violet — they bleed into places they shouldn't |

**Hard rule: no more than 2 saturated colors per card.** Everything else stays desaturated. This single rule carries ~50% of aesthetic consistency on its own.

### Per-character identity hues

Desaturated, painterly — **never neon**. These are the inherited colors from `character_prompts.json`, reframed into the new palette language:

| Character | Raw color | Reframed as |
|---|---|---|
| Zephyr (Netrunner) | cyan | frost on stained glass |
| Bastion (Sysadmin) | green | verdigris on bronze |
| Cipher (Cryptomancer) | purple | bruised cathedral glass |
| Sentinel (White Hat) | white/gold | bone and tarnished leaf |
| FLUX (Technomancer) | magenta | arterial ichor on obsidian |
| Scourge | *TBD* | *TBD* |

---

## Rejection list (non-negotiable)

- **No Tron neon.** No glowing blue grid floors. No circuits-on-everything as wallpaper.
- **No anime, chibi, mascot, or moe energy.**
- **No Marvel-superhero dynamic-pose overacting.**
- **No sterile Apple-store cyberpunk.** No wet-PBR Unreal slickness.
- **No cyberpunk tropes by default:** kanji signs, rainy neon alleys, mirrorshades, mohawks.
- **No AI-slop tells:** symmetrical dead-center faces, glowing floating debris for no reason, too-smooth skin, clenched-jaw heroism.
- **No comic halftone or Western superhero inking.**
- **No text, UI, borders, or frames inside the art.** Frames come from the game engine.

---

## Ground truth for every future prompt

Every generation should be able to answer "yes" to all of:
- [ ] Does it fit the *reverent / corrupted / precise* tone?
- [ ] Does it honor the 80/10/10 palette rule (max 2 saturated colors)?
- [ ] If it's a character, is it painted horror realism with empty hands on green screen?
- [ ] If it's a backdrop, is it an empty architectural shell with no portable set dressing?
- [ ] If it's a prop, is it on green screen, lit from upper-left, with no surrounding architecture?
- [ ] Does it lean into the code/sacred double meaning?
- [ ] Is it free of the rejection list?

If any answer is "no," iterate the prompt.
