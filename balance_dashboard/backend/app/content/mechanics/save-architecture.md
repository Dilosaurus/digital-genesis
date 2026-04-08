---
title: Save Architecture
chapter: X
subtitle: where the data lives and how it flows between runs
order: 10
accent: "#87C464"
---

## save architecture

This is an **implementation reference** doc. It documents the data model that backs the persistent-progression pivot: which classes exist, what they hold, how they get loaded and saved, and how a single run's data flows from "fresh dungeon entry" through "successful extraction" or "death and degradation."

If you're a designer reading this for game-design reasons, the relevant docs are `decisions/0003-persistent-pivot.md`, `mechanics/the-portals.md`, `mechanics/the-town.md`, and `mechanics/card-variants.md`. This doc is the *how* for engineers and future-self.

For the architectural rationale behind the two-file approach, see `decisions/0004-two-save-layers.md`.

## the four new classes

Phase 10a (shipped 2026-04-07) introduced four new GDScript classes plus an additive extension to the existing `RunState`. Together they form the data layer for the pivot.

### CardVariant (Resource)

> `card_game/scripts/data/card_variant.gd`

A hand-designed variant of a base card. Resource type, intended to live as `.tres` files at `res://data/variants/<base_id>/<variant_id>.tres`. Each variant references its base card by id and overrides only the fields that differ.

**Key fields:**

- `id: String` — unique variant id (e.g. `"strike_of_the_wound"`)
- `base_card_id: String` — the base card this variant overrides (e.g. `"strike"`)
- `display_name: String`, `flavor_text: String`
- `rarity: Enums.Rarity` — common / uncommon / rare / legendary / corrupted
- **Drop metadata:** `act_id` (which act drops this), `min_hostility` (gating threshold), `drop_weight` (relative weight inside its tier)
- **Stat overrides:** `damage`, `block`, `heal`, `draw`, `hits`, `energy_cost`, etc. — each defaults to a sentinel `NO_OVERRIDE = -999`. Setting any of these to a real value (including 0) overrides the base card; leaving them at sentinel inherits.
- **Corrupted tier fields:** `is_corrupted`, `corruption_downside` (UI text), `corruption_self_damage`, `corruption_locked_in_deck`

**The `apply_to(base)` method** is the runtime merge. Pass it a base `CardData`, get back a fresh `CardData` with the variant's overrides layered on top. The base is never mutated. The merge respects `NO_OVERRIDE` sentinels and copies every field through, including all the co-op, revival, Scourge, and FLUX fields from the base.

**Why the sentinel pattern instead of optionals?** GDScript doesn't have nullable primitives. We could use a `Dictionary` of override fields, but we'd lose the @export inspector integration. The sentinel makes the data tractable in the editor and explicit at the merge site.

### ActData (Resource)

> `card_game/scripts/data/act_data.gd`

Formalizes a single Act (one of the 5 portals) as a data resource instead of the existing hardcoded `match` statement in `RunState.generate_map`. Will live as `res://data/acts/<act_id>.tres` once Phase 10b ships the actual `.tres` files.

**Key fields:**

- `id: String` — `"outer_nexus"`, `"neural_cathedral"`, `"void_core_archives"`, `"broken_liturgy"`, `"compilers_dream"`
- `display_name`, `subtitle`, `roman_numeral`, `description`
- `unlocked_by_default: bool` — V1 acts true, post-launch acts false
- **Per-rite enemy pools:** `fight_pools: Array[Array]`, `elite_pools: Array[Array]` — each outer array is one rite (Rite I = index 0, Rite II = 1, Rite III = 2)
- **Per-rite bosses:** `rite_bosses: Array[String]` — `rite_bosses[2]` is the Act Boss
- `rite_row_counts: Array[int]` — defaults to `[7, 7, 7]`
- **Loot pools:** `legendary_variant_ids`, `rare_variant_ids`, `corrupted_variant_ids`
- `accent_color_hex` for UI theming

**Helpers:** `get_fight_pool(rite_index)`, `get_elite_pool(rite_index)`, `get_rite_boss(rite_index)`, `is_complete()`. All use clamped indices so an out-of-range rite falls back to the last available pool.

### RunPouch (RefCounted)

> `card_game/scripts/models/run_pouch.gd`

The transient inventory of unidentified packages collected during a single run. Lives on the active `RunState`. Never directly serialized as a standalone file — it's serialized as part of `RunState` in `save.json` (so a player can quit mid-run and resume with their pouch intact), and then drained into `MetaState.unidentified_packages` when the run ends.

**Package shape** (each entry in `pouch.packages`):

