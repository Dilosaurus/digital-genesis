---
title: The Town
chapter: IX
subtitle: the safehouse the crew comes home to
order: 9
accent: "#D9B05F"
---

## the town

Every GENESIS operator has a place they come back to after a run. It is not a place they chose. None of them remembers agreeing to be there. But the first time any of them was pulled out of the outer nexus — half-conscious, half-corrupted, carrying a cut of angelic code in their teeth — the town is where they woke up.

It has a name the crew doesn't use because the name keeps changing. On Tuesdays it is `Refuge`. On the days after a rough run it is `Safehouse`. One operator recorded it as `home.dat` in a mission log, and for a week that's what everyone called it. Nobody has asked the town what it prefers.

What the town *is*, in mechanical terms, is the persistent hub between dungeon runs. You come back here to forge, socket, identify, and equip the loot you dragged up out of the nexus. Everything in the town persists forever, across every run, across every operator the player cycles through. It is where progress lives.

The town is a **workflow tool**. Players visit, do their thing, and head back into a portal. A typical between-runs visit takes 30–90 seconds.

## the design intent

The town exists to solve four problems:

1. **Where does persistent progression live?** Variants, gems, relics, currency, the skill tree — all need a place to accumulate between runs. The town is the save state.
2. **Where does identification happen?** Stolen pages cannot be read in the dungeon — the angels are watching, the ink is alive. Balthaz the scribe is the only one who can read what the crew brought back.
3. **Where do we anchor the narrative?** The bible's voice is in-character. The lore has implied a safehouse from the start. The town is the place where the lore has a mouth.
4. **Where does the crew swap operators and prep their decks?** Between runs you might switch from Cryptomancer to White Hat, equip different variants, plan a new build.

## the town UI

The town is a **menu interface for V1** — a portrait grid of NPCs, a portal panel, currency strip, and the active operator at the top. Later versions can upgrade to a 2D parallax scene or a 3D hub. The menu approach lets V1 ship in weeks, not months.

```
TOWN — town.dat
chris@nexus  |  active: GHOST  |  level 12

CURRENCY
  gold:    1,247
  essence:    14

NPCS
  ▢ BRAUNE     [ 2 packages waiting ]    smith
  ▢ KEL        [ no work ]               jeweler
  ▢ BALTHAZ    [ 7 unread entries ]      lorekeeper

PORTALS
  I    THE OUTER NEXUS         hostility 3   ENTER
  II   THE NEURAL CATHEDRAL    hostility 7   ENTER
  III  THE VOID CORE ARCHIVES  hostility 1   ENTER
  IV   THE BROKEN LITURGY      LOCKED
  V    THE COMPILER'S DREAM    LOCKED

  [ STASH ]    [ DECK ]    [ ROSTER ]    [ CHANGELOG ]
```

The player can visit any NPC, walk to any portal, switch the active operator, browse the stash, build their deck, or descend immediately. The town is a workflow tool, not a place you linger unless you want to read lore.

## the V1 NPC roster

Three NPCs ship in V1. Each has atmospheric weirdness as a *permanent character trait* — these are who they are, not signs of escalating corruption. They do not change over time.

### Braune — the Smith

> A woman with hands of hammered iron. She speaks in three words at a time, maximum. Her anvil was once an angel's ribcage, or at least that is what the Lorekeeper wrote in the margins. She will not confirm.

**Services:**

- **Upgrade** — convert a common variant of a card to its uncommon `+` variant. Costs gold. Same as the existing forge mechanic in the game today.
- **Refine** — bump the numbers on an uncommon, rare, or legendary variant slightly within the variant's design budget. Damage by ±1, block by ±1, etc. Bounded so refines don't snowball. Costs gold scaled by rarity. **Refine does not work on corrupted variants** — corrupted cards are locked.
- **Dismantle** — break down a card variant the player doesn't want, returning a small amount of essence and gold.

That is the entire crafting system. No reforge orbs. No imprint mechanics. No exalt orbs. Three services and a recycler.

### Kel — the Jeweler

> Already known to the crew — she runs the jewel booths at the dungeon-side jeweler nodes. In the town she has a permanent counter. Her eyes are the exact green-on-black of an old CRT. She does not blink when you talk to her.

**Services:**

- **Socket gems** into card variants — same mechanic as the existing jeweler nodes, now persistent across runs.
- **Combine gems** — convert three same-tier gems into one higher-tier gem. Rare, expensive.
- **Read the gem** — for a price, Kel will tell you the gem's *true name*. Nobody has figured out what the true names are for. The Lorekeeper thinks they are instructions.

