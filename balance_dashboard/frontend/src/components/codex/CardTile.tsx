import { memo } from 'react'
import { Link } from 'react-router-dom'
import type { Card } from '../../types/game'
import {
  resolveThumb,
  charClassColor,
  charClassCode,
  CARD_TYPE_COLORS,
  CARD_TYPE_GLYPH,
  RARITY_COLORS,
} from '../../lib/assets'

interface Props {
  card: Card
  onSelect?: (id: string) => void
}

/**
 * CardTile — one card in the catalog grid. Art-forward layout with
 * a minimal name plate below. Clicking opens the detail modal when
 * onSelect is provided; ctrl/meta/shift+click still opens the
 * dedicated detail page in a new tab via the underlying Link.
 */
export const CardTile = memo(function CardTile({ card, onSelect }: Props) {
  const art = resolveThumb(card.artwork)
  const typeColor = CARD_TYPE_COLORS[card.card_type]
  const typeGlyph = CARD_TYPE_GLYPH[card.card_type]
  const rarity = RARITY_COLORS[card.rarity]
  const classColor = charClassColor(card.character_class)

  return (
    <Link
      to={`/codex/cards/${card.id}`}
      className="group relative block"
      style={{
        aspectRatio: '3 / 4',
        textDecoration: 'none',
        contentVisibility: 'auto',
        containIntrinsicSize: 'auto 140px auto 186px',
      } as React.CSSProperties}
      onClick={e => {
        if (onSelect && !e.ctrlKey && !e.metaKey && !e.shiftKey) {
          e.preventDefault()
          onSelect(card.id)
        }
      }}
    >
      {/* ── outer frame ────────────────────────────────────────────── */}
      <div
        className="absolute inset-0 transition-all duration-200 ease-out group-hover:translate-y-[-2px]"
        style={{
          background: 'var(--server-rack)',
          border: '1px solid var(--burnt-brass)',
          boxShadow:
            'inset 0 1px 0 rgba(235, 224, 200, 0.03), 0 1px 0 rgba(0, 0, 0, 0.4)',
        }}
      />

      {/* ── character-class accent stripe (left) ───────────────────── */}
      <div
        className="absolute top-0 bottom-0 left-0 w-[3px] group-hover:w-[5px] transition-[width] duration-150"
        style={{ background: classColor }}
      />

      {/* ── rarity strip (right) ───────────────────────────────────── */}
      <div
        className="absolute top-0 bottom-0 right-0 w-[3px]"
        style={{ background: rarity.fg, opacity: 0.85 }}
      />

      {/* ── art region (72% of card height) ────────────────────────── */}
      <div
        className="absolute overflow-hidden"
        style={{
          top: 5,
          left: 5,
          right: 5,
          height: '72%',
          background: 'var(--void-deeper)',
          border: '1px solid var(--burnt-brass-dim)',
        }}
      >
        {art ? (
          <img
            src={art}
            alt=""
            loading="lazy"
            className="w-full h-full object-cover transition-transform duration-300 ease-out group-hover:scale-[1.04]"
            style={{ filter: 'contrast(1.05) saturate(0.95)' }}
          />
        ) : (
          <MissingArt card={card} />
        )}
        <CornerHatches />
      </div>

      {/* ── energy cost badge (top-left) ───────────────────────────── */}
      <div
        className="absolute flex items-center justify-center"
        style={{
          top: -7,
          left: -7,
          width: 28,
          height: 28,
          borderRadius: '50%',
          background: 'var(--void)',
          border: '1.5px solid var(--oxidized-gold)',
          color: 'var(--halo)',
          fontFamily: 'var(--font-display)',
          fontSize: 14,
          fontWeight: 700,
          boxShadow: '0 0 10px rgba(217, 176, 95, 0.25)',
        }}
      >
        {card.energy_cost}
      </div>

      {/* ── type glyph (top-right of art) ──────────────────────────── */}
      <div
        className="absolute"
        style={{
          top: 9,
          right: 10,
          color: typeColor,
          fontSize: 16,
          fontFamily: 'var(--font-display)',
          textShadow: `0 0 6px ${typeColor}66`,
        }}
      >
        {typeGlyph}
      </div>

      {/* ── name plate ─────────────────────────────────────────────── */}
      <div
        className="absolute left-0 right-0 px-[8px] flex flex-col justify-center"
        style={{ top: '74%', bottom: 0 }}
      >
        <div
          style={{
            fontFamily: 'var(--font-display)',
            fontSize: 12,
            letterSpacing: '0.04em',
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
          {card.display_name}
        </div>

        <div
          className="font-mono flex items-center gap-[5px] mt-[3px]"
          style={{
            fontSize: 8,
            color: 'var(--bone-faint)',
            letterSpacing: '0.08em',
          }}
        >
          <span style={{ color: typeColor }}>{card.card_type}</span>
          <span style={{ color: 'var(--burnt-brass)' }}>·</span>
          <span style={{ color: classColor }}>
            {charClassCode(card.character_class)}
          </span>
          {card.upgraded && (
            <>
              <span style={{ color: 'var(--burnt-brass)' }}>·</span>
              <span style={{ color: 'var(--halo)' }}>+</span>
            </>
          )}
        </div>
      </div>

      {/* ── hover glow ─────────────────────────────────────────────── */}
      <div
        aria-hidden
        className="absolute inset-0 pointer-events-none opacity-0 group-hover:opacity-100 transition-opacity duration-200"
        style={{
          boxShadow: `inset 0 0 0 1px ${classColor}, 0 0 18px -4px ${classColor}`,
        }}
      />
    </Link>
  )
})

/**
 * Fallback for cards without art — big type glyph + filename.
 */
function MissingArt({ card }: { card: Card }) {
  const typeColor = CARD_TYPE_COLORS[card.card_type]
  const glyph = CARD_TYPE_GLYPH[card.card_type]
  return (
    <div
      className="w-full h-full flex flex-col items-center justify-center relative scanlines-soft"
      style={{
        background:
          'radial-gradient(ellipse at center, rgba(217, 176, 95, 0.04) 0%, transparent 60%)',
      }}
    >
      <div
        className="absolute inset-0 opacity-[0.08]"
        style={{
          background:
            'repeating-linear-gradient(45deg, transparent 0, transparent 8px, rgba(217,176,95,0.22) 8px, rgba(217,176,95,0.22) 9px)',
        }}
      />
      <div
        style={{
          fontFamily: 'var(--font-display)',
          fontSize: 48,
          color: typeColor,
          opacity: 0.5,
          lineHeight: 1,
        }}
      >
        {glyph}
      </div>
      <div
        className="font-mono uppercase text-center mt-1 px-2"
        style={{
          color: 'var(--burnt-brass)',
          fontSize: 7,
          letterSpacing: '0.18em',
        }}
      >
        art pending
      </div>
    </div>
  )
}

function CornerHatches() {
  const s = {
    position: 'absolute' as const,
    width: 7,
    height: 7,
    border: '1px solid rgba(217, 176, 95, 0.3)',
  }
  return (
    <>
      <span aria-hidden style={{ ...s, top: 2, left: 2, borderRight: 'none', borderBottom: 'none' }} />
      <span aria-hidden style={{ ...s, top: 2, right: 2, borderLeft: 'none', borderBottom: 'none' }} />
      <span aria-hidden style={{ ...s, bottom: 2, left: 2, borderRight: 'none', borderTop: 'none' }} />
      <span aria-hidden style={{ ...s, bottom: 2, right: 2, borderLeft: 'none', borderTop: 'none' }} />
    </>
  )
}
