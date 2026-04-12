/**
 * deus.exe // codex — shared TypeScript types
 *
 * Mirrors the pydantic models in backend/app/models/game.py. Everything
 * comes from .tres files via the FastAPI parser — treat these as the
 * canonical shape of game data.
 */

// ─── Enums (stringified on the wire) ─────────────────────────────────────

export type CardType = 'ATTACK' | 'SKILL' | 'POWER' | 'STATUS' | 'CURSE'
export type TargetType = 'ENEMY' | 'ALL_ENEMIES' | 'SELF' | 'NONE' | 'ALLY' | 'ALL_ALLIES' | 'PARTY' | 'MARKED_ENEMY'
export type Rarity = 'COMMON' | 'UNCOMMON' | 'RARE' | 'LEGENDARY'
export type CardTag =
  | 'MELEE' | 'RANGED' | 'FIRE' | 'ICE' | 'HOLY' | 'SHADOW'
  | 'TECH' | 'EXPLOIT' | 'PIRACY' | 'CURSE'
export type EquipSlot = 'HEAD' | 'CHEST' | 'WEAPON' | 'ACCESSORY'
export type CharacterClassName =
  | 'NETRUNNER' | 'SYSADMIN' | 'CRYPTOMANCER'
  | 'WHITE_HAT' | 'HERETIC' | 'SCOURGE'
export type Stat =
  | 'DAMAGE' | 'BLOCK' | 'HEAL' | 'DRAW' | 'ENERGY' | 'MAX_HP'
  | 'STRENGTH' | 'DEXTERITY' | 'CORRUPTION' | 'VULNERABLE' | 'WEAK'
  | 'MANA_REGEN' | string
export type ModOp = 'OVERRIDE' | 'FLAT_ADD' | 'PERCENT_ADD' | 'PERCENT_MULT'
export type ModLifecycle = 'PERMANENT' | 'THIS_COMBAT' | 'THIS_TURN' | 'UNTIL_USED'
export type EnemyIntentType = 'ATTACK' | 'DEFEND' | 'BUFF' | 'DEBUFF' | 'HACK' | 'UNKNOWN'

// ─── Modifier (shared sub-resource) ───────────────────────────────────────

export interface Modifier {
  id: string
  stat: Stat
  operation: ModOp
  value: number
  lifecycle: ModLifecycle
  duration: number
  required_card_tags?: CardTag[] | null
  required_card_type?: CardType | null
  only_vs_vulnerable?: boolean
  only_when_hp_below_pct?: number | null
}

// ─── Card ─────────────────────────────────────────────────────────────────

export interface Card {
  // Core identity
  id: string
  display_name: string
  description: string
  energy_cost: number
  card_type: CardType
  target_type: TargetType
  rarity: Rarity
  character_class: number              // -1 = shared, 0..5 = per-character
  tags: CardTag[]
  artwork: string                       // res://... path (empty if none)

  // Combat stats
  damage: number
  block: number
  heal: number
  draw: number
  hits: number
  apply_vulnerable: number
  apply_weak: number
  corruption_gain: number
  exhaust: boolean
  gain_strength: number
  gain_dexterity: number

  // Upgrade chain + sockets
  upgraded: boolean
  upgrade_id: string
  cooldown_max: number
  gem_sockets: number

  // Co-op / party
  party_heal: number
  party_draw: number
  party_damage: number
  share_block: boolean
  transfer_mana: number
  mark_target: boolean

  // Revival
  revive_ally: boolean
  revive_hp: number

  // Corruption removal
  corruption_remove: number
  party_corruption_remove: number

  // Scourge / PIRACY
  steal_block: number
  steal_all_block: boolean
  aoe_steal_block: number
  create_contraband: number
  destroy_contraband_for_damage: number
  destroy_contraband_for_block: number
  destroy_contraband_corruption: number
  damage_per_card_played: number
  damage_per_contraband_in_hand: number
  conditional_damage_if_zero_block: number
  aoe_damage: number

  // FLUX / Daemons
  create_daemon_fragment: number
  destroy_daemons_for_damage: number
}

// ─── Character ────────────────────────────────────────────────────────────

export interface Character {
  id: string
  display_name: string                  // "GHOST"
  title: string                          // "Blade of the Net"
  character_class: CharacterClassName
  character_class_index: number
  backstory: string
  passive_name: string
  passive_description: string
  starter_deck: string[]                // card ids
  starting_hp: number
  starting_energy: number
  color_primary: string                 // "#33D9F2"
  color_primary_rgba: [number, number, number, number]
  color_secondary: string
  color_secondary_rgba: [number, number, number, number]
  icon_text: string                     // "NR"
}

// ─── Gem ──────────────────────────────────────────────────────────────────

export interface Gem {
  id: string
  display_name: string
  description: string
  rarity: Rarity
  icon: string                           // res://... path
  on_play_modifiers: Modifier[]
  trigger_event: string
  trigger_effect: string
  trigger_value: number
  convert_damage_to_heal: number
  extra_hit_percent: number
  add_create_contraband: number
}

// ─── Relic ────────────────────────────────────────────────────────────────

export interface Relic {
  id: string
  display_name: string
  description: string
  rarity: Rarity
  icon: string
  start_combat_strength: number
  start_combat_dexterity: number
  start_combat_block: number
  bonus_draw: number
  bonus_max_energy: number
  bonus_max_hp: number
  heal_on_combat_end: number
  corruption_resistance: number
  auto_revive: boolean
}

// ─── Equipment ────────────────────────────────────────────────────────────

export interface Equipment {
  id: string
  display_name: string
  description: string
  slot: EquipSlot
  rarity: Rarity
  icon: string
  modifiers: Modifier[]
}

// ─── Enemy ────────────────────────────────────────────────────────────────

export interface EnemyIntent {
  intent: EnemyIntentType
  value: number
}

export interface EnemyPhase {
  hp_threshold: number                  // 0-1 float
  intent_pool: EnemyIntent[]
  on_enter: string
  on_enter_value: number
}

export interface Enemy {
  id: string
  display_name: string
  description: string
  lore: string
  max_hp: number
  artwork: string
  intent_pool: EnemyIntent[]
  phases: EnemyPhase[]
  xp_reward: number
}
