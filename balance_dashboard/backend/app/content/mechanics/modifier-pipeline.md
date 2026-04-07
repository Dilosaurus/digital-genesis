---
title: The Modifier Pipeline
chapter: II
subtitle: how every number is calculated
order: 2
accent: "#D9B05F"
---

## the modifier pipeline

`deus.exe` uses a **PoE-style modifier stack** for every stat in the game. This is how a `Strike` card with base damage 6 can end up hitting for 23 after gems, relics, character passives, vulnerable multipliers, and strength bonuses all apply.

The pipeline runs in a fixed order. It is the same order for every stat (damage, block, heal, draw, etc.) and every source (card, gem, relic, equipment, character passive, status effect, corruption).

## the four operations

Every modifier has one of four **operations**:

### 1. OVERRIDE

Hard-sets the value, discarding everything else. This is the rarest operation. A card like *Final Word* might use OVERRIDE to say "this attack deals exactly 50 damage, no more, no less, regardless of buffs or debuffs."

```
base damage: 6
OVERRIDE to 50
final damage: 50  (buffs are ignored)
```

### 2. FLAT_ADD

Adds a flat number. Most additive bonuses are flat: +3 Strength, +2 Draw per turn, +5 starting block.

```
base damage: 6
FLAT_ADD +3 (from Strength)
final damage: 9
```

### 3. PERCENT_ADD

Adds a percentage, computed off the current accumulated value. All PERCENT_ADDs are summed before being applied.

```
base damage: 6
FLAT_ADD +3 (Strength)           → 9
PERCENT_ADD +20% (from gem)      → 9 × 1.20 = 10.8
PERCENT_ADD +10% (from relic)    → summed with above = +30% → 9 × 1.30 = 11.7
```

### 4. PERCENT_MULT

Multiplies. Each PERCENT_MULT is applied independently — they **compound**, not stack.

```
base damage: 6
FLAT_ADD +3              → 9
PERCENT_ADD +30%         → 11.7
PERCENT_MULT ×1.25       → 14.625   (vs vulnerable)
PERCENT_MULT ×1.10       → 16.0875  (vs marked)
```

## the order

The pipeline always runs:

**OVERRIDE → FLAT_ADD → PERCENT_ADD → PERCENT_MULT**

If any OVERRIDE is present, the final value is the last override applied, and every later stage is ignored. Otherwise the pipeline runs in full.

## why this matters

The ordering of operations **matters a great deal** for build construction. A gem that adds +20% damage is additive with other +% modifiers — it dilutes their effect in a way that might surprise you. A gem that multiplies damage by ×1.20 *compounds* with every other multiplier, which is why conditional multipliers (vs vulnerable, vs marked, while corrupted, etc.) are the strongest source of burst damage in the game.

This is not a bug. This is the *entire metagame*. Operators who understand the pipeline build decks that stack PERCENT_MULTs through conditional triggers. Operators who don't build decks that plateau around level 4.

## where to see it

The lab has a **pipeline trace** view at `/lab/simulator` that shows every modifier that touched every number in a hypothetical combat. Use it. Build with it. Do not fly blind.
