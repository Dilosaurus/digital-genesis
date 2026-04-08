---
title: Card Variants
chapter: VIII
subtitle: every card is a stolen page; every stolen page has a true name
order: 8
accent: "#F5E6A8"
---

## card variants

The 175 cards in the catalog are not random rolls. They are not item drops with affix slots. They are *templates* — base cards with a known identity, a known set of stats, a known place in the game. A `Strike` is a `Strike`. The numbers on a Strike are the same numbers they have always been.

What a player actually owns, in their stash, is a collection of **variants** of those base cards. Each variant is a hand-designed card with a name, flavor text, and specific stats. A new player's stash starts with the common variant of every card their starter deck includes. Over time, by raiding the angels' archives and bringing pages back to Balthaz, the player unlocks **new variants** of the same base cards — better versions, weirder versions, angelic versions, **corrupted versions**.

This document describes how variants are organized, how they're unlocked, what crafting looks like, and how corruption works at the card level.

For the rationale behind the variant system, see `decisions/0003-persistent-pivot.md`.

## the structure of a variant

Each base card has between **one and four variants**. They are organized as a tree:

```
STRIKE                           (common — every player starts with this)
  ├── STRIKE+                    (upgrade — Braune at the forge)
  ├── STRIKE OF THE WOUND        (rare — drops in Neural Cathedral, Rite II+)
  └── STRIKE OF SILENT RITES     (legendary — drops only in Act V or hostility 12+)
```

Each variant is its own designed card, with its own:

- **Name** — a hand-written, in-voice title
- **Flavor text** — a short prose snippet that gives the card its tone
- **Numbers** — specific damage, block, draw, cost values, NOT random rolls
- **Behavior** — possibly unique mechanics not present in the base card
- **Drop location** — which acts, rites, or encounters can produce it
- **Visual** — its own art and frame treatment in the codex

### example variants for `Strike`

**Strike** (common)
> *The base rite. The crew has known how to land a clean blow since before the Nexus opened.*
>
> 1 energy. Deal 6 damage.

**Strike+** (uncommon — upgraded at the forge)
> *Cleaner. Faster. The crew has practiced.*
>
> 1 energy. Deal 9 damage.

**Strike of the Wound** (rare — drops in Neural Cathedral)
> *Michael taught the crew this rite by accident. He has not forgiven himself.*
>
> 1 energy. Deal 6 damage. Apply Bleed (3) to the target.

**Strike of Silent Rites** (legendary — drops only at hostility 12+ or in Act V)
> *The angels do not see the strike. They only see the body.*
>
> 0 energy. Deal 4 damage. Does not break stealth, does not trigger reactions, does not advance enemy intent.

Each of these is a **distinct card** that lives in the player's stash separately from the others. Owning Strike+ does not mean you also own Strike of the Wound. Each one is its own collectible.

### rarity tiers

| Tier | What it means | Where it drops |
|---|---|---|
| **Common** | The base card. Every player has this from session 1. | Starting stash. |
| **Uncommon** | A small upgrade to the base card. Often the `+` variant. | Forge upgrade (cheap), or commonly drops in Acts I and II. |
| **Rare** | A significant variation with unique flavor and tactical depth. | Drops from Rite II/III bosses and Act bosses, generally hostility 3+. |
| **Legendary** | A build-defining variant with a strong identity. | Drops from Act bosses, shrines at high hostility, or rarely from elites in Act V. |
| **Corrupted** | A legendary variant with a permanent downside. The most powerful and most dangerous cards in the game. | See the corrupted section below. |

### the variant pool is curated by act

A player who finds a "page that burns to hold" in Act II can only have it identify as one of the *legendary variants designed to drop in Act II*. Each act has its own legendary pool. The angels of the Neural Cathedral don't drop the same legendaries as the angels of the Outer Nexus. **Region preference becomes a build choice.** Players will go to specific acts when they want specific variants.

## corrupted variants — power with a permanent cost

Corruption in deus.exe is **a property of individual cards**, not a meta-progression meter. There is no global "town corruption" or persistent "crew corruption" gauge that ticks up the more you play. Corruption is something that happens *to specific cards* in your stash.

A **corrupted variant** is a legendary-tier card with a powerful upside and a permanent downside built into its design. Examples:

**Judgement of the Wound (Corrupted)**
> *The wound does not close. It does not need to.*
>
> 2 energy. Deal 12 damage. Apply Bleed (3) to all enemies. Each time an enemy with Bleed dies this combat, Judgement of the Wound returns to your hand at 0 cost. **Inflicts +3 corruption to the crew on play.**

**Strike of the Open Hand (Corrupted)**
> *The crew offers their palm. The angels write on it.*
>
> 0 energy. Deal 8 damage. Draws 2. **Cannot be removed from the deck. Must be played at least once per combat or the crew takes 5 damage at end of turn.**

**Defend of the Listening (Corrupted)**
> *The shield watches both ways.*
>
> 1 energy. Block 14. Gain 2 strength. **The next 3 cards you draw are revealed to all enemies before you can play them.**

