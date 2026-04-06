# Nethercode: Complete System Design

**Version:** 2.0
**Date:** 2026-04-05
**Status:** Implementation Blueprint
**Scope:** All progression and combat systems, fully interconnected

---

## Table of Contents

1. [Design Philosophy](#1-design-philosophy)
2. [Build Archetypes](#2-build-archetypes)
3. [Card System](#3-card-system)
4. [Gem System](#4-gem-system)
5. [Relic System](#5-relic-system)
6. [Equipment System](#6-equipment-system)
7. [Skill Tree System](#7-skill-tree-system)
8. [Corruption Integration](#8-corruption-integration)
9. [Power Budget](#9-power-budget)
10. [Co-op Synergies](#10-co-op-synergies)

---

## 1. Design Philosophy

### The Five Layers

Every player's combat identity is the product of five overlapping systems. Each layer answers a different question and occupies a different decision space:

| Layer | Question | Decision Timing | Permanence | Power Share |
|---|---|---|---|---|
| **Cards** | *What do I do?* | Each turn (tactical) | Mutable (add/remove/upgrade) | 35% |
| **Gems** | *How does it behave?* | Between combats (strategic) | Mutable (socket/unsocket) | 15% |
| **Equipment** | *Who am I?* | Between combats (build identity) | Mutable (swap slots) | 15% |
| **Relics** | *What happened to me?* | On acquisition (run-shaping) | Permanent per run | 15% |
| **Skill Tree** | *Where am I going?* | On level-up (commitment) | Permanent per run | 20% |

### The Corruption Contract

Corruption is not a meter to manage -- it is the currency of the game's central tension. Every system touches corruption. The question is never "should I avoid corruption?" but "how much corruption can I afford, and what do I get for it?"

- **Pure (0-24):** Safe. Full control. No bonuses. The cost of purity is mediocrity.
- **Tainted (25-49):** First taste of power. +10% damage. No drawbacks yet. The comfortable zone.
- **Corrupted (50-74):** Real power. +25% damage. But 2 HP/turn burn, and some cards mutate.
- **Demonic (75+):** Glass cannon territory. +50% damage. 5 HP/turn burn. Cards fully corrupted. One mistake kills.

The design principle: **corruption is always the player's choice, never forced.** Every corruption gain has an opt-out path. But opting out means leaving power on the table.

### The Sin Guardrails

The sin system (Wrath/Sloth/Pride) exists to prevent degenerate strategies:
- **7+ attacks in a row = Wrath:** 8 self-damage. Prevents all-attack decks from ignoring defense.
- **7+ blocks in a row = Sloth:** -2 draw next turn. Prevents stall-forever strategies.
- **7+ heals in a row = Pride:** Healing halved 2 turns. Prevents outheal-everything strategies.

Sin punishes monotony. The optimal play is always a balanced hand, which creates natural deck-building tension.

### System Interconnection Map

```
                    CORRUPTION
                   /    |     \
                  /     |      \
            CARDS -- GEMS -- EQUIPMENT
              |       |         |
              +-- RELICS --+    |
              |       |    |    |
              +-- SKILL TREE --+
```

Every arrow is bidirectional. Cards produce corruption; gems modify how much. Equipment can resist or amplify it. Relics change the rules at each tier. Skill tree nodes alter thresholds and tradeoffs. The player who understands these connections builds the strongest runs.

---

## 2. Build Archetypes

Nine distinct build paths. Each is viable on any character but naturally aligns with 1-2 characters. Each archetype is supported by cards, gems, equipment, relics, AND skill tree nodes.

### Archetype Summary Table

| # | Archetype | Fantasy | Primary Tags | Best Characters | Corruption Stance |
|---|---|---|---|---|---|
| 1 | **Glass Cannon** | Maximum burst, minimum HP | SHADOW, EXPLOIT | Cryptomancer, Netrunner | Embrace (60-80+) |
| 2 | **Iron Wall** | Unkillable fortress | MELEE, TECH | Sysadmin | Avoid (0-25) |
| 3 | **Card Engine** | Draw entire deck, combo off | TECH, EXPLOIT | Netrunner, Technomancer | Moderate (25-50) |
| 4 | **Corruption Lord** | Weaponize the corruption itself | SHADOW, CURSE | Cryptomancer | Maximize (75+) |
| 5 | **Holy Purifier** | Cleanse corruption, sustain, support | HOLY | White Hat | Purge (keep at 0) |
| 6 | **Daemon Swarm** | Flood board with summoned tokens | TECH, SHADOW | Technomancer | Moderate (25-50) |
| 7 | **Debuff Controller** | Vulnerable + Weak + bleed out | EXPLOIT, RANGED | Netrunner, White Hat | Flexible |
| 8 | **Berserker** | Low HP = high damage, Death's Door gaming | MELEE, FIRE | Sysadmin, Cryptomancer | High (50-75) |
| 9 | **Pirate King** | Strip, steal, plunder, cash in Contraband | PIRACY, SHADOW | Scourge | Embrace (50-75) |
| 9 | **Pirate King** | Steal everything, drown in Contraband | PIRACY, SHADOW | Scourge | Embrace (50-75) |

### Detailed Archetype Breakdowns

#### 2.1 Glass Cannon

**Fantasy:** Hit so hard that nothing survives long enough to hit back. Trade survivability for overwhelming burst damage. Live fast, die never (because they die first).

**System support:**
- **Cards:** High-damage attacks with self-damage or corruption costs. Multi-hit cards that scale with strength.
- **Gems:** Amplify gems that multiply damage on low-HP cards. Sacrifice gems that trade block for damage.
- **Equipment:** Weapons with +% damage but -HP. Accessories with "below 50% HP" triggers.
- **Relics:** Relics that convert defense into offense. "First attack each combat deals double."
- **Skill Tree:** Cryptomancer's Corruption Power branch. Netrunner's Speed branch.
- **Corruption:** High corruption = high damage multiplier. Glass Cannon lives at Corrupted or Demonic tier.

#### 2.2 Iron Wall

**Fantasy:** The team's anchor. Absorbs damage for the whole party. Wins through attrition, not burst. The last one standing.

**System support:**
- **Cards:** High-block skills, share-block co-op cards, body-slam style block-to-damage conversion.
- **Gems:** Gems that make block carry over between turns. Gems that convert excess block to damage.
- **Equipment:** Chest pieces with massive block bonuses. Weapons that scale with block.
- **Relics:** "Block doesn't reset at turn start" (partial). "Gain 3 block whenever an ally takes damage."
- **Skill Tree:** Sysadmin's Shield Wall branch. Keystone: Unbreakable (+50% block, -25% damage).
- **Corruption:** Stays low corruption. Equipment and relics that reward purity.

#### 2.3 Card Engine

**Fantasy:** Draw the entire deck every combat. Every card is a combo piece. Wins by having the perfect answer to every situation.

**System support:**
- **Cards:** 0-cost cantrips, draw-2 skills, cards that draw when conditions are met.
- **Gems:** Trigger gems that draw on kill or on block threshold. Chain gems that reduce cost when played in sequence.
- **Equipment:** Head slot items with +draw. Accessories that discount cards played after the 5th card per turn.
- **Relics:** "Whenever you play 3+ cards in a turn, draw 1." "Your 6th card each turn costs 0."
- **Skill Tree:** Netrunner's Exploit branch. Technomancer's Efficiency branch.
- **Corruption:** Moderate corruption from playing many cards (each card can generate 1 corruption).

#### 2.4 Corruption Lord

**Fantasy:** Become the thing the Angels fear. Turn corruption into a weapon. The deeper you fall, the stronger you get. You are the final boss.

**System support:**
- **Cards:** Cards that gain power based on corruption level. Cards that add corruption to enemies (thematic). Cards that convert corruption into damage.
- **Gems:** Corruption gems that amplify effects at high tiers. Gems that reduce corruption burn.
- **Equipment:** "Corrupted" equipment that gives massive bonuses with corruption upkeep.
- **Relics:** "At Demonic tier, your attacks ignore block." "Corruption burn damages enemies too."
- **Skill Tree:** Cryptomancer's Corruption Mastery branch. Keystone: Dark Transcendence (Demonic tier burn reduced to 2).
- **Corruption:** Lives at 75+. The build IS corruption.

#### 2.5 Holy Purifier

**Fantasy:** The party's salvation. Cleanses corruption, heals wounds, removes debuffs. In co-op, the Purifier is the reason the Corruption Lord doesn't kill themselves.

**System support:**
- **Cards:** Healing, corruption removal, party-wide buffs, Holy-tagged attacks that purify.
- **Gems:** Purity gems that reduce corruption on card play. Restoration gems that boost healing.
- **Equipment:** Holy vestments that amplify healing. Accessories that share corruption resistance.
- **Relics:** "Whenever you remove corruption, gain 2 block." "Party heals are 50% more effective."
- **Skill Tree:** White Hat's Purification branch. Keystone: Divine Mandate (Holy cards remove 3 corruption from all allies).
- **Corruption:** Stays at Pure (0-24). Gets unique bonuses for staying pure.

#### 2.6 Daemon Swarm

**Fantasy:** Why play cards when your daemons can play them for you? Summon constructs that attack, block, and combo automatically.

**System support:**
- **Cards:** Daemon summon cards that create token cards. Cards that buff all daemons. Cards that sacrifice daemons for burst.
- **Gems:** Replication gems that duplicate daemon effects. Persistence gems that prevent daemon exhaust.
- **Equipment:** Tech equipment that generates free daemon fragments. Weapons that scale with daemons played.
- **Relics:** "Daemons deal +3 damage." "Start combat with a Daemon Fragment in hand."
- **Skill Tree:** Technomancer's Construct branch. Keystone: Hive Mind (Daemon Fragments cost 0 and draw 1).
- **Corruption:** Moderate. Daemon cards generate some corruption but the build is not corruption-dependent.

#### 2.7 Debuff Controller

**Fantasy:** Death by a thousand cuts. Apply Vulnerable, Weak, and mark targets for the team. In co-op, the Controller sets up kills for the Glass Cannon.

**System support:**
- **Cards:** Multi-target debuff cards, mark target for team, cards that deal bonus damage to debuffed enemies.
- **Gems:** Cascade gems that spread debuffs. Duration gems that extend Vulnerable/Weak by 1 turn.
- **Equipment:** Accessories that auto-apply Weak on the first attack each turn. Weapons with "vs. Vulnerable" bonuses.
- **Relics:** "Vulnerable lasts 1 extra turn." "When you apply Weak, also apply 1 Vulnerable."
- **Skill Tree:** Netrunner's Exploit branch. White Hat's Holy Strike branch.
- **Corruption:** Flexible. Debuff cards tend to be low-corruption.

#### 2.8 Berserker

**Fantasy:** Pain is power. The lower your HP, the harder you hit. Death's Door is not a last resort -- it is your optimal state.

**System support:**
- **Cards:** Cards that deal damage based on missing HP. Cards that intentionally self-damage for bonuses.
- **Gems:** Desperation gems that amplify below 50% HP. Fury gems that add damage per hit taken.
- **Equipment:** Berserker equipment with "below X% HP" conditional bonuses.
- **Relics:** "While on Death's Door, deal double damage." "Self-damage triggers your block effects."
- **Skill Tree:** Sysadmin's Retaliation branch. Cryptomancer's Glass Cannon branch.
- **Corruption:** High. Corruption burn helps get your HP low, which is actually a benefit.

#### 2.9 Pirate King

**Fantasy:** Strip everything from your enemies. Steal their block, hijack their buffs, flood your hand with Contraband. The more corrupt you are, the more you take.

**System support:**
- **Cards:** PIRACY cards that steal Block from enemies. Cards that generate Contraband tokens. Cards that cash in Contraband for burst damage or defense.
- **Gems:** Amplify gems on Contraband-generating cards. Trigger gems that proc on Block-steal.
- **Equipment:** Pirate weapons with PIRACY tag bonuses. Accessories that buff Contraband.
- **Relics:** "Contraband cards deal +3 damage." "Whenever you steal Block, steal 50% more."
- **Skill Tree:** Scourge's Plunder branch (Contraband scaling), Sabotage branch (defense stripping), Corsair branch (corruption-as-defense).
- **Corruption:** Embrace (50-75). Corruption fuels piracy — more reckless = more powerful theft.

**Key distinction from Corruption Lord:** The Corruption Lord hoards power for themselves. The Pirate King takes power from enemies and redistributes it. Cipher is selfish; Scourge is an enabler.

---

## 3. Card System

### 3.1 Design Principles

1. **Every card must create a decision.** If a card is always played when drawn, it is too simple. If a card is never played, it is too weak.
2. **Rarity = complexity, not just power.** Commons are efficient and straightforward. Legendaries change the rules.
3. **Tags are build-defining.** A card's tags determine which equipment, gems, and skill tree nodes amplify it.
4. **Gem sockets scale with rarity.** Commons: 0 sockets. Uncommons: 0-1 socket. Rares: 1-2 sockets. Legendaries: 2 sockets.

### 3.2 Rarity Power Guidelines

| Rarity | Energy Efficiency | Sockets | Complexity | Examples |
|---|---|---|---|---|
| **Common** | ~5 damage/energy or ~5 block/energy | 0 | Single effect | Strike (6 dmg), Defend (5 block) |
| **Uncommon** | ~6-7 damage/energy or ~6-7 block/energy | 0-1 | 1-2 effects | Iron Wave (5 dmg + 5 block), Bash (8 dmg + 2 Vuln) |
| **Rare** | ~8-10 damage/energy or ~8-10 block/energy | 1-2 | 2-3 effects, conditional | Heavy Blade (14 dmg, 3x Str scaling), Kernel Panic (12 dmg + draw 2) |
| **Legendary** | Rule-breaking | 2 | Build-defining | God Compiler (play all Daemon cards from discard) |

### 3.3 Starter Decks (10 cards each, existing)

| Character | Deck |
|---|---|
| **Netrunner** | Strike x3, Defend x2, Twin Strike, Pommel Strike, Net Spike, Packet Storm, Backdoor |
| **Sysadmin** | Strike x2, Defend x3, Iron Wave, Data Shield, Firewall Protocol, Hardened Kernel, Shrug It Off |
| **Cryptomancer** | Strike x3, Defend x2, Dark Compile, Void Channel, Malware Inject, Null Pointer |
| **White Hat** | Strike x3, Defend x3, Bash, Purge Routine, Sanctify, Bandage |
| **Technomancer** | Strike x2, Defend x2, Daemon Compile, Flux Shift, Code Summon, Reality Patch |
| **Scourge** | Strike x2, Defend x2, Cutlass.exe, Boarding Hook, Ransack, Smoke Screen, Dead Man's Code, Plunder |

### 3.4 Complete Card Catalog

> **NOTE:** The full 152-card catalog has been moved to **CARD_CATALOG.md**. The tables below are the original 120-card reference. See CARD_CATALOG.md for the expanded pool with 6 characters.

Cards are organized by ownership (shared vs. character-exclusive), then by archetype affinity.

---

#### SHARED CARDS (80 cards, available to all characters)

##### Shared -- Basic / Starter (8 cards)

| ID | Name | Cost | Type | Tags | Effect | Rarity | Sockets |
|---|---|---|---|---|---|---|---|
| `strike` | Strike | 1 | ATTACK | MELEE | Deal 6 damage | COMMON | 0 |
| `strike_plus` | Strike+ | 1 | ATTACK | MELEE | Deal 9 damage | COMMON | 0 |
| `defend` | Defend | 1 | SKILL | -- | Gain 5 Block | COMMON | 0 |
| `defend_plus` | Defend+ | 1 | SKILL | -- | Gain 8 Block | COMMON | 0 |
| `bash` | Bash | 2 | ATTACK | MELEE | Deal 8 damage. Apply 2 Vulnerable. | COMMON | 0 |
| `bash_plus` | Bash+ | 2 | ATTACK | MELEE | Deal 10 damage. Apply 3 Vulnerable. | COMMON | 0 |
| `bandage` | Bandage | 1 | SKILL | -- | Heal 5 HP | COMMON | 0 |
| `shrug_it_off` | Shrug It Off | 1 | SKILL | -- | Gain 8 Block. Draw 1. | COMMON | 0 |

##### Shared -- Offense Commons (10 cards)

| ID | Name | Cost | Type | Tags | Effect | Rarity | Sockets |
|---|---|---|---|---|---|---|---|
| `cleave` | Cleave | 1 | ATTACK | MELEE | Deal 8 damage to ALL enemies | COMMON | 0 |
| `twin_strike` | Twin Strike | 1 | ATTACK | MELEE | Deal 5 damage x2 hits | COMMON | 0 |
| `twin_strike_plus` | Twin Strike+ | 1 | ATTACK | MELEE | Deal 7 damage x2 hits | COMMON | 0 |
| `pommel_strike` | Pommel Strike | 1 | ATTACK | MELEE | Deal 9 damage. Draw 1. | COMMON | 0 |
| `pommel_strike_plus` | Pommel Strike+ | 1 | ATTACK | MELEE | Deal 10 damage. Draw 2. | COMMON | 0 |
| `heavy_strike` | Heavy Strike | 2 | ATTACK | MELEE | Deal 14 damage | COMMON | 1 |
| `iron_wave` | Iron Wave | 1 | ATTACK | MELEE, TECH | Deal 5 damage. Gain 5 Block. | COMMON | 0 |
| `iron_wave_plus` | Iron Wave+ | 1 | ATTACK | MELEE, TECH | Deal 7 damage. Gain 7 Block. | COMMON | 0 |
| `flaming_sword` | Flaming Sword | 2 | ATTACK | MELEE, FIRE | Deal 12 damage. +4 Corruption. | COMMON | 0 |
| `body_slam` | Body Slam | 1 | ATTACK | MELEE | Deal damage equal to current Block | UNCOMMON | 1 |

##### Shared -- Defense Commons (8 cards)

| ID | Name | Cost | Type | Tags | Effect | Rarity | Sockets |
|---|---|---|---|---|---|---|---|
| `data_shield` | Data Shield | 1 | SKILL | TECH | Gain 8 Block | COMMON | 0 |
| `adaptive_shield` | Adaptive Shield | 2 | SKILL | TECH | Gain 12 Block. +2 Corruption. | COMMON | 0 |
| `digital_fortress` | Digital Fortress | 2 | SKILL | TECH | Gain 14 Block | UNCOMMON | 1 |
| `phantom_firewall` | Phantom Firewall | 2 | SKILL | TECH | Gain 10 Block. Draw 1. | UNCOMMON | 1 |
| `fortify` | Fortify | 1 | SKILL | MELEE | Gain 5 Block. Gain 1 Dexterity. | UNCOMMON | 0 |
| `shield_bash` | Shield Bash | 2 | ATTACK | MELEE | Deal 6 damage. Gain 10 Block. | UNCOMMON | 1 |
| `system_patch` | System Patch | 1 | SKILL | TECH | Gain 6 Block. Remove 3 Corruption. | UNCOMMON | 0 |
| `emergency_reboot` | Emergency Reboot | 0 | SKILL | TECH | Gain 6 Block. Exhaust. | COMMON | 0 |

##### Shared -- Utility / Draw (8 cards)

| ID | Name | Cost | Type | Tags | Effect | Rarity | Sockets |
|---|---|---|---|---|---|---|---|
| `cache_flush` | Cache Flush | 1 | SKILL | TECH | Draw 2 | COMMON | 0 |
| `data_mine` | Data Mine | 1 | SKILL | TECH, EXPLOIT | Draw 2. +2 Corruption. | COMMON | 0 |
| `recursive_loop` | Recursive Loop | 1 | SKILL | TECH | Draw 3. Exhaust. | UNCOMMON | 0 |
| `overclock_core` | Overclock Core | 0 | SKILL | TECH | Gain 2 Strength. Exhaust. | UNCOMMON | 0 |
| `power_surge` | Power Surge | 3 | POWER | TECH | Gain +1 Max Energy permanently. | RARE | 1 |
| `infinite_loop` | Infinite Loop | 1 | POWER | TECH | At end of turn, draw 1 extra card. | RARE | 1 |
| `stealth_mode` | Stealth Mode | 1 | SKILL | TECH, EXPLOIT | Gain 4 Block. Draw 1. +1 Corruption. | COMMON | 0 |
| `full_reboot` | Full Reboot | 2 | SKILL | TECH | Shuffle discard into draw. Draw 3. | RARE | 1 |

##### Shared -- Debuff / Control (8 cards)

| ID | Name | Cost | Type | Tags | Effect | Rarity | Sockets |
|---|---|---|---|---|---|---|---|
| `uppercut` | Uppercut | 2 | ATTACK | MELEE | Deal 13 damage. Apply 1 Vulnerable. Apply 1 Weak. | UNCOMMON | 1 |
| `malware_inject` | Malware Inject | 1 | ATTACK | TECH, EXPLOIT | Deal 7 damage. Apply 1 Weak. +3 Corruption. | COMMON | 0 |
| `null_pointer` | Null Pointer | 1 | ATTACK | TECH, EXPLOIT | Deal 3 damage x3 hits. Apply 1 Vulnerable. | UNCOMMON | 1 |
| `trojan_horse` | Trojan Horse | 2 | ATTACK | TECH, EXPLOIT | Deal 10 damage. Apply 2 Vulnerable. +5 Corruption. | UNCOMMON | 1 |
| `memory_leak` | Memory Leak | 1 | ATTACK | TECH, EXPLOIT | Deal 4 damage. Apply 2 Weak. | UNCOMMON | 0 |
| `mark_target` | Mark Target | 0 | SKILL | EXPLOIT, RANGED | Mark enemy: +50% damage from all sources this turn. +2 Corruption. | UNCOMMON | 0 |
| `berserker_virus` | Berserker Virus | 2 | ATTACK | TECH, EXPLOIT | Deal 15 damage. Apply 1 Vulnerable. +5 Corruption. | UNCOMMON | 1 |
| `emp_blast` | EMP Blast | 2 | ATTACK | TECH, RANGED | Deal 8 damage to ALL enemies. Apply 1 Weak to ALL. | RARE | 1 |

##### Shared -- Corruption / Risk (8 cards)

| ID | Name | Cost | Type | Tags | Effect | Rarity | Sockets |
|---|---|---|---|---|---|---|---|
| `dark_pact` | Dark Pact | 0 | SKILL | SHADOW | Gain 2 Strength. +10 Corruption. Exhaust. | UNCOMMON | 0 |
| `dark_ritual` | Dark Ritual | 0 | SKILL | SHADOW | Gain 2 Strength. +10 Corruption. Exhaust. | UNCOMMON | 0 |
| `soul_drain` | Soul Drain | 2 | ATTACK | SHADOW | Deal 12 damage. Heal equal to damage dealt. +8 Corruption. | RARE | 1 |
| `entropy_wave` | Entropy Wave | 2 | ATTACK | SHADOW | Deal 16 damage to ALL enemies. +10 Corruption. All players take 4 damage. | RARE | 1 |
| `shadow_bolt` | Shadow Bolt | 1 | ATTACK | SHADOW, RANGED | Deal 9 damage. +3 Corruption. | COMMON | 0 |
| `void_blast` | Void Blast | 2 | ATTACK | SHADOW | Deal 18 damage. +8 Corruption. Exhaust. | RARE | 1 |
| `kernel_panic` | Kernel Panic | 2 | ATTACK | TECH, EXPLOIT | Deal 12 damage. Draw 2. +5 Corruption. | RARE | 1 |
| `buffer_overflow` | Buffer Overflow | 1 | ATTACK | TECH, EXPLOIT | Deal 8 damage. Draw 1. +3 Corruption. | UNCOMMON | 1 |

##### Shared -- Healing / Support (6 cards)

| ID | Name | Cost | Type | Tags | Effect | Rarity | Sockets |
|---|---|---|---|---|---|---|---|
| `system_restore` | System Restore | 2 | SKILL | TECH | Heal 10 HP. Remove 5 Corruption. | UNCOMMON | 0 |
| `soul_transfer` | Soul Transfer | 1 | SKILL | SHADOW | Party heal 4 HP. +5 Corruption. | UNCOMMON | 0 |
| `shared_shield` | Shared Shield | 2 | SKILL | TECH | Gain 12 Block. Share block with all allies. | RARE | 1 |
| `mana_link` | Mana Link | 0 | SKILL | TECH | Transfer 2 mana to lowest-energy ally. | UNCOMMON | 0 |
| `overclocked_network` | Overclocked Network | 1 | SKILL | TECH | Party draw +1 next turn. Gain 4 Block. | UNCOMMON | 0 |
| `nanobots` | Nanobots | 2 | SKILL | TECH | Heal 8 HP. Gain 6 Block. | RARE | 1 |

##### Shared -- Co-op / Party (6 cards)

| ID | Name | Cost | Type | Tags | Effect | Rarity | Sockets |
|---|---|---|---|---|---|---|---|
| `proxy_chain` | Proxy Chain | 1 | SKILL | TECH, EXPLOIT | Gain 6 Block. All allies gain 3 Block. | UNCOMMON | 0 |
| `rallying_protocol` | Rallying Protocol | 2 | SKILL | TECH | All allies draw 2. You gain 5 Block. | RARE | 1 |
| `sacrifice_subroutine` | Sacrifice Subroutine | 1 | SKILL | SHADOW | Take 6 damage. Target ally heals 10 and draws 1. | UNCOMMON | 0 |
| `resonance_link` | Resonance Link | 2 | POWER | TECH | Whenever you gain Block, allies gain 2 Block. | RARE | 1 |
| `revival_protocol` | Revival Protocol | 3 | SKILL | TECH, HOLY | Revive a downed ally at 15 HP. Exhaust. | RARE | 0 |
| `combined_assault` | Combined Assault | 2 | ATTACK | MELEE | Deal 8 damage. Mark target. All allies deal +3 damage to this enemy this turn. | RARE | 1 |

##### Shared -- Curses / Status (4 cards)

| ID | Name | Cost | Type | Tags | Effect | Rarity | Sockets |
|---|---|---|---|---|---|---|---|
| `curse_glitch` | Glitch | 0 | CURSE | CURSE | Unplayable. While in hand, +3 Corruption per turn. | COMMON | 0 |
| `curse_hellfire` | Hellfire | 0 | CURSE | CURSE | Unplayable. While in hand, take 2 damage per turn. | COMMON | 0 |
| `corrupted_echo` | Corrupted Echo | 1 | STATUS | CURSE | Deal 3 damage to yourself. Exhaust. | COMMON | 0 |
| `divine_static` | Divine Static | 1 | STATUS | CURSE | Unplayable. While in hand, block gains reduced by 2. | COMMON | 0 |

##### Shared -- Berserker / Self-Damage (4 cards)

| ID | Name | Cost | Type | Tags | Effect | Rarity | Sockets |
|---|---|---|---|---|---|---|---|
| `reckless_charge` | Reckless Charge | 0 | ATTACK | MELEE | Deal 7 damage. Take 3 self-damage. | COMMON | 0 |
| `blood_price` | Blood Price | 1 | ATTACK | MELEE, FIRE | Deal damage equal to your missing HP (max 30). Exhaust. | RARE | 2 |
| `pain_conduit` | Pain Conduit | 1 | POWER | SHADOW | Whenever you take damage, gain 1 Strength. | RARE | 1 |
| `adrenaline_surge` | Adrenaline Surge | 0 | SKILL | -- | Draw 2. Take 4 self-damage. | UNCOMMON | 0 |

##### Shared -- Power Cards (4 cards)

| ID | Name | Cost | Type | Tags | Effect | Rarity | Sockets |
|---|---|---|---|---|---|---|---|
| `corruption_engine` | Corruption Engine | 2 | POWER | SHADOW, TECH | At the start of each turn, gain +3 Corruption and +1 Strength. | RARE | 1 |
| `network_tap` | Network Tap | 1 | POWER | TECH, EXPLOIT | Whenever you play an EXPLOIT card, draw 1. | RARE | 1 |
| `overload_protocol` | Overload Protocol | 2 | POWER | TECH | Your first card each turn costs 1 less energy. | RARE | 2 |
| `vengeance_loop` | Vengeance Loop | 2 | POWER | MELEE | Whenever you take unblocked damage, deal 4 damage to the attacker. | RARE | 1 |

**Shared total: 74 cards** (6 more added below in co-op/late-game)

##### Shared -- Late-Game / Boss Drops (6 cards)

| ID | Name | Cost | Type | Tags | Effect | Rarity | Sockets |
|---|---|---|---|---|---|---|---|
| `angel_override` | Angel Override | 3 | ATTACK | HOLY, TECH | Deal 25 damage. Remove all Corruption. Exhaust. | LEGENDARY | 2 |
| `genesis_protocol` | Genesis Protocol | 3 | SKILL | TECH, HOLY | All allies fully heal. Remove 20 Corruption from all allies. Exhaust. | LEGENDARY | 2 |
| `total_collapse` | Total Collapse | 4 | ATTACK | SHADOW, EXPLOIT | Deal 40 damage to ALL enemies. +20 Corruption. All players take 10 damage. Exhaust. | LEGENDARY | 2 |
| `nexus_rewrite` | Nexus Rewrite | 2 | POWER | TECH | At the start of each turn, draw 2 extra cards. +5 Corruption/turn. | LEGENDARY | 2 |
| `black_ice` | Black Ice | 2 | ATTACK | TECH, ICE, EXPLOIT | Deal 10 damage x3 hits. Apply 2 Vulnerable. +8 Corruption. | LEGENDARY | 2 |
| `divine_compilation` | Divine Compilation | 3 | SKILL | HOLY, TECH | Gain 30 Block shared with all allies. Remove 10 Corruption from all allies. | LEGENDARY | 2 |

**Shared total: 80 cards**

---

#### NETRUNNER EXCLUSIVE CARDS (8 cards)

| ID | Name | Cost | Type | Tags | Effect | Rarity | Sockets |
|---|---|---|---|---|---|---|---|
| `net_spike` | Net Spike | 1 | ATTACK | TECH, RANGED | Deal 4 damage x3 hits. | COMMON | 0 |
| `packet_storm` | Packet Storm | 2 | ATTACK | TECH, RANGED | Deal 3 damage x5 hits. +3 Corruption. | UNCOMMON | 1 |
| `backdoor` | Backdoor | 1 | SKILL | TECH, EXPLOIT | Draw 2. Apply 1 Vulnerable to random enemy. | UNCOMMON | 0 |
| `neural_spike` | Neural Spike | 2 | ATTACK | TECH, RANGED | Deal 10 damage. Apply 1 Vulnerable. | UNCOMMON | 1 |
| `zero_day_exploit` | Zero-Day Exploit | 2 | ATTACK | TECH, EXPLOIT | Deal 15 damage. Apply 2 Vulnerable. +5 Corruption. | RARE | 1 |
| `ghost_protocol` | Ghost Protocol | 1 | SKILL | TECH, EXPLOIT | Draw 3. Gain 4 Block. Exhaust. | RARE | 1 |
| `botnet_cascade` | Botnet Cascade | 2 | ATTACK | TECH, RANGED, EXPLOIT | Deal 6 damage to ALL enemies. Draw 1 for each enemy hit. +4 Corruption. | RARE | 2 |
| `singularity_hack` | Singularity Hack | 3 | ATTACK | TECH, EXPLOIT | Deal 8 damage x4 hits. If target dies, draw 3. | LEGENDARY | 2 |

#### SYSADMIN EXCLUSIVE CARDS (8 cards)

| ID | Name | Cost | Type | Tags | Effect | Rarity | Sockets |
|---|---|---|---|---|---|---|---|
| `firewall_protocol` | Firewall Protocol | 1 | SKILL | TECH | Gain 9 Block. | COMMON | 0 |
| `hardened_kernel` | Hardened Kernel | 2 | SKILL | TECH | Gain 14 Block. Gain 1 Dexterity. | UNCOMMON | 1 |
| `root_access` | Root Access | 2 | ATTACK | TECH, MELEE | Deal 8 damage. Gain 8 Block. | UNCOMMON | 1 |
| `kernel_shield` | Kernel Shield | 1 | SKILL | TECH | Gain 6 Block. If Block > 15, gain 3 extra Block. | UNCOMMON | 0 |
| `system_lockdown` | System Lockdown | 3 | SKILL | TECH | Gain 25 Block. Gain 2 Dexterity. Exhaust. | RARE | 1 |
| `iron_bastion` | Iron Bastion | 2 | POWER | TECH, MELEE | At end of turn, retain 5 Block (does not reset fully). | RARE | 1 |
| `fortress_mode` | Fortress Mode | 2 | SKILL | TECH | Gain Block equal to your Max HP / 3. Share with allies. | RARE | 2 |
| `absolute_defense` | Absolute Defense | 4 | SKILL | TECH | Gain 50 Block. All allies gain 15 Block. Exhaust. | LEGENDARY | 2 |

#### CRYPTOMANCER EXCLUSIVE CARDS (8 cards)

| ID | Name | Cost | Type | Tags | Effect | Rarity | Sockets |
|---|---|---|---|---|---|---|---|
| `dark_compile` | Dark Compile | 1 | ATTACK | SHADOW | Deal 8 damage. +3 Corruption. | COMMON | 0 |
| `void_channel` | Void Channel | 2 | ATTACK | SHADOW | Deal 14 damage. +5 Corruption. | UNCOMMON | 1 |
| `corruption_spike` | Corruption Spike | 1 | ATTACK | SHADOW, EXPLOIT | Deal damage equal to your Corruption / 5 (min 4, max 20). | UNCOMMON | 1 |
| `dark_harvest` | Dark Harvest | 2 | ATTACK | SHADOW | Deal 10 damage. Heal 5 HP. +8 Corruption. | RARE | 1 |
| `oblivion_pulse` | Oblivion Pulse | 2 | ATTACK | SHADOW | Deal 12 damage to ALL enemies. +10 Corruption. Gain Strength equal to enemies killed. | RARE | 1 |
| `void_form` | Void Form | 3 | POWER | SHADOW | Gain +1 Strength and +3 Corruption at the start of each turn. | RARE | 1 |
| `black_singularity` | Black Singularity | 3 | ATTACK | SHADOW | Deal 30 damage. +15 Corruption. Exhaust. | RARE | 2 |
| `event_horizon` | Event Horizon | 4 | ATTACK | SHADOW, EXPLOIT | Deal damage equal to your Corruption (max 100). Set Corruption to 0. Exhaust. | LEGENDARY | 2 |

#### WHITE HAT EXCLUSIVE CARDS (8 cards)

| ID | Name | Cost | Type | Tags | Effect | Rarity | Sockets |
|---|---|---|---|---|---|---|---|
| `purge_routine` | Purge Routine | 1 | SKILL | HOLY, TECH | Gain 5 Block. Remove 5 Corruption. | COMMON | 0 |
| `sanctify` | Sanctify | 1 | ATTACK | HOLY, MELEE | Deal 7 damage. Remove 3 Corruption. | COMMON | 0 |
| `holy_strike` | Holy Strike | 1 | ATTACK | HOLY, MELEE | Deal 9 damage. -2 Corruption. | UNCOMMON | 1 |
| `smite` | Smite | 2 | ATTACK | HOLY, MELEE | Deal 14 damage. -5 Corruption. Apply 1 Vulnerable. | UNCOMMON | 1 |
| `divine_barrier` | Divine Barrier | 2 | SKILL | HOLY | Gain 16 Block. -5 Corruption. | RARE | 1 |
| `consecrate` | Consecrate | 2 | ATTACK | HOLY | Deal 10 damage to ALL enemies. -3 Corruption per enemy. | RARE | 1 |
| `radiant_burst` | Radiant Burst | 3 | ATTACK | HOLY | Deal 20 damage. -10 Corruption. Party heal 5. | RARE | 2 |
| `blessing` | Absolution | 3 | SKILL | HOLY | Remove all Corruption. All allies remove 10 Corruption. Heal 10. Exhaust. | LEGENDARY | 2 |

#### TECHNOMANCER EXCLUSIVE CARDS (8 cards)

| ID | Name | Cost | Type | Tags | Effect | Rarity | Sockets |
|---|---|---|---|---|---|---|---|
| `daemon_compile` | Daemon Compile | 1 | ATTACK | TECH, SHADOW | Deal 6 damage. Create a Daemon Fragment in hand. | COMMON | 0 |
| `flux_shift` | Flux Shift | 1 | SKILL | TECH | Gain 5 Block. Draw 1. Create a Daemon Fragment in hand. | COMMON | 0 |
| `code_summon` | Code Summon | 2 | SKILL | TECH, SHADOW | Create 2 Daemon Fragments in hand. Gain 3 Block. | UNCOMMON | 1 |
| `daemon_swarm` | Daemon Swarm | 2 | ATTACK | TECH, SHADOW | Deal 4 damage x(number of Daemon cards played this combat). +3 Corruption. | UNCOMMON | 1 |
| `daemon_process` | Daemon Process | 1 | POWER | TECH, SHADOW | At end of turn, create 1 Daemon Fragment. | RARE | 1 |
| `reality_patch` | Reality Patch | 2 | SKILL | TECH, SHADOW | Gain 10 Block. Create 1 Daemon Fragment. Draw 1. | UNCOMMON | 1 |
| `fusion_core` | Fusion Core | 3 | SKILL | TECH | Destroy all Daemon Fragments in hand. Deal 8 damage per fragment destroyed. | RARE | 2 |
| `god_compiler` | God Compiler | 4 | POWER | TECH, SHADOW | At end of each turn, create 2 Daemon Fragments. Daemon Fragments deal +3 damage. | LEGENDARY | 2 |

**Total card count: 80 shared + 40 exclusive = 120 cards**

---

## 4. Gem System

### 4.1 Design Overhaul

**Problem with current gems:** They are stat sticks. Ruby of Fury is "+15% damage when this card is played." That is a modifier, not a gem.

**New principle:** Gems transform HOW a card works, not just how much damage it does. A gem should make you think "which card do I put this on?" -- not "obviously the highest-damage card."

### 4.2 Gem Categories

| Category | What It Does | Example |
|---|---|---|
| **Amplify** | Multiplies an aspect of the card contextually | "Double damage if this is the first card played this turn" |
| **Convert** | Changes the card's effect type | "This card's damage is dealt as healing to an ally instead" |
| **Trigger** | Adds an on-condition effect to the card | "When this card kills an enemy, draw 2" |
| **Sustain** | Adds defensive/sustain riders | "This card also gains Block equal to 50% of its damage" |
| **Corrupt** | High-power effects with corruption costs | "+50% damage, but +5 corruption each play" |
| **Utility** | Draw, energy, or resource manipulation | "This card costs 1 less if you've played 3+ cards this turn" |

### 4.3 Gem Catalog (20 gems)

Gems are socketed into cards (cards have 0-2 sockets). Each gem applies its effect only when that specific card is played.

#### Amplify Gems

| ID | Name | Rarity | Effect | Implementation (Modifier Spec) |
|---|---|---|---|---|
| `ruby_of_fury` | Ruby of Fury | COMMON | +15% damage when this card is played | DAMAGE PERCENT_ADD 0.15, CARD_PLAY |
| `topaz_of_wrath` | Topaz of Wrath | UNCOMMON | +30% damage vs. Vulnerable targets | DAMAGE PERCENT_ADD 0.30, CARD_PLAY, only_vs_vulnerable |
| `diamond_of_precision` | Diamond of Precision | RARE | +50% damage if this is the only card played this turn | DAMAGE PERCENT_ADD 0.50, CARD_PLAY, conditional: cards_played_this_turn == 1 |
| `star_sapphire` | Star Sapphire | RARE | This card's damage is applied twice (second hit at 50%) | DAMAGE PERCENT_ADD 0.50, CARD_PLAY (implemented as +1 hit at 50% value) |

#### Convert Gems

| ID | Name | Rarity | Effect | Implementation |
|---|---|---|---|---|
| `jade_of_iron_will` | Jade of Iron Will | UNCOMMON | This card also gains Block equal to 30% of its damage | BLOCK FLAT_ADD (= card damage * 0.3), CARD_PLAY |
| `pearl_of_purity` | Pearl of Purity | UNCOMMON | This card removes 3 Corruption instead of adding any | CORRUPTION_GAIN OVERRIDE -3, CARD_PLAY |
| `moonstone_of_conversion` | Moonstone of Conversion | RARE | This card's damage is converted to healing for you (no damage dealt) | DAMAGE OVERRIDE 0 + HEALING FLAT_ADD (= original damage), CARD_PLAY |
| `opal_of_sharing` | Opal of Sharing | UNCOMMON | This card's Block is shared with all allies (50% each) | Sets share_block flag, CARD_PLAY |

#### Trigger Gems

| ID | Name | Rarity | Effect | Implementation |
|---|---|---|---|---|
| `onyx_of_exploitation` | Onyx of Exploitation | UNCOMMON | When this card is played, if enemy is Vulnerable, draw 1 | Conditional draw +1, CARD_PLAY |
| `garnet_of_cascade` | Garnet of Cascade | RARE | When this card kills an enemy, gain 2 energy | Conditional on kill: +2 energy refund |
| `alexandrite_of_chains` | Alexandrite of Chains | RARE | When this card deals unblocked damage, apply 1 Weak | Conditional: apply_weak +1 if unblocked hit |
| `fire_opal_of_ignition` | Fire Opal of Ignition | UNCOMMON | When this card is played, deal 3 damage to ALL enemies | AoE rider: 3 damage all enemies |

#### Sustain Gems

| ID | Name | Rarity | Effect | Implementation |
|---|---|---|---|---|
| `sapphire_of_shielding` | Sapphire of Shielding | COMMON | +4 Block when this card is played | BLOCK FLAT_ADD 4, CARD_PLAY |
| `emerald_of_renewal` | Emerald of Renewal | UNCOMMON | Heal 3 HP when this card is played | HEALING FLAT_ADD 3, CARD_PLAY |
| `amethyst_of_fortitude` | Amethyst of Fortitude | COMMON | +2 Block per hit when this card is played (multi-hit bonus) | BLOCK FLAT_ADD 2 per hit, CARD_PLAY |

#### Corrupt Gems

| ID | Name | Rarity | Effect | Implementation |
|---|---|---|---|---|
| `obsidian_shard` | Obsidian Shard | UNCOMMON | +40% damage. +5 Corruption per play. | DAMAGE PERCENT_ADD 0.40 + CORRUPTION_GAIN FLAT_ADD 5, CARD_PLAY |
| `crimson_opal` | Crimson Opal | RARE | +25% damage and +25% block. Only active at Corrupted tier or above. | DAMAGE PERCENT_ADD 0.25 + BLOCK PERCENT_ADD 0.25, conditional: corruption >= 50 |
| `bloodstone_of_sacrifice` | Bloodstone of Sacrifice | RARE | +30% damage and +30% block when below 50% HP | DAMAGE/BLOCK PERCENT_ADD 0.30, only_when_hp_below_pct 0.5 |

#### Utility Gems

| ID | Name | Rarity | Effect | Implementation |
|---|---|---|---|---|
| `moonstone_of_efficiency` | Moonstone of Efficiency | UNCOMMON | This card costs 1 less energy (min 0) | ENERGY_COST FLAT_ADD -1, CARD_PLAY |
| `diamond_of_efficiency` | Diamond of Efficiency | RARE | This card costs 0 energy. Once per combat. | ENERGY_COST OVERRIDE 0, CARD_PLAY, once per combat |

### 4.4 Gem Socket Strategy

The key decision: **which card do you socket the gem into?**

Examples of meaningful socket decisions:
- **Obsidian Shard** on a 0-cost cantrip = small damage boost, lots of corruption over time (bad)
- **Obsidian Shard** on a 3-cost nuke = massive burst once per combat (good)
- **Pearl of Purity** on Dark Compile = turns a corruption-gaining attack into a corruption-removing one
- **Garnet of Cascade** on Cleave = energy refund on AoE kill turns, enabling more plays
- **Moonstone of Conversion** on Void Blast = 18 healing instead of 18 damage (emergency heal button)

### 4.5 Gem Rarity Distribution

| Rarity | Count | Drop Rate | Shop Price |
|---|---|---|---|
| COMMON | 4 | 60% | 80 gold |
| UNCOMMON | 10 | 30% | 160 gold |
| RARE | 6 | 10% | 300 gold |

---

## 5. Relic System

### 5.1 Design Overhaul

**Problem with current relics:** Most are passive stat bonuses (+1 Strength at combat start, +5 HP). These are invisible power that the player never thinks about after acquiring.

**New principle:** Every relic should change HOW you play, not just how STRONG you are. A good relic makes you reconsider your card play order, your corruption management, or your co-op coordination.

### 5.2 Relic Categories

| Category | Purpose | Example |
|---|---|---|
| **Build Enablers** | Make a build archetype viable | "Block does not reset at turn start (but decay 50%)" |
| **Risk/Reward** | Power with a cost | "Deal +25% damage. Start each combat at 25 Corruption." |
| **Triggers** | React to game events | "Whenever you draw 7+ cards in a turn, gain 3 Strength." |
| **Economy** | Resource manipulation | "After each combat, choose: 50 gold OR remove 15 Corruption." |
| **Co-op** | Benefit the whole party | "Allies within 25 Corruption of you gain +5% damage." |

### 5.3 Relic Catalog (25 relics)

#### Build Enablers (6 relics)

| ID | Name | Rarity | Effect | Archetype |
|---|---|---|---|---|
| `iron_fortress` | Iron Fortress | RARE | Block decays by 50% at turn start instead of resetting to 0. | Iron Wall |
| `hackers_manual` | Hacker's Manual | UNCOMMON | The first EXPLOIT card you play each turn costs 0 energy. | Card Engine |
| `corrupted_core` | Corrupted Core | RARE | Start each combat at 50 Corruption. +2 Strength at combat start. | Corruption Lord |
| `holy_grail` | Holy Grail | RARE | HOLY cards remove 3 extra Corruption. Healing is +30% effective. | Holy Purifier |
| `daemon_motherboard` | Daemon Motherboard | RARE | Daemon Fragments deal +4 damage and gain "Draw 1." | Daemon Swarm |
| `berserker_totem` | Berserker Totem | UNCOMMON | While below 50% HP, gain +2 Strength and +2 Dexterity. | Berserker |

#### Risk/Reward (5 relics)

| ID | Name | Rarity | Effect | Archetype |
|---|---|---|---|---|
| `shadow_idol` | Shadow Idol | UNCOMMON | +25% damage. Start each combat at 25 Corruption. | Glass Cannon |
| `blood_vial` | Blood Vial | COMMON | At the start of combat, lose 10% Max HP. Gain 2 Strength. | Berserker |
| `quantum_lens` | Quantum Lens | UNCOMMON | +1 card draw per turn. Each card drawn past 7 adds +2 Corruption. | Card Engine |
| `phoenix_feather` | Phoenix Feather | RARE | The first time you would die each combat, fully heal to 25% HP instead. Gain +20 Corruption. | Glass Cannon |
| `entropy_crystal` | Entropy Crystal | UNCOMMON | Whenever you gain Corruption, also gain 1 Block per corruption gained. | Corruption Lord |

#### Triggers (5 relics)

| ID | Name | Rarity | Effect | Archetype |
|---|---|---|---|---|
| `whetstone` | Whetstone | COMMON | The first Attack each combat deals +5 damage. | General |
| `data_shard` | Data Shard | COMMON | Whenever you play 3 cards in a single turn, draw 1. | Card Engine |
| `swift_boots` | Swift Boots | UNCOMMON | Whenever you play 5+ cards in a turn, gain 1 energy next turn. | Card Engine |
| `nano_heart` | Nano Heart | UNCOMMON | Whenever you lose 10+ HP in a single turn, heal 5 at turn end. | Berserker |
| `vengeful_circuit` | Vengeful Circuit | RARE | Whenever an ally enters Death's Door, gain +3 Strength for the rest of combat. | Co-op |

#### Economy (4 relics)

| ID | Name | Rarity | Effect | Archetype |
|---|---|---|---|---|
| `battery_pack` | Battery Pack | COMMON | +1 max energy. | General |
| `burning_blood` | Burning Blood | COMMON | Heal 6 HP at end of combat. | General |
| `bag_of_prep` | Bag of Preparation | COMMON | Draw 2 extra cards on the first turn of each combat. | General |
| `digital_crown` | Digital Crown | RARE | After each combat, choose one: remove a card from your deck, OR upgrade a card. | General |

#### Co-op (5 relics)

| ID | Name | Rarity | Effect | Archetype |
|---|---|---|---|---|
| `medic_drone` | Medic Drone | UNCOMMON | At the end of each turn, the lowest-HP ally heals 2. | Support |
| `hardened_shell` | Hardened Shell | UNCOMMON | All allies gain +3 Block at combat start. | Iron Wall |
| `synergy_core` | Synergy Core | RARE | Whenever an ally plays a card with a tag matching your character's affinity, you gain 1 Block. | Co-op |
| `corruption_siphon` | Corruption Siphon | RARE | At end of each turn, transfer 3 Corruption from the highest-corruption ally to you. (Only if you are lower.) | Holy Purifier |
| `shared_fate` | Shared Fate | LEGENDARY | When any ally would take lethal damage, distribute that damage evenly across all living allies instead. | Co-op |

### 5.4 Relic Interactions with Corruption

Every relic's value shifts based on your corruption tier:

- **Iron Fortress** at Pure: reliable block stacking. At Demonic: the retained block helps survive corruption burn.
- **Shadow Idol** at any tier: forces you into Tainted from turn 1, changing card mutation timings.
- **Corrupted Core** skips tiers 0-1 entirely, enabling Corruption Lord immediately.
- **Holy Grail** gets stronger the more corruption you remove (more removal = more trigger opportunities).
- **Phoenix Feather** gives a safety net but pushes corruption to Demonic on trigger.

---

## 6. Equipment System

### 6.1 Design Overhaul

**Problem with current equipment:** All equipment is flat modifier stacks. Shadow Cloak is "+15% damage when below 50% HP." That is a gem, not equipment.

**New principle:** Equipment defines your IDENTITY for the run. Each slot has a clear role, and equipment should have tag synergy (not just stat bonuses). Equipment is what commits you to a build path.

### 6.2 Slot Roles

| Slot | Role | Primary Stat | Secondary Effect |
|---|---|---|---|
| **Head** | Perception & draw | +Draw per turn, +Energy | Information advantage |
| **Chest** | Survivability | +Block, +Max HP | Damage reduction |
| **Weapon** | Offense & tag identity | +Damage (conditional on tags) | Card type synergy |
| **Accessory** | Build specialization | Unique triggered effects | Build-defining passives |

### 6.3 Equipment Catalog (24 equipment)

#### HEAD SLOT (6 items)

| ID | Name | Rarity | Effect | Modifiers |
|---|---|---|---|---|
| `iron_helm` | Iron Helm | COMMON | +5 Max HP | MAX_HP FLAT_ADD 5 |
| `tech_visor` | Tech Visor | COMMON | +1 Draw per turn | DRAW_PER_TURN FLAT_ADD 1 |
| `neural_interface` | Neural Interface | UNCOMMON | +1 Draw per turn. TECH cards deal +2 damage. | DRAW_PER_TURN FLAT_ADD 1, DAMAGE FLAT_ADD 2 (req TECH) |
| `reinforced_helm` | Reinforced Helm | UNCOMMON | +8 Max HP. +3 Block | MAX_HP FLAT_ADD 8, BLOCK FLAT_ADD 3 |
| `corruption_filter` | Corruption Filter | UNCOMMON | +10 Corruption Resistance. +5 Max HP. | CORRUPTION_RESIST FLAT_ADD 10, MAX_HP FLAT_ADD 5 |
| `oracle_crown` | Oracle Crown | RARE | +2 Draw per turn. -5 Max HP. | DRAW_PER_TURN FLAT_ADD 2, MAX_HP FLAT_ADD -5 |

#### CHEST SLOT (6 items)

| ID | Name | Rarity | Effect | Modifiers |
|---|---|---|---|---|
| `leather_vest` | Leather Vest | COMMON | +3 Block | BLOCK FLAT_ADD 3 |
| `mithril_vest` | Mithril Vest | UNCOMMON | +5 Block. +10% Block. | BLOCK FLAT_ADD 5, BLOCK PERCENT_ADD 0.10 |
| `blessed_armor` | Blessed Armor | UNCOMMON | +4 Block. +10% Healing. HOLY cards gain +3 Block. | BLOCK FLAT_ADD 4, HEALING PERCENT_ADD 0.10, BLOCK FLAT_ADD 3 (req HOLY) |
| `void_plate` | Void Plate | RARE | +15% Block. +15% Damage. +5 Corruption per combat start. | BLOCK PERCENT_ADD 0.15, DAMAGE PERCENT_ADD 0.15 |
| `holy_vestments` | Holy Vestments | RARE | +8 Block. +20% Healing. -5 Corruption at combat start. | BLOCK FLAT_ADD 8, HEALING PERCENT_ADD 0.20 |
| `daemon_chassis` | Daemon Chassis | RARE | +10% Block. Whenever you play a SHADOW card, gain 2 Block. | BLOCK PERCENT_ADD 0.10, conditional: +2 block on SHADOW play |

#### WEAPON SLOT (6 items)

| ID | Name | Rarity | Effect | Modifiers |
|---|---|---|---|---|
| `rusty_blade` | Rusty Blade | COMMON | +2 Damage | DAMAGE FLAT_ADD 2 |
| `plasma_edge` | Plasma Edge | UNCOMMON | +3 Damage. TECH attacks deal +15% damage. | DAMAGE FLAT_ADD 3, DAMAGE PERCENT_ADD 0.15 (req TECH) |
| `shadow_fang` | Shadow Fang | UNCOMMON | +4 Damage. SHADOW attacks deal +10% damage. +3 Corruption/combat. | DAMAGE FLAT_ADD 4, DAMAGE PERCENT_ADD 0.10 (req SHADOW) |
| `flame_gauntlets` | Flame Gauntlets | UNCOMMON | FIRE attacks deal +20% damage. MELEE attacks deal +2 damage. | DAMAGE PERCENT_ADD 0.20 (req FIRE), DAMAGE FLAT_ADD 2 (req MELEE) |
| `holy_avenger` | Holy Avenger | RARE | HOLY attacks deal +25% damage. HOLY attacks remove 2 extra Corruption. | DAMAGE PERCENT_ADD 0.25 (req HOLY) |
| `berserker_gauntlet` | Berserker Gauntlet | RARE | +30% Damage when below 50% HP. +5 Damage when below 25% HP. | DAMAGE PERCENT_ADD 0.30 (hp_below 0.5), DAMAGE FLAT_ADD 5 (hp_below 0.25) |

#### ACCESSORY SLOT (6 items)

| ID | Name | Rarity | Effect | Modifiers |
|---|---|---|---|---|
| `corrupt_amulet` | Corrupt Amulet | COMMON | +10% Damage. +2 Corruption per combat start. | DAMAGE PERCENT_ADD 0.10 |
| `exploit_chip` | Exploit Chip | UNCOMMON | EXPLOIT cards deal +15% damage. EXPLOIT cards cost -1 energy (first per turn). | DAMAGE PERCENT_ADD 0.15 (req EXPLOIT) |
| `mana_crystal` | Mana Crystal | UNCOMMON | +1 Max Energy. +1 Mana Regen. | MAX_ENERGY FLAT_ADD 1, MANA_REGEN FLAT_ADD 1 |
| `shadow_cloak` | Shadow Cloak | RARE | +15% Damage when below 50% HP. +15% Block when below 50% HP. | DAMAGE PERCENT_ADD 0.15 (hp_below 0.5), BLOCK PERCENT_ADD 0.15 (hp_below 0.5) |
| `heart_of_corruption` | Heart of Corruption | RARE | +20% Damage per corruption tier (0/20/40/60%). Corruption burn reduced by 1. | DAMAGE PERCENT_ADD (0.20 * tier), CORRUPTION burn -1 |
| `harmony_pendant` | Harmony Pendant | RARE | +10% all stats while at Pure tier. If corruption > 0, no bonus. | DAMAGE/BLOCK/HEALING PERCENT_ADD 0.10, conditional: corruption == 0 |

### 6.4 Equipment + Character Synergy Matrix

| Equipment | Netrunner | Sysadmin | Cryptomancer | White Hat | Technomancer | Scourge |
|---|---|---|---|---|---|---|
| Neural Interface | *** | * | * | * | ** | * |
| Mithril Vest | * | *** | * | ** | * | * |
| Plasma Edge | *** | ** | * | * | *** | * |
| Shadow Fang | * | * | *** | - | ** | ** |
| Holy Avenger | - | * | - | *** | - | - |
| Exploit Chip | *** | * | ** | * | ** | * |
| Heart of Corruption | * | - | *** | - | ** | *** |
| Harmony Pendant | * | ** | - | *** | * | - |

(*** = ideal, ** = good, * = usable, - = anti-synergy)

*Note: Scourge synergizes strongly with Heart of Corruption (embraces corruption) and Shadow Fang (SHADOW cards). Anti-synergy with Holy Avenger and Harmony Pendant (incompatible with corruption-embrace playstyle). Scourge-specific equipment (Pirate Cutlass, Corsair Coat, Skull & Crossbones, etc.) to be added in equipment expansion.*

---

## 7. Skill Tree System

### 7.1 Design Overhaul

**Problem with current skill trees:** All nodes are stat bonuses (+2 Damage, +5 Block, +15% Damage). This is boring and does not create meaningful choices.

**New principle:** Each branch is a BUILD PATH, not a stat ladder. The capstone (tier 3) should be a KEYSTONE that fundamentally changes gameplay. You earn ~10-12 skill points per run. Each branch costs ~8 points to complete. You can NOT max all 3 branches -- you must choose.

### 7.2 Character Count

6 characters x 3 branches = **18 branches total** (15 original + 3 Scourge).

### 7.3 Skill Point Economy

| Source | Points | Timing |
|---|---|---|
| Level-ups (1-8) | 8 points | ~1 per floor |
| Boss kills | 1-2 bonus | 3 bosses per run |
| Special events | 0-2 bonus | Random |
| **Total per run** | **~10-12** | -- |

| Branch Depth | Points Required | What You Get |
|---|---|---|
| Tier 0 (entry) | 1 | Small stat bonus, unlocks the branch |
| Tier 1 (mid) | 1-2 | Moderate bonus or conditional |
| Tier 2 (advanced) | 2 | Strong bonus or build-specific |
| Tier 3 (keystone) | 3 | Game-changing passive |
| **Full branch** | **7-8** | Complete build path |

This means you can fully complete 1 branch and get partway into a second. OR you can go wide with tier 0-1 in all three branches. The choice matters.

### 7.4 All 18 Branches (6 characters x 3 branches)

---

#### NETRUNNER: "Neural Network"

##### Branch 1: Velocity (Offense)
*Go fast. Hit often. Every card played accelerates the next.*

| Tier | ID | Name | Cost | Effect |
|---|---|---|---|---|
| 0 | `nr_rapid_fire` | Rapid Fire | 1 | RANGED attacks deal +2 damage |
| 1 | `nr_burst_mode` | Burst Mode | 1 | TECH attacks deal +15% damage |
| 2 | `nr_chain_hack` | Chain Hack | 2 | After playing 3+ cards in a turn, your next card costs 1 less energy |
| 3 | `nr_overdrive` | **KEYSTONE: Overdrive** | 3 | Every card you play this turn gains +2 damage. Resets each turn. (1st card: +2, 2nd: +4, 3rd: +6...) |

*Overdrive transforms the Netrunner into a scaling machine. The more cards you play per turn, the harder each one hits. Pairs with Card Engine archetype.*

##### Branch 2: Ghost (Defense)
*Untouchable. Evasion over raw block. Punish enemies for missing.*

| Tier | ID | Name | Cost | Effect |
|---|---|---|---|---|
| 0 | `nr_firewall` | Firewall | 1 | +3 Block to all cards |
| 1 | `nr_proxy_shield` | Proxy Shield | 1 | +15% Block |
| 2 | `nr_ghost_protocol` | Ghost Protocol | 2 | +5 Max HP. The first time you take damage each turn, draw 1. |
| 3 | `nr_quantum_dodge` | **KEYSTONE: Quantum Dodge** | 3 | At the start of each turn, gain Block equal to the number of cards in your hand x3. |

*Quantum Dodge rewards a full hand. Combined with the Netrunner's +1 draw passive, starting with 7 cards = 21 Block for free every turn.*

##### Branch 3: Exploit (Utility)
*Information warfare. Debuff, draw, and dismantle.*

| Tier | ID | Name | Cost | Effect |
|---|---|---|---|---|
| 0 | `nr_packet_sniff` | Packet Sniff | 1 | +1 Card Draw per turn |
| 1 | `nr_rootkit` | Rootkit | 2 | EXPLOIT cards cost 1 less energy |
| 2 | `nr_zero_day` | Zero Day | 2 | When you apply Vulnerable, also apply 1 Weak |
| 3 | `nr_backdoor_access` | **KEYSTONE: Backdoor Access** | 3 | The first time each turn you play a card with the EXPLOIT tag, play it twice. |

*Backdoor Access doubles one exploit card per turn. Zero-Day Exploit hitting twice = 30 damage + 4 Vulnerable + 2 Weak. Absurd with Debuff Controller archetype.*

---

#### SYSADMIN: "Fortress Protocol"

##### Branch 1: Shield Wall (Defense)
*Unbreakable defense. Block stacks. Block persists. Block wins.*

| Tier | ID | Name | Cost | Effect |
|---|---|---|---|---|
| 0 | `sa_iron_wall` | Iron Wall | 1 | +5 Block to all cards |
| 1 | `sa_bulwark` | Bulwark | 1 | +20% Block |
| 2 | `sa_aegis` | Aegis | 2 | MELEE Skill cards gain +5 Block |
| 3 | `sa_unbreakable` | **KEYSTONE: Unbreakable** | 3 | 50% of your Block carries over to the next turn (does not fully reset). |

*Unbreakable is the Iron Wall keystone. Block snowballs across turns. A 40-block turn means starting next turn with 20. Makes Body Slam devastating.*

##### Branch 2: Retaliation (Offense)
*Turn defense into offense. The harder they hit you, the harder you hit back.*

| Tier | ID | Name | Cost | Effect |
|---|---|---|---|---|
| 0 | `sa_thorns` | Thorns | 1 | +2 Damage to all attacks |
| 1 | `sa_counter_strike` | Counter Strike | 1 | MELEE attacks deal +3 damage |
| 2 | `sa_power_surge` | Power Surge | 2 | When you take unblocked damage, gain 1 Strength (max 3 per turn) |
| 3 | `sa_crushing_blow` | **KEYSTONE: Crushing Blow** | 3 | Your attacks deal bonus damage equal to 25% of your current Block. |

*Crushing Blow converts defense into offense. With 40 Block, every attack deals +10 damage. The Sysadmin becomes a true tank/bruiser hybrid.*

##### Branch 3: Endurance (Utility)
*Outlast everything. Sustain, purify, endure.*

| Tier | ID | Name | Cost | Effect |
|---|---|---|---|---|
| 0 | `sa_backup_power` | Backup Power | 1 | +1 Max Energy |
| 1 | `sa_redundancy` | Redundancy | 1 | +8 Max HP |
| 2 | `sa_deep_scan` | Deep Scan | 2 | +15 Corruption Resistance |
| 3 | `sa_last_stand` | **KEYSTONE: Last Stand** | 3 | While on Death's Door, gain +10 Block at start of turn and your Death's Door timer does not tick down. |

*Last Stand makes Death's Door survivable indefinitely for the Sysadmin. Combined with the Berserker archetype, you can stay at 1 HP forever while dealing massive damage.*

---

#### CRYPTOMANCER: "Dark Codex"

##### Branch 1: Corruption Power (Offense)
*Corruption IS your weapon. The deeper you fall, the more devastating your attacks.*

| Tier | ID | Name | Cost | Effect |
|---|---|---|---|---|
| 0 | `cm_dark_pulse` | Dark Pulse | 1 | SHADOW attacks deal +3 damage |
| 1 | `cm_void_strike` | Void Strike | 1 | +20% Damage |
| 2 | `cm_chaos_bolt` | Chaos Bolt | 2 | At Corrupted tier (50+), gain +2 Strength at combat start |
| 3 | `cm_annihilate` | **KEYSTONE: Annihilate** | 3 | Your damage multiplier from Corruption is doubled. (Tainted: 1.2x, Corrupted: 1.5x, Demonic: 2.0x) |

*Annihilate makes Demonic tier give 2x damage instead of 1.5x. At 75+ Corruption with the Cryptomancer's +25% passive, attacks hit for 2.5x base damage. Glass cannon perfected.*

##### Branch 2: Corruption Mastery (Utility)
*Control the corruption. Manage the burn. Ride the edge without falling off.*

| Tier | ID | Name | Cost | Effect |
|---|---|---|---|---|
| 0 | `cm_dark_embrace` | Dark Embrace | 1 | +10 Corruption Resistance |
| 1 | `cm_soul_siphon` | Soul Siphon | 1 | Whenever you deal killing damage, heal 5 HP |
| 2 | `cm_void_shield` | Void Shield | 2 | SHADOW Skill cards gain +5 Block. +5 Corruption Resistance. |
| 3 | `cm_dark_transcendence` | **KEYSTONE: Dark Transcendence** | 3 | Corruption burn damage is reduced by 3 (Corrupted: 0 instead of 2, Demonic: 2 instead of 5). Corruption can exceed 100 (max 150). |

*Dark Transcendence eliminates the self-damage at Corrupted tier entirely and reduces Demonic burn to 2. This makes high-corruption builds sustainable long-term.*

##### Branch 3: Glass Cannon (Offense 2)
*Trade everything for damage. HP is just another resource.*

| Tier | ID | Name | Cost | Effect |
|---|---|---|---|---|
| 0 | `cm_empower` | Empower | 1 | +2 Damage |
| 1 | `cm_reckless` | Reckless | 1 | +25% Damage when below 50% HP |
| 2 | `cm_blood_magic` | Blood Magic | 2 | You may pay HP instead of Energy to play cards (1 Energy = 8 HP). |
| 3 | `cm_final_form` | **KEYSTONE: Final Form** | 3 | While below 25% HP: +50% Damage, +50% Block, draw +2 cards per turn. |

*Final Form is the ultimate Berserker keystone. At 25% HP on a 70-HP Cryptomancer (17 HP), you get massive offensive and defensive bonuses. Corruption burn actively helps you reach this threshold.*

---

#### WHITE HAT: "Divine Protocol"

##### Branch 1: Holy Strike (Offense)
*Righteous fury. Holy attacks that purify as they destroy.*

| Tier | ID | Name | Cost | Effect |
|---|---|---|---|---|
| 0 | `wh_smite` | Smite | 1 | HOLY attacks deal +3 damage |
| 1 | `wh_divine_wrath` | Divine Wrath | 1 | MELEE HOLY attacks deal +15% damage |
| 2 | `wh_righteous_fury` | Righteous Fury | 2 | Whenever you remove Corruption, gain +1 Strength (max 3 per combat) |
| 3 | `wh_judgment` | **KEYSTONE: Judgment** | 3 | HOLY attacks deal bonus damage equal to 2x the Corruption you have removed this combat (tracked, max +30). |

*Judgment rewards aggressive corruption removal. Play Sanctify 5 times (-15 corruption removed) = +30 bonus damage on all Holy attacks. The Purifier becomes a damage dealer.*

##### Branch 2: Protection (Defense)
*The team's shield. Protect allies, absorb damage, sustain.*

| Tier | ID | Name | Cost | Effect |
|---|---|---|---|---|
| 0 | `wh_blessing` | Blessing | 1 | +3 Block |
| 1 | `wh_sanctuary` | Sanctuary | 1 | +15% Block |
| 2 | `wh_divine_shield` | Divine Shield | 2 | At the start of combat, gain Block equal to 15% of your Max HP. Allies gain half that. |
| 3 | `wh_absolution` | **KEYSTONE: Absolution** | 3 | Whenever you play a HOLY card, all allies gain 3 Block and heal 1 HP. |

*Absolution turns every Holy card into a party-wide buff. With the White Hat's passive reducing Holy costs, you can spam cheap Holy cards for constant team sustain.*

##### Branch 3: Purification (Utility)
*Corruption is the enemy. Remove it from yourself, from allies, from existence.*

| Tier | ID | Name | Cost | Effect |
|---|---|---|---|---|
| 0 | `wh_cleanse` | Cleanse | 1 | +15 Corruption Resistance |
| 1 | `wh_purify` | Purify | 1 | +15% Healing |
| 2 | `wh_holy_light` | Holy Light | 2 | Whenever you remove Corruption from an ally, that ally also heals 3 HP |
| 3 | `wh_divine_mandate` | **KEYSTONE: Divine Mandate** | 3 | At the start of each turn, remove 5 Corruption from yourself and 3 from all allies. |

*Divine Mandate is automatic corruption removal. In a 4-player party, that is 5+9 = 14 corruption removed per turn across the team. The White Hat becomes the anti-corruption anchor.*

---

#### TECHNOMANCER: "Daemon Forge"

##### Branch 1: Construct (Offense)
*Build an army. Daemons are your weapons.*

| Tier | ID | Name | Cost | Effect |
|---|---|---|---|---|
| 0 | `tm_overclock` | Overclock | 1 | TECH attacks deal +2 damage |
| 1 | `tm_compile` | Compile | 1 | Daemon Fragment cards deal +3 damage |
| 2 | `tm_execute` | Execute | 2 | Whenever you play a Daemon Fragment, gain 1 Block |
| 3 | `tm_hive_mind` | **KEYSTONE: Hive Mind** | 3 | Daemon Fragments cost 0 energy and draw 1 card when played. At end of turn, create 1 extra Daemon Fragment. |

*Hive Mind makes Daemon Fragments free cantrips. Combined with Daemon Process (create 1 per turn) and the passive (2+ cost = create fragment), the Technomancer floods the board with free cards.*

##### Branch 2: Efficiency (Utility)
*Resource optimization. More energy, more draws, more everything.*

| Tier | ID | Name | Cost | Effect |
|---|---|---|---|---|
| 0 | `tm_cache` | Cache | 1 | +1 Mana Regen |
| 1 | `tm_optimize` | Optimize | 2 | TECH cards cost 1 less energy (min 1) |
| 2 | `tm_pipeline` | Pipeline | 2 | +1 Card Draw per turn. Whenever you play a TECH card, gain 1 Block. |
| 3 | `tm_quantum_core` | **KEYSTONE: Quantum Core** | 3 | +2 Max Energy. The first card you play each turn is free (costs 0 energy). |

*Quantum Core gives 6 effective energy per turn (4 base + 2 bonus, with one free card). Enables playing expensive combo pieces alongside cheap cantrips.*

##### Branch 3: Resilience (Defense)
*Survive through adaptation. Self-repair, corruption management, tenacity.*

| Tier | ID | Name | Cost | Effect |
|---|---|---|---|---|
| 0 | `tm_firewall` | Firewall | 1 | +3 Block |
| 1 | `tm_patch` | Patch | 1 | +10% Block. Heal 2 HP at end of each turn. |
| 2 | `tm_debug` | Debug | 2 | +8 Max HP. +10 Corruption Resistance. |
| 3 | `tm_safe_mode` | **KEYSTONE: Safe Mode** | 3 | Corruption cannot exceed 49 (you can never enter Corrupted or Demonic tier). +10% Damage. +10% Block. |

*Safe Mode caps corruption at Tainted tier. You still get the +10% damage from Tainted, plus the flat bonuses, but are immune to corruption burn and card mutations. The safe choice.*

---

#### SCOURGE: "Black Flag Protocol"

##### Branch 1: Plunder (Offense)
*More Contraband. Better Contraband. Contraband everywhere.*

| Tier | ID | Name | Cost | Effect |
|---|---|---|---|---|
| 0 | `sc_raider` | Raider | 1 | PIRACY attacks deal +2 damage |
| 1 | `sc_loaded_dice` | Loaded Dice | 1 | Contraband cards deal +3 damage |
| 2 | `sc_pillage` | Pillage | 2 | Whenever you play a Contraband card, steal 2 Block from random enemy |
| 3 | `sc_dread_pirate` | **KEYSTONE: Dread Pirate** | 3 | Contraband cards cost 0, draw 1, and deal +4 damage. |

*Dread Pirate transforms Contraband into free cantrips that hit hard. Combined with Pirate King power card, Contraband becomes 0-cost, +8 damage, draw 1. Absurd flood turns.*

##### Branch 2: Sabotage (Enabler)
*Strip enemies bare. Your team hits harder because you took everything first.*

| Tier | ID | Name | Cost | Effect |
|---|---|---|---|---|
| 0 | `sc_case_the_joint` | Case the Joint | 1 | +1 Card Draw per turn |
| 1 | `sc_exploit_weakness` | Exploit Weakness | 1 | When you steal Block, steal 50% more (rounded up) |
| 2 | `sc_crippling_blow` | Crippling Blow | 2 | PIRACY cards apply 1 Weak to the target |
| 3 | `sc_letters_of_marque` | **KEYSTONE: Letters of Marque** | 3 | Once per turn, the first PIRACY card you play strips all Strength from the target. You gain half (rounded down). |

*Letters of Marque turns the Scourge into the ultimate debuffer. Strip a boss's 10 Strength on turn 1, gain 5 for yourself. The team hits a naked target.*

##### Branch 3: Corsair (Defense / Corruption)
*Corruption isn't a cost — it's plunder fuel.*

| Tier | ID | Name | Cost | Effect |
|---|---|---|---|---|
| 0 | `sc_thick_hull` | Thick Hull | 1 | +3 Block to all cards |
| 1 | `sc_spoils_of_war` | Spoils of War | 1 | Whenever you gain Corruption, gain 1 Block per corruption gained |
| 2 | `sc_armored_brigantine` | Armored Brigantine | 2 | +8 Max HP. Contraband cards also gain 3 Block. |
| 3 | `sc_ghost_ship` | **KEYSTONE: Ghost Ship** | 3 | At the start of each turn, create 1 Contraband. Corruption burn is converted to Block instead of damage. |

*Ghost Ship is the signature keystone. At Demonic tier (75+), you'd normally take 5 damage/turn. Instead you gain 5 Block/turn AND a free Contraband. Corruption becomes pure upside.*

---

### 7.4 Keystone Summary Table

| Character | Branch 1 Keystone | Branch 2 Keystone | Branch 3 Keystone |
|---|---|---|---|
| **Netrunner** | Overdrive (scaling damage per card played) | Quantum Dodge (hand size = Block) | Backdoor Access (first Exploit card plays twice) |
| **Sysadmin** | Unbreakable (50% Block carries over) | Crushing Blow (25% Block added as damage) | Last Stand (Death's Door doesn't tick) |
| **Cryptomancer** | Annihilate (doubled corruption damage mult) | Dark Transcendence (corruption burn -3) | Final Form (+50% everything below 25% HP) |
| **White Hat** | Judgment (corruption removed = holy damage) | Absolution (Holy cards buff all allies) | Divine Mandate (auto-purify 5+3 corruption/turn) |
| **Technomancer** | Hive Mind (Daemons are free cantrips) | Quantum Core (+2 energy, first card free) | Safe Mode (corruption capped at 49) |
| **Scourge** | Dread Pirate (Contraband costs 0, +4 dmg, draw 1) | Letters of Marque (first PIRACY strips all Strength) | Ghost Ship (corruption burn → Block, free Contraband) |

---

## 8. Corruption Integration

### 8.1 How Corruption Flows Through Every System

Corruption is the universal currency that binds all five systems together.

#### Cards and Corruption

| Card Behavior | Examples | Corruption Effect |
|---|---|---|
| Power attacks generate corruption | Void Blast (+8), Entropy Wave (+10) | Risk/reward: more damage = more corruption |
| Holy cards remove corruption | Sanctify (-3), Purge Routine (-5) | White Hat's primary role |
| Corruption-scaling cards | Corruption Spike (dmg = corruption/5), Event Horizon (dmg = corruption) | Corruption Lord's payoff |
| Curses add passive corruption | Glitch (+3/turn while in hand) | Penalty mechanic |
| 2+ energy cards auto-add 1 corruption | Engine-level rule (CorruptionSystem.get_card_corruption) | Baseline corruption generation |

#### Gems and Corruption

| Gem | Corruption Interaction |
|---|---|
| Pearl of Purity | Overrides corruption gain to -3 (turns corruption-generating cards into purifiers) |
| Obsidian Shard | +5 corruption per play (high risk, high reward) |
| Crimson Opal | Only active at Corrupted tier (50+) -- rewards high corruption |
| Bloodstone of Sacrifice | Below 50% HP trigger synergizes with corruption burn (burn lowers HP = activates gem) |

#### Relics and Corruption

| Relic | Corruption Interaction |
|---|---|
| Shadow Idol | Forces start at 25 corruption (Tainted immediately) |
| Corrupted Core | Forces start at 50 corruption (Corrupted immediately) |
| Holy Grail | +3 extra corruption removal on Holy cards |
| Phoenix Feather | On-death trigger adds +20 corruption |
| Entropy Crystal | Corruption gain = Block gain (turns corruption into defense) |
| Corruption Siphon | Transfers corruption between allies (team management) |

#### Equipment and Corruption

| Equipment | Corruption Interaction |
|---|---|
| Corruption Filter (Head) | +10 Corruption Resistance (reduces all gains) |
| Void Plate (Chest) | +5 Corruption at combat start (forces Tainted) |
| Shadow Fang (Weapon) | +3 Corruption per combat (mild increase for damage) |
| Heart of Corruption (Accessory) | Damage scales with corruption tier (0/20/40/60%) |
| Harmony Pendant (Accessory) | Only works at Pure (0 corruption). Anti-corruption build. |

#### Skill Tree and Corruption

| Node/Keystone | Corruption Interaction |
|---|---|
| Annihilate (CM) | Doubles corruption tier damage multiplier |
| Dark Transcendence (CM) | Reduces corruption burn by 3 |
| Safe Mode (TM) | Caps corruption at 49 (can never reach Corrupted) |
| Divine Mandate (WH) | Auto-removes 5 corruption from self + 3 from allies per turn |
| Judgment (WH) | Tracks corruption removed; converts to Holy damage |
| Final Form (CM) | Below 25% HP bonus -- corruption burn helps reach threshold |
| Blood Magic (CM) | HP-as-energy; corruption burn accelerates this |
| Ghost Ship (SC) | Converts corruption burn to Block. Demonic tier = 5 free Block/turn + Contraband. |
| Spoils of War (SC) | Corruption gain = Block gain. Every corruption point is also a point of defense. |
| Letters of Marque (SC) | First PIRACY card strips all enemy Strength. Enables high-corruption aggressive play. |

### 8.2 Corruption Tier Breakpoints

| Tier | Corruption | Damage Mult | Burn/Turn | Card Mutations | Strategic Implication |
|---|---|---|---|---|---|
| **Pure** | 0-24 | 1.0x | 0 | None | Safe but weak. Holy Purifier territory. |
| **Tainted** | 25-49 | 1.1x | 0 | None | Free power. Everyone should be comfortable here. |
| **Corrupted** | 50-74 | 1.25x | 2 HP | Some cards gain self-damage riders | The decision point. Is the burn worth it? |
| **Demonic** | 75+ | 1.5x | 5 HP | Most cards mutate; unpredictable side effects | Corruption Lord only. Needs Dark Transcendence to survive. |

### 8.3 Corruption Management Strategies by Archetype

| Archetype | Target Tier | How They Manage It |
|---|---|---|
| Glass Cannon | Corrupted-Demonic (50-80) | Ride the edge. Die fast or kill fast. |
| Iron Wall | Pure-Tainted (0-30) | Avoid corruption. Use System Patch, Corruption Filter. |
| Card Engine | Tainted (25-45) | Many cards = gradual gain. Manage with occasional purge. |
| Corruption Lord | Demonic (75+) | Maximize. Dark Transcendence reduces burn. Event Horizon as pressure valve. |
| Holy Purifier | Pure (0-10) | Aggressively remove. Harmony Pendant rewards 0 corruption. |
| Daemon Swarm | Tainted (25-40) | Daemon cards generate mild corruption. Manageable. |
| Debuff Controller | Any (varies) | Debuff cards are low-corruption. Flexible. |
| Berserker | Corrupted (50-70) | Corruption burn helps get HP low. Feature, not bug. |
| Pirate King | Corrupted-Demonic (50-75) | Ghost Ship converts burn to Block. Spoils of War turns gain into defense. |

---

## 9. Power Budget

### 9.1 Power by Rarity (Cards)

A card's "power budget" is its total impact per energy spent.

| Rarity | Damage/Energy | Block/Energy | Draw/Energy | Extra Effects |
|---|---|---|---|---|
| **Common** | 5-7 | 5-8 | 1 | 0-1 simple riders |
| **Uncommon** | 7-10 | 8-12 | 1-2 | 1-2 riders (debuff, self-buff, corruption) |
| **Rare** | 10-15 | 12-18 | 2-3 | 2-3 complex effects, conditional bonuses |
| **Legendary** | 15-25+ | 20-30+ | 3-5 | Game-changing, often Exhaust |

### 9.2 Power by System Layer

How much of a character's total combat power comes from each system at the end of a run.

| Layer | % of Total Power | Examples at End of Act 3 |
|---|---|---|
| **Cards** | 35% | Upgraded deck of 15-20 cards with clear synergies |
| **Skill Tree** | 20% | 1 complete branch (keystone) + tier 0-1 of a second |
| **Equipment** | 15% | 4 equipped items, ideally rare, matching build tags |
| **Gems** | 15% | 4-6 gems socketed in key cards, transforming behavior |
| **Relics** | 15% | 3-5 relics collected through the run, at least 1 build-enabling |

### 9.3 Fully Built Character Examples

#### Example: End-of-Act-3 Netrunner (Card Engine build)

**Stats:** 80 HP, 5 Energy, 8 cards drawn per turn
**Corruption:** Tainted (35)

**Equipment:**
- Head: Neural Interface (+1 draw, TECH +2 dmg)
- Chest: Mithril Vest (+5 block, +10% block)
- Weapon: Plasma Edge (+3 dmg, TECH +15%)
- Accessory: Exploit Chip (EXPLOIT +15%, first per turn -1 cost)

**Skill Tree:** Exploit branch maxed (Backdoor Access keystone) + Velocity tier 0-1

**Key Cards:** Zero-Day Exploit (socketed: Topaz of Wrath), Packet Storm (socketed: Garnet of Cascade), Kernel Panic, Network Tap (power), Botnet Cascade

**Relics:** Hacker's Manual, Data Shard, Swift Boots

**Turn 1 plan:** Play Network Tap (power). Play Backdoor to draw 2 + apply Vulnerable. Backdoor Access doubles it (draw 4, 2 Vulnerable). Play Zero-Day Exploit on Vulnerable target (+30% from Topaz = ~26 damage). Play Kernel Panic (draw 2 more). Likely played 5+ cards, Swift Boots gives energy refund.

**Effective DPT (Damage Per Turn):** ~45-60 with full engine running.

#### Example: End-of-Act-3 Cryptomancer (Corruption Lord build)

**Stats:** 70 HP, 3 Energy, 5 cards drawn per turn
**Corruption:** Demonic (85). With Dark Transcendence: 2 burn/turn.

**Equipment:**
- Head: Oracle Crown (+2 draw, -5 HP)
- Chest: Void Plate (+15% block, +15% damage)
- Weapon: Shadow Fang (+4 dmg, SHADOW +10%)
- Accessory: Heart of Corruption (+60% damage at Demonic)

**Skill Tree:** Corruption Power maxed (Annihilate keystone) + Corruption Mastery tier 0-1

**Damage multiplier stack:**
- Base corruption mult: 2.0x (Annihilate doubles Demonic's 1.5x)
- Cryptomancer passive: x1.25 (corruption >= 50)
- Heart of Corruption: +60%
- Void Plate: +15%
- Shadow Fang: +10% (SHADOW) + 4 flat
- Total on a SHADOW attack: base x (2.0) x (1.25) x (1.85) = ~4.6x multiplier

**A Dark Compile (8 base damage) hits for: ~37 damage for 1 energy.**

**Effective DPT:** ~80-110. But taking 2 burn/turn and has only 65 HP. True glass cannon.

#### Example: End-of-Act-3 White Hat (Holy Purifier in 4-player co-op)

**Stats:** 88 HP, 3 Energy, 5 cards drawn per turn
**Corruption:** Pure (0-5). Divine Mandate removes 5/turn.

**Equipment:**
- Head: Reinforced Helm (+8 HP, +3 block)
- Chest: Holy Vestments (+8 block, +20% healing)
- Weapon: Holy Avenger (HOLY +25%, HOLY -2 extra corruption)
- Accessory: Harmony Pendant (+10% all at Pure)

**Skill Tree:** Purification maxed (Divine Mandate keystone) + Protection tier 0-1

**Relics:** Holy Grail, Medic Drone, Corruption Siphon

**Per-turn team impact:**
- Divine Mandate: remove 5 from self + 3 from each ally (14 total corruption removed)
- Absolution (if branch 2 partially taken): each Holy card = 3 block + 1 heal to all allies
- Holy Grail: +3 extra removal per Holy card
- Playing Sanctify: 7 damage + 3+3+2 = 8 corruption removed + party gets 3 block + 1 heal
- Corruption Siphon: pulls 3 corruption from highest-corruption ally

**Role:** Not the damage dealer. The reason the Corruption Lord can survive at 85 corruption without dying. Removes ~20+ corruption from the party per turn.

### 9.4 Diminishing Returns

Each system has built-in ceilings to prevent infinite scaling:

| System | Ceiling | Mechanism |
|---|---|---|
| **Damage** | ~5x multiplier | Percent_add stacks additively, then one PERCENT_MULT. Two 50% boosts = 2.0x, not 2.25x. |
| **Block** | ~50 per turn (without carryover) | Block resets. Only Unbreakable keystone enables stacking, and that decays 50%. |
| **Draw** | ~10 cards/turn | Diminishing value: past 8 cards, you run out of energy to play them. |
| **Corruption Damage** | 2.0x (with Annihilate) | Hard cap at Demonic tier. Burn increases linearly. |
| **Energy** | ~6 effective energy | Quantum Core is +2 + free first card. Power Surge adds 1. Battery Pack adds 1. Total ~6-7. |
| **Healing** | Halved by Pride sin | Can't stall infinitely. Sin system punishes heal spam. |

---

## 10. Co-op Synergies

### 10.1 Party Role Matrix

In a 4-player party, the ideal composition covers all roles:

| Role | Function | Best Characters | Key Mechanic |
|---|---|---|---|
| **Damage** | Kill things fast | Cryptomancer, Netrunner | Mark Target (+50% from all sources) |
| **Tank** | Absorb hits, share block | Sysadmin | Shared Shield, Fortress Mode |
| **Support** | Heal, purify, buff | White Hat | Party heal, corruption removal |
| **Utility** | Debuff, draw for team, manage resources | Technomancer, Netrunner | Overclocked Network, Mana Link |
| **Enabler** | Strip enemy defenses, weaken for team | Scourge | Steal Block, strip Strength, apply Weak via PIRACY |

### 10.2 Emergent Team Combos

#### Combo: "The Purge Engine" (White Hat + Cryptomancer)

**Setup:** White Hat has Divine Mandate (auto -5 corruption/turn from self, -3 from allies). Cryptomancer runs at Demonic (85+ corruption).

**Synergy:** Without the White Hat, the Cryptomancer dies to corruption burn in ~13 turns. With the White Hat removing 3/turn, corruption stays manageable. The White Hat's Judgment keystone also tracks corruption removed -- removing 3 from the Cryptomancer per turn fuels the White Hat's own damage.

**Result:** The Cryptomancer deals 4.5x damage. The White Hat keeps them alive AND gets stronger from doing so. Symbiotic.

#### Combo: "The Mark and Execute" (Netrunner + Sysadmin)

**Setup:** Netrunner plays Mark Target (0 cost, marks enemy for +50% damage from all sources). Sysadmin plays Body Slam (damage = current Block).

**Synergy:** With Unbreakable keystone, the Sysadmin starts the turn with 20+ carried-over Block. Plays Hardened Kernel (+14 more = 34 Block). Body Slam deals 34 damage x1.5 (marked) = 51 damage. The Netrunner's 0-cost Mark Target enabled the Sysadmin's biggest hit.

**Result:** 51 damage from a "defensive" character, enabled by a 0-cost card from the Netrunner.

#### Combo: "The Daemon Flood" (Technomancer + Netrunner)

**Setup:** Technomancer has Hive Mind (Daemon Fragments are free cantrips that draw 1). Netrunner has Overclocked Network (party draw +1 next turn).

**Synergy:** Technomancer plays 4 Daemon Fragments (0 cost each, draw 1 each = 4 cards drawn). Netrunner's Overclocked Network gives the Technomancer +1 draw. Combined with God Compiler (create 2 fragments/turn + fragments deal +3), the Technomancer plays ~8 cards per turn.

**Result:** The Technomancer becomes a card-playing machine, triggering any "on play" effects 8+ times per turn. If they have Data Shard relic (play 3+ cards = draw 1), they draw even more.

#### Combo: "Death's Defiance" (Sysadmin + White Hat)

**Setup:** Sysadmin has Last Stand (Death's Door doesn't tick). White Hat has Absolution (Holy cards heal all allies 1 HP + 3 Block).

**Synergy:** The Sysadmin intentionally enters Death's Door (1 HP). Last Stand means they never die from the timer. Berserker cards deal massive damage at low HP. The White Hat's passive healing keeps them at 1 HP (they don't need more). The Sysadmin gets +10 Block/turn from Last Stand AND the White Hat's 3 Block per Holy card.

**Result:** The Sysadmin is functionally immortal while dealing Berserker-level damage. The White Hat's tiny 1-HP heals are the safety net.

#### Combo: "The Plunder Engine" (Scourge + Cryptomancer + White Hat)

**Setup:** Scourge has Ghost Ship (corruption burn → Block, free Contraband/turn) and Letters of Marque (first PIRACY strips all Strength). Cryptomancer is at Demonic tier. White Hat has Divine Mandate (auto-purify).

**Synergy:** Scourge plays Hijack Protocol first — strips ALL Block AND all Strength from the boss (Letters of Marque). Scourge gains half the Strength. Boss now has 0 Block, 0 Strength. Cryptomancer hits the naked boss with Event Horizon (damage = corruption, ~85 damage). White Hat keeps both alive by removing 3 corruption from each per turn.

**Result:** Scourge enables a one-shot by stripping every defensive stat. Cipher delivers the killing blow. White Hat is the reason they don't both die to corruption burn. Three-way symbiosis.

#### Combo: "Full Party Block" (Sysadmin + everyone)

**Setup:** Sysadmin plays Absolute Defense (50 Block to self, 15 to all allies). Has Resonance Link power (when you gain Block, allies gain 2).

**Synergy:** Every block card the Sysadmin plays sends 2 Block to each ally. Absolute Defense sends 15 directly. In a 4-player party, the Sysadmin's block generation becomes party-wide defense.

**Result:** The team does not need to play their own block cards. The Sysadmin handles ALL defense, freeing 3 other players to focus entirely on offense, draw, and debuffs.

### 10.3 Enemy Scaling and Co-op Balance

| Players | Enemy HP Mult | Player Power Mult (approx) | Balance Notes |
|---|---|---|---|
| 1 | 1.0x | 1.0x | Baseline. Player must cover all roles. |
| 2 | 1.5x | ~1.8x | Slight advantage to players (specialization > generalism). |
| 3 | 2.0x | ~2.5x | Team combos start to dominate. Mark Target very strong. |
| 4 | 2.5x | ~3.5x | Full party synergies. Roles are fully specialized. Bosses need raid mechanics to stay threatening. |

The power increase is superlinear because specialization enables multiplicative synergies (Mark Target x Glass Cannon x Debuff Controller). Boss raid mechanics (shields, phase transitions, party-damage attacks) exist specifically to challenge optimized 4-player parties.

### 10.4 Co-op Card Interactions

| Card | Solo Effect | Co-op Effect |
|---|---|---|
| Mark Target | +50% damage for you | +50% damage for ALL players (massive in 4-player) |
| Shared Shield | Share your block | In 4-player: 40 block / 4 = 10 each (less per player but collective gain) |
| Mana Link | No target (wasted) | Transfer 2 energy to lowest-energy ally (enables big plays) |
| Soul Transfer | Heal 4 HP (just you) | Party heal 4 HP (12 effective healing in 4-player) |
| Overclocked Network | +1 draw next turn | ALL players +1 draw next turn (4 extra draws total) |
| Sacrifice Subroutine | Take 6 damage for nothing | Take 6 damage, ally heals 10 and draws 1 (net positive) |
| Revival Protocol | Wasted (can't self-revive) | Revive dead ally at 15 HP (game-changing in co-op) |
| Combined Assault | 8 damage + mark | 8 damage + mark + all allies deal +3 (scales with player count) |

### 10.5 Character Pairing Recommendations

| Pair | Synergy Rating | Why |
|---|---|---|
| Cryptomancer + White Hat | **S-tier** | Purifier enables Corruption Lord. Symbiotic damage. |
| Netrunner + Sysadmin | **A-tier** | Debuff + tank. Mark Target + Body Slam. |
| Technomancer + Netrunner | **A-tier** | Card engine overflow. Daemon + Exploit flood. |
| Sysadmin + White Hat | **A-tier** | Unkillable duo. Sustain fortress. |
| Cryptomancer + Technomancer | **B-tier** | Both generate corruption. Need external purification. |
| Scourge + Cryptomancer | **A-tier** | Scourge strips defenses, Cipher nukes the naked target. Both embrace corruption. |
| Scourge + White Hat | **S-tier** | Scourge strips enemy defenses. White Hat cleanses Scourge's corruption. Perfect symbiosis. |
| Scourge + Sysadmin | **A-tier** | Scourge steals block from enemies, Sysadmin holds the line. Combined: enemies have 0 block and face a wall. |
| Scourge + Netrunner | **B-tier** | Overlap in utility/debuff. Both are fast and tricky but lack raw defense. |
| White Hat + White Hat (co-op) | **C-tier** | Too much support, not enough damage. |

---

## Appendix A: Implementation Priority

| Priority | System | Effort | Dependencies |
|---|---|---|---|
| 1 | Skill tree keystone rework | Medium | Modifier pipeline (done) |
| 2 | Gem category rework (triggers, converts) | High | GemSystem needs new effect types beyond modifiers |
| 3 | New card data files (152 cards, 6 characters) | High | CardData schema (done), see CARD_CATALOG.md |
| 4 | Relic effect rework (triggers, conditionals) | High | RelicData needs new effect fields |
| 5 | Equipment tag synergy | Low | ModifierData conditions (done) |
| 6 | Corruption integration testing | Medium | All above systems |

## Appendix B: Data Schema Extensions Needed

### GemData Extensions

Current `on_play_modifiers` handles Amplify/Sustain/Corrupt gems. New categories need:

```gdscript
# Trigger gems need an event + effect pair
@export var trigger_event: String = ""  # "on_kill", "on_unblocked_hit", "on_play"
@export var trigger_effect: String = ""  # "draw", "gain_energy", "apply_weak"
@export var trigger_value: int = 0

# Convert gems need flag overrides
@export var convert_damage_to_heal: bool = false
@export var override_corruption_gain: int = -999  # -999 = no override
@export var add_share_block: bool = false
```

### RelicData Extensions

Current RelicData has flat start-of-combat bonuses. New categories need:

```gdscript
# Trigger relics
@export var trigger_event: String = ""       # "on_cards_played_3", "on_hp_lost_10", "on_ally_deaths_door"
@export var trigger_effect: String = ""      # "draw", "gain_strength", "gain_block"
@export var trigger_value: int = 0

# Build-enabling relics
@export var block_decay_percent: float = -1.0    # If >= 0, block decays by this % instead of resetting
@export var first_card_free: bool = false         # First card each turn costs 0
@export var corruption_start: int = 0             # Start combat with this corruption
@export var max_corruption_override: int = -1     # Cap corruption at this value

# Co-op relics
@export var ally_block_on_damage: int = 0         # Gain this block when ally takes damage
@export var party_heal_multiplier: float = 1.0    # Multiplier on all party heals
```

### SkillNodeData Extensions

Current nodes only support modifier specs. Keystones need:

```gdscript
# Flag for keystone (UI treatment + one-per-tree restriction)
@export var is_keystone: bool = false

# Keystone-specific effect keys (checked by CombatEngine/StatResolver)
@export var keystone_effect: String = ""
# Values: "block_carryover_50", "block_as_damage_25", "deaths_door_freeze",
#          "corruption_mult_double", "corruption_burn_minus_3", "hp_as_energy_8",
#          "below_25_all_50", "scaling_damage_per_card", "hand_size_block_3",
#          "first_exploit_double", "judgment_holy_bonus", "holy_party_buff",
#          "auto_purify_5_3", "daemon_free_cantrip", "first_card_free_plus2",
#          "corruption_cap_49",
#          "contraband_free_cantrip", "strip_strength_first_piracy",
#          "corruption_burn_to_block"
```

---

## Appendix C: Card Tag Reference

| Tag Enum | Name | Characters | Equipment Synergy | Skill Tree Synergy |
|---|---|---|---|---|
| 0 | MELEE | Sysadmin, White Hat | Flame Gauntlets, Berserker Gauntlet | Sysadmin branches, WH Holy Strike |
| 1 | RANGED | Netrunner | -- | Netrunner Velocity |
| 2 | FIRE | Shared | Flame Gauntlets | -- |
| 3 | ICE | Shared | -- | -- |
| 4 | HOLY | White Hat | Holy Avenger, Holy Vestments, Blessed Armor | All WH branches |
| 5 | SHADOW | Cryptomancer, Technomancer | Shadow Fang, Daemon Chassis | CM branches, TM Construct |
| 6 | TECH | Netrunner, Sysadmin, Technomancer | Plasma Edge, Neural Interface | NR/SA/TM branches |
| 7 | EXPLOIT | Netrunner, Cryptomancer, Technomancer | Exploit Chip | NR Exploit branch |
| 8 | PIRACY | Scourge | (Pirate equipment TBD) | SC Plunder, Sabotage, Corsair branches |
| 9 | CURSE | Curses/Status | -- | -- |
