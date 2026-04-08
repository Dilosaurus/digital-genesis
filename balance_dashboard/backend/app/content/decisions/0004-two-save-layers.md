---
title: Two save layers — MetaState (persistent) and RunState (transient)
status: accepted
date: 2026-04-07
order: 4
tag: architecture
---

## context

Before the persistent-progression pivot (`decisions/0003-persistent-pivot.md`), deus.exe had a single save file: `user://save.json`, which serialized the active `RunState` — character, deck, current HP, gold, current map position, etc. Save = current run. If you died, the save was deleted. There was no concept of "things that survive death."

The pivot introduces persistence: a stash of unlocked card variants, a per-act hostility counter, character XP and skill points, a roster of operators, currencies that survive a run, and unidentified packages waiting for Balthaz to identify. None of these belong on the run state — they need to outlast individual runs by definition.

The straightforward question: do we extend `RunState` to include all the new persistent fields and save the whole thing as one mega-blob, or do we split persistent state into a separate layer with its own file?

## decision

**Two save layers, two files.**

- **`RunState`** (existing, in `scripts/models/run_state.gd`) stays focused on a *single in-progress run*. It serializes to **`user://save.json`**. Holds character, deck, current HP, currencies *earned this run*, gem assignments, current map data, current row/col, completed nodes, run-level corruption (the existing Cryptomancer mechanic), and now also `act_id`, `rite_index`, and the transient `RunPouch`.
- **`MetaState`** (new, in `scripts/models/meta_state.gd`) holds *everything that survives runs*. It serializes to **`user://meta.json`**. Holds the variant stash, equipped variant per character per slot, per-act hostility, act unlock state, persistent gold and essence, unidentified packages waiting for Balthaz, the character roster (per-character persistent level/XP/skill points), and lifetime stats (total runs completed, total deaths, total clean clears per act).

The two files coexist. A new player starts with a fresh `MetaState` and no `RunState`. Starting a run creates a new `RunState` and writes to `save.json`. Returning to town discards the `RunState` and updates the `MetaState`. Death does the same — the `RunState` is discarded, but earnings are committed to the `MetaState` via the pouch (degraded if death) and currency totals.

## consequences

**Good:**

- **Clean separation of concerns.** Code that touches the run never accidentally touches persistent state. Code that touches the stash never accidentally touches a half-finished combat. The boundary is enforced by file location.
- **Robust to corrupt-mid-run.** If `save.json` ever gets corrupted or wedged, the player's persistent stash and progression are still safe in `meta.json`. They lose the in-progress run, not their account.
- **Easier migrations.** When we evolve the schema (we will), each layer migrates independently. Adding a field to `MetaState` doesn't require touching `RunState` serialization, and vice versa.
- **Cleaner save inspection.** A debugger can look at `meta.json` to see "what does this player own" without having to parse run-specific noise. A bug report can include `meta.json` without leaking the player's exact mid-combat state.
- **Save deletion is more meaningful.** "Delete my run and start over" deletes only `save.json`. "Delete my entire save" deletes both. These are now genuinely different operations.

**Bad:**

- **Two files to coordinate.** When a run ends, we have to drain the pouch from `RunState` into `MetaState` *before* discarding `RunState`. If the game crashes between these two writes, we lose either the pouch or the run. Mitigation: write `MetaState` *first* (with the drained pouch), then delete `RunState`. Pouch contents are never in flight without being written somewhere.
- **Slightly more complex bootstrap.** Instead of just loading `save.json`, the game now loads `meta.json` (always — persistent state) and conditionally loads `save.json` if it exists (in-progress run). Both loaders need defaults.
- **Two save format versions to track.** When we change the format of either file, we need migration code for that file. This is the cost of separation; it's bounded.

**Neutral:**

- **Co-op multiplayer is unchanged.** Each player has their own pair of save files. Co-op happens during a run; the host's `RunState` is the authoritative shared one for the session, and each player's `MetaState` updates locally when they return to their own town.
- **The legacy `act: int` field on `RunState` stays.** Old saves load fine. New code prefers `act_id`. We can deprecate the int later when no migration risk remains.
- **JSON, not binary.** Both files are JSON. Easy to inspect, easy to debug, easy to migrate. Slightly larger on disk but the savings would be in the kilobytes.

## file shapes (current as of Phase 10a)

`user://meta.json` schema:

```json
{
  "unlocked_variants": { "strike": ["strike_of_the_wound"], "defend": [] },
  "equipped_variants": { "netrunner": { "strike": "strike_of_the_wound" } },
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
    { "rarity_hint": "rare", "card_type_hint": "ATTACK", "base_card_id": "strike", "variant_id": "strike_of_the_wound", "discovery_room": 7, "discovery_rite": 2 }
  ],
  "character_roster": {
    "netrunner": { "level": 12, "xp": 4500, "skill_points": 3, "unlocked_skills": ["...", "..."] }
  },
  "total_runs_completed": 47,
  "total_runs_failed": 13,
  "total_act_clears": { "outer_nexus": 8, "neural_cathedral": 3 },
  "lifetime_packages_identified": 312
}
```

`user://save.json` schema (additions in **bold**):

```json
{
  "character_id": "netrunner",
  "deck": ["strike", "strike", "defend", ...],
  "current_hp": 51,
  "max_hp": 80,
  "gold": 142,
  "souls": 0,
  "act": 1,
  "act_id": "outer_nexus",
  "rite_index": 2,
  "pouch_packages": [
    { "rarity_hint": "rare", "card_type_hint": "ATTACK", "base_card_id": "strike", "variant_id": "strike_of_the_wound", "discovery_room": 4, "discovery_rite": 2 }
  ],
  "completed_nodes": [...],
  "map_data": [...],
  "...": "all the existing RunState fields"
}
```

Note that `pouch_packages` lives only in `save.json` (the in-progress run). On extract or death, those packages move to `meta.json`'s `unidentified_packages` (with degradation if death). The pouch is never in two places at once.

## when we would revisit

1. **If managing two files becomes a real coordination problem.** If the "drain pouch then discard run state" flow has bugs we can't kill, we could fall back to a single mega-save at the cost of separation cleanliness. We'd need to see the bugs first; we don't have them today.
2. **If we add cloud saves or syncing.** Cloud sync usually wants atomic blob writes. If we're syncing both files, we either combine them at sync time or split the upload. Solvable either way; not a problem yet.
3. **If we decide to support multiple in-progress runs per player** (unlikely — the design is "one active run per save"). If that ever happened, `RunState` could stay where it is and we'd add a `runs/` directory. Still doesn't change the core split.

## related documents

- `decisions/0003-persistent-pivot.md` — the pivot this enables
- `mechanics/save-architecture.md` — full data model walkthrough with the lifecycle of a run, from town descent through extraction or death
- `mechanics/the-portals.md` — the run loop that the two-layer save supports
- `mechanics/card-variants.md` — the variant identification flow that drains the pouch into the meta layer
- `roadmap/13-pivot-persistent.md` — the implementation rollout
