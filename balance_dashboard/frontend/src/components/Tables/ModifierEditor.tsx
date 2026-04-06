import { useState, useCallback } from 'react'
import type { Stat, ModOp } from '../../types'

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const STAT_OPTIONS: Stat[] = [
  'DAMAGE', 'BLOCK', 'HEALING', 'MAX_HP', 'MAX_ENERGY',
  'DRAW_PER_TURN', 'ENERGY_COST', 'CORRUPTION_GAIN', 'CORRUPTION_RESIST',
]

const OP_OPTIONS: ModOp[] = ['FLAT_ADD', 'PERCENT_ADD', 'PERCENT_MULT', 'OVERRIDE']

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface ModifierRow {
  id?: string
  stat: string
  operation: string
  value: number
  lifecycle?: string
  duration?: number
  required_card_tags?: string[]
  only_vs_vulnerable?: boolean
  only_when_hp_below_pct?: number
}

export interface ModifierEditorProps {
  entityType: 'equipment' | 'gems'
  entityId: string
  modifiers: ModifierRow[]
  onClose: () => void
  onSaved: () => void
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export function ModifierEditor({
  entityType,
  entityId,
  modifiers: initialModifiers,
  onClose,
  onSaved,
}: ModifierEditorProps) {
  const [rows, setRows] = useState<ModifierRow[]>(initialModifiers)
  const [savingId, setSavingId] = useState<string | null>(null)
  const [deletingId, setDeletingId] = useState<string | null>(null)
  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  // ---- Helpers -------------------------------------------------------------

  const baseUrl = `/api/${entityType}/${entityId}/modifiers`

  const updateRow = useCallback((index: number, patch: Partial<ModifierRow>) => {
    setRows(prev => prev.map((r, i) => (i === index ? { ...r, ...patch } : r)))
  }, [])

  // ---- CRUD ----------------------------------------------------------------

  const handleSave = async (index: number) => {
    const row = rows[index]
    setError(null)

    try {
      if (row.id) {
        // Existing modifier — PATCH
        setSavingId(row.id)
        const res = await fetch(`${baseUrl}/${row.id}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            stat: row.stat,
            operation: row.operation,
            value: row.value,
          }),
        })
        if (!res.ok) throw new Error(`PATCH failed: ${res.status}`)
      } else {
        // New modifier — POST
        setSavingId(`new-${index}`)
        const newId = `${entityId}_mod_${Date.now()}`
        const res = await fetch(baseUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ ...row, id: newId }),
        })
        if (!res.ok) throw new Error(`POST failed: ${res.status}`)
        updateRow(index, { id: newId })
      }
      onSaved()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error')
    } finally {
      setSavingId(null)
    }
  }

  const handleDelete = async (index: number) => {
    const row = rows[index]

    // If it's a new unsaved row, just remove locally
    if (!row.id) {
      setRows(prev => prev.filter((_, i) => i !== index))
      setConfirmDeleteId(null)
      return
    }

    // Confirmation gate
    if (confirmDeleteId !== row.id) {
      setConfirmDeleteId(row.id)
      return
    }

    setError(null)
    setDeletingId(row.id)
    try {
      const res = await fetch(`${baseUrl}/${row.id}`, { method: 'DELETE' })
      if (!res.ok) throw new Error(`DELETE failed: ${res.status}`)
      setRows(prev => prev.filter((_, i) => i !== index))
      setConfirmDeleteId(null)
      onSaved()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error')
    } finally {
      setDeletingId(null)
    }
  }

  const handleAdd = () => {
    setRows(prev => [
      ...prev,
      { stat: 'DAMAGE', operation: 'FLAT_ADD', value: 0 },
    ])
  }

  // ---- Render --------------------------------------------------------------

  return (
    // Backdrop
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm"
      onClick={onClose}
    >
      {/* Panel */}
      <div
        className="w-full max-w-2xl rounded-lg border border-purple-500/10 border-t-2 border-t-purple-500/50 bg-[var(--bg-surface)] shadow-xl shadow-[0_0_40px_rgba(168,85,247,0.1)]"
        onClick={e => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between border-b border-gray-700/30 px-5 py-3">
          <h2 className="text-sm font-semibold text-gray-100">
            Modifiers &mdash;{' '}
            <span className="text-purple-400">{entityId}</span>
          </h2>
          <button
            onClick={onClose}
            className="rounded p-1 text-gray-400 hover:bg-[var(--bg-hover)] hover:text-gray-100"
            aria-label="Close"
          >
            <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        {/* Error banner */}
        {error && (
          <div className="mx-5 mt-3 rounded bg-red-900/50 border border-red-500/20 px-3 py-2 text-xs text-red-300">
            {error}
          </div>
        )}

        {/* Table */}
        <div className="max-h-[60vh] overflow-y-auto px-5 py-3">
          <table className="w-full text-xs">
            <thead>
              <tr className="text-left text-purple-300/60">
                <th className="pb-2 pr-2 font-medium">Stat</th>
                <th className="pb-2 pr-2 font-medium">Operation</th>
                <th className="pb-2 pr-2 font-medium">Value</th>
                <th className="pb-2 font-medium">Actions</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row, idx) => {
                const rowKey = row.id ?? `new-${idx}`
                const isSaving = savingId === rowKey
                const isDeleting = deletingId === row.id
                const isConfirming = confirmDeleteId === row.id

                return (
                  <tr key={rowKey} className="border-t border-gray-700/30">
                    {/* Stat */}
                    <td className="py-1.5 pr-2">
                      <select
                        value={row.stat}
                        onChange={e => updateRow(idx, { stat: e.target.value })}
                        className="w-full rounded border border-gray-600/50 bg-[var(--bg-elevated)] px-2 py-1 text-gray-100 focus:border-purple-500 focus:outline-none"
                      >
                        {STAT_OPTIONS.map(s => (
                          <option key={s} value={s}>{s}</option>
                        ))}
                      </select>
                    </td>

                    {/* Operation */}
                    <td className="py-1.5 pr-2">
                      <select
                        value={row.operation}
                        onChange={e => updateRow(idx, { operation: e.target.value })}
                        className="w-full rounded border border-gray-600/50 bg-[var(--bg-elevated)] px-2 py-1 text-gray-100 focus:border-purple-500 focus:outline-none"
                      >
                        {OP_OPTIONS.map(o => (
                          <option key={o} value={o}>{o}</option>
                        ))}
                      </select>
                    </td>

                    {/* Value */}
                    <td className="py-1.5 pr-2">
                      <input
                        type="number"
                        value={row.value}
                        onChange={e => updateRow(idx, { value: Number(e.target.value) })}
                        className="w-20 rounded border border-gray-600/50 bg-[var(--bg-elevated)] px-2 py-1 text-gray-100 focus:border-purple-500 focus:outline-none"
                      />
                    </td>

                    {/* Actions */}
                    <td className="flex gap-1.5 py-1.5">
                      <button
                        onClick={() => handleSave(idx)}
                        disabled={isSaving}
                        className="rounded bg-purple-600 px-2.5 py-1 text-xs font-medium text-white hover:bg-purple-500 hover:shadow-[0_0_15px_rgba(168,85,247,0.25)] disabled:opacity-50 transition-shadow"
                      >
                        {isSaving ? 'Saving...' : 'Save'}
                      </button>
                      <button
                        onClick={() => handleDelete(idx)}
                        disabled={isDeleting}
                        className={`rounded px-2.5 py-1 text-xs font-medium text-white transition-shadow ${
                          isConfirming
                            ? 'bg-red-600 hover:bg-red-500 shadow-[0_0_12px_rgba(239,68,68,0.3)]'
                            : 'bg-gray-700 text-red-400 hover:bg-red-900/50 hover:shadow-[0_0_10px_rgba(239,68,68,0.15)]'
                        } disabled:opacity-50`}
                      >
                        {isDeleting
                          ? 'Deleting...'
                          : isConfirming
                            ? 'Confirm'
                            : 'Delete'}
                      </button>
                    </td>
                  </tr>
                )
              })}

              {rows.length === 0 && (
                <tr>
                  <td colSpan={4} className="py-6 text-center text-gray-500">
                    No modifiers yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between px-5 py-3" style={{ borderTop: '1px solid transparent', borderImage: 'linear-gradient(to right, transparent, rgba(168,85,247,0.3), transparent) 1' }}>
          <button
            onClick={handleAdd}
            className="rounded border border-dashed border-purple-500/30 px-3 py-1.5 text-xs text-gray-300 hover:border-purple-500/60 hover:bg-purple-500/5 hover:text-purple-400 transition-colors"
          >
            + Add Modifier
          </button>
          <button
            onClick={onClose}
            className="rounded bg-gray-700 px-3 py-1.5 text-xs text-gray-300 hover:bg-gray-600"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  )
}
