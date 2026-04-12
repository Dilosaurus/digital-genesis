import { resolveThumb, RARITY_COLORS } from '../../lib/assets'
import type { Rarity } from '../../types/game'
import type { ReactNode } from 'react'

interface Props {
  id: string
  displayName: string
  description: string
  rarity: Rarity
  icon?: string | null
  glyph?: string                 // fallback glyph for missing icon
  accentColor?: string           // left-edge stripe color (slot/tier specific)
  topRightLabel?: string         // e.g. slot name, gem tier
  topRightColor?: string
  footer?: ReactNode             // modifier chips etc.
  href?: string                  // optional, renders as a link
}

/**
 * ItemTile — a single catalog entry for gems / relics / equipment.
 *
 * Horizontal landscape layout (as opposed to CardTile which is portrait):
 *   [icon 96x96]  [name / rarity / description]     [accent bar]
 *   [footer: modifiers...]
 *
 * The accent bar on the right edge is colored by rarity; a left-edge
 * stripe is colored by slot/tier/category when provided.
 */
export function ItemTile({
  id,
  displayName,
  description,
  rarity,
  icon,
  glyph = '⧫',
  accentColor,
  topRightLabel,
  topRightColor,
  footer,
}: Props) {
  const iconUrl = resolveThumb(icon)
  const r = RARITY_COLORS[rarity]

  return (
    <div
      className="relative group min-w-0"
      style={{
        background: 'var(--server-rack)',
        border: '1px solid var(--burnt-brass)',
        boxShadow:
          'inset 0 1px 0 rgba(235, 224, 200, 0.03), 0 1px 0 rgba(0, 0, 0, 0.4)',
      }}
    >
      {/* accent stripe (left) */}
      {accentColor && (
        <div
          className="absolute top-0 bottom-0 left-0 w-[3px] group-hover:w-[5px] transition-[width] duration-150"
          style={{ background: accentColor }}
        />
      )}
      {/* rarity strip (right) */}
      <div
        className="absolute top-0 bottom-0 right-0 w-[3px]"
        style={{ background: r.fg, opacity: 0.85 }}
      />

      <div className="flex items-start gap-3 md:gap-4 p-4 pl-5 pr-5 min-w-0">
        {/* icon */}
        <div
          className="relative shrink-0 overflow-hidden scanlines-soft"
          style={{
            width: 'clamp(56px, 16vw, 72px)',
            aspectRatio: '1 / 1',
            background: 'var(--void-deeper)',
            border: '1px solid var(--burnt-brass-dim)',
          }}
        >
          {iconUrl ? (
            <img
              src={iconUrl}
              alt=""
              loading="lazy"
              className="w-full h-full object-cover transition-transform duration-300 group-hover:scale-[1.05]"
              style={{ filter: 'contrast(1.05) saturate(0.95)' }}
            />
          ) : (
            <div className="w-full h-full flex items-center justify-center">
              <span
                style={{
                  fontFamily: 'var(--font-display)',
                  fontSize: 'clamp(24px, 7vw, 32px)',
                  color: 'var(--burnt-brass)',
                  lineHeight: 1,
                }}
              >
                {glyph}
              </span>
            </div>
          )}
          {/* corner hatches */}
          {['tl', 'tr', 'bl', 'br'].map(c => (
            <span
              key={c}
              aria-hidden
              className="absolute"
              style={{
                width: 6,
                height: 6,
                border: '1px solid rgba(217, 176, 95, 0.4)',
                ...(c === 'tl' && { top: 2, left: 2, borderRight: 'none', borderBottom: 'none' }),
                ...(c === 'tr' && { top: 2, right: 2, borderLeft: 'none', borderBottom: 'none' }),
                ...(c === 'bl' && { bottom: 2, left: 2, borderRight: 'none', borderTop: 'none' }),
                ...(c === 'br' && { bottom: 2, right: 2, borderLeft: 'none', borderTop: 'none' }),
              }}
            />
          ))}
        </div>

        {/* text column */}
        <div className="flex-1 min-w-0">
          <div className="flex items-start justify-between gap-2 mb-1">
            <div className="min-w-0 flex-1">
              <div
                style={{
                  fontFamily: 'var(--font-display)',
                  fontSize: 'clamp(14px, 4vw, 17px)',
                  letterSpacing: '0.05em',
                  color: 'var(--bone)',
                  fontWeight: 600,
                  textTransform: 'uppercase',
                  lineHeight: 1.15,
                  overflow: 'hidden',
                  display: '-webkit-box',
                  WebkitLineClamp: 2,
                  WebkitBoxOrient: 'vertical',
                  wordBreak: 'break-word',
                  overflowWrap: 'anywhere',
                }}
              >
                {displayName}
              </div>
              <div
                className="mt-[3px] font-mono flex items-center gap-2 truncate"
                style={{ fontSize: 9, letterSpacing: '0.12em' }}
              >
                <span style={{ color: r.fg }}>{rarity}</span>
                <span style={{ color: 'var(--burnt-brass)' }}>·</span>
                <span className="truncate" style={{ color: 'var(--bone-faint)' }}>{id}</span>
              </div>
            </div>

            {topRightLabel && (
              <span
                className="shrink-0 font-mono uppercase"
                style={{
                  fontSize: 9,
                  letterSpacing: '0.14em',
                  color: topRightColor ?? 'var(--oxidized-gold)',
                  padding: '3px 6px',
                  border: `1px solid ${topRightColor ?? 'var(--oxidized-gold)'}`,
                  lineHeight: 1,
                }}
              >
                {topRightLabel}
              </span>
            )}
          </div>

          <p
            style={{
              fontFamily: 'var(--font-body)',
              fontSize: 14,
              lineHeight: 1.45,
              color: 'var(--bone-dim)',
              fontStyle: description ? 'normal' : 'italic',
              overflow: 'hidden',
              display: '-webkit-box',
              WebkitLineClamp: 2,
              WebkitBoxOrient: 'vertical',
              wordBreak: 'break-word',
              overflowWrap: 'anywhere',
            }}
          >
            {description || '—'}
          </p>
        </div>
      </div>

      {footer && (
        <div
          className="px-4 md:px-5 pb-4 pt-0 min-w-0"
          style={{ borderTop: '1px dotted var(--burnt-brass-dim)', marginTop: 0 }}
        >
          <div className="pt-3 flex flex-wrap gap-2 min-w-0">{footer}</div>
        </div>
      )}
    </div>
  )
}
