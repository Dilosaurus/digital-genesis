---
title: Pivot to persistent town, portal-based acts, and extraction-style runs
status: accepted
date: 2026-04-07
order: 3
tag: direction
---

## context

The current design of deus.exe is a one-shot roguelike deck-builder in the Slay the Spire mold: pick a character, draft a deck through three linear acts, fight a boss, win or die, try again. The combat loop is excellent and the modifier pipeline is over-built — but the *meta-loop* is thin. Every run starts from zero. Cards die with the run. Progression between runs is a sparse trickle. The 175 cards in the catalog are *known* on day one, leaving very little to discover.

At the same time, the game has been quietly accumulating systems that hint at a different shape: a persistent gem and skill-tree system, a modifier pipeline that's vastly over-engineered for one-shot runs, a corruption mechanic that the lore treats as *the angels' language*, and a bible (this dashboard) full of NPCs, towns, and lore beats that the game itself doesn't yet portray.

The combat loop and the meta-loop are independent decisions. We have been treating them as if they were the same. They are not.

## decision

deus.exe pivots from **one-shot roguelike** to **persistent-hub deck-builder with extraction-style dungeon runs**. Five interlocking pieces. None of them are PoE-shaped. The reference stack is:

> **Slay the Spire** (combat & cards) **+ Hades** (persistent hub & NPC bonds) **+ Darkest Dungeon** (atmospheric tone) **+ Escape from Tarkov** (extraction tension on a persistent inventory)

The full design lives in:

- `mechanics/the-town.md` — the hub
- `mechanics/the-portals.md` — the 5 acts
- `mechanics/card-variants.md` — how cards work now

This ADR captures *what* we decided and *why*. Implementation specifics live in those mechanics docs.

### 1. The Town

A persistent hub the crew comes home to between dungeon runs. **Three NPCs in V1:** Braune the Smith (upgrades, refines, dismantles), Kel the Jeweler (sockets gems, combines gems), Balthaz the Lorekeeper (identifies stolen pages, reads in-game records). Stash, currencies, character roster, and skill tree progress all live here forever.

The town is a workflow tool, not a state machine. NPCs have permanent atmospheric weirdness — Kel doesn't blink, Balthaz writes in two scripts, Braune's hands are iron — but those are *character traits*, not corruption thresholds. The town does not visibly degrade over time. It is a refuge in the literal sense, even if the lore implies the refuge is a lie.

### 2. Card Variants (NOT rolled affixes)

Cards are static, StS-style. The 175 base templates keep their current numbers and identities. Every card has 1–4 **hand-designed variants** unlocked through gameplay — `Strike`, `Strike+`, `Strike of the Wound`, `Strike of Silent Rites`. Each variant is a specific designed card with named flavor text and set numbers. They are *collectibles*, not random rolls.

There are no affix tiers, no currency orb crafting tabs, no reforge-then-pray loops. Crafting at Braune's forge is two services: upgrade a card to its `+` variant, and **refine** a variant to bump its numbers slightly within a designer-set range. That's it.

**Corruption is a card-level tier.** Some variants are **corrupted** — they get a powerful upside plus a permanent downside (e.g. *"deal 12 damage, but inflicts +3 corruption to the crew on play"*). Corrupted variants drop from high-hostility runs. Later, the Alchemist NPC (post-V1) can corrupt a card on demand at the player's choice. Corruption is a property of *individual cards*, not a meta-progression meter on the town or the crew.

This was the most important course-correction in the design. An earlier draft proposed PoE-style rolled affixes with five rarity tiers, currency orbs, and a town-wide corruption meter that visibly degraded NPCs over time. The author of the game pushed back twice — once on the PoE complexity, once on the over-engineered town corruption — and both were right. The final design has neither.

### 3. Five Acts as Portals from the Town

The town has **five portals**, each leading to a self-contained themed Act. V1 ships with three portals (mapping cleanly to existing Act 1/2/3 content); two more arrive as post-launch content drops, with the fifth being the endgame Metatron encounter.

| # | Act | Theme | V1 Status |
|---|---|---|---|
| I | The Outer Nexus | corrupted server farms | shipped |
| II | The Neural Cathedral | Michael's domain | shipped |
| III | The Void Core Archives | soul storage, deep memory | shipped |
| IV | The Broken Liturgy | ruined ritual spaces | post-launch |
| V | The Compiler's Dream | Metatron, the endgame gate | post-launch |

