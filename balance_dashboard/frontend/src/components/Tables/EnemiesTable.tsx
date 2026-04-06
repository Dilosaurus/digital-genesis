import { useState, useMemo } from 'react'
import { createColumnHelper } from '@tanstack/react-table'
import { DataTable } from './DataTable'
import { EditableCell } from './EditableCell'
import { IntentEditor } from './IntentEditor'
import { useEnemies } from '../../hooks/useApi'
import type { Enemy, EnemyIntent, EnemyIntentEntry } from '../../types'

// ---------------------------------------------------------------------------
// Intent badge colors
// ---------------------------------------------------------------------------

const INTENT_CLASSES: Record<EnemyIntent, string> = {
  ATTACK: 'bg-gradient-to-r from-red-900/80 to-red-800/60 text-red-300 border border-red-700/30',
  DEFEND: 'bg-gradient-to-r from-blue-900/80 to-blue-800/60 text-blue-300 border border-blue-700/30',
  BUFF: 'bg-gradient-to-r from-green-900/80 to-green-800/60 text-green-300 border border-green-700/30',
  DEBUFF: 'bg-gradient-to-r from-yellow-900/80 to-yellow-800/60 text-yellow-300 border border-yellow-700/30',
  UNKNOWN: 'bg-gradient-to-r from-gray-700/80 to-gray-600/60 text-gray-400 border border-gray-600/30',
  HACK: 'bg-gradient-to-r from-purple-900/80 to-purple-800/60 text-purple-300 border border-purple-700/30',
}

function IntentBadge({ type, count }: { type: EnemyIntent; count: number }) {
  const cls = INTENT_CLASSES[type] ?? 'bg-gray-700 text-gray-400'
  return (
    <span className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs ${cls}`}>
      <span className="font-medium">{type}</span>
      <span className="opacity-70">&times;{count}</span>
    </span>
  )
}

// ---------------------------------------------------------------------------
// Derived row type
// ---------------------------------------------------------------------------

interface IntentSummary {
  type: EnemyIntent
  count: number
}

interface EnemyRow extends Enemy {
  intentSummary: IntentSummary[]
  avgDamagePerTurn: number
}

function summarizeIntents(pool: EnemyIntentEntry[]): IntentSummary[] {
  const counts: Partial<Record<EnemyIntent, number>> = {}
  for (const entry of pool) {
    const t = entry.intent ?? entry.type ?? 'UNKNOWN'
    counts[t] = (counts[t] ?? 0) + 1
  }
  return Object.entries(counts).map(([type, count]) => ({
    type: type as EnemyIntent,
    count: count!,
  }))
}

function computeAvgDamagePerTurn(pool: EnemyIntentEntry[]): number {
  if (!pool.length) return 0
  const totalDamage = pool.reduce(
    (sum, entry) => {
      const t = entry.intent ?? entry.type ?? 'UNKNOWN'
      return sum + (t === 'ATTACK' ? (entry.value ?? entry.damage ?? 0) : 0)
    },
    0,
  )
  return totalDamage / pool.length
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export function EnemiesTable() {
  const { data, loading, error, refetch } = useEnemies()
  const [editingEnemyId, setEditingEnemyId] = useState<string | null>(null)

  const rows = useMemo<EnemyRow[]>(() => {
    if (!data) return []
    return data.map(enemy => ({
      ...enemy,
      intentSummary: summarizeIntents(enemy.intent_pool),
      avgDamagePerTurn: computeAvgDamagePerTurn(enemy.intent_pool),
    }))
  }, [data])

  // -------------------------------------------------------------------------
  // Column definitions (inside component so they can close over state)
  // -------------------------------------------------------------------------

  const columnHelper = createColumnHelper<EnemyRow>()

  const columns = [
    columnHelper.accessor('display_name', {
      header: 'Name',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="enemies"
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
    columnHelper.accessor('max_hp', {
      header: 'HP',
      cell: info => (
        <EditableCell
          value={info.getValue()}
          entityType="enemies"
          entityId={info.row.original.id}
          field="max_hp"
          type="number"
          onSaved={refetch}
          displayRenderer={v => (
            <span className="text-green-300 font-medium">{String(v)}</span>
          )}
        />
      ),
    }),
    columnHelper.accessor('intentSummary', {
      header: 'Intent Pool',
      enableSorting: false,
      cell: info => {
        const summary = info.getValue()
        const enemy = info.row.original
        return (
          <div className="flex items-center gap-2">
            {!summary.length ? (
              <span className="text-gray-600">&mdash;</span>
            ) : (
              <div className="flex flex-wrap gap-1">
                {summary.map(({ type, count }) => (
                  <IntentBadge key={type} type={type} count={count} />
                ))}
              </div>
            )}
            <button
              className="shrink-0 rounded bg-gray-700 px-2 py-0.5 text-xs text-gray-300 hover:bg-gray-600 transition-colors"
              onClick={() => setEditingEnemyId(enemy.id)}
            >
              Edit
            </button>
          </div>
        )
      },
    }),
    columnHelper.accessor('avgDamagePerTurn', {
      header: 'Avg DMG/Turn',
      cell: info => {
        const v = info.getValue()
        if (v === 0) return <span className="text-gray-600">&mdash;</span>
        const color =
          v >= 20 ? 'text-red-400 font-semibold' :
          v >= 12 ? 'text-orange-300' :
          'text-gray-300'
        return <span className={color}>{v.toFixed(1)}</span>
      },
    }),
  ] as ReturnType<typeof columnHelper.accessor>[]

  if (loading) return <LoadingState />
  if (error) return <ErrorState message={error} />

  const editingEnemy = editingEnemyId
    ? data?.find(e => e.id === editingEnemyId)
    : null

  return (
    <>
      <DataTable data={rows} columns={columns} />
      {editingEnemy && (
        <IntentEditor
          entityId={editingEnemy.id}
          intents={editingEnemy.intent_pool as any}
          onClose={() => setEditingEnemyId(null)}
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
