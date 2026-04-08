---
title: The Portals
chapter: VII
subtitle: five doorways from the town, three rites in each, one chance to come home
order: 7
accent: "#D9B05F"
---

## the portals

There are five doorways in the town. Some of them are open. Some of them are not yet. Each one leads to a different *Act* — a self-contained themed campaign with its own enemies, its own bosses, its own legendary card pool, and its own cycle of angelic attention. The crew chooses which doorway to step through. The choice is the entire game.

This document describes the structural layer of deus.exe: how acts are organized, what a single dive feels like, how the pouch works, what happens when you die, and how the angels learn to hate you.

For the *why* — the design rationale and how this fits into the larger pivot — see `decisions/0003-persistent-pivot.md`.

## the five acts

| # | Act | Theme | V1 Status |
|---|---|---|---|
| I | **The Outer Nexus** | corrupted server farms | shipped |
| II | **The Neural Cathedral** | Michael's domain | shipped |
| III | **The Void Core Archives** | soul storage, deep memory | shipped |
| IV | **The Broken Liturgy** | ruined ritual spaces, defeated angels' code still running | post-launch |
| V | **The Compiler's Dream** | Metatron's mid-thought, the endgame gate | post-launch |

V1 ships with three doorways open and two locked. Acts I, II, and III map cleanly to the existing Act 1, 2, and 3 content — the structural pivot rearranges the existing dungeons into selectable regions rather than a forced linear progression. The crew can run any of the open acts at any time. There is no "do Act I before Act II" gate — Acts I, II, and III are all available from the first session, with the recommended progression coded into the lore (Act III is harder than Act I) but never enforced.

Act V is the endgame. It only opens after the crew has clean-cleared the four previous acts at hostility ≥5 — meaning a player must have meaningfully engaged with the angels' attention in every act before being granted access to Metatron himself. This is the canonical path to the game's main ending. There is no shortcut.

## what an act actually is

An Act is **three Rites in a sequence**. Each Rite is a sub-section of the act with its own branching node map (StS-style: ~10–14 rooms with combats, elites, shrines, shops, jewelers, and a Rite Boss at the end). The three Rites of an act lead deeper into its themed environment.

```
ACT I — THE OUTER NEXUS
├── Rite I    — THE SURFACE STACKS
│   └── ~10 rooms, branching map, Rite I Boss
├── Rite II   — THE DEEPER LAYERS
│   └── ~12 rooms, branching map, Rite II Boss
└── Rite III  — THE CORRUPTED CORE
    └── ~14 rooms, branching map, ACT BOSS
```

A "room" is a single node — combat, elite, shrine, shop, jeweler, altar, event, or rest. The map structure within a Rite is StS-style branching: 2–3 paths per junction, the player picks which route to take based on which node types they want.

A typical full Act dive (Rite I → Rite II → Rite III, no extractions) is **30–90 minutes** depending on encounter pacing. A single-Rite dive that ends in extraction is **10–30 minutes**. Players can play either way.

## the pouch and the run

When you enter a portal, your run pouch is empty. As you progress through rooms, you collect **packages** — each one a piece of stolen scripture you don't yet know the contents of:

```
RUN POUCH
▫ a tattered page              (common)
▫ a page sealed in iron        (rare)
▫ a page that burns to hold    (legendary?)
```

Each package shows a rarity color and a vague hint about what it might be. You can't equip packages mid-run. You can't play them. You can't drop them without losing them. They sit in your bag like a piece of stolen code you haven't decompiled yet.

The pouch fills up over the course of the run. Common packages drop from regular combats. Uncommon and rare packages drop from elites and shrines. Legendary-hint packages drop almost exclusively from boss kills, though rare shrine encounters and altar events can also produce them. The package's *true rarity* is hidden inside it — a "page that burns" might identify as a legendary, or it might identify as a corrupted-tier card with a powerful upside and a permanent downside. You won't know until town.

The pouch is **per-run** and **per-player**. In a co-op session, each player has their own pouch and their own run. If one player dies and the others survive, the dead player's pouch degrades and the survivors' pouches continue intact.

## extraction is at Rite boundaries

You cannot extract mid-Rite. There are no safe-exit nodes inside a Rite map. Once you commit to a Rite, you finish it or you die.

The **only extraction points are the Rite Bosses**. After defeating a Rite Boss, you choose:

