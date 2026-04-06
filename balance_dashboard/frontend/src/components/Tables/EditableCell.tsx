import { useState, useRef, useEffect, useCallback } from 'react'
import type { ReactNode } from 'react'
import { usePatchEntity } from '../../hooks/usePatchEntity'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type EntityType = 'cards' | 'relics' | 'equipment' | 'gems' | 'enemies'

interface SelectOption {
  value: string
  label: string
}

interface EditableCellProps {
  value: unknown
  entityType: EntityType
  entityId: string
  field: string
  type: 'text' | 'number' | 'select'
  options?: SelectOption[]
  onSaved?: () => void
  displayRenderer?: (value: unknown) => ReactNode
}

// ---------------------------------------------------------------------------
// Flash animation — briefly applies a background color then fades out
// ---------------------------------------------------------------------------

function useFlash(ref: React.RefObject<HTMLElement | null>) {
  return useCallback(
    (color: 'green' | 'red') => {
      const el = ref.current
      if (!el) return
      const shadow =
        color === 'green'
          ? '0 0 10px rgba(34,197,94,0.3), inset 0 0 5px rgba(34,197,94,0.1)'
          : '0 0 10px rgba(239,68,68,0.3), inset 0 0 5px rgba(239,68,68,0.1)'
      el.style.boxShadow = shadow
      el.style.transition = 'box-shadow 0s'
      // Force reflow so the instant glow takes effect before we transition out
      void el.offsetHeight
      el.style.transition = 'box-shadow 600ms ease-out'
      el.style.boxShadow = 'none'
    },
    [ref],
  )
}

// ---------------------------------------------------------------------------
// Spinner
// ---------------------------------------------------------------------------

function Spinner() {
  return (
    <svg
      className="inline-block ml-1 h-3 w-3 animate-spin text-gray-400"
      viewBox="0 0 24 24"
      fill="none"
    >
      <circle
        className="opacity-25"
        cx="12"
        cy="12"
        r="10"
        stroke="currentColor"
        strokeWidth="4"
      />
      <path
        className="opacity-75"
        fill="currentColor"
        d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"
      />
    </svg>
  )
}

// ---------------------------------------------------------------------------
// Pencil icon — subtle edit indicator
// ---------------------------------------------------------------------------

function PencilIcon() {
  return (
    <svg
      className="inline-block ml-1 h-3 w-3 text-gray-600 group-hover:text-purple-400 transition-colors flex-shrink-0"
      viewBox="0 0 20 20"
      fill="currentColor"
    >
      <path d="M13.586 3.586a2 2 0 112.828 2.828l-.793.793-2.828-2.828.793-.793zM11.379 5.793L3 14.172V17h2.828l8.38-8.379-2.83-2.828z" />
    </svg>
  )
}

// ---------------------------------------------------------------------------
// EditableCell component
// ---------------------------------------------------------------------------

