/**
 * Client-side modifier resolution pipeline.
 *
 * Ports modifier_stack.gd (resolve / _get_active_for_stat / _check_conditions)
 * and stat_resolver.gd (resolve_damage / resolve_block / resolve_healing) to
 * TypeScript so the Simulator page can show instant previews without a server
 * round-trip.
 *
 * Resolution order (mirrors modifier_stack.gd lines 40-75):
 *   1. OVERRIDE  — highest value wins, short-circuits the rest
 *   2. FLAT_ADD  — all additive flat bonuses applied to base
 *   3. PERCENT_ADD — all stack additively, then one multiply
 *   4. PERCENT_MULT — each multiplies independently
 *
 * Post-stack modifiers (mirrors stat_resolver.gd):
 *   - Vulnerable on target: damage × 1.5
 *   - Weak on player:       damage × 0.75
 *
 * Pre-stack adjustments (mirrors stat_resolver.gd):
 *   - adjusted_base_damage = base_damage + strength
 *   - adjusted_base_block  = base_block  + dexterity
 */

import type {
  Stat,
  ModOp,
  CardType,
  CardTag,
  ModifierData,
  Card,
  Relic,
  Equipment,
  Gem,
  SkillNode,
  Loadout,
  SimulationResult,
  ModContribution,
} from '../types'

// ---------------------------------------------------------------------------
// Context passed through the resolution pipeline
// ---------------------------------------------------------------------------

interface ResolveContext {
  card_type: CardType | null    // null = no card in context
  card_tags: CardTag[]
  target_vulnerable: boolean
  player_hp_pct: number         // 0.0–1.0
}

// ---------------------------------------------------------------------------
// Intermediate pipeline step — used for breakdown display
// ---------------------------------------------------------------------------

export interface PipelineStep {
  operation: ModOp | 'PRE_STACK' | 'POST_STACK_VULNERABLE' | 'POST_STACK_WEAK'
  source: string
  value: number
  running_total: number
}

export interface ResolveResult {
  steps: PipelineStep[]
  final: number
}

// ---------------------------------------------------------------------------
// Condition checking (mirrors modifier_stack.gd _check_conditions)
// ---------------------------------------------------------------------------

function checkConditions(mod: ModifierData, ctx: ResolveContext): boolean {
  const conditions = mod.conditions

  // required_card_tags: ALL listed tags must be present
  if (conditions.required_card_tags && conditions.required_card_tags.length > 0) {
    for (const requiredTag of conditions.required_card_tags) {
      if (!ctx.card_tags.includes(requiredTag)) return false
    }
  }

  // required_card_type: must match if set
  if (conditions.required_card_type != null) {
    if (ctx.card_type !== conditions.required_card_type) return false
  }

  // only_vs_vulnerable
  if (conditions.only_vs_vulnerable) {
    if (!ctx.target_vulnerable) return false
  }

  // only_when_hp_below_pct: -1 means disabled
  if (
    conditions.only_when_hp_below_pct != null &&
    conditions.only_when_hp_below_pct >= 0
  ) {
    if (ctx.player_hp_pct > conditions.only_when_hp_below_pct) return false
  }

  return true
}

// ---------------------------------------------------------------------------
// Core resolve — mirrors modifier_stack.gd resolve()
// ---------------------------------------------------------------------------