Each Act has its own enemies, its own boss roster, its own legendary card variants, its own lore tone. Players replay each act indefinitely. Acts are not linear story beats — they are *places the crew raids*.

### 4. Three Rites per Act

Each Act is structured as **three Rites** — sub-sections of the act, each with its own branching map (StS-style: ~10–14 rooms with combats, elites, shrines, shops, jewelers, and a Rite Boss at the end). Rite III's boss is the **Act Boss** — the named angel for that act.

The terminology is fixed:

- **Act** = top-level region (one of the 5 portals)
- **Rite** = sub-section within an act (3 per act)
- **Rite Boss** = boss at the end of any Rite
- **Act Boss** = the boss at the end of Rite III, the final encounter of an act

### 5. Extraction-Style Runs

Loot during a run drops as **unidentified packages** into your run pouch. Each package shows a rarity color and a vague hint (`"a tattered page"`, `"a page sealed in iron"`, `"a page that burns"`) but not its contents. You can't equip or play unidentified packages mid-run. They're stolen scripture you haven't decoded yet.

**Extraction is only at Rite boundaries.** After clearing a Rite Boss, you choose: extract to town with your current pouch, or push to the next Rite of the same act.

**Death anywhere in a Rite degrades your entire pouch to commons.** When Balthaz identifies the degraded packages in town, each one becomes a common variant of the same base card type. The legendary you were carrying is *gone* — what comes home is a Strike, a Defend, a generic rite. Diegetically, the angels eat the power in your pages and let your body's husk float back. You're not empty-handed, but you are emptied of *meaning*.

**Hostility per act.** Each act has its own hostility counter, ranging from 0 (the act has not noticed you) to 12+ (the angels are actively hunting). Hostility persists across runs and characters. It is the *only* meta-progression cost in the game — there is no town corruption meter, no character corruption meter, no global rot. The angels notice when you grind a specific portal, and the portal gets harder.

- `+1` per entry
- `+1` additional on death (so death = +2 total)
- `+0` on extraction
- **Resets to 0 on a clean clear** of the Act Boss at hostility ≥5

Higher hostility = more elites, harder enemies, eventually a hunting angel. Lower hostility = a manageable farming run.

**Hostility decays by session count, never by real time.** For each completed run in an *other* portal, this portal's hostility decreases by 1. Players must actually play other content to cool a hot portal. Closing the game and waiting does not work.

This creates two valid playstyles:

- **Specialist** — pick a favorite act, push hostility for the loot density, occasionally clean-clear for the reset.
- **Cycler** — rotate through portals, keep them all moderate, never let any of them get brutal.

Both are valid. Both produce legendary variants. Different player personalities will gravitate to different sides.

## consequences

**Good:**

- The combat engine, modifier pipeline, gem system, and skill trees finally have a meta-loop that justifies them instead of leaving them over-engineered.
- The pirate-heist tone of the lore is now mechanically expressed: the crew steals scripture, brings it home to read, and pays in extraction risk when they push too far.
- Replayability stops being an engineering problem and becomes a content problem. New variants, new portals — each is a small designer-led addition rather than a system rebuild.
- The bible (this dashboard) becomes more useful, not less — every variant, every portal, every legendary is a discrete piece of content that can be tracked here and balanced from this UI.
- The death-downgrade rule gives the game a *signature feeling* nothing else has. Tarkov's extraction loop applied to a deckbuilder, with a sacred-machine-horror diegesis on top.
- The session-count hostility decay closes the most obvious cheese vector and forces players to engage with multiple portals.

**Bad:**

- Two new NPCs need art, dialog, and service implementations (Braune and Balthaz are concept-only today; Kel exists as a node but needs an NPC implementation). Even a minimal V1 is several weeks of art and writing.
- The town hub itself needs UI scaffolding that doesn't currently exist. Menu-based for V1 keeps the scope manageable but is still a meaningful build.
- Variant content has to be hand-designed. ~350 variants for V1 (avg 2 per base card), with the ambition to grow to ~525 over the first year of post-launch content. This is a real content burden, even if individual variants are simple.
- The skill tree, currently per-character and per-run, needs to become persistent. Some balance assumptions have to shift.
- The 6 character starter decks were designed for a one-shot draft loop. Under persistent variants, they become "the common variants every operator starts with" — fine conceptually, but the existing balance pass is now an approximation.
- Some existing roadmap items are superseded. Mana pool migration is parked. The sins system needs a re-think under persistent decks.