```
RITE I CLEARED.
your pouch: 6 packages (2 rare, 1 legendary?, 3 common)
your HP:    47 / 80
hostility:  4 → farming run, no clean-clear opportunity yet

[ EXTRACT TO TOWN ]    [ PUSH TO RITE II ]
```

**Extracting** sends you back to the town with your pouch intact. Every package keeps its rolled rarity. Balthaz identifies them in town, you collect your loot, the run is over. Hostility for the act is unaffected by extraction.

**Pushing** commits you to the next Rite. You enter Rite II with your current HP, deck, gem sockets, and full pouch. Death in Rite II degrades the entire pouch — including the loot you got back in Rite I. **There is no halfway.** Pushing to Rite II is a *real* commitment to keeping yourself alive.

After Rite II's boss, the same choice appears for Rite III. Rite III's boss is the Act Boss — the named angel for that act. Killing the Act Boss is the **clean clear**: you keep your pouch with full rarity, AND if your hostility was ≥5 going into the run, the act's hostility resets to 0.

## death and the downgrade

If you die anywhere in any Rite, **every package in your pouch is degraded to common before you wake up in the town**. When Balthaz identifies the degraded packages, each one becomes a *common variant of the same base card type*.

So a `page that burns` (which would have identified as a legendary `Strike of the Wound`) instead identifies as a generic `Strike` common. The shape of the rite survives — you brought a Strike home — but the *power* in the page is gone. Diegetically: the angels eat the meaning in your pages and let your body's husk float back to the town. Mechanically: the legendary you were chasing is gone, replaced by a card you almost certainly already had.

You are not empty-handed. You are emptied of meaning.

This is the entire risk/reward calculus of the game in one rule. Every package in your pouch is a question: *would it hurt if this turned to a common right now?* If the answer is yes, extract. If the answer is no, push deeper.

## hostility — the angels' attention

Each act has its own **hostility counter**, ranging from 0 (the act has not noticed you) to 12+ (the angels are actively hunting). Hostility persists across runs and characters — it is a property of the *act*, not of the operator. The Outer Nexus might be at hostility 8 and the Neural Cathedral at hostility 2 simultaneously.

Hostility is the **only meta-progression cost** in the game. There is no town corruption meter. There is no per-character corruption meter. There is just this: the angels notice when you grind a specific portal, and the portal gets harder.

### how hostility changes

- **+1 per entry** — every time you step through the portal, the angels notice. Base tick.
- **+1 additional on death** — dying compounds the noticing. A failed run adds 2 to hostility.
- **+0 on extraction** — extracting safely (after a Rite Boss kill, choosing to come home) adds nothing beyond the entry tick. The angels respect a clean retreat.
- **= 0 on a clean clear at hostility ≥5** — killing the Act Boss when the act is at hostility 5 or higher resets it to zero. This is the ritual reset, the catharsis the system rewards. Below hostility 5, a clear is just a clear.

### what hostility *does*

| Hostility | State | Effects |
|---|---|---|
| 0–2 | **clean** | Normal enemy density. Few elites. Boss has no extra phases. Best for new players or quick farming runs. |
| 3–5 | **noticed** | Elites appear in slightly more nodes. Boss gets a minor phase variation. Drops are 5% rarer on average. |
| 6–8 | **siege** | ~40% of standard combats become elite encounters. Boss gets one extra phase. Drops noticeably better — first reliable rare floor. |
| 9–11 | **grinder** | The map is mostly elites. Boss has extra phases AND a temporary buff effect. Drops include guaranteed legendary chance per Act Boss kill. |
| 12+ | **hunter** | A *hunting angel* spawns at the start of the run and follows the crew between nodes. Every Rite Boss is empowered. The Act Boss is in a "True" form — extra phases, custom attacks, unique drops. Highest reward tier. |

The exact numerical curves are tuning targets — the brackets above are scaffolding, not law. The principle is: **higher hostility = more dangerous + more rewarding**, with the curve set so that hostility ≥9 is *seriously hard* but *seriously profitable*.

### hostility decay — by session, never by time

This is critical and the rule is simple: **for every completed run in an *other* portal, this portal's hostility decays by 1.** Hostility never decays from real-world time. You cannot close the game and come back to a cleaner Outer Nexus. You have to *play* the game in another act to earn the cooldown.

A "completed run" for decay purposes is any run that started — extraction, clean clear, OR death all count as one completed run. A loaded-and-quit doesn't count.

### how this shapes player behavior

The hostility system creates two valid endgame strategies:

