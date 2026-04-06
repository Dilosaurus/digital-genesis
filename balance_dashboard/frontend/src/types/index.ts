// ---------------------------------------------------------------------------
// Enums — string unions matching Godot's Enums class (enums.gd)
// ---------------------------------------------------------------------------

export type Stat =
  | 'DAMAGE'
  | 'BLOCK'
  | 'HEALING'
  | 'MAX_HP'
  | 'MAX_ENERGY'
  | 'DRAW_PER_TURN'
  | 'ENERGY_COST'
  | 'CORRUPTION_GAIN'
  | 'CORRUPTION_RESIST'

export type ModOp = 'FLAT_ADD' | 'PERCENT_ADD' | 'PERCENT_MULT' | 'OVERRIDE'

// Note: SINGLE_USE from the original spec doesn't exist in GDScript — actual
// values are PERMANENT | COMBAT | TURN | CARD_PLAY | CONDITIONAL
export type ModLifecycle = 'PERMANENT' | 'COMBAT' | 'TURN' | 'CARD_PLAY' | 'CONDITIONAL'

export type CardTag =
  | 'MELEE'
  | 'RANGED'
  | 'FIRE'
  | 'ICE'
  | 'HOLY'
  | 'SHADOW'
  | 'TECH'
  | 'EXPLOIT'
  | 'CURSE'

// Note: TargetType actual values from enums.gd: ENEMY | SELF | ALL_ENEMIES | ALL_PLAYERS | NONE
export type CardType = 'ATTACK' | 'SKILL' | 'POWER' | 'STATUS' | 'CURSE'
export type TargetType = 'ENEMY' | 'SELF' | 'ALL_ENEMIES' | 'ALL_PLAYERS' | 'NONE'

// Note: EquipSlot actual values from enums.gd: HEAD | CHEST | WEAPON | ACCESSORY
export type EquipSlot = 'HEAD' | 'CHEST' | 'WEAPON' | 'ACCESSORY'

// Note: EnemyIntent actual values from enums.gd: ATTACK | DEFEND | BUFF | DEBUFF | UNKNOWN | HACK
export type EnemyIntent = 'ATTACK' | 'DEFEND' | 'BUFF' | 'DEBUFF' | 'UNKNOWN' | 'HACK'

export type SinType = 'WRATH' | 'SLOTH' | 'PRIDE'

// ---------------------------------------------------------------------------
// Core data types — matching JSON export format from the Godot backend
// ---------------------------------------------------------------------------

export interface ModifierConditions {
  required_card_tags?: CardTag[]
  required_card_type?: CardType | null    // null = any
  only_vs_vulnerable?: boolean
  only_when_hp_below_pct?: number         // -1 = disabled, 0.5 = below 50%
}

export interface ModifierData {
  id?: string
  stat: Stat
  operation: ModOp
  value: number
  lifecycle: ModLifecycle
  duration: number                        // -1 = not applicable
  conditions: ModifierConditions
  source_type: string                     // "equipment" | "gem" | "relic" | "skill_tree" | "status"
  source_id: string
}

// card_data.gd fields — all exported fields mapped 1:1
export interface Card {
  id: string
  display_name: string
  description: string
  energy_cost: number
  card_type: CardType
  target_type: TargetType
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
  upgraded: boolean
  upgrade_id: string
  tags: CardTag[]
  gem_sockets: number
}

export interface Relic {
  id: string
  display_name: string
  description: string
  rarity: string
  start_combat_strength: number
  start_combat_dexterity: number
  start_combat_block: number
  bonus_draw: number
  bonus_max_energy: number
  bonus_max_hp: number
  heal_on_combat_end: number
  corruption_resistance: number
}

export interface Equipment {
  id: string
  display_name: string
  description: string
  slot: EquipSlot
  rarity: string
  modifiers: ModifierData[]
}

export interface Gem {
  id: string
  display_name: string
  description: string
  rarity: string
  on_play_modifiers: ModifierData[]
}

export interface SkillNode {
  id: string
  display_name: string
  tier: number
  cost: number
  description: string
  prerequisites: string[]
  modifier_specs: ModifierData[]
  modifiers?: ModifierData[]
}

export interface EnemyIntentEntry {
  intent: EnemyIntent
  value?: number
  type?: EnemyIntent
  damage?: number
  block?: number
  [key: string]: unknown
}

export interface Enemy {
  id: string
  display_name: string
  max_hp: number
  intent_pool: EnemyIntentEntry[]
}

export interface CorruptionData {
  corrupted_cards: Record<string, unknown>
  shrine_corrupted_cards: Record<string, unknown>
}

// ---------------------------------------------------------------------------
// Graph types — for the dependency graph view
// ---------------------------------------------------------------------------

export interface GraphNode {
  id: string
  type: string
  label: string
  data: Record<string, unknown>
}

export interface GraphEdge {
  id: string
  source: string
  target: string
  label: string
}

export interface GraphData {
  nodes: GraphNode[]
  edges: GraphEdge[]
}

// ---------------------------------------------------------------------------
// Simulator types
// ---------------------------------------------------------------------------

// A player loadout sent to the simulator
export interface Loadout {
  relics: string[]
  equipment: Record<string, string>         // slot -> equipment_id
  gems: Record<string, string[]>            // card_id -> gem_id[]
  skills: string[]
  corruption_tier: number
  strength: number
  dexterity: number
  context: {
    vulnerable: boolean   // whether the target is vulnerable
    weak: boolean         // whether the player is weak
    hp_pct: number        // player HP percentage (0.0–1.0), for conditional mods
  }
}

// Per-modifier contribution entry used in breakdown arrays
export interface ModContribution {
  source: string
  value: number
}

// Full simulation result for a single card
export interface SimulationResult {
  card_id: string
  card_name: string
  // Before modifier pipeline
  base_damage: number
  base_block: number
  // After pre-stack adjustments (strength/dex added)
  adjusted_base_damage: number
  adjusted_base_block: number
  // Final values after full pipeline
  final_damage: number
  final_block: number
  final_heal: number
  // Step-by-step breakdowns per stat
  damage_flat_adds: ModContribution[]
  damage_pct_adds: ModContribution[]
  damage_pct_mults: ModContribution[]
  block_flat_adds: ModContribution[]
  block_pct_adds: ModContribution[]
  block_pct_mults: ModContribution[]
}