export function resolveModifiers(
  baseValue: number,
  modifiers: ModifierData[],
  stat: Stat,
  ctx: ResolveContext,
): ResolveResult {
  const steps: PipelineStep[] = []

  // Filter to modifiers that target this stat and pass conditions
  const active = modifiers.filter(
    mod => mod.stat === stat && checkConditions(mod, ctx),
  )

  if (active.length === 0) {
    return { steps, final: baseValue }
  }

  // Phase 1: OVERRIDE — highest value wins
  const overrides = active.filter(m => m.operation === 'OVERRIDE')
  if (overrides.length > 0) {
    let best = overrides[0]
    for (const m of overrides) {
      if (m.value > best.value) best = m
    }
    steps.push({
      operation: 'OVERRIDE',
      source: `${best.source_type}:${best.source_id}`,
      value: best.value,
      running_total: best.value,
    })
    return { steps, final: best.value }
  }

  // Phase 2: FLAT_ADD
  let flatTotal = baseValue
  for (const mod of active) {
    if (mod.operation === 'FLAT_ADD') {
      flatTotal += mod.value
      steps.push({
        operation: 'FLAT_ADD',
        source: `${mod.source_type}:${mod.source_id}`,
        value: mod.value,
        running_total: flatTotal,
      })
    }
  }

  // Phase 3: PERCENT_ADD — all stack additively, one multiply
  let pctAddSum = 0
  for (const mod of active) {
    if (mod.operation === 'PERCENT_ADD') {
      pctAddSum += mod.value
    }
  }
  let afterPctAdd = flatTotal
  if (pctAddSum !== 0) {
    afterPctAdd = flatTotal * (1 + pctAddSum)
    // Emit one step per PERCENT_ADD modifier for the breakdown, but show the
    // combined multiplier in the running total only after all are applied.
    let runningPctAdd = flatTotal
    for (const mod of active) {
      if (mod.operation === 'PERCENT_ADD') {
        runningPctAdd += flatTotal * mod.value
        steps.push({
          operation: 'PERCENT_ADD',
          source: `${mod.source_type}:${mod.source_id}`,
          value: mod.value,
          running_total: runningPctAdd,
        })
      }
    }
  }

  // Phase 4: PERCENT_MULT — each multiplies independently
  let result = afterPctAdd
  for (const mod of active) {
    if (mod.operation === 'PERCENT_MULT') {
      result *= mod.value
      steps.push({
        operation: 'PERCENT_MULT',
        source: `${mod.source_type}:${mod.source_id}`,
        value: mod.value,
        running_total: result,
      })
    }
  }

  return { steps, final: result }
}

// ---------------------------------------------------------------------------
// Loadout → flat modifier list
// Collects all modifiers from equipped relics, equipment, gems, and skills.
// ---------------------------------------------------------------------------

function collectModifiers(
  loadout: Loadout,
  allRelics: Relic[],
  allEquipment: Equipment[],
  allGems: Gem[],
  allSkills: SkillNode[],
): ModifierData[] {
  const mods: ModifierData[] = []

  // Relics do not contribute ModifierData objects to the stack in the GDScript
  // version — they apply flat stat bonuses (strength, dexterity, etc.) at
  // combat start rather than through the modifier pipeline. Relic bonuses are
  // captured in loadout.strength / loadout.dexterity and applied as pre-stack
  // adjustments below. No modifier objects to add here.

  // Equipment modifiers
  for (const [, equipId] of Object.entries(loadout.equipment)) {
    const equip = allEquipment.find(e => e.id === equipId)
    if (!equip) continue
    for (const mod of equip.modifiers) {
      mods.push({ ...mod, source_type: 'equipment', source_id: equip.id })
    }
  }

  // Gem on_play_modifiers — active only during CARD_PLAY lifecycle
  // The pipeline treats CARD_PLAY gems as always active for preview purposes
  // (they fire when the socketed card is played).
  for (const [, gemIds] of Object.entries(loadout.gems)) {
    for (const gemId of gemIds) {
      const gem = allGems.find(g => g.id === gemId)
      if (!gem) continue
      for (const mod of gem.on_play_modifiers) {
        mods.push({ ...mod, source_type: 'gem', source_id: gem.id })
      }
    }
  }

  // Skill tree modifiers
  for (const skillId of loadout.skills) {
    const skill = allSkills.find(s => s.id === skillId)
    if (!skill) continue
    for (const mod of (skill.modifier_specs ?? skill.modifiers ?? [])) {
      mods.push({ ...mod, source_type: 'skill_tree', source_id: skill.id })
    }
  }

  return mods
}

// ---------------------------------------------------------------------------
// Build a breakdown of contributions per operation type for one stat
// ---------------------------------------------------------------------------

function buildBreakdown(
  modifiers: ModifierData[],
  stat: Stat,
  operation: ModOp,
  ctx: ResolveContext,
): ModContribution[] {
  return modifiers
    .filter(
      m =>
        m.stat === stat &&
        m.operation === operation &&
        checkConditions(m, ctx),
    )
    .map(m => ({
      source: `${m.source_type}:${m.source_id}`,
      value: m.value,
    }))
}