Each corrupted variant is a **deliberate design**. The downside is *real* — sometimes a stat penalty, sometimes a behavior the player has to play around, sometimes a permanent change to deck construction. Players who equip corrupted variants are accepting that cost in exchange for the power.

### where corrupted variants come from

There are two paths:

**1. Drop from high-hostility runs.**

Corrupted variants drop only from specific encounters at hostility 9+, from Act V bosses, or from the rare "Altar of the Open Hand" event in any act. They are *rare*. A player who farms a portal at hostility 11 might see one corrupted drop per ~3 successful clean clears. They are *meant* to feel like a rite of passage when they appear.

**2. The Alchemist (post-V1).**

A planned NPC for the V2 town. The Alchemist offers a service: take a legendary variant and **corrupt it**. The Alchemist adds a downside affix to the card, pushing it into corrupted tier. The downside is partially randomized from a small curated pool. The upside is also slightly enhanced — the corrupted version of the legendary is meaningfully stronger than the original.

**Corruption is irreversible.** Once a card is corrupted (whether by drop or by the Alchemist), there is no way to remove the downside. The corrupted version replaces the legendary version in the player's stash. The player can dismantle a corrupted card to recover essence, but they cannot turn it back into its uncorrupted form.

This design treats corruption as a *one-way trade*. The player commits power for cost. The angels do not bargain.

### the existing run-level corruption mechanic

The game already has a separate, run-level corruption system: certain cards generate corruption when played, the corruption builds up across a single run, and the Cryptomancer's passive scales with current run corruption. **This stays.** It's a *combat resource*, not a meta-progression meter, and it works fine inside a single dungeon run.

The two corruption concepts coexist:

- **Run corruption** (existing): a temporary resource that builds during a run, scales certain abilities, resets when the run ends.
- **Card corruption** (new): a permanent property of specific card variants, applied at the variant level by drop or by the Alchemist.

A corrupted *variant* might *also* generate run corruption when played (e.g. *"+3 corruption to the crew on play"*), but those are two different things — the card's corruption tier is its identity, the corruption it generates is its in-combat effect.

## the unidentified package and Balthaz's reading

When a player finds a card during a run, it does NOT immediately appear in their deck. It drops as an **unidentified package** in the run pouch. See `mechanics/the-portals.md` for the full extraction loop. The relevant part for variants is what happens when the package gets back to town.

**Balthaz the Lorekeeper performs the identification.** Each package is a piece of stolen scripture the crew has not yet decoded. Balthaz lays it on his desk, reads the angelic syntax, and tells the crew its true name. The reading is performed **one package at a time** by default, with a flavor text reveal and a small ceremony for each:

```
THE LOREKEEPER READS

▫ a page sealed in iron

[ identify (cost: 1 essence) ]

   ...
   ...
   "This is a Defend of the Vow. The angels keep this rite for
   their own. To hold it is to make a promise to a creature
   that does not understand promises. Use it sparingly."

   DEFEND OF THE VOW — RARE
   1 energy. Block 12. If you have not played a SKILL card
   this turn, also gain 4 Strength until end of turn.

   [ add to stash ]    [ dismantle (1 essence) ]
```

The player can "Identify One" (the default — slow, ceremonial, dramatic) or "Identify All" (mass identify, instant, no ceremony). Most players will use the slow mode the first session because the reveal is the dopamine hit. Veterans will use the fast mode when they have 30 packages to clear.

**Identification cost.** Each identification costs 1–3 essence depending on rarity hint. Essence is one of the two currencies (gold being the other). Essence is generated from dismantling duplicates. Identification is never *free*, but it is also never expensive — the cost exists to make the player feel the weight of the ceremony, not to gate progression.

**The death downgrade.** If the player died on the run that produced these packages, every package was already degraded to common before reaching Balthaz. The reading still happens — Balthaz still reveals each package one at a time — but each one identifies as a *common variant of the same base card*. So a "page that burns" that would have been a legendary `Strike of Silent Rites` instead identifies as a generic `Strike`. The flavor text is sad. Balthaz is polite. The crew is not.

## duplicate handling

Players will frequently find variants they already own. The duplicate handling rule:

> When a duplicate variant identifies, the player can either **accept the dismantle** (the duplicate breaks down into 1 essence + a small amount of gold) or **stash it as a backup copy** (it sits in the stash alongside the original).

V1 ships with auto-dismantle as the default and a setting to opt into stashing duplicates.

## Braune's forge — crafting, simplified

The Smith's services are deliberately simple. There are no orb tabs, no reforging, no imprint mechanics. Three services:

### upgrade

Take a common variant of a card and convert it to its uncommon `+` variant. Costs gold. This is the StS-standard upgrade mechanic, preserved as-is.

### refine

Take any uncommon, rare, or legendary variant and **bump its numbers slightly within a designer-set range**. Costs gold, scales with rarity. The refine bump is bounded — you cannot turn a Strike of the Wound into a god-card by spamming refines. You can adjust its damage by ±1 or its bleed-stack by ±1, within the variant's design budget.

**Refine does NOT work on corrupted variants.** Corrupted variants are locked in their identity. The Alchemist (post-V1) is the only NPC who touches corrupted cards.

