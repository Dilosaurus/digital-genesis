import { useMemo } from 'react'
import { createColumnHelper } from '@tanstack/react-table'
import { DataTable } from './DataTable'
import { EditableCell } from './EditableCell'
import { useCards } from '../../hooks/useApi'
import type { Card, CardType, CardTag } from '../../types'

// ---------------------------------------------------------------------------
// Badge helpers
// ---------------------------------------------------------------------------

const TYPE_BADGE_CLASSES: Record<CardType, string> = {
  ATTACK: 'bg-gradient-to-r from-red-900/80 to-red-800/60 text-red-300 border border-red-700/30',
  SKILL: 'bg-gradient-to-r from-blue-900/80 to-blue-800/60 text-blue-300 border border-blue-700/30',
  POWER: 'bg-gradient-to-r from-green-900/80 to-green-800/60 text-green-300 border border-green-700/30',
  STATUS: 'bg-gradient-to-r from-yellow-900/80 to-yellow-800/60 text-yellow-300 border border-yellow-700/30',
  CURSE: 'bg-gradient-to-r from-purple-900/80 to-purple-800/60 text-purple-300 border border-purple-700/30',
}

const TAG_BADGE_CLASSES: Record<CardTag, string> = {
  MELEE: 'bg-gradient-to-r from-orange-900/80 to-orange-800/60 text-orange-300 border border-orange-700/30',
  RANGED: 'bg-gradient-to-r from-cyan-900/80 to-cyan-800/60 text-cyan-300 border border-cyan-700/30',
  FIRE: 'bg-gradient-to-r from-red-900/80 to-red-800/60 text-red-300 border border-red-700/30',
  ICE: 'bg-gradient-to-r from-sky-900/80 to-sky-800/60 text-sky-300 border border-sky-700/30',
  HOLY: 'bg-gradient-to-r from-yellow-800/80 to-yellow-700/60 text-yellow-200 border border-yellow-600/30',
  SHADOW: 'bg-gradient-to-r from-violet-900/80 to-violet-800/60 text-violet-300 border border-violet-700/30',
  TECH: 'bg-gradient-to-r from-teal-900/80 to-teal-800/60 text-teal-300 border border-teal-700/30',
  EXPLOIT: 'bg-gradient-to-r from-pink-900/80 to-pink-800/60 text-pink-300 border border-pink-700/30',
  CURSE: 'bg-gradient-to-r from-purple-900/80 to-purple-800/60 text-purple-300 border border-purple-700/30',
}

function TypeBadge({ type }: { type: CardType }) {
  return (
    <span
      className={`inline-block rounded-full px-2 py-0.5 text-xs font-medium ${TYPE_BADGE_CLASSES[type] ?? 'bg-gray-700 text-gray-300'}`}
    >
      {type}
    </span>
  )
}

