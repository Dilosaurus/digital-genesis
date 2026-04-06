import { useMemo, useState } from 'react'
import { createColumnHelper } from '@tanstack/react-table'
import { DataTable } from './DataTable'
import { EditableCell } from './EditableCell'
import { ModifierChipList } from './ModifierChip'
import { ModifierEditor } from './ModifierEditor'
import { useEquipment } from '../../hooks/useApi'
import type { Equipment, EquipSlot } from '../../types'

// ---------------------------------------------------------------------------
// Badges
// ---------------------------------------------------------------------------

const SLOT_CLASSES: Record<EquipSlot, string> = {
  HEAD: 'bg-gradient-to-r from-cyan-900/80 to-cyan-800/60 text-cyan-300 border border-cyan-700/30',
  CHEST: 'bg-gradient-to-r from-blue-900/80 to-blue-800/60 text-blue-300 border border-blue-700/30',
  WEAPON: 'bg-gradient-to-r from-red-900/80 to-red-800/60 text-red-300 border border-red-700/30',
  ACCESSORY: 'bg-gradient-to-r from-purple-900/80 to-purple-800/60 text-purple-300 border border-purple-700/30',
}

const RARITY_CLASSES: Record<string, string> = {
  COMMON: 'bg-gradient-to-r from-gray-700/80 to-gray-600/60 text-gray-300 border border-gray-600/30',
  UNCOMMON: 'bg-gradient-to-r from-blue-900/80 to-blue-800/60 text-blue-300 border border-blue-700/30',
  RARE: 'bg-gradient-to-r from-yellow-900/80 to-yellow-800/60 text-yellow-300 border border-yellow-700/30',
  EPIC: 'bg-gradient-to-r from-purple-900/80 to-purple-800/60 text-purple-300 border border-purple-700/30',
  LEGENDARY: 'bg-gradient-to-r from-orange-900/80 to-orange-800/60 text-orange-300 border border-orange-700/30',
}

function SlotBadge({ slot }: { slot: EquipSlot }) {
  const cls = SLOT_CLASSES[slot] ?? 'bg-gray-700 text-gray-300'
  return (
    <span className={`inline-block rounded-full px-2 py-0.5 text-xs font-medium ${cls}`}>
      {slot}
    </span>
  )
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
// Select options
// ---------------------------------------------------------------------------

const SLOT_OPTIONS = [
  { value: 'HEAD', label: 'HEAD' },
  { value: 'CHEST', label: 'CHEST' },
  { value: 'WEAPON', label: 'WEAPON' },
  { value: 'ACCESSORY', label: 'ACCESSORY' },
]

const RARITY_OPTIONS = [
  { value: 'COMMON', label: 'COMMON' },
  { value: 'UNCOMMON', label: 'UNCOMMON' },
  { value: 'RARE', label: 'RARE' },
]

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export function EquipmentTable() {
  const { data, loading, error, refetch } = useEquipment()
  const [editingEquipId, setEditingEquipId] = useState<string | null>(null)

  const columnHelper = createColumnHelper<Equipment>()

  const columns = useMemo(() => [
    columnHelper.accessor('display_name', {
      header: 'Name',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="equipment"
          entityId={info.row.original.id}
          field="display_name"
          type="text"
          onSaved={refetch}
          displayRenderer={v => <span className="font-medium text-gray-100">{String(v)}</span>}
        />
      ),
    }),
    columnHelper.accessor('slot', {
      header: 'Slot',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="equipment"
          entityId={info.row.original.id}
          field="slot"
          type="select"
          options={SLOT_OPTIONS}
          onSaved={refetch}
          displayRenderer={v => <SlotBadge slot={String(v) as EquipSlot} />}
        />
      ),
    }),
    columnHelper.accessor('rarity', {
      header: 'Rarity',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="equipment"
          entityId={info.row.original.id}
          field="rarity"
          type="select"
          options={RARITY_OPTIONS}
          onSaved={refetch}
          displayRenderer={v => <RarityBadge rarity={String(v)} />}
        />
      ),
    }),
    columnHelper.accessor('modifiers', {
      header: 'Modifiers',
      enableSorting: false,
      cell: info => {
        const row = info.row.original
        return (
          <div className="flex items-center gap-2">
            <ModifierChipList mods={info.getValue()} />
            <button
              type="button"
              className="text-xs text-purple-400 hover:underline flex-shrink-0"
              onClick={() => setEditingEquipId(row.id)}
            >
              Edit
            </button>
          </div>
        )
      },
    }),
  ] as ReturnType<typeof columnHelper.accessor>[], [refetch])

  if (loading) return <LoadingState />
  if (error) return <ErrorState message={error} />

  const editingEquip = editingEquipId
    ? (data ?? []).find(e => e.id === editingEquipId)
    : null

  return (
    <>
      <DataTable data={data ?? []} columns={columns} />
      {editingEquip && (
        <ModifierEditor
          entityType="equipment"
          entityId={editingEquip.id}
          modifiers={editingEquip.modifiers}
          onClose={() => setEditingEquipId(null)}
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