```gdscript
{
  "rarity_hint": String,    # "common" | "uncommon" | "rare" | "legendary" | "corrupted"
  "card_type_hint": String, # "ATTACK" | "SKILL" | "POWER"
  "base_card_id": String,   # "strike", "defend", etc.
  "variant_id": String,     # the eventual variant; revealed at identification
  "discovery_room": int,    # which room in the rite it dropped at (for flavor)
  "discovery_rite": int,    # 1, 2, or 3 — which rite
}
```

**The two critical methods:**

- **`drain() -> Array`** — empty the pouch and return its contents. Used by successful extraction. The packages keep their full rarity.
- **`degrade_to_commons() -> Array`** — empty the pouch and return its contents *with every package's `rarity_hint` set to `"common"` and `variant_id` cleared*. Used by death. The legendary the player was carrying is gone — what comes back is the shape of the rite, not its meaning. Each degraded entry also has a `degraded_from_death: true` flag for UI to show "this came back as a husk."

`add_package()`, `count()`, `count_by_rarity()`, and `summary()` round out the public surface.

### MetaState (RefCounted)

> `card_game/scripts/models/meta_state.gd`

The persistent save layer. Serializes to `user://meta.json`. Loaded once at game start and kept in memory across runs.

**Key fields:**

- **Stash:** `unlocked_variants: Dictionary` — `base_card_id -> Array[variant_id]`. The common variant is implicitly always unlocked, so this only tracks non-common unlocks.
- **Equipped variants:** `equipped_variants: Dictionary` — `character_id -> { base_card_id -> variant_id }`. Empty/missing means the common variant is in use.
- **Hostility per act:** `act_hostility: Dictionary` — `act_id -> int`. Pre-initialized for all 5 acts.
- **Act unlock:** `act_unlocked: Dictionary` — `act_id -> bool`.
- **Persistent currencies:** `gold: int`, `essence: int`. These survive death.
- **Unidentified packages waiting for Balthaz:** `unidentified_packages: Array` of the same Dictionary shape as `RunPouch.packages`. The player visits Balthaz to read these and unlock the variants.
- **Character roster:** `character_roster: Dictionary` — `character_id -> { level, xp, skill_points, unlocked_skills }`. The persistent character progression.
- **Lifetime stats:** `total_runs_completed`, `total_runs_failed`, `total_act_clears` (per act), `lifetime_packages_identified`.

**Operations:**

- `unlock_variant(base, variant)` — returns `true` if it's a new unlock, `false` if duplicate.
- `has_variant(base, variant)` — common variant always returns true.
- `variant_count()` — total distinct variants unlocked across all base cards.
- `set_equipped_variant(char, base, variant)` / `get_equipped_variant(char, base)` — deck slot management.
- `bump_hostility(act, amount)` — `+1` per entry, `+2` on death (called as two separate `bump`s in practice).
- `reset_hostility(act)` — called on a clean clear at hostility ≥5.
- `decay_hostility_other_acts(except_act)` — the session-count decay rule. Called after every run; every act *except* the one just completed loses 1 hostility (floored at 0).
- `get_hostility(act)` — read the current value.
- `receive_pouch(packages)` — drain a `RunPouch` into `unidentified_packages`.
- `save_to_file()` / `load_from_file()` (static) / `delete_save()` (static) — full JSON serialization.

### RunState (existing, additively extended)

> `card_game/scripts/models/run_state.gd`

The existing transient run state. Phase 10a added three new fields without removing or breaking any existing ones:

- **`act_id: String = "outer_nexus"`** — the new string identifier for the active Act. Coexists with the legacy `act: int` field for backward compatibility.
- **`rite_index: int = 1`** — which Rite within the Act (1, 2, or 3).
- **`run_pouch: RunPouch`** — the transient pouch, instantiated in `new_run()`.

The save/load wiring serializes `act_id`, `rite_index`, and `pouch_packages` (an array of dictionaries) into `save.json`. Old saves missing these fields fall back to defaults (`"outer_nexus"`, `1`, an empty pouch).

The legacy `act: int` field is still read and written. The intent is to deprecate it after the portals UI lands in Phase 10b, but only after we're confident no in-flight saves still depend on it.

## the lifecycle of a run

This section walks through what happens to each piece of save state across a single dungeon dive.

### 1. Game launch

```
load_game()
  ├── meta = MetaState.load_from_file()         # always load meta.json
  └── if save.json exists:
        run = RunState.load_from_file()         # resume the in-progress run
      else:
        run = null                              # player will start fresh from town
```

