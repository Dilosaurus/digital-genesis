import { memo } from 'react'
import { Handle, Position } from '@xyflow/react'
import type { NodeProps } from '@xyflow/react'

// ---------------------------------------------------------------------------
// Type-to-style mapping — gradient backgrounds, borders, accents, glows
// ---------------------------------------------------------------------------

interface TypeStyle {
  bg: string
  border: string
  borderActive: string
  topBorder: string
  badge: string
  glow: string
}

const TYPE_STYLES: Record<string, TypeStyle> = {
  card: {
    bg: 'bg-gradient-to-b from-blue-900/90 to-blue-950/80',
    border: 'border-blue-500/40',
    borderActive: 'border-blue-400',
    topBorder: 'border-t-blue-400',
    badge: 'bg-blue-500/20 text-blue-300 border-blue-500/30',
    glow: 'glow-blue',
  },
  stat: {
    bg: 'bg-gradient-to-b from-red-900/90 to-red-950/80',
    border: 'border-red-500/40',
    borderActive: 'border-red-400',
    topBorder: 'border-t-red-400',
    badge: 'bg-red-500/20 text-red-300 border-red-500/30',
    glow: 'glow-red',
  },
  relic: {
    bg: 'bg-gradient-to-b from-green-900/90 to-green-950/80',
    border: 'border-green-500/40',
    borderActive: 'border-green-400',
    topBorder: 'border-t-green-400',
    badge: 'bg-green-500/20 text-green-300 border-green-500/30',
    glow: 'glow-green',
  },
  equipment: {
    bg: 'bg-gradient-to-b from-purple-900/90 to-purple-950/80',
    border: 'border-purple-500/40',
    borderActive: 'border-purple-400',
    topBorder: 'border-t-purple-400',
    badge: 'bg-purple-500/20 text-purple-300 border-purple-500/30',
    glow: 'glow-purple',
  },
  gem: {
    bg: 'bg-gradient-to-b from-orange-900/90 to-orange-950/80',
    border: 'border-orange-500/40',
    borderActive: 'border-orange-400',
    topBorder: 'border-t-orange-400',
    badge: 'bg-orange-500/20 text-orange-300 border-orange-500/30',
    glow: 'glow-orange',
  },
  skill: {
    bg: 'bg-gradient-to-b from-cyan-900/90 to-cyan-950/80',
    border: 'border-cyan-500/40',
    borderActive: 'border-cyan-400',
    topBorder: 'border-t-cyan-400',
    badge: 'bg-cyan-500/20 text-cyan-300 border-cyan-500/30',
    glow: 'glow-cyan',
  },
  enemy: {
    bg: 'bg-gradient-to-b from-slate-800/90 to-slate-900/80',
    border: 'border-slate-500/40',
    borderActive: 'border-slate-400',
    topBorder: 'border-t-slate-400',
    badge: 'bg-slate-500/20 text-slate-300 border-slate-500/30',
    glow: '',
  },
  tag: {
    bg: 'bg-gradient-to-b from-yellow-900/90 to-yellow-950/80',
    border: 'border-yellow-500/40',
    borderActive: 'border-yellow-400',
    topBorder: 'border-t-yellow-400',
    badge: 'bg-yellow-500/20 text-yellow-300 border-yellow-500/30',
    glow: 'glow-yellow',
  },
}

const DEFAULT_STYLE: TypeStyle = {
  bg: 'bg-gradient-to-b from-gray-800/90 to-gray-900/80',
  border: 'border-gray-500/40',
  borderActive: 'border-gray-400',
  topBorder: 'border-t-gray-400',
  badge: 'bg-gray-500/20 text-gray-300 border-gray-500/30',
  glow: '',
}

// ---------------------------------------------------------------------------
// Key stat extraction — shows the most relevant numbers per node type
// ---------------------------------------------------------------------------

function getKeyStats(type: string, data: Record<string, unknown>): string | null {
  switch (type) {
    case 'card': {
      const parts: string[] = []
      if (typeof data.damage === 'number' && data.damage > 0)
        parts.push(`DMG ${data.damage}`)
      if (typeof data.block === 'number' && data.block > 0)
        parts.push(`BLK ${data.block}`)
      if (typeof data.energy_cost === 'number')
        parts.push(`E${data.energy_cost}`)
      return parts.length ? parts.join('  ') : null
    }
    case 'enemy': {
      if (typeof data.max_hp === 'number') return `HP ${data.max_hp}`
      return null
    }
    case 'relic': {
      const parts: string[] = []
      if (typeof data.bonus_max_hp === 'number' && data.bonus_max_hp !== 0)
        parts.push(`+${data.bonus_max_hp} HP`)
      if (typeof data.bonus_max_energy === 'number' && data.bonus_max_energy !== 0)
        parts.push(`+${data.bonus_max_energy} NRG`)
      return parts.length ? parts.join('  ') : null
    }
    case 'skill': {
      if (typeof data.tier === 'number') return `Tier ${data.tier}`
      return null
    }
    case 'stat': {
      if (typeof data.value === 'number') return String(data.value)
      return null
    }
    default:
      return null
  }
}

// ---------------------------------------------------------------------------
// CustomNode component
// ---------------------------------------------------------------------------

export interface CustomNodeData extends Record<string, unknown> {
  label: string
  nodeType: string
  highlighted?: boolean
  dimmed?: boolean
}

function CustomNodeComponent({ data, selected }: NodeProps) {
  const nodeData = data as CustomNodeData
  const { label, nodeType, highlighted, dimmed } = nodeData

  const style = TYPE_STYLES[nodeType] ?? DEFAULT_STYLE
  const keyStats = getKeyStats(nodeType, nodeData)

  const isActive = selected || highlighted

  return (
    <div
      className={[
        // Layout & shape
        'rounded-lg border-2 px-3 py-2.5 min-w-[160px] max-w-[200px]',
        // Top accent border (3px)
        'border-t-[3px]',
        style.topBorder,
        // Background gradient
        style.bg,
        // Shadow
        'shadow-lg shadow-black/20',
        // Transition
        'transition-all duration-150 select-none',
        // Border color: active vs default
        isActive
          ? `${style.borderActive} ${style.glow}`
          : style.border,
        // Dimmed state
        dimmed ? 'opacity-20 blur-[0.5px]' : 'opacity-100',
      ].join(' ')}
    >
      {/* Source handle — top */}
      <Handle
        type="target"
        position={Position.Top}
        className="!w-2 !h-2 !bg-gray-400 !border-gray-600"
      />

      {/* Type badge */}
      <div className="flex items-center justify-between gap-1 mb-1.5">
        <span
          className={[
            'badge text-[9px]',
            style.badge,
          ].join(' ')}
        >
          {nodeType}
        </span>
      </div>

      {/* Label */}
      <div
        className="text-gray-100 text-sm font-semibold leading-tight truncate"
        title={label}
      >
        {label}
      </div>

      {/* Key stats */}
      {keyStats && (
        <div className="mt-1.5 text-gray-400 font-mono text-[10px] tracking-wide">
          {keyStats}
        </div>
      )}

      {/* Target handle — bottom */}
      <Handle
        type="source"
        position={Position.Bottom}
        className="!w-2 !h-2 !bg-gray-400 !border-gray-600"
      />
    </div>
  )
}

export const CustomNode = memo(CustomNodeComponent)
export default CustomNode
