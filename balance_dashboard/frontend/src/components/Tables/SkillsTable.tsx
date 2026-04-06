import { useMemo } from 'react'
import { createColumnHelper } from '@tanstack/react-table'
import { DataTable } from './DataTable'
import { ModifierChipList } from './ModifierChip'
import { useSkillTree } from '../../hooks/useApi'
import type { SkillNode } from '../../types'

// ---------------------------------------------------------------------------
// Derived row type — adds computed cost effectiveness
// ---------------------------------------------------------------------------

interface SkillRow extends SkillNode {
  costEffectiveness: number
}

// Cost effectiveness = sum of absolute modifier values / max(cost, 1)
function computeCostEffectiveness(node: SkillNode): number {
  const mods = node.modifier_specs ?? node.modifiers ?? []
  if (!mods.length) return 0
  const totalValue = mods.reduce((sum, mod) => {
    // For percent ops values are fractions like 0.15; scale to percentage points
    const abs =
      mod.operation === 'PERCENT_ADD' || mod.operation === 'PERCENT_MULT'
        ? Math.abs(mod.value * 100)
        : Math.abs(mod.value)
    return sum + abs
  }, 0)
  return totalValue / Math.max(node.cost, 1)
}

// ---------------------------------------------------------------------------
// Column definitions
// ---------------------------------------------------------------------------

const columnHelper = createColumnHelper<SkillRow>()

const columns = [
  columnHelper.accessor('display_name', {
    header: 'Name',
    cell: info => <span className="font-medium text-gray-100">{info.getValue()}</span>,
  }),
  columnHelper.accessor('tier', {
    header: 'Tier',
    cell: info => (
      <span className="inline-block rounded-full px-2 py-0.5 text-xs bg-gradient-to-r from-gray-700/80 to-gray-600/60 text-gray-300 border border-gray-600/30">
        T{info.getValue()}
      </span>
    ),
  }),
  columnHelper.accessor('cost', {
    header: 'Cost',
    cell: info => <span className="text-yellow-300">{info.getValue()}</span>,
  }),
  columnHelper.accessor('prerequisites', {
    header: 'Prerequisites',
    enableSorting: false,
    cell: info => {
      const prereqs = info.getValue()
      if (!prereqs.length) return <span className="text-gray-600">—</span>
      return (
        <span className="text-gray-400 text-xs">{prereqs.join(', ')}</span>
      )
    },
  }),
  columnHelper.accessor('modifier_specs', {
    header: 'Modifiers',
    enableSorting: false,
    cell: info => <ModifierChipList mods={info.getValue() ?? []} />,
  }),
  columnHelper.accessor('costEffectiveness', {
    header: 'Value/Cost',
    cell: info => {
      const v = info.getValue()
      if (v === 0) return <span className="text-gray-600">—</span>
      const color =
        v >= 20 ? 'text-green-400 font-semibold' :
        v >= 10 ? 'text-yellow-300' :
        'text-gray-400'
      return <span className={color}>{v.toFixed(1)}</span>
    },
  }),
] as ReturnType<typeof columnHelper.accessor>[]

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export function SkillsTable() {
  const { data, loading, error } = useSkillTree()

  const rows = useMemo<SkillRow[]>(() => {
    if (!data) return []
    return data.map(node => ({
      ...node,
      costEffectiveness: computeCostEffectiveness(node),
    }))
  }, [data])

  if (loading) return <LoadingState />
  if (error) return <ErrorState message={error} />

  return <DataTable data={rows} columns={columns} />
}

function LoadingState() {
  return (
    <div className="flex items-center justify-center h-40 text-gray-500 text-sm">
      Loading...
    </div>
  )
}

function ErrorState({ message }: { message: string }) {
  return (
    <div className="flex items-center justify-center h-40 text-red-400 text-sm">
      Error: {message}
    </div>
  )
}
