import { useEffect } from 'react'
import type { Card } from '../../types/game'
import {
  resolveAsset, charClassColor, charClassName,
  CARD_TYPE_COLORS, CARD_TYPE_GLYPH, TAG_COLORS,
} from '../../lib/assets'
import { RarityChip } from './RarityChip'
import { pad } from '../../lib/format'

interface Props {
  card: Card
  allCards: Card[]
  onClose: () => void
  onSelectCard: (id: string) => void
}

export function CardModal({ card, allCards, onClose, onSelectCard }: Props) {
  useEffect(() => {
    const h = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    document.addEventListener('keydown', h)
    return () => document.removeEventListener('keydown', h)
  }, [onClose])

  useEffect(() => {
    const prev = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => { document.body.style.overflow = prev }
  }, [])

  const art = resolveAsset(card.artwork)
  const typeColor = CARD_TYPE_COLORS[card.card_type]
  const typeGlyph = CARD_TYPE_GLYPH[card.card_type]
  const classColor = charClassColor(card.character_class)
  const cls = charClassName(card.character_class)
  const upgradeCard = card.upgrade_id
    ? allCards.find(c => c.id === card.upgrade_id)
    : undefined

  return (
    <>
      <style>{`
        @keyframes cm-fade { from { opacity: 0 } }
        @keyframes cm-rise { from { opacity: 0; transform: translateY(16px) } }
      `}</style>

      {/* backdrop */}
      <div
        className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto py-8 md:py-12 px-4"
        style={{
          background: 'rgba(5, 5, 8, 0.88)',
          backdropFilter: 'blur(12px)',
          WebkitBackdropFilter: 'blur(12px)',
          animation: 'cm-fade 0.2s ease-out',
        }}
        onClick={onClose}
      >
        {/* panel */}
        <div
          className="relative w-full max-w-[880px]"
          style={{
            background: 'var(--void-deeper)',
            border: '1px solid var(--burnt-brass)',
            boxShadow:
              '0 0 80px rgba(0,0,0,0.7), 0 0 1px rgba(217,176,95,0.3), inset 0 1px 0 rgba(235,224,200,0.04)',
            animation: 'cm-rise 0.3s ease-out',
          }}
          onClick={e => e.stopPropagation()}
        >
          {/* close */}
          <button
            onClick={onClose}
            className="absolute top-4 right-5 z-10 font-mono text-[12px] uppercase transition-colors duration-150"
            style={{
              color: 'var(--bone-faint)',
              letterSpacing: '0.14em',
              background: 'none',
              border: 'none',
              cursor: 'pointer',
            }}
            onMouseEnter={e => (e.currentTarget.style.color = 'var(--bone)')}
            onMouseLeave={e => (e.currentTarget.style.color = 'var(--bone-faint)')}
          >
            ✕
          </button>

          {/* class accent stripe */}
          <div
            className="absolute top-0 bottom-0 left-0 w-[4px]"
            style={{ background: classColor }}
          />

          {/* ─── hero: art + info ──────────────────────────────────────── */}
          <div className="flex flex-col md:flex-row gap-6 md:gap-10 p-6 md:p-10 md:pr-12">
            {/* art panel */}
            <div className="w-full max-w-[260px] mx-auto md:mx-0 flex-shrink-0">
              <div
                className="relative"
                style={{
                  aspectRatio: '3 / 4',
                  background: 'var(--void)',
                  border: '1px solid var(--burnt-brass-dim)',
                  boxShadow: '0 8px 32px -8px rgba(0,0,0,0.6)',
                }}
              >
                {art ? (
                  <img
                    src={art}
                    alt={card.display_name}
                    className="absolute inset-0 w-full h-full object-cover"
                    style={{ filter: 'contrast(1.05) saturate(0.95)' }}
                  />
                ) : (
                  <div className="absolute inset-0 flex items-center justify-center scanlines-soft">
                    <div className="text-center">
                      <div
                        style={{
                          fontFamily: 'var(--font-display)',
                          fontSize: 48,
                          color: typeColor,
                          opacity: 0.5,
                        }}
                      >
                        {typeGlyph}
                      </div>
                      <div
                        className="font-mono uppercase mt-2"
                        style={{
                          color: 'var(--burnt-brass)',
                          fontSize: 9,
                          letterSpacing: '0.18em',
                        }}
                      >
                        art pending
                      </div>
                    </div>
                  </div>
                )}

                {/* corner hatches */}
                <span aria-hidden className="absolute" style={{ top: 3, left: 3, width: 14, height: 14, borderTop: '1px solid var(--oxidized-gold)', borderLeft: '1px solid var(--oxidized-gold)' }} />
                <span aria-hidden className="absolute" style={{ top: 3, right: 3, width: 14, height: 14, borderTop: '1px solid var(--oxidized-gold)', borderRight: '1px solid var(--oxidized-gold)' }} />
                <span aria-hidden className="absolute" style={{ bottom: 3, left: 3, width: 14, height: 14, borderBottom: '1px solid var(--oxidized-gold)', borderLeft: '1px solid var(--oxidized-gold)' }} />
                <span aria-hidden className="absolute" style={{ bottom: 3, right: 3, width: 14, height: 14, borderBottom: '1px solid var(--oxidized-gold)', borderRight: '1px solid var(--oxidized-gold)' }} />

                {/* energy cost badge */}
                <div
                  className="absolute flex items-center justify-center"
                  style={{
                    top: -12,
                    left: -12,
                    width: 44,
                    height: 44,
                    borderRadius: '50%',
                    background: 'var(--void)',
                    border: '2px solid var(--oxidized-gold)',
                    color: 'var(--halo)',
                    fontFamily: 'var(--font-display)',
                    fontSize: 22,
                    fontWeight: 700,
                    boxShadow: '0 0 20px rgba(217,176,95,0.3)',
                  }}
                >
                  {card.energy_cost}
                </div>

                {/* type glyph */}
                <div
                  className="absolute"
                  style={{
                    top: 10,
                    right: 12,
                    color: typeColor,
                    fontSize: 26,
                    fontFamily: 'var(--font-display)',
                    textShadow: `0 0 10px ${typeColor}88`,
                  }}
                >
                  {typeGlyph}
                </div>
              </div>

              {/* gem sockets below art */}
              {card.gem_sockets > 0 && (
                <div
                  className="mt-3 flex items-center gap-2 font-mono text-[10px]"
                  style={{ color: 'var(--bone-faint)' }}
                >
                  <span style={{ letterSpacing: '0.14em' }}>SOCKETS</span>
                  <span className="flex gap-1">
                    {Array.from({ length: card.gem_sockets }).map((_, i) => (
                      <span
                        key={i}
                        style={{
                          display: 'inline-block',
                          width: 8,
                          height: 8,
                          background: 'var(--oxidized-gold)',
                          border: '1px solid var(--halo)',
                          transform: 'rotate(45deg)',
                        }}
                      />
                    ))}
                  </span>
                </div>
              )}
            </div>

            {/* info panel */}
            <div className="min-w-0 flex-1 pt-1">
              {/* meta line */}
              <div
                className="flex items-center gap-3 mb-3 font-mono text-[10px] uppercase"
                style={{ color: 'var(--burnt-brass)', letterSpacing: '0.16em' }}
              >
                <span style={{ color: typeColor }}>
                  {typeGlyph}&ensp;{card.card_type}
                </span>
                <span>·</span>
                <span style={{ color: classColor }}>{cls}</span>
                <span>·</span>
                <RarityChip rarity={card.rarity} size="xs" />
              </div>

              {/* name */}
              <h2
                style={{
                  fontFamily: 'var(--font-display)',
                  fontSize: 'clamp(1.8rem, 4vw, 3rem)',
                  lineHeight: 0.95,
                  letterSpacing: '0.05em',
                  color: 'var(--bone)',
                  fontWeight: 600,
                  marginBottom: '0.5em',
                }}
              >
                {card.display_name}
                {card.upgraded && (
                  <span style={{ color: 'var(--halo)' }}>&nbsp;+</span>
                )}
              </h2>

              {/* description */}
              <p
                className="mb-6 max-w-[50ch]"
                style={{
                  fontFamily: 'var(--font-body)',
                  fontSize: 17,
                  lineHeight: 1.5,
                  color: 'var(--ink)',
                  fontStyle: 'italic',
                }}
              >
                &ldquo;{card.description || 'No description.'}&rdquo;
              </p>

              {/* stat grid */}
              <StatGrid card={card} />

              {/* tags */}
              {card.tags.length > 0 && (
                <div className="mt-6">
                  <div
                    className="font-mono text-[9px] uppercase mb-2"
                    style={{
                      color: 'var(--burnt-brass)',
                      letterSpacing: '0.18em',
                    }}
                  >
                    TAGS
                  </div>
                  <div className="flex flex-wrap gap-[6px]">
                    {card.tags.map(tag => (
                      <span
                        key={tag}
                        className="inline-flex items-center font-mono uppercase"
                        style={{
                          padding: '2px 8px',
                          fontSize: 9,
                          letterSpacing: '0.12em',
                          color: TAG_COLORS[tag],
                          border: `1px solid ${TAG_COLORS[tag]}44`,
                          background: `${TAG_COLORS[tag]}08`,
                        }}
                      >
                        {tag}
                      </span>
                    ))}
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* ─── field table ────────────────────────────────────────────── */}
          <FieldSection card={card} />

          {/* ─── upgrade chain ──────────────────────────────────────────── */}
          {upgradeCard && (
            <div className="px-6 md:px-10 pb-8">
              <div
                className="font-mono text-[9px] uppercase mb-3"
                style={{
                  color: 'var(--oxidized-gold)',
                  letterSpacing: '0.18em',
                }}
              >
                UPGRADE CHAIN
              </div>
              <button
                onClick={() => onSelectCard(upgradeCard.id)}
                className="inline-flex items-center gap-3 px-5 py-3"
                style={{
                  background: 'var(--server-rack)',
                  border: '1px solid var(--burnt-brass-dim)',
                  cursor: 'pointer',
                }}
              >
                <span
                  className="font-mono text-[11px]"
                  style={{ color: 'var(--bone-faint)' }}
                >
                  {card.id}
                </span>
                <span style={{ color: 'var(--oxidized-gold)', fontSize: 16 }}>
                  →
                </span>
                <span
                  className="sacred-underline"
                  style={{
                    fontFamily: 'var(--font-display)',
                    fontSize: 14,
                    color: 'var(--halo)',
                    letterSpacing: '0.06em',
                    textTransform: 'uppercase',
                  }}
                >
                  {upgradeCard.display_name}&nbsp;+
                </span>
              </button>
            </div>
          )}
        </div>
      </div>
    </>
  )
}

// ─── stat grid ──────────────────────────────────────────────────────────────

function StatGrid({ card }: { card: Card }) {
  const stats: [string, number | string, string][] = []
  if (card.damage)
    stats.push([
      'Damage',
      card.hits > 1 ? `${card.damage}×${card.hits}` : String(card.damage),
      '#B13340',
    ])
  if (card.block) stats.push(['Block', String(card.block), '#33D9F2'])
  if (card.heal) stats.push(['Heal', String(card.heal), '#F5E6A8'])
  if (card.draw) stats.push(['Draw', String(card.draw), '#87C464'])
  if (card.apply_vulnerable)
    stats.push(['Vulnerable', String(card.apply_vulnerable), '#F2D94C'])
  if (card.apply_weak)
    stats.push(['Weak', String(card.apply_weak), '#E85C2B'])
  if (card.gain_strength)
    stats.push(['Strength', `+${card.gain_strength}`, '#B13340'])
  if (card.gain_dexterity)
    stats.push(['Dexterity', `+${card.gain_dexterity}`, '#33D9F2'])
  if (card.corruption_gain)
    stats.push(['Corruption', `+${card.corruption_gain}`, '#5C1B7A'])
  if (card.party_damage)
    stats.push(['Party Dmg', String(card.party_damage), '#D9B05F'])
  if (card.party_heal)
    stats.push(['Party Heal', String(card.party_heal), '#D9B05F'])
  if (card.party_draw)
    stats.push(['Party Draw', String(card.party_draw), '#D9B05F'])
  if (stats.length === 0) return null

  return (
    <div
      className="grid gap-[6px]"
      style={{
        gridTemplateColumns: 'repeat(auto-fill, minmax(100px, 1fr))',
      }}
    >
      {stats.map(([label, value, color], i) => (
        <div
          key={i}
          style={{
            padding: '8px 12px',
            background: 'var(--server-rack)',
            border: '1px solid var(--burnt-brass-dim)',
          }}
        >
          <div
            className="font-mono uppercase"
            style={{
              fontSize: 8,
              color: 'var(--burnt-brass)',
              letterSpacing: '0.14em',
            }}
          >
            {label}
          </div>
          <div
            style={{
              fontFamily: 'var(--font-display)',
              fontSize: 20,
              color,
              fontWeight: 600,
              marginTop: 1,
            }}
          >
            {value}
          </div>
        </div>
      ))}
    </div>
  )
}

// ─── field table ────────────────────────────────────────────────────────────

function FieldSection({ card }: { card: Card }) {
  const EXCLUDE = [
    'id',
    'display_name',
    'description',
    'artwork',
    'tags',
    'card_type',
    'target_type',
    'rarity',
    'character_class',
  ]
  const rows: [string, unknown][] = []
  for (const [k, v] of Object.entries(card)) {
    if (EXCLUDE.includes(k)) continue
    if (v === 0 || v === false || v === '' || v == null) continue
    rows.push([k, v])
  }
  if (rows.length === 0) return null

  return (
    <div className="px-6 md:px-10 pb-6">
      <div
        className="font-mono text-[9px] uppercase mb-3"
        style={{ color: 'var(--oxidized-gold)', letterSpacing: '0.18em' }}
      >
        $&nbsp;CAT --FIELDS {card.id.toUpperCase()}.TRES
      </div>
      <div
        className="scanlines-soft"
        style={{
          background: 'var(--server-rack)',
          border: '1px solid var(--burnt-brass-dim)',
          padding: '10px 14px',
        }}
      >
        <table
          className="w-full font-mono"
          style={{ fontSize: 11, letterSpacing: '0.02em' }}
        >
          <tbody>
            {rows.map(([key, value], i) => (
              <tr
                key={key}
                style={{
                  borderBottom:
                    i < rows.length - 1
                      ? '1px dotted var(--burnt-brass-dim)'
                      : 'none',
                }}
              >
                <td
                  className="py-1 pr-4"
                  style={{
                    color: 'var(--burnt-brass)',
                    width: '2rem',
                    textAlign: 'right',
                  }}
                >
                  {pad(i + 1)}
                </td>
                <td
                  className="py-1 px-2"
                  style={{ color: 'var(--bone-dim)' }}
                >
                  {key}
                </td>
                <td
                  className="py-1 pl-2 text-right"
                  style={{ color: 'var(--oxidized-gold)' }}
                >
                  {String(value)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
