---
title: The Combat Loop
chapter: I
subtitle: how a rite is resolved
order: 1
accent: "#B13340"
---

## the combat loop

Combat in `deus.exe` is a **turn-based liturgy**. Your crew draws cards, plays them, and the enemies respond. The basic rhythm is old and well-understood — any deck-builder player will recognize it — but underneath the familiar skeleton is a layered modifier system that's doing more work than it looks.

## the turn

Each combat turn has **four phases**:

1. **Draw** — you draw to your hand size (usually 5, modified by relics, gems, and character passives).
2. **Play** — you spend energy to play cards. Energy refills to your maximum every turn. Cards can damage enemies, block incoming damage, buff you, debuff enemies, or do all four at once.
3. **Enemy intent** — enemies telegraph their next action and resolve it. You can see what's coming. You rarely have enough block to stop it entirely.
4. **End-of-turn** — status effects tick, block expires (mostly), corruption may advance, triggered gems fire. Then back to phase 1.

## what makes a rite different

`deus.exe` is a **co-op** deck-builder. Up to four operators share the same combat. Each operator has their own deck, their own hand, their own energy. But a single combat is **one timeline**, and the turn phases are synchronized across the crew.

This means:

- **Vote phases** happen before certain decisions. If the crew must accept or refuse a pact, you vote — majority rules.
- **Party cards** exist. A card like *Rally* can grant block to every operator, not just the one who played it. The Sysadmin's whole kit is built around this.
- **Marked targets** persist across operators. The Netrunner marks an enemy; the Scourge's next attack gets bonus damage against marked.
- **Corruption pools** are per-operator. One operator can be fully corrupted while another is clean. This has tactical implications because the Cryptomancer *gains power* from her own corruption.

## the stat pipeline

Every number in combat goes through the modifier pipeline before it is applied. A `damage: 6` card is not "6 damage" — it's the starting value for a calculation that involves:

- **flat additions** (from relics, character passives, buffs like Strength)
- **percent additions** (from gems that boost damage by a percentage)
- **percent multipliers** (applied last, for things like "x1.25 damage vs vulnerable")
- **overrides** (rare — certain cards set the final value directly)

The order is always: **OVERRIDE → FLAT_ADD → PERCENT_ADD → PERCENT_MULT**.

Read `mechanics.gd/modifier-pipeline` for the deep dive. The short version is: your actual damage per hit is a function of half a dozen sources, and the lab tools will show you exactly where every number came from.

## winning and losing

You win a combat when every enemy reaches 0 HP. You lose when every operator reaches 0 HP. An operator at 0 HP is **downed**, not dead — the crew can revive them, and certain cards specialize in revival. But if the whole crew goes down at once, the run ends.

**The run ends** is not the same as a game over. You come back to the GENESIS safehouse, the spoils you carried out are banked, and you plan your next descent. The currency persists. The relics persist. Only the run is lost.

Only the run.
