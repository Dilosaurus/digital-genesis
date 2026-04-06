import { useState } from 'react'
import type { EnemyIntent } from '../../types'

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const INTENT_OPTIONS: EnemyIntent[] = [
  'ATTACK', 'DEFEND', 'BUFF', 'DEBUFF', 'UNKNOWN', 'HACK',
]

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface IntentRow {
  intent: string
  value: number
}

export interface IntentEditorProps {
  entityId: string
  intents: IntentRow[]
  onClose: () => void
  onSaved: () => void
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export function IntentEditor({
  entityId,
  intents: initialIntents,
  onClose,
  onSaved,
}: IntentEditorProps) {
  const [rows, setRows] = useState<IntentRow[]>(initialIntents)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // ---- Row helpers ---------------------------------------------------------

  const updateRow = (index: number, patch: Partial<IntentRow>) => {
    setRows(prev => prev.map((r, i) => (i === index ? { ...r, ...patch } : r)))
  }

  const removeRow = (index: number) => {
    setRows(prev => prev.filter((_, i) => i !== index))
  }

  const addRow = () => {
    setRows(prev => [...prev, { intent: 'ATTACK', value: 0 }])
  }

  // ---- Save ----------------------------------------------------------------

  const handleSaveAll = async () => {
    setSaving(true)
    setError(null)

    try {
      const res = await fetch(`/api/enemies/${entityId}/intents`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(rows),
      })
      if (!res.ok) throw new Error(`PUT failed: ${res.status}`)
      onSaved()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error')
    } finally {
      setSaving(false)
    }
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
        className="w-full max-w-lg rounded-lg border border-purple-500/10 border-t-2 border-t-purple-500/50 bg-[var(--bg-surface)] shadow-xl shadow-[0_0_40px_rgba(168,85,247,0.1)]"
        onClick={e => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between border-b border-gray-700/30 px-5 py-3">
          <h2 className="text-sm font-semibold text-gray-100">
            Intent Pool &mdash;{' '}
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

        {/* Rows */}
        <div className="max-h-[60vh] overflow-y-auto px-5 py-3">
          <table className="w-full text-xs">
            <thead>
              <tr className="text-left text-purple-300/60">
                <th className="pb-2 pr-2 font-medium">Intent</th>
                <th className="pb-2 pr-2 font-medium">Value</th>
                <th className="pb-2 font-medium" />
              </tr>
            </thead>
            <tbody>
              {rows.map((row, idx) => (
                <tr key={idx} className="border-t border-gray-700/30">
                  {/* Intent type */}
                  <td className="py-1.5 pr-2">
                    <select
                      value={row.intent}
                      onChange={e => updateRow(idx, { intent: e.target.value })}
                      className="w-full rounded border border-gray-600/50 bg-[var(--bg-elevated)] px-2 py-1 text-gray-100 focus:border-purple-500 focus:outline-none"
                    >
                      {INTENT_OPTIONS.map(i => (
                        <option key={i} value={i}>{i}</option>
                      ))}
                    </select>
                  </td>

                  {/* Value */}
                  <td className="py-1.5 pr-2">
                    <input
                      type="number"
                      value={row.value}
                      onChange={e => updateRow(idx, { value: Number(e.target.value) })}
                      className="w-24 rounded border border-gray-600/50 bg-[var(--bg-elevated)] px-2 py-1 text-gray-100 focus:border-purple-500 focus:outline-none"
                    />
                  </td>

                  {/* Remove */}
                  <td className="py-1.5 text-right">
                    <button
                      onClick={() => removeRow(idx)}
                      className="rounded bg-gray-700 px-2 py-1 text-red-400 hover:bg-red-900/50 hover:text-red-300 hover:shadow-[0_0_10px_rgba(239,68,68,0.15)] transition-shadow"
                      aria-label="Remove intent"
                    >
                      <svg className="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                      </svg>
                    </button>
                  </td>
                </tr>
              ))}

              {rows.length === 0 && (
                <tr>
                  <td colSpan={3} className="py-6 text-center text-gray-500">
                    No intents defined.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between px-5 py-3" style={{ borderTop: '1px solid transparent', borderImage: 'linear-gradient(to right, transparent, rgba(168,85,247,0.3), transparent) 1' }}>
          <button
            onClick={addRow}
            className="rounded border border-dashed border-purple-500/30 px-3 py-1.5 text-xs text-gray-300 hover:border-purple-500/60 hover:bg-purple-500/5 hover:text-purple-400 transition-colors"
          >
            + Add Intent
          </button>
          <div className="flex gap-2">
            <button
              onClick={onClose}
              className="rounded bg-gray-700 px-3 py-1.5 text-xs text-gray-300 hover:bg-gray-600"
            >
              Cancel
            </button>
            <button
              onClick={handleSaveAll}
              disabled={saving}
              className="rounded bg-purple-600 px-4 py-1.5 text-xs font-medium text-white hover:bg-purple-500 hover:shadow-[0_0_15px_rgba(168,85,247,0.25)] disabled:opacity-50 transition-shadow"
            >
              {saving ? 'Saving...' : 'Save All'}
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
