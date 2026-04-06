import type { ModifierData } from '../../types'

// Friendly label for stat names
const STAT_LABELS: Record<string, string> = {
  DAMAGE: 'DMG',
  BLOCK: 'BLOCK',
  HEALING: 'HEAL',
  MAX_HP: 'MAX HP',
  MAX_ENERGY: 'MAX ENERGY',
  DRAW_PER_TURN: 'DRAW',
  ENERGY_COST: 'COST',
  CORRUPTION_GAIN: 'CORRUPT',
  CORRUPTION_RESIST: 'RESIST',
}

// Friendly label for operations
const OP_LABELS: Record<string, string> = {
  FLAT_ADD: '+',
  PERCENT_ADD: '%+',
  PERCENT_MULT: 'x%',
  OVERRIDE: '=',
}

// Color per operation
const OP_CLASSES: Record<string, string> = {
  FLAT_ADD: 'bg-blue-900 text-blue-200',
  PERCENT_ADD: 'bg-teal-900 text-teal-200',
  PERCENT_MULT: 'bg-indigo-900 text-indigo-200',
  OVERRIDE: 'bg-orange-900 text-orange-200',
}

interface ModifierChipProps {
  mod: ModifierData
}

export function ModifierChip({ mod }: ModifierChipProps) {
  const statLabel = STAT_LABELS[mod.stat] ?? mod.stat
  const opLabel = OP_LABELS[mod.operation] ?? mod.operation
  const cls = OP_CLASSES[mod.operation] ?? 'bg-gray-700 text-gray-300'
  const sign = mod.value >= 0 ? '+' : ''
  const valueLabel =
    mod.operation === 'PERCENT_ADD' || mod.operation === 'PERCENT_MULT'
      ? `${sign}${(mod.value * 100).toFixed(0)}%`
      : `${sign}${mod.value}`

  return (
    <span className={`inline-block rounded-full px-2 py-0.5 text-xs font-mono ${cls}`}>
      {statLabel}&nbsp;{opLabel}&nbsp;{valueLabel}
    </span>
  )
}

interface ModifierChipListProps {
  mods: ModifierData[]
}

export function ModifierChipList({ mods }: ModifierChipListProps) {
  if (!mods.length) return <span className="text-gray-600">—</span>
  return (
    <div className="flex flex-wrap gap-1">
      {mods.map((mod, i) => (
        <ModifierChip key={mod.id ?? `${mod.stat}-${mod.operation}-${i}`} mod={mod} />
      ))}
    </div>
  )
}
