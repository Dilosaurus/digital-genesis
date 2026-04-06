import { useMemo } from 'react'
import { createColumnHelper } from '@tanstack/react-table'
import { DataTable } from './DataTable'
import { EditableCell } from './EditableCell'
import { useRelics } from '../../hooks/useApi'
import type { Relic } from '../../types'

// ---------------------------------------------------------------------------
// Rarity badge
// ---------------------------------------------------------------------------

const RARITY_CLASSES: Record<string, string> = {
  COMMON: 'bg-gradient-to-r from-gray-700/80 to-gray-600/60 text-gray-300 border border-gray-600/30',
  UNCOMMON: 'bg-gradient-to-r from-blue-900/80 to-blue-800/60 text-blue-300 border border-blue-700/30',
  RARE: 'bg-gradient-to-r from-yellow-900/80 to-yellow-800/60 text-yellow-300 border border-yellow-700/30',
  BOSS: 'bg-gradient-to-r from-red-900/80 to-red-800/60 text-red-300 border border-red-700/30',
  STARTER: 'bg-gradient-to-r from-green-900/80 to-green-800/60 text-green-300 border border-green-700/30',
}

function RarityBadge({ rarity }: { rarity: string }) {
  const cls = RARITY_CLASSES[rarity.toUpperCase()] ?? 'bg-gray-700 text-gray-300'
  return (
    <span className={`inline-block rounded-full px-2 py-0.5 text-xs font-medium ${cls}`}>
      {rarity}
    </span>
  )
}

// Highlight non-zero numeric values with a subtle color
function NumCell({ value }: { value: number }) {
  if (value === 0) return <span className="text-gray-600">—</span>
  return <span className="text-emerald-300 font-medium">{value}</span>
}

// ---------------------------------------------------------------------------
// Select options
// ---------------------------------------------------------------------------

const RARITY_OPTIONS = [
  { value: 'COMMON', label: 'COMMON' },
  { value: 'UNCOMMON', label: 'UNCOMMON' },
  { value: 'RARE', label: 'RARE' },
]

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export function RelicsTable() {
  const { data, loading, error, refetch } = useRelics()

  const columnHelper = createColumnHelper<Relic>()

  const columns = useMemo(() => [
    columnHelper.accessor('display_name', {
      header: 'Name',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="relics"
          entityId={info.row.original.id}
          field="display_name"
          type="text"
          onSaved={refetch}
          displayRenderer={v => <span className="font-medium text-gray-100">{String(v)}</span>}
        />
      ),
    }),
    columnHelper.accessor('rarity', {
      header: 'Rarity',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="relics"
          entityId={info.row.original.id}
          field="rarity"
          type="select"
          options={RARITY_OPTIONS}
          onSaved={refetch}
          displayRenderer={v => <RarityBadge rarity={String(v)} />}
        />
      ),
    }),
    columnHelper.accessor('start_combat_strength', {
      header: 'Strength',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="relics"
          entityId={info.row.original.id}
          field="start_combat_strength"
          type="number"
          onSaved={refetch}
          displayRenderer={v => <NumCell value={Number(v)} />}
        />
      ),
    }),
    columnHelper.accessor('start_combat_dexterity', {
      header: 'Dexterity',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="relics"
          entityId={info.row.original.id}
          field="start_combat_dexterity"
          type="number"
          onSaved={refetch}
          displayRenderer={v => <NumCell value={Number(v)} />}
        />
      ),
    }),
    columnHelper.accessor('start_combat_block', {
      header: 'Block',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="relics"
          entityId={info.row.original.id}
          field="start_combat_block"
          type="number"
          onSaved={refetch}
          displayRenderer={v => <NumCell value={Number(v)} />}
        />
      ),
    }),
    columnHelper.accessor('bonus_draw', {
      header: 'Draw',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="relics"
          entityId={info.row.original.id}
          field="bonus_draw"
          type="number"
          onSaved={refetch}
          displayRenderer={v => <NumCell value={Number(v)} />}
        />
      ),
    }),
    columnHelper.accessor('bonus_max_energy', {
      header: 'Max Energy',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="relics"
          entityId={info.row.original.id}
          field="bonus_max_energy"
          type="number"
          onSaved={refetch}
          displayRenderer={v => <NumCell value={Number(v)} />}
        />
      ),
    }),
    columnHelper.accessor('bonus_max_hp', {
      header: 'Max HP',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="relics"
          entityId={info.row.original.id}
          field="bonus_max_hp"
          type="number"
          onSaved={refetch}
          displayRenderer={v => <NumCell value={Number(v)} />}
        />
      ),
    }),
    columnHelper.accessor('heal_on_combat_end', {
      header: 'Heal on End',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="relics"
          entityId={info.row.original.id}
          field="heal_on_combat_end"
          type="number"
          onSaved={refetch}
          displayRenderer={v => <NumCell value={Number(v)} />}
        />
      ),
    }),
    columnHelper.accessor('corruption_resistance', {
      header: 'Corrupt Resist',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="relics"
          entityId={info.row.original.id}
          field="corruption_resistance"
          type="number"
          onSaved={refetch}
          displayRenderer={v => <NumCell value={Number(v)} />}
        />
      ),
    }),
  ] as ReturnType<typeof columnHelper.accessor>[], [refetch])

  if (loading) return <LoadingState />
  if (error) return <ErrorState message={error} />

  return <DataTable data={data ?? []} columns={columns} />
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
