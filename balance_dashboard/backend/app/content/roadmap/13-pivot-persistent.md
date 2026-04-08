---
title: Pivot to persistent town, portals, and extraction-style runs
status: in-flight
order: 13
phase: 10
tag: direction
---

## pivot

deus.exe shifts from a one-shot roguelike deck-builder to a **persistent-hub deck-builder with extraction-style dungeon runs**. Five interlocking pieces:

1. **The town** — persistent hub with 3 NPCs (Braune the Smith, Kel the Jeweler, Balthaz the Lorekeeper). Stash, currencies, characters, skill trees all live here forever. No corruption meter, no daily-omen NPC, no fourth-wall reading.
2. **Card variants** — static base cards with hand-designed variants unlocked through play. NOT PoE-style rolled affixes. Cards stay StS-shaped; the persistence layer is a *collection* of variants. Includes a corrupted variant tier for cards that are powerful but cursed.
3. **Five acts as portals** — town has 5 doorways (3 in V1), each leading to a self-contained themed Act with its own enemies, bosses, and legendary pool.
4. **Three rites per act** — each Act is structured as 3 Rites with branching maps. Acts are the top-level region. Rites are the descents within an act. Extraction is only at Rite boundaries.
5. **Death downgrade** — die in a Rite, your run pouch degrades to commons. Legendaries are lost. The single rule that makes the entire extraction loop work.

Full design lives in:

- `decisions/0003-persistent-pivot.md` — rationale and trade-offs
- `mechanics/the-town.md` — hub layout, NPCs, services
- `mechanics/the-portals.md` — acts, rites, extraction, hostility
- `mechanics/card-variants.md` — the variant system, identification, corruption

The reference stack is **Slay the Spire (combat) + Hades (hub) + Darkest Dungeon (atmosphere) + Escape from Tarkov (extraction)**. NOT Path of Exile.

## phased rollout

The pivot is too large to ship in one drop. The phasing ensures the game stays playable throughout. Each phase is independently shippable.

### Phase 10a — schema foundation ✓ shipped 2026-04-07

Backend-only. Added the Godot data model for the persistent pivot. No gameplay change; the existing one-shot loop continues to work, and the new structures are dormant data containers waiting for the run loop to start using them in 10b+.

**What got built:**

- **`scripts/data/card_variant.gd`** — `CardVariant` Resource class. Hand-designed variants of base cards with optional stat overrides via a `NO_OVERRIDE` sentinel pattern, drop metadata (act / hostility / weight), corruption tier flags, and an `apply_to(base)` method that merges the variant onto a base `CardData` at runtime.
- **`scripts/data/act_data.gd`** — `ActData` Resource class. Formalizes the 5 acts as data resources (instead of the existing hardcoded `match` statement in `RunState.generate_map`). Holds per-rite enemy/elite/boss pools, legendary variant pool, accent color, unlock state. Helper methods for `get_fight_pool(rite)`, `get_rite_boss(rite)`, `is_complete()`.
- **`scripts/models/run_pouch.gd`** — `RunPouch` (RefCounted, transient). Holds unidentified packages collected during a single run. Critical method: `degrade_to_commons()` for the death-downgrade rule. Also `drain()` for successful extraction and `summary()` for UI.
- **`scripts/models/meta_state.gd`** — `MetaState` (RefCounted, persistent). The new save layer at `user://meta.json`. Holds the variant stash, equipped variants per character, per-act hostility, persistent currencies (gold + essence), unidentified packages waiting for Balthaz, character roster with persistent levels/XP/skills, and lifetime stats. Methods for `unlock_variant()`, `bump_hostility()`, `decay_hostility_other_acts()` (the session-count decay rule), `receive_pouch()`, and full save/load.
- **`scripts/models/run_state.gd`** — additively extended. Added three new fields without removing any existing field: `act_id: String`, `rite_index: int`, `run_pouch: RunPouch`. Save/load wiring extended. Old saves still load fine; new saves carry both legacy and new fields so the migration to act_id can happen at our own pace.

**Verification:**
- Godot project class cache rebuilt.
- `--check-only --quit` shows zero parse errors in any of the new files.
- "Loaded 175 cards" confirms the existing card parser still works.
- All errors in headless boot are pre-existing missing-texture issues unrelated to schema work.

