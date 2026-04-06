import { useState } from 'react'
import { createColumnHelper } from '@tanstack/react-table'
import { DataTable } from './DataTable'
import { EditableCell } from './EditableCell'
import { ModifierChipList } from './ModifierChip'
import { ModifierEditor } from './ModifierEditor'
import { useGems } from '../../hooks/useApi'
import type { Gem } from '../../types'

// ---------------------------------------------------------------------------
// Rarity badge (shared palette)
// ---------------------------------------------------------------------------

const RARITY_CLASSES: Record<string, string> = {
  COMMON: 'bg-gradient-to-r from-gray-700/80 to-gray-600/60 text-gray-300 border border-gray-600/30',
  UNCOMMON: 'bg-gradient-to-r from-blue-900/80 to-blue-800/60 text-blue-300 border border-blue-700/30',
  RARE: 'bg-gradient-to-r from-yellow-900/80 to-yellow-800/60 text-yellow-300 border border-yellow-700/30',
  EPIC: 'bg-gradient-to-r from-purple-900/80 to-purple-800/60 text-purple-300 border border-purple-700/30',
  LEGENDARY: 'bg-gradient-to-r from-orange-900/80 to-orange-800/60 text-orange-300 border border-orange-700/30',
}

function RarityBadge({ rarity }: { rarity: string }) {
  const cls = RARITY_CLASSES[rarity.toUpperCase()] ?? 'bg-gray-700 text-gray-300'
  return (
    <span className={`inline-block rounded-full px-2 py-0.5 text-xs font-medium ${cls}`}>
      {rarity}
    </span>
  )
}

// ---------------------------------------------------------------------------
// Rarity select options
// ---------------------------------------------------------------------------

const RARITY_OPTIONS = [
  { value: 'COMMON', label: 'COMMON' },
  { value: 'UNCOMMON', label: 'UNCOMMON' },
  { value: 'RARE', label: 'RARE' },
]

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export function GemsTable() {
  const { data, loading, error, refetch } = useGems()
  const [editingGemId, setEditingGemId] = useState<string | null>(null)

  // -------------------------------------------------------------------------
  // Column definitions (inside component so they can close over state)
  // -------------------------------------------------------------------------

  const columnHelper = createColumnHelper<Gem>()

  const columns = [
    columnHelper.accessor('display_name', {
      header: 'Name',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="gems"
          entityId={info.row.original.id}
          field="display_name"
          type="text"
          onSaved={refetch}
          displayRenderer={v => (
            <span className="font-medium text-gray-100">{String(v)}</span>
          )}
        />
      ),
    }),
    columnHelper.accessor('rarity', {
      header: 'Rarity',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="gems"
          entityId={info.row.original.id}
          field="rarity"
          type="select"
          options={RARITY_OPTIONS}
          onSaved={refetch}
          displayRenderer={v => <RarityBadge rarity={String(v)} />}
        />
      ),
    }),
    columnHelper.accessor('on_play_modifiers', {
      header: 'On-Play Modifiers',
      enableSorting: false,
      cell: info => {
        const gem = info.row.original
        return (
          <div className="flex items-center gap-2">
            <ModifierChipList mods={info.getValue()} />
            <button
              className="shrink-0 rounded bg-gray-700 px-2 py-0.5 text-xs text-gray-300 hover:bg-gray-600 transition-colors"
              onClick={() => setEditingGemId(gem.id)}
            >
              Edit
            </button>
          </div>
        )
      },
    }),
  ] as ReturnType<typeof columnHelper.accessor>[]

  if (loading) return <LoadingState />
  if (error) return <ErrorState message={error} />

  const editingGem = editingGemId
    ? data?.find(g => g.id === editingGemId)
    : null

  return (
    <>
      <DataTable data={data ?? []} columns={columns} />
      {editingGem && (
        <ModifierEditor
          entityType="gems"
          entityId={editingGem.id}
          modifiers={editingGem.on_play_modifiers as any}
          onClose={() => setEditingGemId(null)}
          onSaved={refetch}
        />
      )}
    </>
  )
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