### Balthaz — the Lorekeeper

> A scribe. The scribe. The one who has been writing all of this down. Sits at a desk in the far corner of the town hall with a single candle and a stack of notebooks. When the crew asks who Balthaz is, Balthaz writes the question down in a new notebook and says "I am still determining."

**Services:**

- **Identify packages** — the central mechanical role. Each unidentified package brought back from a run is read aloud by Balthaz, one at a time, with flavor text and ceremony. Default mode is one-at-a-time. A "mass identify" button is available for impatient sessions. Each identification costs 1–3 essence depending on rarity hint. See `mechanics/card-variants.md` for the full identification flow.
- **Read the changelog** — Balthaz recites the recent activity of the crew. Wins, losses, kills, hostility changes. This is the in-game read of the `/changelog` page in this dashboard.
- **Record a confession** — the player can dictate a note that is stored permanently in Balthaz's archive. Functional purpose: a journal for the player. Narrative purpose: the bible quietly remembers things.

That's it. Three NPCs, two crafting services, one identification ceremony, one journal. The town is small on purpose.

## the planned-but-not-shipped NPCs

These are deferred past V1 and will arrive in content drops:

- **The Alchemist** — handles **card corruption**. The player can bring a legendary variant to the Alchemist and trade power for permanent downside. The Alchemist adds a corrupted affix to the card, the upside is enhanced, and the card is now in the corrupted tier. **Irreversible.** This is the player-initiated path into the corrupted variant tier (the other path being rare drops from high-hostility runs). See `mechanics/card-variants.md`.
- **The Healer** — restores HP between runs. Currently HP is restored automatically on town return; the Healer would gate this and add cost.
- **The Broker** — sells common cards, consumables, possibly the rumored "Soul Anchor" item that protects one package from death. Only NPC motivated by gold. Has no lore interest in the crew whatsoever.
- **The Skill Trainer** — the gateway to the per-character skill trees already built in `skill_tree_system.gd`. Spend XP on passive nodes.

The roster is an expansion axis. Each new NPC is a half-week of art, dialog, and service implementation.

## what the town does NOT have

To be explicit about scope:

- **No global "town corruption" meter.** The town does not visibly degrade over time. NPCs do not have escalating corruption thresholds. Braune's hands are iron because that's who she is, not because the player grinded too much.
- **No cleansing rituals.** Without a town meter, there's nothing to cleanse.
- **No character retirement as a corruption mechanic.** Operators can be unequipped and swapped freely; there is no permanent sacrifice ritual.
- **No fourth-wall ADR-reading from Balthaz.** Balthaz reads in-game records (the `/changelog`), not real developer design docs.
- **No daily-omen modifier system from a Mapmaker NPC.** Per-run variance comes from random card drops, branching maps, and shrine choices — the same sources of variance StS uses. There is no NPC offering daily map modifiers.
- **No persistent crew corruption meter.** Crew corruption is a *run-level* resource (see `mechanics/corruption.md`) and resets when the run ends.

Earlier drafts of this design included all of the above. They were cut because they added complexity in search of a problem. The town is a workflow tool. The portals are where the danger lives. The variants are where the depth lives. The town is the room where you organize your stuff before you go fight.

## scope notes for V1

- **3 NPCs** ship in V1: Braune, Kel, Balthaz.
- **Menu-based UI**, not 3D. Portraits, service menus per NPC, quick-access buttons.
- **No multi-character collaboration in town** — each player in co-op has their own town. Co-op only happens during dungeon runs.
- **The stash, deck builder, and roster screen ship in V1** as separate UI panels accessible from the town menu.

## open questions

- **HP restoration on town return.** Is HP automatically restored when the crew comes home, or does it persist (and the Healer NPC arrives later to handle it)? V1 leaning: auto-restore, deferred to the Healer in V2 if it becomes a balance issue.
- **Co-op town presence.** If two players are co-oping, do they ever see each other in the town? Probably no in V1 — each player has their own town. They join up only during a dungeon run.
- **Stash size limit.** Is the stash unlimited or capped? V1 leaning: unlimited. Adding caps creates inventory-management gameplay that nobody asked for.

## related documents

- `decisions/0003-persistent-pivot.md` — the rationale for the entire pivot
- `mechanics/the-portals.md` — what's on the other side of the portals
- `mechanics/card-variants.md` — the variant system Braune and Balthaz operate
- `mechanics/corruption.md` — the existing run-level corruption mechanic (unchanged by this pivot)