See `decisions/0004-two-save-layers.md` for the architectural rationale and `mechanics/save-architecture.md` for the data flow reference.

### Phase 10b — the portals

First visible gameplay change. Replace the existing 3-act linear progression with 3 portal selections in the town. Acts I, II, III map to existing dungeon content with zero new map work — the structural change is wrapping them as portals from a hub.

### Phase 10c — Braune's forge

Brings Braune online as an NPC. Implements the three crafting services: upgrade (which already exists in the existing forge code), refine (new), dismantle (new). Cuts the old forge node from in-run dungeons since crafting is now a town-only activity.

### Phase 10d — the unidentified pouch + Balthaz identification

The big mechanical addition. In-run loot drops as unidentified packages. Pouch persists through Rites within a run but degrades on death. Balthaz's identification ceremony in town. This is the phase where the extraction loop becomes real.

### Phase 10e — character variants + persistent skill trees

Persistent skill tree XP and node allocations per character. Character switching from the town. Each character has their own deck, their own gem sockets, their own skill tree state.

### Phase 10f — the stash UI

Full visual codex of unlocked variants with locked-but-visible entries showing what the player is chasing. This is the "quest log" of the entire game and is critical to the unlock dopamine.

### Phase 10g — hostility per act + decay-by-session

Per-act hostility counters with visible threshold effects (more elites, extra boss phases, hunting angel at hostility 12+). Session-count decay between acts. Clean clear reset mechanic.

### Phase 10h — corrupted variant drops

Implements the "corrupted" variant tier as a drop pool from high-hostility runs. Hand-designed corrupted variants with permanent downsides. Player-facing UI to flag corrupted cards in the deck builder. (The Alchemist NPC who corrupts cards on demand is post-V1.)

## what stays untouched

- Combat engine (`combat_engine.gd`)
- Modifier pipeline
- Gem socket system
- Skill tree definitions (just the persistence layer changes)
- The 6 character classes
- Multiplayer / co-op model
- Visual aesthetic, typography, all bible content
- All existing card data (becomes the common variant baseline)
- Run-level crew corruption (the existing Cryptomancer mechanic; unchanged)

## risks

- **Scope creep.** This is a pivot, not a feature. Holding the line on "V1 is menu-based, 3 NPCs, 3 portals, deferred everything else" is essential.
- **Variant content burden.** Hand-designed variants are real work. ~350 (avg 2 per base card) is the realistic V1 target. Add more in post-launch content drops.
- **Tone erosion.** The death downgrade is the signature move. If it gets softened in playtesting, we lose what makes this distinctive.
- **Save-data format lock-in.** Once players have stash data, schema changes need migration tooling.
- **Co-op extraction edge cases.** Multiplayer pouch handling has open questions (see `the-portals.md`).

## NOT changing — and explicitly cut

- **No PoE-style rolled affixes.** Cards are static, variants are hand-designed.
- **No currency orb economy.** Only gold and essence.
- **No real-time hostility decay.** Session-count only.
- **No mid-rite extraction.** Only at Rite boss kills.
- **No global town corruption meter.** Earlier drafts had a meter that visibly degraded the town over time. Cut. Corruption is a property of individual cards, not the town.
- **No Mapmaker NPC, no daily omens.** Earlier drafts had Vane the Mapmaker offering per-run modifier choices. Cut. Run variance comes from random map paths and card drops, not a daily-modifier UI.
- **No fourth-wall ADR-reading from Balthaz.** Earlier drafts had Balthaz read real developer ADRs aloud as in-game lore. Cut. Balthaz reads in-game records only.
- **No persistent crew corruption meter.** Crew corruption is a run-level resource. Earlier drafts proposed a per-character persistent meter. Cut.
- **No cleansing rituals, no character retirement as a corruption sink, no growing floor.** All cut along with the town corruption meter.

These cuts removed roughly half the previous draft's complexity without losing any of the emotional payoff. The simpler design preserves all the hooks (extraction tension, the angels' attention via hostility, hand-designed variants you collect) without the meta-meter overhead.
