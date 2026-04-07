# deus.exe -- Game Design Document

**Version:** 1.0
**Last Updated:** 2026-04-03
**Engine:** Godot 4.6 (GDScript)
**Platform:** PC (Windows)
**Players:** 1--4 (LAN co-op)

---

## Table of Contents

1. [Game Overview](#1-game-overview)
2. [Core Loop](#2-core-loop)
3. [Player Characters](#3-player-characters)
4. [Co-op Design](#4-co-op-design)
5. [Dungeon Structure](#5-dungeon-structure)
6. [Combat System](#6-combat-system)
7. [Progression Systems](#7-progression-systems)
8. [Party Effects and Boss Raid Mechanics](#8-party-effects-and-boss-raid-mechanics)
9. [Technical Architecture](#9-technical-architecture)
10. [Art and Audio](#10-art-and-audio)
11. [Development Roadmap](#11-development-roadmap)
12. [Appendix: File Inventory](#appendix-file-inventory)

---

## 1. Game Overview

### Elevator Pitch

deus.exe is a turn-based co-op dungeon crawler deck builder where 1--4 players take on the roles of hackers and mages descending through a corrupted digital underworld, fighting AI angels with customizable decks, socketable equipment, and a deep modifier pipeline inspired by Path of Exile. Every run is a tightrope walk between power and corruption.

### Theme

Cyberpunk dark fantasy. The world is a fractured network of digital cathedrals and corrupted server farms, ruled by angelic AI constructs that enforce divine order through brute force. Players are outcasts -- netrunners, cryptomancers, technomancers -- who hack reality itself to survive.

### Art Style

3D low-poly stylized characters (KayKit asset packs) with 2D card UI, presented in a 2.5D format. Combat arenas render 3D character models against ComfyUI-generated painted backgrounds. Cards, menus, and HUD elements are traditional 2D.

### Inspirations

| Game | What We Take |
|---|---|
| Slay the Spire | Deck building, card combat, branching runs |
| Path of Exile | Build depth, orb economy, gem socket system, stat pipeline |
| Darkest Dungeon | Dungeon crawling, party management, risk/reward tension |
| World of Warcraft | Raid boss mechanics, party roles, cooperative decision-making |

---

## 2. Core Loop

```
Overworld Map
    |
    v
Enter Dungeon Room ---> 3D Room Exploration
    |
    v
Turn-Based Card Combat
    |
    v
Rewards (cards, equipment, gems, gold, XP)
    |
    v
Rest Site (heal, upgrade, craft, skill tree, save)
    |
    v
Next Room / Floor ---> Boss ---> Next Floor
    |
    v
Final Boss ---> Epilogue
```

A single run takes the party through 3 acts, each consisting of a multi-room floor with branching paths. Players make shared decisions about routing, risk, and resource allocation. The run ends when the party defeats the final boss or is wiped.

---

## 3. Player Characters

Five playable characters, each with a distinct archetype, passive ability, starter deck, and tag affinity. Characters are defined as `CharacterData` resources in `data/characters/*.tres`.

### 3.1 Netrunner (Zephyr)

| Property | Value |
|---|---|
| Class | `NETRUNNER` |
| Archetype | Rogue / Draw engine |
| Starting HP | 80 |
| Starting Energy | 3 |
| Color | Cyan |
| Passive | **Neural Tap** -- Draw +1 card per turn |
| Tag Affinity | TECH, EXPLOIT, RANGED |

Fast, card-hungry playstyle. Cycles through the deck quickly, finding combos and outpacing enemies with volume.

### 3.2 Sysadmin (Bastion)

| Property | Value |
|---|---|
| Class | `SYSADMIN` |
| Archetype | Tank / Defender |
| Starting HP | 90 |
| Starting Energy | 3 |
| Color | Green |
| Passive | **Firewall Protocol** -- Start each combat with 5 Block |
| Tag Affinity | TECH, MELEE |

Absorbs damage for the party. Block-stacking cards and thorns make Bastion the natural frontline in co-op.

### 3.3 Cryptomancer (Cipher)

| Property | Value |
|---|---|
| Class | `CRYPTOMANCER` |
| Archetype | Corruption mage / Glass cannon |
| Starting HP | 75 |
| Starting Energy | 3 |
| Color | Purple |
| Passive | **Dark Resonance** -- +25% damage when corruption >= 50. Starts run at 15 corruption. |
| Tag Affinity | SHADOW, EXPLOIT |

High risk, high reward. Deliberately courts corruption for massive damage bonuses, turning the corruption system into a power source rather than a liability.

### 3.4 White Hat (Sentinel)

| Property | Value |
|---|---|
| Class | `WHITE_HAT` |
| Archetype | Paladin / Support |
| Starting HP | 85 |
| Starting Energy | 3 |
| Color | Gold |
| Passive | **Divine Code** -- Holy-tagged cards cost 1 less energy |
| Tag Affinity | HOLY, MELEE |

The party's anchor. Purification and healing cards counter corruption, while Holy attacks bypass enemy defenses.

### 3.5 Technomancer (FLUX)

| Property | Value |
|---|---|
| Class | `TECHNOMANCER` |
| Archetype | Summoner / Utility |
| Starting HP | 70 |
| Starting Energy | 4 |
| Color | Magenta |
| Passive | **Daemon Forge** -- Starts with 4 max energy (instead of 3) |
| Tag Affinity | TECH, SHADOW, EXPLOIT |

Summons daemon processes and compiles constructs. The extra energy enables expensive multi-card turns that deploy persistent board presence.

---

## 4. Co-op Design

### 4.1 Core Principles

- **Shared combat, separate decks.** All players fight the same enemies simultaneously. Each player maintains their own deck, equipment, skill tree, and corruption level.
- **Persistent runs.** Run state serializes to JSON (`user://save.json`). Games can be saved at rest sites and resumed across sessions.
- **Party roles emerge, not enforced.** No hard role assignments. Build choices naturally produce tanks, DPS, supports, and corruption specialists.

### 4.2 Networking

- ENet peer-to-peer via `NetworkManager` autoload.
- Host creates game, others join via IP.
- `GameManager.per_player_characters` maps `peer_id -> character_id` for each connected player.
- Enemy HP scales with player count: `base_hp * (1.0 + 0.5 * (player_count - 1))`.

### 4.3 Vote System

Party decisions that affect everyone trigger a vote:

- Tithe payment (pay HP or lose cards)
- Pact acceptance (trade HP/corruption for power)
- Boss mechanics (sacrifice, orientation, routing)
- Event choices at narrative nodes

**Vote rules:**
- 10-second timer.
- Majority wins.
- Ties broken by boss targeting (highest HP) or random.
- Certain relics/cards grant veto power (once per boss fight).

**UI:** Modal overlay showing options, player votes as they come in, and a countdown timer.

---

## 5. Dungeon Structure

### 5.1 Map Layout

Each act generates a 7-row branching map. Players navigate row by row, choosing which node to visit based on visible connections.

```
Row 0:  [Fight] --- [Fight] --- [Fight]          (2-3 nodes)
Row 1:  [Fight] --- [Event] --- [Shop]           (2-4 nodes)
Row 2:  [Fight] --- [Elite] --- [Altar]          (2-4 nodes)
Row 3:  [Event] --- [Shop] --- [Elite]           (2-4 nodes)
Row 4:  [Rest]                                    (always 1)
Row 5:  [Fight] --- [Elite]                       (1-3 nodes)
Row 6:  [Boss]                                    (always 1)
```

Node connections are generated with spatial coherence -- nodes connect forward to nearby columns in the next row, with branching probability of 45%.

### 5.2 Room Types

| Room Type | Icon | Description |
|---|---|---|
| **Fight** | Swords | Standard combat encounter (1-2 enemies from the act's pool) |
| **Elite** | Skull | Difficult combat against a powerful enemy. Better rewards. |
| **Boss** | Crown | Act-ending boss fight with unique mechanics. |
| **Rest** | Campfire | Heal, upgrade cards, craft gems, access skill tree, save & quit. |
| **Shop** | Coins | Buy cards, equipment, potions. Remove cards for gold. |
| **Event** | Scroll | Narrative encounter with choices (risk/reward). |
| **Forge** | Anvil | Upgrade a card (e.g., Strike -> Strike+). |
| **Altar** | Flame | Remove a card from your deck permanently. |
| **Shrine** | Dark star | Corrupt a specific card for power at a corruption cost. |
| **Jeweler** | Gem | Receive gem rewards. |

### 5.3 Acts

#### Act 1: Corrupted Server Farm

The surface layer of the digital underworld. Glitching server racks, flickering fluorescent corridors, corrupted data streams.

| Role | Enemies |
|---|---|
| Common | Jaw Worm, Louse (Red), Cultist |
| Elite | Hexaghost |
| Boss | Michael |

#### Act 2: Neural Cathedral

Deeper into the network. Gothic digital architecture, stained-glass data windows, angelic constructs patrolling vast halls.

| Role | Enemies |
|---|---|
| Common | Data Leech, Firewall Sentinel, Memory Worm |
| Elite | Gabriel, Fallen Archangel |
| Boss | Raphael |

#### Act 3: The Void Core

The heart of the system. Reality dissolves into raw computation. The final guardians stand between the party and freedom.

| Role | Enemies |
|---|---|
| Common | Quantum Ghost, Seraph Drone, Core Guardian |
| Elite | Uriel, Azrael, Corrupted Throne |
| Boss | Metatron |

### 5.4 Room Experience Flow

```
Enter room -> See 3D scene (KayKit dungeon tiles, character models)
           -> Interact (fight / loot / talk / rest / shop)
           -> Receive rewards
           -> Return to map -> Choose next room
```

---

## 6. Combat System

### 6.1 Mana System (Hybrid Pool + Cooldowns)

**Current implementation:** Flat energy (3/turn, reset each turn).
**Target design:** Mana pool with regeneration.

| Property | Value |
|---|---|
| Base Pool | 10/10 mana |
| Regen per Turn | 3 mana (base, modifiable) |
| Basic Cards | 1-2 mana |
| Powerful Cards | 4-6 mana |
| Cooldown Cards | X-turn cooldown after use |

This creates strategic tension: dump the pool with cheap attacks this turn, or save mana for a powerful play next turn. Equipment, gems, and skills can boost max pool, regen rate, and reduce cooldowns.

> **Migration note:** The existing `energy` / `max_energy` fields on `PlayerState` will be repurposed. The `start_player_turn()` method in `CombatEngine` currently resets energy to `max_energy` each turn -- this changes to additive regen.

### 6.2 Turn Structure

**Start of Player Turn:**
1. Regenerate mana (base 3 + modifiers)
2. Draw cards (base 5 + modifiers - draw penalties)
3. Tick cooldowns -1 on all cooldown cards
4. Tick debuff durations (modifier stack `tick_turn()`)
5. Apply corruption burn damage (2 HP at tier 2, 5 HP at tier 3)
6. Apply sin penalties (draw penalty from Sloth)
7. Blood Tithe check (every 3 turns, party vote)

**Player Phase:**
- Play cards from hand (costs mana), targeting enemies or allies
- Activate soul abilities (costs soul fragments)
- Accept or reject pact offers
- End turn voluntarily (discards remaining hand)

**End of Turn / Enemy Turn:**
- When all living players have ended their turn, enemy phase begins
- Each enemy executes its displayed intent (ATTACK, DEFEND, BUFF, DEBUFF, HACK)
- Enemy picks next intent for display
- Boss absorbs uncollected soul fragments (up to 3/turn)
- Tick enemy debuffs (vulnerable, weak)
- Tick player debuffs (vulnerable, weak)
- Check win/loss conditions

**Combat End:**
- All enemies defeated: victory, rewards screen
- All players truly dead: defeat, lose progress to last rest point

### 6.3 Card Properties

Cards are defined as `CardData` resources with the following fields:

| Field | Type | Description |
|---|---|---|
| `id` | String | Unique identifier (e.g., `"strike"`, `"bash_plus"`) |
| `display_name` | String | Shown on card face |
| `description` | String | Card effect text |
| `energy_cost` | int | Mana cost to play |
| `card_type` | CardType | ATTACK, SKILL, POWER, STATUS, CURSE |
| `target_type` | TargetType | ENEMY, SELF, ALL_ENEMIES, ALL_PLAYERS, NONE |
| `damage` | int | Base damage dealt |
| `block` | int | Base block gained |
| `heal` | int | Base healing applied |
| `draw` | int | Cards drawn on play |
| `hits` | int | Number of damage instances |
| `apply_vulnerable` | int | Turns of Vulnerable applied to target |
| `apply_weak` | int | Turns of Weak applied to target |
| `corruption_gain` | int | Corruption added on play (negative = purge) |
| `exhaust` | bool | Removed from deck for remainder of combat |
| `gain_strength` | int | Permanent +damage for this combat |
| `gain_dexterity` | int | Permanent +block for this combat |
| `upgraded` | bool | Whether this is an upgraded variant |
| `upgrade_id` | String | ID of the upgraded version |
| `tags` | Array[CardTag] | Tags for modifier conditions |
| `gem_sockets` | int | Number of gem slots (0-2) |

### 6.4 Card Types

| Type | Behavior |
|---|---|
| **ATTACK** | Deals damage to enemies. Generates Wrath sin. |
| **SKILL** | Gains block, draws cards, applies utility effects. Block cards generate Sloth sin; heal cards generate Pride sin. |
| **POWER** | Persistent buff for the remainder of combat. |
| **STATUS** | Neutral/negative cards added to deck by enemies or events. |
| **CURSE** | Negative cards gained from corruption, events, or enemy abilities. |

### 6.5 Card Tags

Tags determine which modifiers apply to a card during resolution.

```
MELEE    RANGED    FIRE    ICE    HOLY    SHADOW    TECH    EXPLOIT    CURSE
```

A gem that grants "+3 FIRE damage" only activates when the played card has the `FIRE` tag. A skill tree node that gives "+15% MELEE damage" only applies to `MELEE`-tagged cards. Tags are the connective tissue between cards and the modifier system.

### 6.6 Modifier Stack (PoE-Style Stat Pipeline)

The modifier stack is the central stat resolution system. Every source of stat modification -- equipment, gems, relics, skill tree nodes, corruption tiers, status effects, pact bonuses -- feeds into the same pipeline.

#### Resolution Order

```
OVERRIDE -> FLAT_ADD -> PERCENT_ADD -> PERCENT_MULT
```

1. **OVERRIDE:** Highest value wins. If any OVERRIDE modifier exists, it becomes the base and all other phases are skipped.
2. **FLAT_ADD:** All flat additions sum onto the base value.
3. **PERCENT_ADD:** All percentage additions sum together, then multiply once. `(base + flats) * (1 + sum_of_percent_adds)`.
4. **PERCENT_MULT:** Each multiplier applies independently in sequence. `result * mult1 * mult2 * ...`.

**Example:**

```
Base damage: 6
Modifiers:
  +3 FLAT_ADD (from weapon equipment)
  +2 FLAT_ADD (from relic "Vajra")
  +25% PERCENT_ADD (from corruption tier 2)
  x1.25 PERCENT_MULT (from Cryptomancer passive at corruption >= 50)

Resolution:
  Flat phase:    6 + 3 + 2 = 11
  Percent add:   11 * (1 + 0.25) = 13.75
  Percent mult:  13.75 * 1.25 = 17.1875
  Final:         17 (truncated to int)
```

#### Modifier Properties

Each modifier (`ModifierData` resource) carries:

| Field | Description |
|---|---|
| `stat` | Which stat to modify (DAMAGE, BLOCK, HEALING, MAX_HP, MAX_ENERGY, DRAW_PER_TURN, ENERGY_COST, CORRUPTION_GAIN, CORRUPTION_RESIST) |
| `operation` | FLAT_ADD, PERCENT_ADD, PERCENT_MULT, or OVERRIDE |
| `value` | Numeric value of the modification |
| `lifecycle` | When the modifier is active and when it expires |
| `duration` | Turns remaining (-1 for non-expiring) |
| `required_card_tags` | Only applies if the card has ALL listed tags |
| `required_card_type` | Only applies to a specific card type (-1 = any) |
| `only_vs_vulnerable` | Only applies when target has Vulnerable |
| `only_when_hp_below_pct` | Only applies when player HP is below threshold |
| `source_type` | Origin category: "equipment", "gem", "relic", "skill_tree", "sin", "pact", "corruption" |
| `source_id` | Specific item/node ID for removal tracking |

#### Lifecycles

| Lifecycle | Duration | Source Examples |
|---|---|---|
| `PERMANENT` | Entire run | Skill tree nodes |
| `COMBAT` | Current combat only | Relic bonuses, corruption tier bonuses |
| `TURN` | Ticks down each turn | Debuffs, pact boosts, sin penalties |
| `CARD_PLAY` | Active only during card resolution | Gem effects |
| `CONDITIONAL` | Always present, conditional activation | (Reserved for future) |

#### Modifier Bridge

`ModifierBridge` is the integration layer that populates a player's modifier stack at combat start:

1. Equipment modifiers (from `EquipmentData.modifiers`)
2. Relic modifiers (strength, dexterity, draw, corruption resist)
3. Corruption tier damage multiplier
4. Skill tree modifiers (all `PERMANENT` lifecycle)
5. Start-of-combat block and energy bonuses (applied directly, not as modifiers)

At each turn start, `ModifierBridge.tick_turn()` decrements `TURN` lifecycle modifiers and removes expired ones.

### 6.7 Card Resolution

`CardResolver` handles the actual effect of playing a card:

1. Resolve energy/mana cost (with White Hat discount for HOLY cards)
2. Remove card from hand, place in discard or exhaust pile
3. For ATTACK cards: `StatResolver.resolve_damage(base, player, target, card)` through the full modifier pipeline
4. For SKILL cards with block: `StatResolver.resolve_block(base, player, card)`
5. For healing: `StatResolver.resolve_healing(base, player, card)`
6. Apply status effects (Vulnerable, Weak)
7. Apply strength/dexterity gains
8. Process gem effects (CARD_PLAY lifecycle modifiers activated during resolution)

Post-resolution:
- Soul fragments generated from damage dealt
- Corruption applied (from card data + card corruption overrides at high tiers)
- Sin tracking updated (WRATH from attacks, SLOTH from blocks, PRIDE from heals)
- Pact offer check
- Phase transition check (boss HP thresholds)

---

## 7. Progression Systems

### 7.1 Light Leveling (XP)

| Source | XP |
|---|---|
| Killing an enemy | 10-50 |
| Completing a room | 25 |
| Defeating a boss | 200 |

**Level-up rewards:**
- +5 max HP
- +1 skill point
- Occasionally +1 max mana

Level cap: 10 per run. Leveling is supplementary -- the primary power curve comes from cards, equipment, gems, and the skill tree.

### 7.2 Currencies

| Currency | Source | Spent On |
|---|---|---|
| **Gold** | Combat rewards, chests, events | Shop purchases (cards, equipment, potions), card removal |
| **Souls** | Elite/boss kills, corruption events | Skill tree nodes, powerful upgrades, reviving downed players |
| **Crystals** | Gem drops, disenchanting equipment | Crafting gems, rerolling gem sockets, upgrading gems |
| **Corruption Essence** | Corrupting cards, dark events | Corrupt equipment for power (risky), dark skill tree branch |

> **Current state:** Gold is implemented and tracked on `RunState`. Souls are partially implemented as soul fragments in combat. Crystals and Corruption Essence are planned.

### 7.3 Equipment System

Four equipment slots, each with a role:

| Slot | Primary Stats | Examples |
|---|---|---|
| **HEAD** | +HP, +block, +corruption resist | Iron Helm, Holy Circlet, Tech Visor |
| **CHEST** | +HP, +resist, +block | Leather Vest, Blessed Armor, Shadow Cloak |
| **WEAPON** | +damage, +draw, +strength | Rusty Blade, Flame Gauntlets, Berserker Gauntlet |
| **ACCESSORY** | +mana, +special effects | Corrupt Amulet |

**Equipment data model:** Each `EquipmentData` resource contains an array of `ModifierData` entries. When equipped, these modifiers are stamped with source tracking and loaded into the player's modifier stack via `ModifierBridge`.

**Rarity tiers:**

| Rarity | Sockets | Stat Quality |
|---|---|---|
| Common | 0 | Basic |
| Uncommon | 1 | Better |
| Rare | 2 | Strong |

**Sources:** Treasure rooms, shop, elite/boss rewards, equipment reward screen.

**Existing equipment (10 pieces):** `iron_helm`, `holy_circlet`, `tech_visor`, `leather_vest`, `blessed_armor`, `shadow_cloak`, `rusty_blade`, `flame_gauntlets`, `berserker_gauntlet`, `corrupt_amulet`.

### 7.4 Gem System

Gems socket into equipment (via equipment sockets) or directly into cards (via card `gem_sockets`). They modify card behavior through `CARD_PLAY` lifecycle modifiers that activate only during card resolution.

**Gem data model:** Each `GemData` resource contains `on_play_modifiers` -- an array of `ModifierData` entries with `CARD_PLAY` lifecycle.

| Gem | Effect |
|---|---|
| Ruby of Fury | +fire damage per attack |
| Sapphire of Shielding | Block cards also grant block bonus |
| Emerald of Renewal | +draw on kill |
| Topaz of Wrath | +damage bonus on attack cards |
| Amethyst of Fortitude | +block bonus |
| Crimson Opal | +damage with conditions |
| Diamond of Efficiency | Energy cost reduction |
| Obsidian Shard | Shadow/corruption synergy |

**Card sockets:** Cards can have 0-2 gem sockets. Gem assignments are tracked per card in `RunState.gem_assignments` (card_id -> Array of gem IDs).

**Equipment sockets:** Equipment pieces provide passive gem bonuses (not tied to card play).

**Gem sources:** Jeweler rooms, gem reward screen, crafting at rest sites (costs Crystals).

### 7.5 Skill Tree

Each character spends skill points to unlock nodes on a tree with 3 branches:

| Branch | Focus | Example Nodes |
|---|---|---|
| **Offensive** | +damage, crit, multi-hit | "+10% MELEE damage", "+3 flat damage to FIRE cards" |
| **Defensive** | +block, thorns, regen | "+5 block per turn", "+15% healing" |
| **Utility** | +draw, +mana, card manipulation | "+1 draw per turn", "-1 energy cost for TECH cards" |

**Implementation:** `SkillTreeSystem` loads programmatically generated tree structures. `SkillNodeData` resources define individual nodes with `ModifierData` arrays. All skill tree modifiers use `PERMANENT` lifecycle and are loaded into the stack via `ModifierBridge`.

**Skill point sources:** Level-ups, elite kills, boss kills.

**Node prerequisites:** Must unlock parent node before accessing children.

**Current state:** 6 skill trees are generated programmatically. Character-specific trees are planned for Phase 5.

### 7.6 Relics

Slay the Spire-style persistent passive bonuses that last the entire run.

**Relic data model (`RelicData`):**

| Field | Description |
|---|---|
| `start_combat_strength` | +damage at combat start |
| `start_combat_dexterity` | +block at combat start |
| `start_combat_block` | Flat block at combat start |
| `bonus_draw` | +cards drawn per turn |
| `bonus_max_energy` | +max energy for combat |
| `bonus_max_hp` | Permanent max HP increase (applied on pickup) |
| `heal_on_combat_end` | HP restored after winning combat |
| `corruption_resistance` | Reduces corruption gained |

**Rarity distribution:** Common (60%), Uncommon (30%), Rare (10%). Reward selection uses weighted random from unowned relics.

**Sources:** Elite/boss kills, events, shop.

**Existing relics (10):** Anchor, Bag of Prep, Blood Vial, Burning Blood, Horn Cleat, Lantern, Oddly Smooth Stone, Red Skull, Vajra, War Paint.

### 7.7 Corruption System

Corruption is the game's central risk/reward axis.

#### Corruption Gauge

- Range: 0-100
- Tracked per player (`PlayerState.corruption`)
- Persistent across combats within a run (`RunState.run_corruption`)

#### Corruption Tiers

| Tier | Threshold | Name | Damage Bonus | Burn/Turn | Side Effects |
|---|---|---|---|---|---|
| 0 | 0-24 | Pure | None | 0 | None |
| 1 | 25-49 | Tainted | +10% | 0 | Minor visual glitches |
| 2 | 50-74 | Corrupted | +25% | 2 HP | Cards mutate unpredictably |
| 3 | 75-100 | Demonic | +50% | 5 HP | Major card mutations, massive risk |

#### Corruption Sources

- Playing high-cost or high-damage cards (auto-generated 1 corruption for 2+ energy or 10+ damage cards)
- Explicit `corruption_gain` on card data
- Pact acceptance
- Dark events
- Corruption shrines

#### Corruption Mitigation

- Cards with negative `corruption_gain` (purge cards, White Hat specialty)
- Soul ability "Purify" (10 fragments, removes 20 corruption)
- Corruption resistance from relics/equipment (reduces gain via modifier stack)
- Rest site options

#### Card Corruption (Mutation)

At corruption tier 2+, cards can mutate when played. `CardCorruption` checks `should_corrupt(card_id, corruption_tier)` and applies overrides:
- Increased damage values
- Self-damage on play
- Extra corruption generation
- Cards in `RunState.shrine_corrupted_cards` are permanently corrupted via shrine visits

#### Corruption as Build Strategy

The Cryptomancer is designed to exploit corruption:
- Starts at 15 corruption
- +25% damage passive at corruption >= 50
- Corruption tier damage multiplier stacks with passive
- Shadow-tagged cards synergize with corruption effects

### 7.8 Sin System

Three sins are tracked per player, creating deck-building tension.

| Sin | Triggered By | Threshold | Punishment |
|---|---|---|---|
| **WRATH** | Playing ATTACK cards | 7 | Take 8 self-damage |
| **SLOTH** | Playing SKILL cards with block | 7 | Draw 2 fewer cards next turn |
| **PRIDE** | Playing SKILL cards with heal | 7 | Healing halved for 2 turns (PERCENT_MULT 0.5, TURN lifecycle) |

Sin counters increment with each qualifying card play. When a sin reaches its threshold, the punishment triggers immediately and the counter resets to 0.

**Design intent:** Prevents degenerate all-attack or all-block decks. Forces players to build diverse decks or accept periodic punishment as a cost of specialization.

### 7.9 Death and Revival

#### Death's Door

When HP reaches 0, the player enters Death's Door instead of dying immediately:
- Set to 1 HP
- 3-turn countdown
- Max energy reduced by 1
- Can still play cards and act normally
- If the countdown reaches 0, the player is truly dead

#### True Death

- `is_dead = true`
- Skip all turns, cannot play cards
- Down for the remainder of combat

#### Revival Methods

| Method | Cost | When |
|---|---|---|
| Revival cards/items | Card play | During combat |
| Rest site revive | 1 Soul | Between combats |
| Auto-revive relic | 1 charge/floor | Passive trigger |
| `DeathsDoorSystem.revive()` | -- | Heals 15 HP, restores 3 max energy |

#### Full Party Wipe

All players truly dead = combat loss. Party loses progress back to the last rest point and loses some gold.

### 7.10 Soul System

Soul fragments are a shared combat resource.

#### Fragment Generation

| Damage Dealt | Fragments |
|---|---|
| 1-7 | 1 |
| 8-14 | 2 |
| 15+ | 3 |

Fragments are added to a shared pool (`CombatState.soul_fragments`) whenever any player deals damage.

#### Boss Absorption

At the end of each enemy turn, the boss absorbs up to 3 uncollected fragments. At 5+ absorbed fragments, the boss gains a damage bonus (+2 per 5 absorbed). This creates urgency to spend fragments before they empower the enemy.

#### Soul Abilities

| Ability | Cost | Effect |
|---|---|---|
| **Heal All** | 8 | Heal all players for 15 HP |
| **Energy Surge** | 5 | All players gain +2 energy this turn |
| **Purify** | 10 | Remove 20 corruption from the most corrupted player |
| **Soul Blast** | 12 | Deal 30 damage to all enemies |

### 7.11 Pact System

Pacts are Faustian bargains offered during combat.

**Trigger:** After each card play, if `turn_number > 1` and random check passes (base 20% + 1% per corruption point).

| Pact | Benefit | Cost |
|---|---|---|
| **Dark Power** | +1 max energy this combat | 15 HP, +10 corruption |
| **Blood Offering** | Draw 3 extra cards next turn | 10 HP, teammates take 5 damage, +5 corruption |
| **Hellfire Pact** | +50% damage for 2 turns | 20 HP, +15 corruption |
| **Soul Bargain** | Full heal | +25 corruption, lose 2 random cards |
| **Demon's Gift** | Gain 20 Block | 8 HP, +5 corruption |

In co-op, pact acceptance triggers a party vote (the cost affects others via team damage or shared corruption consequences).

### 7.12 Tithe System

Every 3 turns, the party faces a divine tax.

- **Base cost:** 10 HP, scaling +5 per subsequent tithe
- **Pay:** Split HP cost evenly among living players (cannot kill via tithe, minimum 1 HP remaining)
- **Refuse:** Each player loses a random card from their draw or discard pile permanently

In co-op, whether to pay or refuse is a party vote.

---

## 8. Party Effects and Boss Raid Mechanics

### 8.1 Design Philosophy

Every boss has 2-3 unique party mechanics that force cooperative decisions. These are not "big enemy hits hard" encounters -- they change how the party plays and demand communication.

### 8.2 Gabriel -- "The Herald" (Act 1 Boss)

The introductory boss. Teaches co-op mechanics without overwhelming.

| Mechanic | Description |
|---|---|
| **Divine Trumpet** | Every 3 turns, the player with the lowest block takes massive damage. Forces the party to coordinate blocking. |
| **Blessing of the Worthy** | Gabriel heals the player who dealt the least damage last turn. Prevents one player from AFK/turtling. |

### 8.3 Michael -- "The Judge" (Act 2 Boss)

The mechanical peak. Multiple vote-based mechanics.

| Mechanic | Description |
|---|---|
| **Judgment** | Every 4 turns: VOTE to sacrifice 50% of one player's HP to remove Michael's shield. Without the vote, Michael is invulnerable. |
| **Twin Swords** | Attacks TWO players simultaneously. Party must split defensive resources or accept that someone will take damage. |
| **Holy Fire** | Arena burns with escalating damage. Party votes to spend 2 Souls to extinguish, or endure the heat. |

### 8.4 Azrael -- "The Reaper" (Act 3 Elite)

The punishment fight. Tests the party's willingness to sacrifice.

| Mechanic | Description |
|---|---|
| **Death Mark** | Marks one player. In 3 turns, they go DOWN. Other players can transfer the mark to themselves. Who takes the bullet? |
| **Soul Harvest** | When Azrael kills his own minions, ALL players lose 1 max HP permanently for this floor. Do you kill the minions first, or race the boss? |

### 8.5 Metatron -- "Reality Breaks" (Final Boss)

The ultimate test. Every mechanic subverts the co-op formula.

| Mechanic | Description |
|---|---|
| **Reality Split** | Party is randomly split into pairs. Each pair faces a different challenge. Vote on which pair faces the harder side. |
| **The Cube** | A rotating cube with debuff faces. Party votes on which face to orient toward them -- pick your poison. |
| **Final Convergence** | At 25% HP, all players play cards simultaneously and blind (no coordination). Tests how well the party has internalized each other's builds. |

### 8.6 Boss Phase Transitions

Bosses have phase data defined in their `EnemyData` resources. When HP drops below a threshold, the boss transitions to a new phase:

- New intent pool
- On-enter effects: `strength_buff`, `heal`, `block_buff`, `shuffle_discard`, `dialogue`
- Phase intents cycle independently

Example: Michael at 50% HP gains +5 strength and shuffles all player discard piles back into draw piles.

### 8.7 Party Combo Cards

Cards designed for cross-player synergy:

| Card | Effect |
|---|---|
| Mark Target | Enemy takes +50% damage from ALL sources this turn |
| Mana Link | Transfer mana to another player |
| Shared Shield | Split your block evenly among all players |
| Overclocked Network | ALL players draw +2 next turn, ALL take 5 damage |

---

## 9. Technical Architecture

### 9.1 Project Structure

```
card_game/
  scripts/
    autoload/          # 9 singletons (GameManager, NetworkManager, SFXManager, etc.)
    data/              # 10 resource definitions (CardData, EnemyData, ModifierData, etc.)
    models/            # 4 state classes (CombatState, PlayerState, EnemyState, RunState)
    systems/           # 19 game systems (CombatEngine, ModifierStack, CardResolver, etc.)
    scenes/            # 8 scene controllers (combat, map, menus)
    puppets/           # 4 puppet controllers (2D + 3D player/base)
    enemies/           # 8 boss puppet + effects scripts
    effects/           # 5 VFX scripts (shaders, screen shake, tendrils)
    ui/                # 35 UI scripts
  data/
    cards/             # 55 card resources (.tres)
    enemies/           # 18 enemy resources (.tres)
    relics/            # 10 relic resources (.tres)
    equipment/         # 10 equipment resources (.tres)
    gems/              # 8 gem resources (.tres)
    characters/        # 5 character resources (.tres)
  scenes/              # Scene trees (.tscn)
  assets/              # Textures, models, audio
  shaders/             # Visual shaders
  themes/              # UI themes
```

### 9.2 Autoload Singletons

| Singleton | Responsibility |
|---|---|
| `GameManager` | Card database, run state, character selection, save/load |
| `NetworkManager` | ENet peer connection (host/join), RPC dispatch |
| `SFXManager` | Sound effects (card play, hit, block, heal, ambient) |
| `TransitionManager` | Scene transition animations |
| `EventBus` | Global signal bus for decoupled communication |
| `BalanceTracker` | Runtime balance data collection |
| `BalanceDashboard` | F12 debug overlay (pipeline trace, modifier tweaking, Monte Carlo sim) |
| `LoreManager` | Lore entry unlocking and codex state |
| `PauseManager` | Pause/unpause handling |

### 9.3 Core Systems (Existing, Working)

| System | Class | Description |
|---|---|---|
| Combat Engine | `CombatEngine` | Full state machine: WAITING -> PLAYER_TURN -> RESOLVING -> ENEMY_TURN -> COMBAT_OVER |
| Modifier Stack | `ModifierStack` | PoE-style resolution pipeline with conditional filtering |
| Card Resolver | `CardResolver` | Damage/block/heal resolution through the modifier pipeline |
| Stat Resolver | `StatResolver` | `resolve_damage()`, `resolve_block()`, `resolve_healing()` with full context |
| Modifier Bridge | `ModifierBridge` | Loads modifiers from equipment/relics/skills at combat start |
| Deck Manager | `DeckManager` | Draw/discard/shuffle/exhaust operations |
| Equipment System | `EquipmentSystem` | Equipment loading, lookup, slot management |
| Gem System | `GemSystem` | Gem loading, socket assignment, CARD_PLAY modifier injection |
| Relic System | `RelicSystem` | Relic database, weighted random rewards |
| Skill Tree System | `SkillTreeSystem` | Tree generation, node unlocking, modifier extraction |
| Corruption System | `CorruptionSystem` | Tier calculation, burn damage, damage multipliers |
| Card Corruption | `CardCorruption` | Card mutation at high corruption tiers |
| Sin System | `SinSystem` | Sin tracking, threshold punishment |
| Death's Door | `DeathsDoorSystem` | Death prevention, countdown, revival |
| Soul System | `SoulSystem` | Fragment generation, boss absorption, soul abilities |
| Pact System | `PactSystem` | Pact generation, benefit/cost application |
| Tithe System | `TitheSystem` | Periodic HP tax, refusal penalties |
| Enemy AI | `EnemyAI` | Intent selection from enemy data pools |
| Stat Resolver Trace | `StatResolverTrace` | Debug tracing for modifier pipeline (balance dashboard) |

### 9.4 Data Models

| Model | Class | Description |
|---|---|---|
| `CardData` | Resource | Card definition with stats, tags, sockets |
| `EnemyData` | Resource | Enemy definition with HP, intents, phases |
| `RelicData` | Resource | Relic definition with combat bonuses |
| `EquipmentData` | Resource | Equipment with slot, rarity, modifier arrays |
| `GemData` | Resource | Gem with on-play modifier arrays |
| `ModifierData` | Resource | Individual stat modifier with conditions |
| `CharacterData` | Resource | Character with HP, energy, deck, passives |
| `SkillTreeData` | Resource | Skill tree structure |
| `SkillNodeData` | Resource | Individual skill node with modifiers |

### 9.5 State Models

| Model | Class | Description |
|---|---|---|
| `CombatState` | RefCounted | Current combat: players dict, enemies array, turn number, phase, soul fragments |
| `PlayerState` | RefCounted | Per-player: HP, energy, deck piles, status effects, corruption, sins, modifier stack |
| `EnemyState` | RefCounted | Per-enemy: HP, block, intent, strength, phase index |
| `RunState` | RefCounted | Persistent run: deck, equipment, gems, skills, gold, map, corruption, stats |

### 9.6 Persistence

`RunState` serializes to `user://save.json` as a flat JSON dictionary. All arrays, nested dictionaries, and map data are manually serialized/deserialized. Save is triggered at rest sites and between combats.

### 9.7 New Systems Needed

| System | Type | Description |
|---|---|---|
| `DungeonManager` | Autoload | Floor/room state machine, procedural room generation, 3D scene loading |
| `PartyManager` | Autoload | Multi-player state wrapper, shared effects, party-wide modifiers |
| `CurrencyManager` | Autoload | Gold, souls, crystals, essence tracking with event signals |
| `VoteSystem` | System | Timed votes, majority resolution, veto handling |
| `LevelSystem` | System | XP tracking, level thresholds, level-up reward dispatch |
| `CooldownTracker` | System | Per-card cooldown counters, tick-down logic |
| `ManaSystem` | System | Pool + regen replacing flat energy reset |
| `BossEncounter` | System | Raid mechanics orchestration, party-wide effects |

### 9.8 New Scenes Needed

| Scene | Description |
|---|---|
| `DungeonFloor` | Room grid/map visualization for current floor |
| `RoomScene` | 3D room with KayKit dungeon tiles, character placement, interaction triggers |
| `RestSite` | Full rest UI: heal, upgrade cards, craft gems, skill tree, equipment management, save & quit |
| `VoteOverlay` | Modal vote UI with options, player indicators, countdown timer |
| `PartyStatusHUD` | All player HP/mana/status visible during combat |

### 9.9 Key Architecture Principle

**Most existing systems do not need changes.** New systems layer on top. The modifier stack, card resolver, equipment, gems, relics, and skill tree all function correctly through the stat pipeline. The migration path is:

- `DungeonManager` replaces the branching map navigation
- `PartyManager` wraps `PlayerState` instances for shared effects
- `ManaSystem` replaces the flat energy reset in `CombatEngine.start_player_turn()`
- `VoteSystem` hooks into existing signals (tithe, pact, boss events)

---

## 10. Art and Audio

### 10.1 Character Models

**Source:** KayKit Adventurers Pack (low-poly stylized).

| KayKit Model | Game Character |
|---|---|
| Rogue | Netrunner (Zephyr) |
| Knight | Sysadmin (Bastion) |
| Mage | Cryptomancer (Cipher) |
| Paladin | White Hat (Sentinel) |
| Ranger | Technomancer (FLUX) |

All characters share the `Rig_Medium` skeleton, making animations interchangeable.

**Animations available:** Idle_A, Idle_B, Hit_A, Hit_B, Death_A, Death_B, Interact, Use_Item, Throw, Walking, Running, Jump.

**Weapons:** Attached to `handslot.r` bone. Options include sword, axe, dagger, staff, wand, shields, bow.

### 10.2 Enemy Models

**Source:** KayKit Skeletons Pack.

| KayKit Model | Game Enemies |
|---|---|
| Skeleton Warrior | Jaw Worm, Firewall Sentinel |
| Skeleton Mage | Cultist, Memory Worm |
| Skeleton Rogue | Louse, Data Leech |
| Skeleton Minion | Seraph Drone, Core Guardian |

Boss models use custom assemblies from the same packs or ComfyUI-generated sprites for unique appearances.

### 10.3 Environments

| Source | Usage |
|---|---|
| KayKit Dungeon Pack | 211 tile assets: walls, floors, arches, banners, props. Room construction. |
| KayKit RPG Tools Pack | 49 prop assets: anvils, books, scrolls, tools. Rest sites and shops. |
| ComfyUI pipeline | AI-generated painted backgrounds for arena combat scenes. |

**Art pipeline:** ComfyUI + SDXL + LoRA on local GPU. KomikoAI for automatic layer splitting. Output feeds into arena background scenes.

### 10.4 UI Art

- 2D card interface (fully functional) with card visual component
- PoE-style resource orbs for HP and mana (`resource_orb.gd`)
- Status effect icons (`status_icon.gd`)
- Floating damage numbers (`damage_number.gd`)
- Combat log (`combat_log.gd`)
- Card glow shaders (existing in `shaders/`)
- Corruption meter with tier indicators
- Sin display
- Soul fragment counter

### 10.5 Audio

**Existing:**
- SFXManager with sound effects for: card play, card draw, hit impact, block, heal, death, level up
- Ambient hum during combat
- Multiple sound variants per action (sound variety system)

**Planned:**
- Music system with dynamic layering
- Per-act dungeon ambience
- Boss-specific battle themes
- UI feedback sounds (menu navigation, reward selection)

---

## 11. Development Roadmap

### Phase 1: Core Refactor (Current Priority)

Replace the flat energy system with the mana pool + regen model. This is the most impactful single change to combat feel.

| Task | Description | Touches |
|---|---|---|
| Mana pool + regen | Replace `energy`/`max_energy` with 10-pool, 3/turn regen | `PlayerState`, `CombatEngine.start_player_turn()` |
| Cooldown tracking | Add cooldown counter per card, tick-down each turn | `CardData` (new field), `CombatEngine` |
| RPC sync | Wire up multiplayer RPC for combat state changes | `NetworkManager`, `CombatEngine` |
| XP/leveling | Add XP and level fields to `PlayerState`, grant XP on kill | `PlayerState`, `RunState`, `CombatEngine` |

### Phase 2: Dungeon System

Replace the branching map with room-by-room dungeon exploration.

| Task | Description |
|---|---|
| DungeonManager autoload | Floor/room state machine, procedural generation |
| Room scenes | 3D rooms using KayKit dungeon tiles |
| Room navigation | Enter room -> interact -> return to floor map |
| Rest site overhaul | Full crafting, upgrade, skill tree, equipment management UI |
| Save system update | Persist dungeon progress, room completion state |

### Phase 3: Party Systems

Build the co-op infrastructure for shared effects and decisions.

| Task | Description |
|---|---|
| PartyManager autoload | Multi-player state wrapper, party-wide modifiers |
| VoteSystem | Timed votes with majority resolution and UI overlay |
| Party-targeting cards | Auras, mana transfer, shared shields |
| Down/revive mechanics | Full party death handling, revival during combat |
| Party status HUD | All-player HP/mana/status display |

### Phase 4: Boss Raid Mechanics

Design and implement the signature boss encounters.

| Task | Description |
|---|---|
| Gabriel mechanics | Divine Trumpet, Blessing of the Worthy |
| Michael mechanics | Judgment vote, Twin Swords, Holy Fire |
| Azrael mechanics | Death Mark, Soul Harvest |
| Metatron mechanics | Reality Split, The Cube, Final Convergence |
| Boss scripting framework | Reusable system for boss-specific party effects |

### Phase 5: Polish and Content

Expand content breadth and quality.

| Task | Description |
|---|---|
| Currency system | Full implementation of Souls, Crystals, Corruption Essence |
| Character-specific skill trees | Unique trees per character replacing generic ones |
| Content expansion | More cards (target: 150+), equipment (30+), gems (20+), relics (50+) |
| Event system | Narrative events with meaningful branching choices |
| Music and audio | Boss themes, dungeon ambience, dynamic music layering |
| Tutorial | New player onboarding flow |
| Balance pass | Monte Carlo simulation (via balance dashboard), playtest-driven tuning |

---

## Appendix: File Inventory

### A.1 Scripts by Category

**Autoload Singletons (9):**
`game_manager.gd`, `network_manager.gd`, `sfx_manager.gd`, `transition_manager.gd`, `event_bus.gd`, `balance_tracker.gd`, `balance_dashboard.gd`, `lore_manager.gd`, `pause_manager.gd`

**Data Models (10):**
`card_data.gd`, `enemy_data.gd`, `relic_data.gd`, `equipment_data.gd`, `gem_data.gd`, `modifier_data.gd`, `character_data.gd`, `skill_tree_data.gd`, `skill_node_data.gd`, `enums.gd`

**State Models (4):**
`combat_state.gd`, `player_state.gd`, `enemy_state.gd`, `run_state.gd`

**Game Systems (19):**
`combat_engine.gd`, `modifier_stack.gd`, `card_resolver.gd`, `stat_resolver.gd`, `stat_resolver_trace.gd`, `modifier_bridge.gd`, `deck_manager.gd`, `equipment_system.gd`, `gem_system.gd`, `relic_system.gd`, `skill_tree_system.gd`, `corruption_system.gd`, `card_corruption.gd`, `sin_system.gd`, `deaths_door_system.gd`, `soul_system.gd`, `pact_system.gd`, `tithe_system.gd`, `enemy_ai.gd`

**Scene Controllers (8):**
`combat_scene.gd`, `combat_3d_stage.gd`, `main_menu.gd`, `map_screen.gd`, `settings_screen.gd`, `character_select.gd`, `intro_screen.gd`, `run_summary_screen.gd`

**Puppet Controllers (4):**
`puppet_base.gd`, `player_puppet.gd`, `puppet_base_3d.gd`, `player_puppet_3d.gd`

**Boss Scripts (8):**
`metatron_puppet.gd`, `metatron_effects.gd`, `michael_puppet.gd`, `michael_effects.gd`, `azrael_puppet.gd`, `azrael_effects.gd`, `tommy_puppet.gd`, `tommy_effects.gd`

**VFX Scripts (5):**
`summoning_circle.gd`, `shader_controller.gd`, `afterimage.gd`, `screen_shake.gd`, `dark_tendrils.gd`

**UI Scripts (35):**
`card_visual.gd`, `hand_display.gd`, `enemy_display.gd`, `hp_bar.gd`, `combat_log.gd`, `corruption_meter.gd`, `deaths_door_overlay.gd`, `deck_viewer.gd`, `event_screen.gd`, `reward_screen.gd`, `relic_display.gd`, `relic_reward_screen.gd`, `shop_screen.gd`, `status_icon.gd`, `turn_banner.gd`, `damage_number.gd`, `player_board.gd`, `sin_display.gd`, `soul_display.gd`, `pact_screen.gd`, `tithe_screen.gd`, `hack_challenge.gd`, `resource_orb.gd`, `equipment_display.gd`, `equipment_screen.gd`, `equipment_reward_screen.gd`, `gem_socket_screen.gd`, `gem_reward_screen.gd`, `skill_tree_screen.gd`, `corruption_shrine_screen.gd`, `epilogue_screen.gd`, `lore_codex_screen.gd`, `arena_background.gd`, `arena_config.gd`, `ui_constants.gd`

### A.2 Data Assets

| Category | Count | Path |
|---|---|---|
| Cards | 55 | `data/cards/*.tres` |
| Enemies | 18 | `data/enemies/*.tres` |
| Relics | 10 | `data/relics/*.tres` |
| Equipment | 10 | `data/equipment/*.tres` |
| Gems | 8 | `data/gems/*.tres` |
| Characters | 5 | `data/characters/*.tres` |

### A.3 Enum Reference

```gdscript
enum CardType    { ATTACK, SKILL, POWER, STATUS, CURSE }
enum SinType     { WRATH, SLOTH, PRIDE }
enum TargetType  { ENEMY, SELF, ALL_ENEMIES, ALL_PLAYERS, NONE }
enum EnemyIntent { ATTACK, DEFEND, BUFF, DEBUFF, UNKNOWN, HACK }
enum CombatPhase { WAITING_FOR_PLAYERS, PLAYER_TURN, RESOLVING, ENEMY_TURN, COMBAT_OVER }
enum Stat        { DAMAGE, BLOCK, HEALING, MAX_HP, MAX_ENERGY, DRAW_PER_TURN,
                   ENERGY_COST, CORRUPTION_GAIN, CORRUPTION_RESIST }
enum ModOp       { FLAT_ADD, PERCENT_ADD, PERCENT_MULT, OVERRIDE }
enum ModLifecycle{ PERMANENT, COMBAT, TURN, CARD_PLAY, CONDITIONAL }
enum CardTag     { MELEE, RANGED, FIRE, ICE, HOLY, SHADOW, TECH, EXPLOIT, CURSE }
enum EquipSlot   { HEAD, CHEST, WEAPON, ACCESSORY }
enum CharacterClass { NETRUNNER, SYSADMIN, CRYPTOMANCER, WHITE_HAT, TECHNOMANCER }
```

---

*This document is the single source of truth for deus.exe. It reflects both the current implementation and the target design. Systems marked as "existing" have working code. Systems marked as "planned" or "needed" are part of the development roadmap.*
