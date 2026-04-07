import type { Rarity } from '../../types/game'
import { RARITY_COLORS } from '../../lib/assets'

interface Props {
  rarity: Rarity
  size?: 'xs' | 'sm' | 'md'
}

/**
 * Rarity label. Sharp rectangle, mono, 1-char width indicator on the left.
 * Legendary gets a chromatic-hover flourish.
 */
export function RarityChip({ rarity, size = 'sm' }: Props) {
  const { fg, bg, border } = RARITY_COLORS[rarity]
  const h = size === 'xs' ? 16 : size === 'sm' ? 18 : 22
  const fs = size === 'xs' ? 9 : size === 'sm' ? 10 : 11
  return (
    <span
      className={`inline-flex items-center gap-[4px] font-mono uppercase ${rarity === 'LEGENDARY' ? 'chromatic-hover' : ''}`}
      style={{
        height: h,
        padding: `0 ${size === 'xs' ? 6 : 8}px`,
        fontSize: fs,
        letterSpacing: '0.12em',
        color: fg,
        background: bg,
        border: `1px solid ${border}`,
        lineHeight: 1,
      }}
    >
      <span
        aria-hidden
        style={{
          display: 'inline-block',
          width: 3,
          height: h - 8,
          background: fg,
        }}
      />
      {rarity}
    </span>
  )
}