function TagChip({ tag }: { tag: CardTag }) {
  return (
    <span
      className={`inline-block rounded-full px-2 py-0.5 text-xs ${TAG_BADGE_CLASSES[tag] ?? 'bg-gray-700 text-gray-300'}`}
    >
      {tag}
    </span>
  )
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const CARD_TYPE_OPTIONS = [
  { value: 'ATTACK', label: 'ATTACK' },
  { value: 'SKILL', label: 'SKILL' },
  { value: 'POWER', label: 'POWER' },
  { value: 'STATUS', label: 'STATUS' },
  { value: 'CURSE', label: 'CURSE' },
]

// ---------------------------------------------------------------------------
// Derived row type with computed columns
// ---------------------------------------------------------------------------

interface CardRow extends Card {
  dpe: number
  bpe: number
}

// ---------------------------------------------------------------------------
// Column definitions (created inside the component so they close over refetch)
// ---------------------------------------------------------------------------

const columnHelper = createColumnHelper<CardRow>()

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export function CardsTable() {
  const { data, loading, error, refetch } = useCards()

  const columns = useMemo(() => [
    columnHelper.accessor('display_name', {
      header: 'Name',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="cards"
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
    columnHelper.accessor('card_type', {
      header: 'Type',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="cards"
          entityId={info.row.original.id}
          field="card_type"
          type="select"
          options={CARD_TYPE_OPTIONS}
          onSaved={refetch}
          displayRenderer={v => <TypeBadge type={v as CardType} />}
        />
      ),
    }),
    columnHelper.accessor('energy_cost', {
      header: 'Energy',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="cards"
          entityId={info.row.original.id}
          field="energy_cost"
          type="number"
          onSaved={refetch}
          displayRenderer={v => (
            <span className="text-gray-300">{String(v)}</span>
          )}
        />
      ),
    }),
    columnHelper.accessor('damage', {
      header: 'Damage',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="cards"
          entityId={info.row.original.id}
          field="damage"
          type="number"
          onSaved={refetch}
          displayRenderer={v => {
            const n = Number(v)
            return <span className={n > 0 ? 'text-red-300' : 'text-gray-500'}>{n || '—'}</span>
          }}
        />
      ),
    }),
    columnHelper.accessor('block', {
      header: 'Block',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="cards"
          entityId={info.row.original.id}
          field="block"
          type="number"
          onSaved={refetch}
          displayRenderer={v => {
            const n = Number(v)
            return <span className={n > 0 ? 'text-blue-300' : 'text-gray-500'}>{n || '—'}</span>
          }}
        />
      ),
    }),
    columnHelper.accessor('heal', {
      header: 'Heal',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="cards"
          entityId={info.row.original.id}
          field="heal"
          type="number"
          onSaved={refetch}
          displayRenderer={v => {
            const n = Number(v)
            return <span className={n > 0 ? 'text-green-300' : 'text-gray-500'}>{n || '—'}</span>
          }}
        />
      ),
    }),
    columnHelper.accessor('draw', {
      header: 'Draw',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="cards"
          entityId={info.row.original.id}
          field="draw"
          type="number"
          onSaved={refetch}
          displayRenderer={v => {
            const n = Number(v)
            return <span className={n > 0 ? 'text-yellow-300' : 'text-gray-500'}>{n || '—'}</span>
          }}
        />
      ),
    }),
    columnHelper.accessor('hits', {
      header: 'Hits',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="cards"
          entityId={info.row.original.id}
          field="hits"
          type="number"
          onSaved={refetch}
          displayRenderer={v => {
            const n = Number(v)
            return <span className="text-gray-300">{n > 1 ? n : '—'}</span>
          }}
        />
      ),
    }),
    columnHelper.accessor('dpe', {
      header: 'DPE',
      cell: info => {
        const v = info.getValue()
        if (v === 0) return <span className="text-gray-500">—</span>
        return (
          <span className={v > 8 ? 'text-red-400 font-semibold' : 'text-gray-300'}>
            {v.toFixed(1)}
          </span>
        )
      },
    }),
    columnHelper.accessor('bpe', {
      header: 'BPE',
      cell: info => {
        const v = info.getValue()
        if (v === 0) return <span className="text-gray-500">—</span>
        return (
          <span className={v > 8 ? 'text-red-400 font-semibold' : 'text-gray-300'}>
            {v.toFixed(1)}
          </span>
        )
      },
    }),
    columnHelper.accessor('tags', {
      header: 'Tags',
      enableSorting: false,
      cell: info => {
        const tags = info.getValue()
        if (!tags.length) return <span className="text-gray-600">—</span>
        return (
          <div className="flex flex-wrap gap-1">
            {tags.map(tag => (
              <TagChip key={tag} tag={tag} />
            ))}
          </div>
        )
      },
    }),
    columnHelper.accessor('gem_sockets', {
      header: 'Sockets',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="cards"
          entityId={info.row.original.id}
          field="gem_sockets"
          type="number"
          onSaved={refetch}
          displayRenderer={v => {
            const n = Number(v)
            return <span className={n > 0 ? 'text-purple-300' : 'text-gray-600'}>{n || '—'}</span>
          }}
        />
      ),
    }),
  ] as ReturnType<typeof columnHelper.accessor>[], [refetch])

  const rows = useMemo<CardRow[]>(() => {
    if (!data) return []
    return data.map(card => ({
      ...card,
      dpe: card.damage > 0 ? (card.damage * Math.max(card.hits, 1)) / Math.max(card.energy_cost, 1) : 0,
      bpe: card.block > 0 ? card.block / Math.max(card.energy_cost, 1) : 0,
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
