import type { ChangeEvent } from 'react'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export const NODE_TYPES = [
  'card',
  'stat',
  'relic',
  'equipment',
  'gem',
  'skill',
  'enemy',
  'tag',
] as const

export type NodeTypeKey = (typeof NODE_TYPES)[number]

const NODE_TYPE_LABELS: Record<NodeTypeKey, string> = {
  card:      'Cards',
  stat:      'Stats',
  relic:     'Relics',
  equipment: 'Equipment',
  gem:       'Gems',
  skill:     'Skills',
  enemy:     'Enemies',
  tag:       'Tags',
}

const TYPE_DOT_COLORS: Record<NodeTypeKey, string> = {
  card:      'bg-blue-400',
  stat:      'bg-red-400',
  relic:     'bg-green-400',
  equipment: 'bg-purple-400',
  gem:       'bg-orange-400',
  skill:     'bg-cyan-400',
  enemy:     'bg-slate-400',
  tag:       'bg-yellow-400',
}

const TYPE_CHECKBOX_ACCENT: Record<NodeTypeKey, string> = {
  card:      'accent-blue-400',
  stat:      'accent-red-400',
  relic:     'accent-green-400',
  equipment: 'accent-purple-400',
  gem:       'accent-orange-400',
  skill:     'accent-cyan-400',
  enemy:     'accent-slate-400',
  tag:       'accent-yellow-400',
}

// ---------------------------------------------------------------------------
// Props
// ---------------------------------------------------------------------------

export interface GraphControlsProps {
  visibleTypes: Set<NodeTypeKey>
  onToggleType: (type: NodeTypeKey) => void
  onToggleAll: (checked: boolean) => void
  onResetView: () => void
  nodeCount: number
  edgeCount: number
  selectedNodeLabel?: string | null
  onClearSelection: () => void
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export function GraphControls({
  visibleTypes,
  onToggleType,
  onToggleAll,
  onResetView,
  nodeCount,
  edgeCount,
  selectedNodeLabel,
  onClearSelection,
}: GraphControlsProps) {
  const allChecked = NODE_TYPES.every(t => visibleTypes.has(t))
  const someChecked = NODE_TYPES.some(t => visibleTypes.has(t))

  function handleMasterChange(e: ChangeEvent<HTMLInputElement>) {
    onToggleAll(e.target.checked)
  }

  return (
    <aside className="panel panel-accent-purple flex flex-col gap-4 w-52 shrink-0 p-4 text-sm text-gray-300 overflow-y-auto">
      {/* Header */}
      <div>
        <div className="flex items-center gap-2 mb-1.5">
          <svg
            className="w-4 h-4 text-purple-400"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={2}
            aria-hidden
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z"
            />
          </svg>
          <h2 className="text-gray-100 font-semibold text-xs uppercase tracking-wider">
            Filters
          </h2>
        </div>
        <div className="text-gray-500 text-[10px] font-mono">
          {nodeCount} nodes &middot; {edgeCount} edges
        </div>
      </div>

      {/* Master toggle */}
      <label className="flex items-center gap-2.5 cursor-pointer hover:text-gray-100 transition-colors bg-purple-500/10 border border-purple-500/20 rounded-lg px-3 py-2">
        <input
          type="checkbox"
          checked={allChecked}
          ref={el => {
            if (el) el.indeterminate = !allChecked && someChecked
          }}
          onChange={handleMasterChange}
          className="accent-purple-400 w-4 h-4"
        />
        <span className="font-semibold text-gray-100 text-xs uppercase tracking-wide">All types</span>
      </label>

      <div className="border-t border-purple-500/10" />

      {/* Per-type checkboxes */}
      <ul className="flex flex-col gap-2">
        {NODE_TYPES.map(type => (
          <li key={type}>
            <label className="flex items-center gap-2.5 cursor-pointer hover:text-gray-100 transition-colors px-1">
              <input
                type="checkbox"
                checked={visibleTypes.has(type)}
                onChange={() => onToggleType(type)}
                className={`${TYPE_CHECKBOX_ACCENT[type]} w-3.5 h-3.5`}
              />
              <span
                className={[
                  'inline-block w-3 h-3 rounded-full shrink-0',
                  TYPE_DOT_COLORS[type],
                ].join(' ')}
              />
              <span className="text-xs">{NODE_TYPE_LABELS[type]}</span>
            </label>
          </li>
        ))}
      </ul>

      <div className="border-t border-purple-500/10" />

      {/* Reset view button */}
      <button
        onClick={onResetView}
        className="w-full gradient-purple text-white rounded-lg px-3 py-2 text-xs font-semibold uppercase tracking-wide flex items-center justify-center gap-2 hover:glow-purple transition-all active:scale-[0.97]"
      >
        <svg
          className="w-3.5 h-3.5"
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          strokeWidth={2}
          aria-hidden
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
          />
        </svg>
        Reset View
      </button>

      {/* Selected node info */}
      {selectedNodeLabel && (
        <>
          <div className="border-t border-purple-500/10" />
          <div className="bg-purple-500/5 border border-purple-500/15 rounded-lg px-3 py-2.5">
            <div className="text-[10px] text-purple-400 uppercase tracking-widest font-semibold mb-1">
              Selected
            </div>
            <div className="text-gray-100 text-xs font-medium truncate" title={selectedNodeLabel}>
              {selectedNodeLabel}
            </div>
            <button
              onClick={onClearSelection}
              className="mt-2 text-[10px] text-purple-400/70 hover:text-purple-300 transition-colors underline underline-offset-2"
            >
              Clear selection
            </button>
          </div>
        </>
      )}
    </aside>
  )
}

export default GraphControls
