import { useMemo } from 'react'
import type { Loadout, ModifierData, ModOp, Stat } from '../../types'
import { useRelics, useEquipment, useGems, useSkillTree } from '../../hooks/useApi'

// ---------------------------------------------------------------------------
// Resolution order for display
// ---------------------------------------------------------------------------

const OP_ORDER: ModOp[] = ['OVERRIDE', 'FLAT_ADD', 'PERCENT_ADD', 'PERCENT_MULT']

const OP_LABELS: Record<ModOp, string> = {
  OVERRIDE: 'Override',
  FLAT_ADD: 'Flat Add',
  PERCENT_ADD: 'Percent Add',
  PERCENT_MULT: 'Percent Mult',
}

const OP_COLOR: Record<ModOp, string> = {
  OVERRIDE: 'text-yellow-400',
  FLAT_ADD: 'text-blue-400',
  PERCENT_ADD: 'text-green-400',
  PERCENT_MULT: 'text-purple-400',
}

const OP_BORDER_BG: Record<ModOp, string> = {
  OVERRIDE: 'border-l-2 border-yellow-500/50 bg-yellow-500/5',
  FLAT_ADD: 'border-l-2 border-blue-500/50 bg-blue-500/5',
  PERCENT_ADD: 'border-l-2 border-green-500/50 bg-green-500/5',
  PERCENT_MULT: 'border-l-2 border-purple-500/50 bg-purple-500/5',
}

const STAT_LABELS: Record<Stat, string> = {
  DAMAGE: 'Damage',
  BLOCK: 'Block',
  HEALING: 'Healing',
  MAX_HP: 'Max HP',
  MAX_ENERGY: 'Max Energy',
  DRAW_PER_TURN: 'Draw / Turn',
  ENERGY_COST: 'Energy Cost',
  CORRUPTION_GAIN: 'Corruption Gain',
  CORRUPTION_RESIST: 'Corruption Resist',
}

const STAT_GLOW_COLOR: Record<string, string> = {
  DAMAGE: 'shadow-[0_0_6px_rgba(168,85,247,0.3)]',
  BLOCK: 'shadow-[0_0_6px_rgba(59,130,246,0.3)]',
  HEALING: 'shadow-[0_0_6px_rgba(34,197,94,0.3)]',
  MAX_HP: 'shadow-[0_0_6px_rgba(239,68,68,0.3)]',
  MAX_ENERGY: 'shadow-[0_0_6px_rgba(234,179,8,0.3)]',
  DRAW_PER_TURN: 'shadow-[0_0_6px_rgba(6,182,212,0.3)]',
  ENERGY_COST: 'shadow-[0_0_6px_rgba(249,115,22,0.3)]',
  CORRUPTION_GAIN: 'shadow-[0_0_6px_rgba(239,68,68,0.3)]',
  CORRUPTION_RESIST: 'shadow-[0_0_6px_rgba(34,197,94,0.3)]',
}