// ---------------------------------------------------------------------------
// Full card simulation — mirrors StatResolver in stat_resolver.gd
// ---------------------------------------------------------------------------

export function simulateCard(
  card: Card,
  loadout: Loadout,
  allRelics: Relic[],
  allEquipment: Equipment[],
  allGems: Gem[],
  allSkills: SkillNode[],
): SimulationResult {
  const allMods = collectModifiers(
    loadout,
    allRelics,
    allEquipment,
    allGems,
    allSkills,
  )

  const ctx: ResolveContext = {
    card_type: card.card_type,
    card_tags: card.tags,
    target_vulnerable: loadout.context.vulnerable,
    player_hp_pct: loadout.context.hp_pct,
  }

  // --- Damage ---
  // adjusted_base = base_damage + strength  (mirrors stat_resolver.gd line 7)
  const adjustedBaseDamage = Math.max(0, card.damage + loadout.strength)
  let finalDamage = 0

  if (adjustedBaseDamage > 0) {
    const damageResult = resolveModifiers(
      adjustedBaseDamage,
      allMods,
      'DAMAGE',
      ctx,
    )
    finalDamage = damageResult.final

    // Post-stack: vulnerable × 1.5, weak × 0.75  (stat_resolver.gd lines 13-16)
    if (loadout.context.vulnerable) {
      finalDamage *= 1.5
    }
    if (loadout.context.weak) {
      finalDamage *= 0.75
    }
    finalDamage = Math.floor(finalDamage)
  }

  // --- Block ---
  // adjusted_base = base_block + dexterity  (mirrors stat_resolver.gd line 21)
  const adjustedBaseBlock = Math.max(0, card.block + loadout.dexterity)
  let finalBlock = 0

  if (adjustedBaseBlock > 0) {
    const blockResult = resolveModifiers(
      adjustedBaseBlock,
      allMods,
      'BLOCK',
      ctx,
    )
    finalBlock = Math.floor(blockResult.final)
  }

  // --- Healing ---
  let finalHeal = 0
  if (card.heal > 0) {
    const healResult = resolveModifiers(card.heal, allMods, 'HEALING', ctx)
    finalHeal = Math.floor(healResult.final)
  }

  // --- Contribution breakdowns ---
  const damage_flat_adds = buildBreakdown(allMods, 'DAMAGE', 'FLAT_ADD', ctx)
  const damage_pct_adds = buildBreakdown(allMods, 'DAMAGE', 'PERCENT_ADD', ctx)
  const damage_pct_mults = buildBreakdown(allMods, 'DAMAGE', 'PERCENT_MULT', ctx)
  const block_flat_adds = buildBreakdown(allMods, 'BLOCK', 'FLAT_ADD', ctx)
  const block_pct_adds = buildBreakdown(allMods, 'BLOCK', 'PERCENT_ADD', ctx)
  const block_pct_mults = buildBreakdown(allMods, 'BLOCK', 'PERCENT_MULT', ctx)

  return {
    card_id: card.id,
    card_name: card.display_name,
    base_damage: card.damage,
    base_block: card.block,
    adjusted_base_damage: adjustedBaseDamage,
    adjusted_base_block: adjustedBaseBlock,
    final_damage: finalDamage,
    final_block: finalBlock,
    final_heal: finalHeal,
    damage_flat_adds,
    damage_pct_adds,
    damage_pct_mults,
    block_flat_adds,
    block_pct_adds,
    block_pct_mults,
  }
}

// ---------------------------------------------------------------------------
// Convenience: simulate an entire deck at once
// ---------------------------------------------------------------------------

export function simulateDeck(
  cards: Card[],
  loadout: Loadout,
  allRelics: Relic[],
  allEquipment: Equipment[],
  allGems: Gem[],
  allSkills: SkillNode[],
): SimulationResult[] {
  return cards.map(card =>
    simulateCard(card, loadout, allRelics, allEquipment, allGems, allSkills),
  )
}
