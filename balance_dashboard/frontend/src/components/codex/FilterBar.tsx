import type { ReactNode } from 'react'

/**
 * Terminal-style filter bar for codex pages. Horizontal strip with a
 * mono prompt on the left ("$ grep ..."), one or more filter groups,
 * and a counter slot on the right.
 */
interface FilterBarProps {
  children: ReactNode
  counter?: ReactNode
}

export function FilterBar({ children, counter }: FilterBarProps) {
  return (
    <div
      className="relative mb-5 md:mb-8 terminal-frame scanlines-soft min-w-0"
      style={{
        marginLeft: 'clamp(1rem, 6vw, 6rem)',
        marginRight: 'clamp(1rem, 6vw, 6rem)',
        padding: '10px 12px',
      }}
    >
      <div className="flex flex-col md:flex-row md:flex-wrap md:items-center gap-3 md:gap-x-6 md:gap-y-3 font-mono min-w-0">
        {children}
        {counter && (
          <div
            className="md:ml-auto text-[10px] md:text-[11px] pt-2 md:pt-0 min-w-0"
            style={{
              color: 'var(--bone-faint)',
              letterSpacing: '0.02em',
              borderTop: '1px dotted var(--burnt-brass-dim)',
            }}
          >
            {counter}
          </div>
        )}
      </div>
    </div>
  )
}

// ─── Filter group: a label + a row of chips ──────────────────────────────

interface FilterGroupProps {
  label: string
  children: ReactNode
}

export function FilterGroup({ label, children }: FilterGroupProps) {
  return (
    <div className="flex items-center gap-2 min-w-0 w-full md:w-auto">
      <span
        className="uppercase text-[10px] shrink-0"
        style={{ color: 'var(--burnt-brass)', letterSpacing: '0.18em' }}
      >
        {label}
      </span>
      <span className="shrink-0" style={{ color: 'var(--burnt-brass)' }}>/</span>
      <div
        className="flex gap-[6px] overflow-x-auto no-scrollbar md:flex-wrap min-w-0"
        style={{ paddingBottom: 2 }}
      >
        {children}
      </div>
    </div>
  )
}

// ─── Filter chip: generic toggleable filter ──────────────────────────────

interface FilterChipProps {
  label: string
  active: boolean
  onClick: () => void
  color?: string
  size?: 'xs' | 'sm'
}

export function FilterChip({ label, active, onClick, color, size = 'sm' }: FilterChipProps) {
  const col = color ?? '#D9B05F'
  const h = size === 'xs' ? 16 : 18
  const fs = size === 'xs' ? 9 : 10
  return (
    <button
      type="button"
      onClick={onClick}
      className="inline-flex items-center font-mono uppercase transition-colors duration-150 cursor-pointer"
      style={{
        height: h,
        padding: `0 ${size === 'xs' ? 6 : 8}px`,
        fontSize: fs,
        letterSpacing: '0.12em',
        color: active ? '#0A0808' : col,
        background: active ? col : 'transparent',
        border: `1px solid ${col}`,
        lineHeight: 1,
      }}
    >
      {label}
    </button>
  )
}

// ─── Search input: mono, terminal prompt prefix ──────────────────────────

interface SearchInputProps {
  value: string
  onChange: (v: string) => void
  placeholder?: string
}

export function SearchInput({ value, onChange, placeholder = 'search...' }: SearchInputProps) {
  return (
    <div className="flex items-center gap-2 w-full md:w-auto md:min-w-[220px] min-w-0">
      <span
        className="font-mono text-[11px] shrink-0"
        style={{ color: 'var(--oxidized-gold)', letterSpacing: '0.02em' }}
      >
        $&nbsp;grep
      </span>
      <input
        type="text"
        value={value}
        onChange={e => onChange(e.target.value)}
        placeholder={placeholder}
        className="flex-1 min-w-0 font-mono bg-transparent outline-none border-0 border-b border-dotted"
        style={{
          color: 'var(--bone)',
          borderBottomColor: 'var(--burnt-brass)',
          fontSize: 12,
          padding: '2px 0',
          letterSpacing: '0.02em',
        }}
      />
    </div>
  )
}
