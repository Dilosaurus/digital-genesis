import type { CardTag } from '../../types/game'
import { TAG_COLORS } from '../../lib/assets'

interface Props {
  tag: CardTag
  size?: 'xs' | 'sm'
  active?: boolean
  onClick?: () => void
}

/**
 * Tag label (MELEE, PIRACY, HOLY...). Sharp corners, mono, low contrast
 * until hover or active. Interactive when onClick is provided.
 */
export function TagChip({ tag, size = 'sm', active = false, onClick }: Props) {
  const color = TAG_COLORS[tag]
  const interactive = !!onClick
  const h = size === 'xs' ? 16 : 18
  const fs = size === 'xs' ? 9 : 10

  return (
    <button
      type="button"
      onClick={onClick}
      disabled={!interactive}
      className="inline-flex items-center font-mono uppercase transition-colors duration-150"
      style={{
        height: h,
        padding: `0 ${size === 'xs' ? 6 : 8}px`,
        fontSize: fs,
        letterSpacing: '0.14em',
        color: active ? '#0A0808' : color,
        background: active ? color : 'transparent',
        border: `1px solid ${color}`,
        cursor: interactive ? 'pointer' : 'default',
        lineHeight: 1,
      }}
    >
      {tag}
    </button>
  )
}