const STAT_BG_COLOR: Record<string, string> = {
  DAMAGE: 'bg-purple-500',
  BLOCK: 'bg-blue-500',
  HEALING: 'bg-green-500',
  MAX_HP: 'bg-red-500',
  MAX_ENERGY: 'bg-yellow-500',
  DRAW_PER_TURN: 'bg-cyan-500',
  ENERGY_COST: 'bg-orange-500',
  CORRUPTION_GAIN: 'bg-red-500',
  CORRUPTION_RESIST: 'bg-green-500',
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

interface AnnotatedMod extends ModifierData {
  displaySource: string
}

function collectAnnotatedMods(
  loadout: Loadout,
  allRelicsData: ReturnType<typeof useRelics>['data'],
  allEquipmentData: ReturnType<typeof useEquipment>['data'],
  allGemsData: ReturnType<typeof useGems>['data'],
  allSkillsData: ReturnType<typeof useSkillTree>['data'],
): AnnotatedMod[] {
  const mods: AnnotatedMod[] = []
  const allRelics = allRelicsData ?? []
  const allEquipment = allEquipmentData ?? []
  const allGems = allGemsData ?? []
  const allSkills = allSkillsData ?? []

  // Relic stat bonuses are applied as pre-stack adjustments (strength/dex),
  // not as modifier stack entries. They are shown in the loadout summary
  // but don't appear in the modifier pipeline breakdown.

  // Equipment
  for (const [, equipId] of Object.entries(loadout.equipment)) {
    const equip = allEquipment.find(e => e.id === equipId)
    if (!equip) continue
    for (const mod of equip.modifiers) {
      mods.push({ ...mod, source_type: 'equipment', source_id: equip.id, displaySource: `Equipment: ${equip.display_name}` })
    }
  }

  // Gems
  for (const [cardId, gemIds] of Object.entries(loadout.gems)) {
    for (const gemId of gemIds) {
      if (!gemId) continue
      const gem = allGems.find(g => g.id === gemId)
      if (!gem) continue
      for (const mod of gem.on_play_modifiers) {
        mods.push({ ...mod, source_type: 'gem', source_id: gem.id, displaySource: `Gem: ${gem.display_name} (${cardId})` })
      }
    }
  }

  // Skills
  for (const skillId of loadout.skills) {
    const skill = allSkills.find(s => s.id === skillId)
    if (!skill) continue
    for (const mod of (skill.modifier_specs ?? skill.modifiers ?? [])) {
      mods.push({ ...mod, source_type: 'skill_tree', source_id: skill.id, displaySource: `Skill: ${skill.display_name}` })
    }
  }

  // Corruption tier as a pseudo-modifier (informational)
  if (loadout.corruption_tier > 0) {
    const mult = [1, 1.1, 1.25, 1.5][loadout.corruption_tier]
    mods.push({
      stat: 'DAMAGE',
      operation: 'PERCENT_MULT',
      value: mult,
      lifecycle: 'PERMANENT',
      duration: -1,
      conditions: {},
      source_type: 'corruption',
      source_id: `tier_${loadout.corruption_tier}`,
      displaySource: `Corruption Tier ${loadout.corruption_tier} (x${mult})`,
    })
  }

  return mods
}

function formatValue(op: ModOp, value: number): string {
  if (op === 'FLAT_ADD') return value >= 0 ? `+${value}` : `${value}`
  if (op === 'PERCENT_ADD') return `${value >= 0 ? '+' : ''}${(value * 100).toFixed(0)}%`
  if (op === 'PERCENT_MULT') return `x${value.toFixed(2)}`
  if (op === 'OVERRIDE') return `= ${value}`
  return String(value)
}

// ---------------------------------------------------------------------------
// Props
// ---------------------------------------------------------------------------

interface ModifierStackPreviewProps {
  loadout: Loadout
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export function ModifierStackPreview({ loadout }: ModifierStackPreviewProps) {
  const relicsApi = useRelics()
  const equipmentApi = useEquipment()
  const gemsApi = useGems()
  const skillTreeApi = useSkillTree()

  const annotatedMods = useMemo(
    () =>
      collectAnnotatedMods(
        loadout,
        relicsApi.data,
        equipmentApi.data,
        gemsApi.data,
        skillTreeApi.data,
      ),
    [loadout, relicsApi.data, equipmentApi.data, gemsApi.data, skillTreeApi.data],
  )

  // Group by stat then by operation in resolution order
  const grouped = useMemo(() => {
    const statMap = new Map<Stat, Map<ModOp, AnnotatedMod[]>>()

    for (const mod of annotatedMods) {
      if (!statMap.has(mod.stat)) {
        statMap.set(mod.stat, new Map())
      }
      const opMap = statMap.get(mod.stat)!
      if (!opMap.has(mod.operation)) {
        opMap.set(mod.operation, [])
      }
      opMap.get(mod.operation)!.push(mod)
    }

    // Convert to sorted array
    const stats = Array.from(statMap.entries()).sort(([a], [b]) =>
      a.localeCompare(b),
    )

    return stats.map(([stat, opMap]) => ({
      stat,
      ops: OP_ORDER.filter(op => opMap.has(op)).map(op => ({
        op,
        mods: opMap.get(op)!,
      })),
    }))
  }, [annotatedMods])

  const loading = relicsApi.loading || equipmentApi.loading || gemsApi.loading || skillTreeApi.loading

  if (loading) {
    return (
      <div className="text-sm text-gray-500 py-4 text-center">Loading modifier data...</div>
    )
  }

  if (annotatedMods.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-8 text-gray-500">
        <svg className="w-8 h-8 mb-2 text-gray-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
        </svg>
        <span className="text-sm">No active modifiers.</span>
        <span className="text-xs mt-0.5">Add equipment, gems, or skills to see the modifier stack.</span>
      </div>
    )
  }

  // Pre-stack adjustments summary
  const preStackItems: string[] = []
  if (loadout.strength > 0) preStackItems.push(`+${loadout.strength} Strength -> Base Damage`)
  if (loadout.dexterity > 0) preStackItems.push(`+${loadout.dexterity} Dexterity -> Base Block`)
  if (loadout.context.vulnerable) preStackItems.push('Target Vulnerable -> x1.5 Damage (post-stack)')
  if (loadout.context.weak) preStackItems.push('Player Weak -> x0.75 Damage (post-stack)')

  return (
    <div className="flex flex-col gap-4">
      {/* Pre-stack adjustments */}
      {preStackItems.length > 0 && (
        <div className="panel-elevated rounded-lg p-3">
          <h4 className="text-xs font-semibold uppercase tracking-wider text-gray-400 mb-2">
            Pre/Post-Stack Adjustments
          </h4>
          <ul className="flex flex-col gap-1">
            {preStackItems.map((item, i) => (
              <li key={i} className="text-xs text-gray-400 flex items-center gap-2 border-l-2 border-yellow-500/40 pl-2 py-0.5">
                <span className="w-1.5 h-1.5 rounded-full bg-yellow-500 shrink-0" />
                {item}
              </li>
            ))}
          </ul>
        </div>
      )}

      {/* Per-stat modifier groups */}
      {grouped.map(({ stat, ops }) => (
        <div key={stat}>
          <h4 className="text-xs font-semibold uppercase tracking-wider text-gray-300 mb-2 flex items-center gap-2">
            <span className={`w-3 h-3 rounded-sm ${STAT_BG_COLOR[stat] ?? 'bg-purple-500'} inline-block ${STAT_GLOW_COLOR[stat] ?? ''}`} />
            {STAT_LABELS[stat] ?? stat}
          </h4>
          <div className="flex flex-col gap-1.5 pl-5">
            {ops.map(({ op, mods }) => (
              <div key={op} className="flex flex-col gap-1">
                <span className={['text-xs font-medium', OP_COLOR[op]].join(' ')}>
                  {OP_LABELS[op]}
                </span>
                {mods.map((mod, i) => (
                  <div
                    key={i}
                    className={`flex items-center justify-between pl-3 pr-2 py-1 rounded-md ${OP_BORDER_BG[op]}`}
                  >
                    <span className="text-xs text-gray-300">{mod.displaySource}</span>
                    <span className={['text-xs font-mono font-semibold', OP_COLOR[op]].join(' ')}>
                      {formatValue(op, mod.value)}
                    </span>
                  </div>
                ))}
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  )
}