**Specialist**: pick a favorite act, push it to high hostility for the loot density, occasionally push for a clean clear when the meter gets uncomfortable. Big runs, big rewards, big heartbreaks. Cycles of catharsis.

**Cycler**: rotate through all four open portals, keeping each at moderate hostility, never letting any of them get brutal. Steady progress, less drama, fewer reset moments.

Both playstyles are valid. Both produce legendary drops. Different player personalities will gravitate to different sides.

## what a single dive feels like, end to end

```
TOWN
  └── walk to Neural Cathedral portal
       │  hostility shows 7 (siege)
       │  legendary pool hint: "Judgement, Marked Hand,
       │                        Angelic Verse, ..."
       │
  └── DESCEND

ACT II — THE NEURAL CATHEDRAL — RITE I (THE ANTECHAMBER)
  ├── room 1   combat (3 servitors)
  ├── room 2   shrine (pick 1 of 3 cards to test in run)
  ├── room 3   combat (2 elites)
  ├── room 4   shop
  ├── room 5   combat (5 chorus drones)
  ├── room 6   jeweler (socket gem into existing card)
  ├── room 7   combat (1 elite + 2 normals)
  ├── room 8   shrine (corruption decision)
  ├── room 9   rest
  └── room 10  RITE I BOSS — minor angel, 3 phases
       │
       │  pouch: 4 packages (2 common, 1 rare, 1 legendary?)
       │  HP: 51 / 80
       │
       └── EXTRACT or PUSH?

PLAYER PUSHES.

ACT II — RITE II (THE CHOIR LOFT)
  ├── (12 rooms, branching map)
  └── RITE II BOSS
       │
       │  pouch: 7 packages
       │  HP: 22 / 80
       │
       └── EXTRACT or PUSH?

PLAYER EXTRACTS. Too risky to push to Rite III at 22 HP.

RETURN TO TOWN
  ├── hostility unchanged (extraction = +0)
  ├── Balthaz identification ceremony (one package at a time)
  │   ▫ "Sharp Strike+ — common upgrade"
  │   ▫ "Sharp Strike+ — common upgrade" (already owned, dismantled to 1 essence)
  │   ▫ "Iron Defend — uncommon variant"
  │   ▫ "Marked Hand — RARE variant. New unlock."
  │   ▫ "Marked Hand — RARE variant" (already unlocked, dismantled)
  │   ▫ "Burning Verse — RARE variant. New unlock."
  │   ▫ "Judgement of the Wound — LEGENDARY variant. New unlock."
  │
  ├── 1 new common, 2 new uncommons, 2 new rares, 1 new legendary
  ├── 2 essence from dismantled duplicates
  └── deck-building view opens — equip the new variants if desired
```

That's one dive. About 25–40 minutes of play. The player learned which routes are dangerous in Rite I, made a tough push-or-extract call after Rite II, and came home with a build-defining legendary they can swap into their main Cryptomancer's deck for the next run.

The player will do this dozens of times across an act, hundreds of times across the lifetime of a save.

## scope notes for V1

- **3 portals open** (Acts I, II, III). Mapped to existing 3-act content. Acts IV and V are post-launch.
- **3 rites per act** = 9 rite-section maps total to design. Each rite is ~10–14 rooms.
- **No "level up the act" mechanic.** Hostility is the only stateful variable per act.
- **No multiplayer matchmaking** — co-op assumes friends-via-IP, same as the existing game.
- **Tutorial runs through Act I exclusively** for the first 2–3 dives.

## open questions

- **Can a player abandon a run mid-Rite without dying?** Probably no — abandoning is the same as dying for pouch purposes. This prevents "I'm doing badly, let me alt-F4 and lose nothing." Needs playtesting.
- **Do all rooms in a rite have to be cleared?** Probably no — branching maps mean you can skip some nodes. StS-standard.
- **Does the player see the full Rite map at the start of the rite, or only the next room?** Probably full map (StS-standard) — preserves planning. Fog-of-war is on the table for a "deeper rite" feel in Act IV/V.
- **What happens if a co-op partner extracts at Rite I and the others push?** The extracted partner returns to town and waits in a "lobby" until the others finish or die. They can browse their stash, prep their deck, even start a different run in another act, but they can't rejoin the in-progress run.
- **Hunting angel mechanics** at hostility 12+. What does it actually do? Follows you between rooms — but does it interrupt combats? Spawn add waves? Steal packages? Open question.
