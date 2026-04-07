import { Link } from 'react-router-dom'
import type { Card } from '../../types/game'
import {
  resolveAsset,
  charClassColor,
  charClassCode,
  CARD_TYPE_COLORS,
  CARD_TYPE_GLYPH,
  RARITY_COLORS,
} from '../../lib/assets'

interface Props {
  card: Card
  index?: number
}

/**
 * CardTile — one card in the catalog grid. A vertical rectangle with a
 * gold-brass frame, a proportion of space for art (when present), a name
 * block, an energy cost badge, a type glyph, a rarity strip, a row of
 * gem socket pips, and the character-class accent line on the left.
 *
 * Intentional visual idiom: nothing is centered. The cost badge sits
 * slightly outside the frame in the top-left notch. The rarity strip is
 * a vertical bar on the right edge, not a bottom badge.
 */
export function CardTile({ card, index }: Props) {
  const art = resolveAsset(card.artwork)
  const typeColor = CARD_TYPE_COLORS[card.card_type]
  const typeGlyph = CARD_TYPE_GLYPH[card.card_type]
  const rarity = RARITY_COLORS[card.rarity]
  const classColor = charClassColor(card.character_class)

  return (
    <Link
      to={`/codex/cards/${card.id}`}
      className="group relative block"
      style={{
        aspectRatio: '3 / 4.1',
        textDecoration: 'none',
      }}
    >
      {/* ── outer frame (burnt brass) ───────────────────────────────── */}
      <div
        className="absolute inset-0 transition-all duration-200 ease-out group-hover:translate-y-[-2px]"
        style={{
          background: 'var(--server-rack)',
          border: '1px solid var(--burnt-brass)',
          boxShadow:
            'inset 0 1px 0 rgba(235, 224, 200, 0.03), 0 1px 0 rgba(0, 0, 0, 0.4)',
        }}
      />

      {/* ── character-class accent stripe (left edge) ───────────────── */}
      <div
        className="absolute top-0 bottom-0 left-0 w-[3px] group-hover:w-[5px] transition-[width] duration-150"
        style={{ background: classColor }}
      />

      {/* ── rarity strip (right edge) ───────────────────────────────── */}
      <div
        className="absolute top-0 bottom-0 right-0 w-[3px]"
        style={{ background: rarity.fg, opacity: 0.85 }}
      />

      {/* ── art region ──────────────────────────────────────────────── */}
      <div
        className="absolute overflow-hidden"
        style={{
          top: 6,
          left: 6,
          right: 6,
          height: '62%',
          background: 'var(--void-deeper)',
          border: '1px solid var(--burnt-brass-dim)',
        }}
      >
        {art ? (
          <img
            src={art}
            alt=""
            loading="lazy"
            className="w-full h-full object-cover transition-all duration-300 ease-out group-hover:scale-[1.04]"
            style={{
              filter: 'contrast(1.05) saturate(0.95)',
            }}
          />
        ) : (
          <MissingArt card={card} />
        )}

        {/* Corner hatch marks */}
        <CornerHatches />
      </div>

      {/* ── energy cost (top-left, half-outside the frame) ──────────── */}
      <div
        className="absolute flex items-center justify-center font-display font-bold"
        style={{
          top: -8,
          left: -8,
          width: 30,
          height: 30,
          borderRadius: '50%',
          background: 'var(--void)',
          border: '1.5px solid var(--oxidized-gold)',
          color: 'var(--halo)',
          fontFamily: 'var(--font-display)',
          fontSize: 15,
          letterSpacing: 0,
          boxShadow: '0 0 12px rgba(217, 176, 95, 0.25)',
        }}
      >
        {card.energy_cost}
      </div>

      {/* ── type glyph (top-right of art) ───────────────────────────── */}
      <div
        className="absolute font-display"
        style={{
          top: 10,
          right: 12,
          color: typeColor,
          fontSize: 18,
          textShadow: `0 0 6px ${typeColor}66`,
          fontFamily: 'var(--font-display)',
        }}
      >
        {typeGlyph}
      </div>

      {/* ── name + meta ─────────────────────────────────────────────── */}
      <div
        className="absolute left-0 right-0 px-3 pt-2 pb-2 min-w-0"
        style={{
          top: '65%',
          bottom: 0,
        }}
      >
        <div
          className="mb-[2px]"
          style={{
            fontFamily: 'var(--font-display)',
            fontSize: 13,
            letterSpacing: '0.05em',
            color: 'var(--bone)',
            fontWeight: 600,
            textTransform: 'uppercase',
            lineHeight: 1.1,
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
          className="font-mono flex items-center gap-[6px] mb-2"
          style={{
            fontSize: 9,
            color: 'var(--bone-faint)',
            letterSpacing: '0.1em',
          }}
        >
          <span style={{ color: typeColor }}>{card.card_type}</span>
          <span style={{ color: 'var(--burnt-brass)' }}>·</span>
          <span style={{ color: classColor }}>{charClassCode(card.character_class)}</span>
          {card.upgraded && (
            <>
              <span style={{ color: 'var(--burnt-brass)' }}>·</span>
              <span style={{ color: 'var(--halo)' }}>+</span>
            </>
          )}
        </div>

        {/* description preview */}
        <div
          className="line-clamp-2"
          style={{
            fontFamily: 'var(--font-body)',
            fontSize: 11,
            lineHeight: 1.35,
            color: 'var(--bone-dim)',
            fontStyle: card.description ? 'normal' : 'italic',
            overflow: 'hidden',
            display: '-webkit-box',
            WebkitLineClamp: 2,
            WebkitBoxOrient: 'vertical',
          }}
        >
          {card.description || '—'}
        </div>
      </div>

      {/* ── gem sockets (bottom-left pips) ──────────────────────────── */}
      {card.gem_sockets > 0 && (
        <div
          className="absolute flex gap-[3px]"
          style={{ bottom: 4, left: 6 }}
        >
          {Array.from({ length: card.gem_sockets }).map((_, i) => (
            <span
              key={i}
              style={{
                display: 'inline-block',
                width: 5,
                height: 5,
                background: 'var(--oxidized-gold)',
                border: '0.5px solid var(--halo)',
                transform: 'rotate(45deg)',
              }}
            />
          ))}
        </div>
      )}

      {/* ── index in gutter (bottom-right, filename-style) ──────────── */}
      {index != null && (
        <div
          className="absolute font-mono"
          style={{
            bottom: 4,
            right: 8,
            fontSize: 8,
            color: 'var(--burnt-brass)',
            letterSpacing: '0.04em',
          }}
        >
          #{String(index).padStart(3, '0')}
        </div>
      )}

      {/* ── hover chromatic aberration on title ─────────────────────── */}
      <div
        aria-hidden
        className="absolute inset-0 pointer-events-none opacity-0 group-hover:opacity-100 transition-opacity duration-200"
        style={{
          boxShadow: `inset 0 0 0 1px ${classColor}, 0 0 18px -4px ${classColor}`,
        }}
      />
    </Link>
  )
}

/**
 * Fallback art slot for cards without illustrations. Shows a big type glyph
 * and the card id as a filename — very deliberate "this is missing" framing,
 * not a placeholder.
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
          fontSize: 56,
          color: typeColor,
          opacity: 0.6,
          letterSpacing: 0,
          lineHeight: 1,
          marginBottom: 6,
          filter: `drop-shadow(0 0 8px ${typeColor}44)`,
        }}
      >
        {glyph}
      </div>
      <div
        className="font-mono uppercase text-center px-2"
        style={{
          color: 'var(--burnt-brass)',
          fontSize: 8,
          letterSpacing: '0.18em',
        }}
      >
        art pending
      </div>
      <div
        className="font-mono text-center mt-1 px-2 truncate max-w-full"
        style={{
          color: 'var(--bone-faint)',
          fontSize: 9,
          letterSpacing: '0.02em',
        }}
      >
        {card.id}.png
      </div>
    </div>
  )
}

function CornerHatches() {
  const style = {
    position: 'absolute',
    width: 8,
    height: 8,
    border: '1px solid rgba(217, 176, 95, 0.35)',
  } as const
  return (
    <>
      <span aria-hidden style={{ ...style, top: 2, left: 2, borderRight: 'none', borderBottom: 'none' }} />
      <span aria-hidden style={{ ...style, top: 2, right: 2, borderLeft: 'none', borderBottom: 'none' }} />
      <span aria-hidden style={{ ...style, bottom: 2, left: 2, borderRight: 'none', borderTop: 'none' }} />
      <span aria-hidden style={{ ...style, bottom: 2, right: 2, borderLeft: 'none', borderTop: 'none' }} />
    </>
  )
}