export function EditableCell({
  value,
  entityType,
  entityId,
  field,
  type,
  options,
  onSaved,
  displayRenderer,
}: EditableCellProps) {
  const [editing, setEditing] = useState(false)
  const [draft, setDraft] = useState('')
  const [errorTooltip, setErrorTooltip] = useState<string | null>(null)

  const { patch, loading } = usePatchEntity(entityType)

  const cellRef = useRef<HTMLDivElement | null>(null)
  const inputRef = useRef<HTMLInputElement | null>(null)
  const selectRef = useRef<HTMLSelectElement | null>(null)

  const flash = useFlash(cellRef)

  // -----------------------------------------------------------------------
  // Enter edit mode
  // -----------------------------------------------------------------------

  const startEditing = useCallback(() => {
    if (loading) return
    setDraft(value == null ? '' : String(value))
    setErrorTooltip(null)
    setEditing(true)
  }, [value, loading])

  // Auto-focus the input/select when entering edit mode
  useEffect(() => {
    if (!editing) return
    if (type === 'select') {
      selectRef.current?.focus()
    } else {
      inputRef.current?.focus()
      inputRef.current?.select()
    }
  }, [editing, type])

  // -----------------------------------------------------------------------
  // Save
  // -----------------------------------------------------------------------

  const save = useCallback(async () => {
    // Coerce the draft to the right type
    let coerced: unknown = draft
    if (type === 'number') {
      const num = Number(draft)
      if (Number.isNaN(num)) {
        setErrorTooltip('Invalid number')
        flash('red')
        setEditing(false)
        return
      }
      coerced = num
    }

    // Skip save if value hasn't changed
    const currentStr = value == null ? '' : String(value)
    if (String(coerced) === currentStr) {
      setEditing(false)
      return
    }

    try {
      await patch(entityId, { [field]: coerced })
      flash('green')
      setEditing(false)
      onSaved?.()
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err)
      setErrorTooltip(msg)
      flash('red')
      setEditing(false)
    }
  }, [draft, type, value, patch, entityId, field, flash, onSaved])

  // -----------------------------------------------------------------------
  // Cancel
  // -----------------------------------------------------------------------

  const cancel = useCallback(() => {
    setEditing(false)
    setErrorTooltip(null)
  }, [])

  // -----------------------------------------------------------------------
  // Key handler
  // -----------------------------------------------------------------------

  const onKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault()
        cancel()
      } else if (e.key === 'Enter') {
        e.preventDefault()
        save()
      }
    },
    [cancel, save],
  )

  // -----------------------------------------------------------------------
  // Clear error tooltip after a delay
  // -----------------------------------------------------------------------

  useEffect(() => {
    if (!errorTooltip) return
    const timer = setTimeout(() => setErrorTooltip(null), 3000)
    return () => clearTimeout(timer)
  }, [errorTooltip])

  // -----------------------------------------------------------------------
  // Shared input classes
  // -----------------------------------------------------------------------

  const inputClasses =
    'w-full bg-[var(--bg-elevated)] text-gray-100 text-sm rounded px-1.5 py-0.5 border border-purple-500/30 ' +
    'focus:border-purple-500 focus:outline-none focus:ring-1 focus:ring-purple-500/30 focus:shadow-[0_0_10px_rgba(168,85,247,0.15)]'

  // -----------------------------------------------------------------------
  // Render — edit mode
  // -----------------------------------------------------------------------

  if (editing) {
    return (
      <div ref={cellRef} className="relative">
        {type === 'select' ? (
          <select
            ref={selectRef}
            className={inputClasses}
            value={draft}
            onChange={e => setDraft(e.target.value)}
            onKeyDown={onKeyDown}
            onBlur={save}
          >
            {options?.map(opt => (
              <option key={opt.value} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>
        ) : (
          <input
            ref={inputRef}
            className={inputClasses}
            type={type}
            value={draft}
            onChange={e => setDraft(e.target.value)}
            onKeyDown={onKeyDown}
            onBlur={save}
          />
        )}
        {loading && <Spinner />}
      </div>
    )
  }

  // -----------------------------------------------------------------------
  // Render — display mode
  // -----------------------------------------------------------------------

  const displayValue = displayRenderer
    ? displayRenderer(value)
    : value == null || value === ''
      ? <span className="text-gray-500">--</span>
      : <span>{String(value)}</span>

  return (
    <div
      ref={cellRef}
      className="group relative flex items-center cursor-pointer rounded px-1 -mx-1 border-b border-dotted border-gray-700/50 hover:border-purple-500/40 hover:bg-[var(--bg-hover)] transition-colors"
      onClick={startEditing}
      role="button"
      tabIndex={0}
      onKeyDown={e => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault()
          startEditing()
        }
      }}
    >
      <span className="truncate">{displayValue}</span>
      {loading ? <Spinner /> : <PencilIcon />}

      {errorTooltip && (
        <div className="absolute left-0 -bottom-8 z-10 whitespace-nowrap rounded bg-red-900/90 backdrop-blur-sm border border-red-500/30 px-2 py-1 text-xs text-red-200 shadow-lg">
          {errorTooltip}
        </div>
      )}
    </div>
  )
}