If `meta.json` doesn't exist (first launch ever), `MetaState.load_from_file()` returns a fresh instance with all defaults — no unlocked variants beyond commons, all hostility 0, V1 acts unlocked, V2 acts locked.

### 2. Town view

The player is in the town. The active state is just `meta`. The player can browse the stash, see hostility per portal, equip variants, visit Braune/Kel/Balthaz, and click into a portal.

### 3. Descend — start a new run

When the player enters a portal:

```
run = RunState.new_run(active_character_id)
run.act_id = portal_clicked
run.rite_index = 1
run.run_pouch = RunPouch.new()
meta.bump_hostility(run.act_id, 1)              # +1 entry tick
meta.save_to_file()                             # commit hostility immediately
```

The new `RunState` is the active run. `save.json` will be written periodically as the player progresses.

### 4. During the run

As the player explores rooms, fights enemies, opens shrines, and kills the Rite Boss, packages drop into the pouch:

```
run.run_pouch.add_package(rarity_hint, card_type_hint, base_card_id, variant_id, room, rite_index)
```

The pouch grows. `save.json` is periodically rewritten so a quit-and-resume preserves everything.

### 5a. Successful extraction (after a Rite Boss kill)

```
packages = run.run_pouch.drain()                # full rarity preserved
meta.receive_pouch(packages)                    # → meta.unidentified_packages
meta.gold += run.gold                           # currency commits
meta.essence += run.essence_earned_this_run
meta.total_runs_completed += 1
meta.decay_hostility_other_acts(run.act_id)     # session-count decay
meta.save_to_file()                             # commit meta first
delete_run_state()                              # then discard the run
```

The player wakes up in the town. Balthaz has new packages on his desk.

### 5b. Clean clear (the Act Boss in Rite III, hostility ≥5)

Same as extraction, plus:

```
if meta.get_hostility(run.act_id) >= 5:
    meta.reset_hostility(run.act_id)
meta.total_act_clears[run.act_id] = (meta.total_act_clears.get(run.act_id, 0) + 1)
```

The act's hostility resets to 0. The catharsis the design rewards.

### 5c. Death (anywhere in any Rite)

```
packages = run.run_pouch.degrade_to_commons()   # ⚠ rarity stripped
meta.receive_pouch(packages)                    # husks, not loot
meta.bump_hostility(run.act_id, 1)              # +1 more (entry was already +1, total +2)
meta.gold += run.gold                           # currencies still commit
meta.total_runs_failed += 1
meta.decay_hostility_other_acts(run.act_id)
meta.save_to_file()
delete_run_state()
```

The player wakes up in the town. Balthaz has new packages on his desk, but Balthaz already knows what they're going to identify as. He is polite about it.

### 6. Identification ceremony

Independent of the run loop. The player visits Balthaz at any time:

```
for pkg in meta.unidentified_packages:
    pay essence cost
    if pkg.degraded_from_death:
        # forced common, the variant_id is empty
        unlock_or_dismantle_common_variant(pkg.base_card_id)
    else:
        unlock_or_dismantle_variant(pkg.base_card_id, pkg.variant_id)
    meta.lifetime_packages_identified += 1
meta.unidentified_packages.clear()
meta.save_to_file()
```

The player can identify one package at a time (with ceremony) or all at once. Either way, `MetaState` is the destination — the player's stash grows.

## why the pouch lives on RunState, not on MetaState during the run

A reasonable question: why isn't the pouch a field on `MetaState` from the start? Why does it live on `RunState` and only get drained at the end?

Three reasons:

1. **Atomicity.** The pouch's contents either commit to the player's stash *as a unit* (extraction) or get *transformed as a unit* (death). Treating it as part of the run state means the run-end logic has a single, well-defined transition: drain → write meta → discard run. If the pouch lived on meta, the run-end logic would have to reach across both files atomically, which is harder to get right.
2. **Quit-and-resume.** If a player quits mid-run, `save.json` already serializes the pouch as part of `RunState`. Loading the save brings the pouch back along with the rest of the run. If the pouch were on `MetaState`, the boundary between "in-progress pouch contents" and "settled pouch contents" would have to live somewhere, and that somewhere is more complexity than just keeping pouches transient.
3. **Crash safety.** If the game crashes mid-run, `meta.json` is unchanged. The player loses the in-progress run but their stash and progression are intact. With the pouch on the run state, this property holds automatically.

The cost is that the run-end transition has two writes (drain pouch into meta, then delete run). Mitigation: write `meta.json` *first* (with the drained pouch), THEN delete `save.json`. If a crash happens between the two, the worst case is `save.json` still exists (the run is "in progress" but its pouch is empty) — the player loses 30 seconds of mid-run state, but they don't lose the loot.