**Neutral:**

- The 175 existing cards are not thrown out. They become base templates and their current numbers become the common variant baseline.
- The 20 gems stay as gems, orthogonal to variants. A card has both a variant identity and 0–2 gem sockets.
- The 25 relics stay as relics, now persistent across runs.
- The combat engine (`combat_engine.gd`, ~1860 lines) is unchanged.
- Multiplayer / co-op still works. Each player has their own town and stash. Co-op happens during dungeon runs. If a co-op partner dies mid-run, *their* pouch degrades; the surviving players keep going with theirs.

## when we would revisit

1. **If the death downgrade is too punishing in playtesting.** If players bounce because losing a legendary on death feels arbitrary, we soften the rule — maybe a "soul anchor" item enters as a rare consumable that protects one package. The current rule is the *strict* version because soft death-loss is easy to add later but hard to remove.
2. **If the variant content burden is unsustainable.** If we discover ~525 variants is a multi-year project, we reduce the variant-per-card count or generate variants procedurally with curated affix pools.
3. **If persistence makes failure feel meaningless.** Hades solved this by making *narrative* progress through failure. If death in deus.exe stops feeling like a loss, we add stakes that only appear after failure.
4. **If 5 portals is too thin.** V1 has 3. If even those feel small, we expand within the existing portals before adding new ones.

## what we are explicitly NOT deciding yet

- **The town's visual treatment.** V1 is a menu interface; later versions can be 2D parallax or 3D scenes.
- **Specific NPC dialog.** The voice work matters but is its own pass.
- **The exact pool of variants per card.** Needs a separate design pass and iteration.
- **The hostility numerical curve.** Tier-by-tier elite scaling, hunting angel mechanics, boss extra phases — all need playtesting to tune.
- **The endgame ending shape.** Multiple endings tied to which Act V variant the player chose. Specifics deferred.
- **Whether sins (existing mechanic) survive the pivot.** Sins were designed for one-shot framing. They might collapse into "downside variants" or stay separate. Open question.
- **The Alchemist NPC** (post-V1) — which corruption operations he offers, how dangerous they are, whether corruption can be reversed once applied to a card.

## what we explicitly cut

A previous draft of this ADR included several systems that didn't survive design review:

- **Town corruption meter** — a global meter that visibly rotted the NPCs and town environment over time. Cut. There is no meta-meter on the town. NPCs have permanent atmospheric traits, not escalating thresholds.
- **Vane the Mapmaker** — an NPC who offered "omens" (per-run modifiers). Cut. Run variance comes from the existing random map paths, card drops, and shrine choices. No daily-modifier UI.
- **Cleansing rituals** — Alchemist purges and Lorekeeper purges. Cut. Without a town corruption meter, there's nothing to cleanse.
- **Character retirement as a corruption sink** — the "big lever" for cleaning the town. Cut. Without town corruption, retirement has no mechanical role.
- **The growing floor** — a slowly-rising minimum corruption value tracking save lifetime. Cut.
- **Balthaz reading real ADRs as in-game lore** — a fourth-wall meta joke. Cut. Balthaz just identifies packages and reads the in-game changelog.
- **Per-character persistent corruption meter** — corruption was going to track per-character across runs. Cut. Crew corruption is a *run-level* resource (the existing Cryptomancer scaling mechanic), not a persistent meter.

These were all things I (the implementer-AI) added because they sounded cool. The author of the game correctly pushed back that they were complexity in search of a problem. The simpler design preserves all the emotional hooks (extraction tension, the angels' attention via hostility, hand-designed variants you collect, atmospheric NPC weirdness) without any of the meta-meter overhead.

## related documents

- `mechanics/the-town.md` — the hub: NPC roster, services, crafting
- `mechanics/the-portals.md` — the 5 acts: portals, rites, extraction, hostility
- `mechanics/card-variants.md` — the variant system: identification, drops, corruption
- `mechanics/corruption.md` — the existing run-level corruption mechanic (largely unchanged)
- `mechanics/sins.md` — possibly absorbed by variants, possibly preserved; under review
- `roadmap/13-pivot-persistent.md` — the phased rollout plan
- `roadmap/07-mana-pool.md` — superseded / parked