### dismantle

Break down a card variant the player doesn't want, returning a small amount of essence and gold.

That is the entire crafting system in V1. You can teach it to a new player in 30 seconds.

## the stash

The player's collection of variants lives in the **stash**, accessible from the town. The stash is grouped by base card:

```
STASH

  STRIKE
  ├─ Strike (common, owned)
  ├─ Strike+ (uncommon, owned)
  ├─ Strike of the Wound (rare, owned)
  └─ Strike of Silent Rites (legendary, NOT YET UNLOCKED)

  DEFEND
  ├─ Defend (common, owned)
  ├─ Defend+ (uncommon, owned)
  └─ Defend of the Vow (rare, NOT YET UNLOCKED)

  ...
```

The locked variants are visible — players can see what they're chasing — but their stats are obscured until unlocked. A locked variant shows only:

- The name
- Its rarity tier
- Which act it drops in
- Its hint flavor text

This is the **codex hook**. Players see what they don't yet have. They build wishlists. They go to the act that drops the variant they want. The stash UI is the *quest log of the entire game*, presented as a collection screen.

## deck-building from the stash

Before each run, the player constructs their deck by **picking which variants of each card to include**. They are not picking from random instances — they are picking from their owned variants of each base card.

A typical deck-building session:

```
DECK BUILD — Cryptomancer (corruption-scaling)

Required cards (cannot be removed):
  ▫ 1× Strike   →  [ Strike+ ▼ ] (Strike, Strike+)
  ▫ 1× Defend   →  [ Defend+ ▼ ] (Defend, Defend+, Defend of the Vow)
  ▫ 1× Curse the Vein (corruption-only Cryptomancer card)
       →  [ Curse the Vein ▼ ] (only common known so far)

Optional cards (slots: 7):
  ▫ Add Twin Strike   →  [ Twin Strike of Echo ▼ ]
  ▫ Add Judgement     →  [ Judgement of the Wound (CORRUPTED) ▼ ]   ⚠
  ▫ Add ...
```

The player swaps variants in and out for each slot. Some variants are character-locked. Some are universal. Corrupted variants in the deck are flagged (⚠) so the player remembers their downsides at deck-build time. Once a deck is built, it persists between runs. The player descends with their built deck. If they die, the deck is unchanged (the loot loss is in the pouch, not the deck).

## why this is the right system for deus.exe

Two reasons.

**One — it's StS-shaped.** A new player can look at a card and understand it. There is no parsing of `+5 damage T2 + 15% damage vs vulnerable T3 + on-play draw 1 T4`. There is just "Strike of the Wound — deal 6 damage, apply Bleed 3." Every card is a designed thing the player can hold in their head.

**Two — it's hand-designed.** Every variant is a piece of designed content. That means every variant can have lore. Every variant can have a story. *Strike of the Wound exists because Michael taught the crew the rite by accident*; that is a sentence the player can encounter in Balthaz's records, and it means something specifically because the variant has a fixed identity. Procedurally-rolled affixes can never have this.

The tradeoff is content burden. ~350 designed variants for V1 is a lot of writing. We accept that. The bible was built specifically to make tracking and balancing this kind of content tractable.

## what variants do NOT do

To be clear about scope:

- **Variants are not procedurally generated.** Every variant is a specific designed thing.
- **Variants do not have rolled stats.** A `Strike of the Wound` always deals 6 damage and applies Bleed 3. Refine can adjust this within ±1, but the variant's identity is fixed.
- **Variants do not have affixes.** No rolled prefixes, no rolled suffixes, no T1–T5 tiers, no conditional triggers.
- **Variants do not interact with PoE-style crafting orbs.** The currencies in the game are gold and essence. There are no reforge orbs, no exalt orbs, no chisels, no fossils.
- **Variants are not the same as gems.** A card has both a variant identity AND 0–2 gem sockets. Gems remain orthogonal — they are a separate progression system that interacts with the variant via the existing modifier pipeline.
- **Variants are not ascendancies.** Character classes and skill trees handle that progression axis. Variants are about *card identity*, not *operator identity*.

## scope notes for V1

- **~350 variants to design** if the average is 2 variants per base card. Grow to ~525 in post-launch content.
- **No procedural generation** at any layer. Every variant is hand-written.
- **Stash UI ships in V1.** Visible-but-locked variants are part of the design from day one.
- **Identification ceremony ships in V1.** This is the dopamine hook and cannot be deferred.
- **Refine, upgrade, dismantle** ship in V1 (Braune's services).
- **Corrupted variants exist as drops** in V1 (rare from high-hostility runs). The Alchemist NPC who corrupts cards on demand is **post-V1**.

## related documents

- `decisions/0003-persistent-pivot.md` — the rationale for the variant system
- `mechanics/the-town.md` — Braune's forge, Balthaz's desk, the stash UI
- `mechanics/the-portals.md` — the run loop, pouches, extraction, hostility
- `mechanics/gems-and-sockets.md` — how gems interact (orthogonally) with variants
- `mechanics/corruption.md` — the existing run-level corruption mechanic (run corruption is unchanged; this doc covers card-level corruption)