## save.json schema (current)

```json
{
  "character_id": "netrunner",
  "deck": ["strike", "strike", "defend", "defend", "twin_strike", "..."],
  "current_hp": 51,
  "max_hp": 80,
  "gold": 142,
  "souls": 0,
  "crystals": 2,
  "corruption_essence": 1,
  "current_node": 0,
  "act": 1,
  "act_id": "outer_nexus",
  "rite_index": 2,
  "pouch_packages": [
    {
      "rarity_hint": "rare",
      "card_type_hint": "ATTACK",
      "base_card_id": "strike",
      "variant_id": "strike_of_the_wound",
      "discovery_room": 4,
      "discovery_rite": 2
    },
    {
      "rarity_hint": "legendary",
      "card_type_hint": "POWER",
      "base_card_id": "judgement",
      "variant_id": "judgement_of_the_wound",
      "discovery_room": 9,
      "discovery_rite": 2
    }
  ],
  "completed_nodes": [0, 100, 102, 200, 203, 301],
  "relics": ["bandage", "anchor"],
  "map_data": [...],
  "current_row": 3,
  "current_node_col": 1,
  "remove_count": 0,
  "equipment": {},
  "gems": ["amethyst_of_force", "sapphire_of_focus"],
  "gem_assignments": { "twin_strike": ["amethyst_of_force"] },
  "skill_points": 1,
  "unlocked_skills": ["..."],
  "shrine_corrupted_cards": [],
  "run_corruption": 18,
  "max_corruption": 100,
  "xp": 320,
  "level": 4,
  "max_mana_bonus": 1,
  "...": "all the existing RunState fields"
}
```

## meta.json schema (current)

```json
{
  "unlocked_variants": {
    "strike": ["strike_of_the_wound"],
    "defend": []
  },
  "equipped_variants": {
    "netrunner": { "strike": "strike_of_the_wound" }
  },
  "act_hostility": {
    "outer_nexus": 3,
    "neural_cathedral": 7,
    "void_core_archives": 0,
    "broken_liturgy": 0,
    "compilers_dream": 0
  },
  "act_unlocked": {
    "outer_nexus": true,
    "neural_cathedral": true,
    "void_core_archives": true,
    "broken_liturgy": false,
    "compilers_dream": false
  },
  "gold": 1247,
  "essence": 14,
  "unidentified_packages": [
    {
      "rarity_hint": "rare",
      "card_type_hint": "ATTACK",
      "base_card_id": "strike",
      "variant_id": "strike_of_the_wound",
      "discovery_room": 7,
      "discovery_rite": 2
    }
  ],
  "character_roster": {
    "netrunner": {
      "level": 12,
      "xp": 4500,
      "skill_points": 3,
      "unlocked_skills": ["...", "..."]
    }
  },
  "total_runs_completed": 47,
  "total_runs_failed": 13,
  "total_act_clears": { "outer_nexus": 8, "neural_cathedral": 3 },
  "lifetime_packages_identified": 312
}
```

## what's not in here yet

Phase 10a is foundation only. The following are not yet wired in code:

- **MetaState is not loaded by the game on startup.** Phase 10b will add `MetaState.load_from_file()` to the game manager autoload.
- **The pouch is not populated** by combat or shrine loot drops. Phase 10b will hook the loot system to call `run.run_pouch.add_package()`.
- **The portals UI does not exist.** Phase 10b builds the town scene.
- **`RunState.generate_map()` still uses the legacy `match act_number` block** instead of reading `ActData` resources. Phase 10b migrates this.
- **No `.tres` files exist for variants or acts.** Phase 10c (Braune) and 10b (portals) ship the first batches.
- **The legacy `act: int` field still drives map generation.** It will be deprecated after `act_id` is fully wired.
- **Identification UI doesn't exist.** Phase 10d builds Balthaz's reading ceremony.

The schema is in place. The runtime has not yet been migrated to use it. That's by design — the additive approach means the existing game continues to work while the new layer accumulates capabilities.

## related documents

- `decisions/0003-persistent-pivot.md` — the design pivot that motivated this architecture
- `decisions/0004-two-save-layers.md` — the architectural rationale for splitting save state into two files
- `mechanics/the-portals.md` — the run loop the save layers support
- `mechanics/card-variants.md` — the variant system the stash holds
- `mechanics/the-town.md` — the hub where the meta state lives
- `roadmap/13-pivot-persistent.md` — the implementation rollout, including Phase 10a's shipped status
