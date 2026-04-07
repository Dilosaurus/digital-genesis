import { Link, useParams } from 'react-router-dom'
import { useCard, useCards } from '../hooks/useCodex'
import {
  resolveAsset, charClassColor, charClassName, charClassCode,
  CARD_TYPE_COLORS, CARD_TYPE_GLYPH, TAG_COLORS,
} from '../lib/assets'
import { RarityChip } from '../components/codex/RarityChip'
import type { Card } from '../types/game'
import { titleCase, pad } from '../lib/format'

/**
 * /codex/cards/:id — single-card dossier.
 *
 * Layout:
 *   [art panel — large]                 [title block]
 *                                       [primary stats]
 *                                       [effect prose]
 *                                       [tags + meta]
 *   [technical field table — all non-zero fields]
 *   [upgrade chain — linked tile if exists]
 */
export function CardDetail() {
  const { id } = useParams()
  const { data: card, isLoading, error, isError } = useCard(id)
  const { data: allCards } = useCards()

  if (isLoading) {
    return (
      <div className="p-16 font-mono text-[12px]" style={{ color: 'var(--bone-faint)' }}>
        <span className="prompt" />&nbsp;cat codex/cards/{id}.tres<span className="caret" />
      </div>
    )
  }

  if (isError || !card) {
    return (
      <div className="p-8 md:p-16 terminal-frame mx-4 md:mx-12 font-mono text-[12px]">
        <div style={{ color: 'var(--blood-bright)', letterSpacing: '0.18em' }} className="mb-2">
          ERR · FILE NOT FOUND
        </div>
        <p style={{ color: 'var(--bone-dim)', fontFamily: 'var(--font-body)', fontSize: 15 }}>
          No such rite: <span style={{ color: 'var(--oxidized-gold)' }} className="mono">{id}</span>.
          {error ? ` (${String(error)})` : ''}
        </p>
        <Link
          to="/codex/cards"
          className="inline-block mt-4 sacred-underline"
          style={{ color: 'var(--oxidized-gold)', fontFamily: 'var(--font-mono)', fontSize: 11 }}
        >
          ← return to catalog
        </Link>
      </div>
    )
  }

  const art = resolveAsset(card.artwork)
  const typeColor = CARD_TYPE_COLORS[card.card_type]
  const typeGlyph = CARD_TYPE_GLYPH[card.card_type]
  const classColor = charClassColor(card.character_class)
  const className = charClassName(card.character_class)
  const upgradeCard = card.upgrade_id
    ? allCards?.find(c => c.id === card.upgrade_id)
    : undefined

  return (
    <article className="relative pb-20">
      {/* ─── back link + path ───────────────────────────────────────── */}
      <div
        className="reveal reveal-0 pt-8 md:pt-10 px-[clamp(1rem,6vw,6rem)] mb-6 font-mono text-[11px]"
        style={{ color: 'var(--bone-faint)', letterSpacing: '0.02em' }}
      >
        <Link to="/codex/cards" className="sacred-underline" style={{ color: 'var(--bone-dim)' }}>
          codex/cards/
        </Link>
        <span style={{ color: 'var(--halo)' }}>{card.id}</span>
      </div>

      {/* ─── hero: art + title. Stacks on mobile. ───────────────────── */}
      <section
        className="px-[clamp(1rem,6vw,6rem)] flex flex-col md:grid gap-8 md:gap-[clamp(2rem,5vw,5rem)]"
        style={{ gridTemplateColumns: 'minmax(260px, 360px) minmax(0, 1fr)' }}
      >
        {/* art panel — capped width on mobile so it doesn't fill the whole viewport */}
        <div className="reveal reveal-1 w-full max-w-[320px] mx-auto md:max-w-none md:mx-0">
          <div
            className="relative"
            style={{
              aspectRatio: '3 / 4',
              background: 'var(--void-deeper)',
              border: '1px solid var(--burnt-brass)',
              boxShadow:
                'inset 0 1px 0 rgba(235, 224, 200, 0.05), 0 18px 40px -20px rgba(0,0,0,0.8)',
            }}
          >
            {/* class accent stripe */}
            <div
              className="absolute top-0 bottom-0 left-0 w-[4px]"
              style={{ background: classColor }}
            />
            {/* type glyph top-right */}
            <div
              className="absolute"
              style={{
                top: 14,
                right: 16,
                color: typeColor,
                fontSize: 32,
                fontFamily: 'var(--font-display)',
                textShadow: `0 0 12px ${typeColor}88`,
              }}
            >
              {typeGlyph}
            </div>
            {/* energy cost large badge */}
            <div
              className="absolute flex items-center justify-center"
              style={{
                top: -14,
                left: -14,
                width: 52,
                height: 52,
                borderRadius: '50%',
                background: 'var(--void)',
                border: '2px solid var(--oxidized-gold)',
                color: 'var(--halo)',
                fontFamily: 'var(--font-display)',
                fontSize: 26,
                fontWeight: 700,
                boxShadow: '0 0 24px rgba(217, 176, 95, 0.35)',
              }}
            >
              {card.energy_cost}
            </div>

            {/* the art itself */}
            {art ? (
              <img
                src={art}
                alt={card.display_name}
                className="absolute inset-0 w-full h-full object-cover"
                style={{ filter: 'contrast(1.05) saturate(0.95)' }}
              />
            ) : (
              <div className="absolute inset-0 flex items-center justify-center scanlines-soft">
                <div
                  className="font-mono uppercase text-center"
                  style={{ color: 'var(--burnt-brass)', fontSize: 10, letterSpacing: '0.18em' }}
                >
                  art pending
                  <br />
                  <span style={{ color: 'var(--bone-faint)' }}>{card.id}.png</span>
                </div>
              </div>
            )}

            {/* corner hatches */}
            {['top-0 left-0 border-t border-l', 'top-0 right-0 border-t border-r', 'bottom-0 left-0 border-b border-l', 'bottom-0 right-0 border-b border-r'].map((cls, i) => (
              <span
                key={i}
                aria-hidden
                className={`absolute ${cls}`}
                style={{ width: 16, height: 16, borderColor: 'var(--oxidized-gold)' }}
              />
            ))}
          </div>

          {/* gem sockets row */}
          {card.gem_sockets > 0 && (
            <div className="mt-3 flex items-center gap-2 font-mono text-[11px]" style={{ color: 'var(--bone-faint)' }}>
              <span style={{ letterSpacing: '0.14em' }}>SOCKETS /</span>
              <span className="flex gap-1">
                {Array.from({ length: card.gem_sockets }).map((_, i) => (
                  <span
                    key={i}
                    style={{
                      display: 'inline-block',
                      width: 9,
                      height: 9,
                      background: 'var(--oxidized-gold)',
                      border: '1px solid var(--halo)',
                      transform: 'rotate(45deg)',
                    }}
                  />
                ))}
              </span>
              <span style={{ color: 'var(--bone-dim)' }}>×{card.gem_sockets}</span>
            </div>
          )}
        </div>

        {/* title block */}
        <div className="min-w-0 reveal reveal-2">
          <div
            className="flex items-center gap-3 mb-3 font-mono text-[10px] uppercase"
            style={{ color: 'var(--burnt-brass)', letterSpacing: '0.18em' }}
          >
            <span style={{ color: typeColor }}>{typeGlyph}&nbsp;&nbsp;{card.card_type}</span>
            <span style={{ color: 'var(--burnt-brass)' }}>·</span>
            <span style={{ color: classColor }}>{className}</span>
            <span style={{ color: 'var(--burnt-brass)' }}>·</span>
            <RarityChip rarity={card.rarity} size="sm" />
          </div>

          <h1
            style={{
              fontFamily: 'var(--font-display)',
              fontSize: 'clamp(2.4rem, 5vw, 4.2rem)',
              lineHeight: 0.95,
              letterSpacing: '0.05em',
              color: 'var(--bone)',
              fontWeight: 600,
              marginBottom: '0.4em',
            }}
          >
            {card.display_name}
            {card.upgraded && <span style={{ color: 'var(--halo)' }}>&nbsp;+</span>}
          </h1>

          <p
            className="mb-8 max-w-[60ch]"
            style={{
              fontFamily: 'var(--font-body)',
              fontSize: 20,
              lineHeight: 1.55,
              color: 'var(--ink)',
              fontStyle: 'italic',
            }}
          >
            &ldquo;{card.description || 'No description.'}&rdquo;
          </p>

          {/* primary stats grid */}
          <StatGrid card={card} />

          {/* tags */}
          {card.tags.length > 0 && (
            <div className="mt-8">
              <div
                className="font-mono text-[10px] uppercase mb-2"
                style={{ color: 'var(--burnt-brass)', letterSpacing: '0.18em' }}
              >
                TAGS /
              </div>
              <div className="flex flex-wrap gap-2">
                {card.tags.map(tag => (
                  <span
                    key={tag}
                    className="inline-flex items-center font-mono uppercase"
                    style={{
                      padding: '3px 9px',
                      fontSize: 10,
                      letterSpacing: '0.14em',
                      color: TAG_COLORS[tag],
                      border: `1px solid ${TAG_COLORS[tag]}`,
                    }}
                  >
                    {tag}
                  </span>
                ))}
              </div>
            </div>
          )}
        </div>
      </section>

      {/* ─── technical field dump ───────────────────────────────────── */}
      <section className="reveal reveal-4 mt-12 md:mt-16 px-[clamp(1rem,6vw,6rem)]">
        <div
          className="mb-4 font-mono text-[10px] uppercase"
          style={{ color: 'var(--oxidized-gold)', letterSpacing: '0.18em' }}
        >
          $&nbsp;cat --fields {card.id}.tres
        </div>
        <FieldTable card={card} />
      </section>

      {/* ─── upgrade chain ──────────────────────────────────────────── */}
      {upgradeCard && (
        <section className="reveal reveal-5 mt-12 md:mt-16 px-[clamp(1rem,6vw,6rem)]">
          <div
            className="mb-4 font-mono text-[10px] uppercase"
            style={{ color: 'var(--oxidized-gold)', letterSpacing: '0.18em' }}
          >
            UPGRADE CHAIN /
          </div>
          <Link
            to={`/codex/cards/${upgradeCard.id}`}
            className="inline-flex items-center gap-3 terminal-frame px-5 py-4 group"
            style={{ textDecoration: 'none' }}
          >
            <span style={{ color: 'var(--bone-faint)', fontFamily: 'var(--font-mono)', fontSize: 11 }}>
              {card.id}
            </span>
            <span style={{ color: 'var(--oxidized-gold)', fontSize: 18 }}>→</span>
            <span
              className="sacred-underline"
              style={{
                fontFamily: 'var(--font-display)',
                fontSize: 16,
                color: 'var(--halo)',
                letterSpacing: '0.06em',
                textTransform: 'uppercase',
              }}
            >
              {upgradeCard.display_name}
              <span>&nbsp;+</span>
            </span>
          </Link>
        </section>
      )}
    </article>
  )
}

// ─── stat grid (primary combat stats) ────────────────────────────────────

function StatGrid({ card }: { card: Card }) {
  const stats: [string, number | string, string?][] = []
  if (card.damage) stats.push(['Damage', card.hits > 1 ? `${card.damage}×${card.hits}` : String(card.damage), '#B13340'])
  if (card.block) stats.push(['Block', String(card.block), '#33D9F2'])
  if (card.heal) stats.push(['Heal', String(card.heal), '#F5E6A8'])
  if (card.draw) stats.push(['Draw', String(card.draw), '#87C464'])
  if (card.apply_vulnerable) stats.push(['Vulnerable', String(card.apply_vulnerable), '#F2D94C'])
  if (card.apply_weak) stats.push(['Weak', String(card.apply_weak), '#E85C2B'])
  if (card.gain_strength) stats.push(['Strength', `+${card.gain_strength}`, '#B13340'])
  if (card.gain_dexterity) stats.push(['Dexterity', `+${card.gain_dexterity}`, '#33D9F2'])
  if (card.corruption_gain) stats.push(['Corruption', `+${card.corruption_gain}`, '#5C1B7A'])
  if (card.party_damage) stats.push(['Party Damage', String(card.party_damage), '#D9B05F'])
  if (card.party_heal) stats.push(['Party Heal', String(card.party_heal), '#D9B05F'])
  if (card.party_draw) stats.push(['Party Draw', String(card.party_draw), '#D9B05F'])
  if (stats.length === 0) stats.push(['—', 'no direct stats', '#7F6640'])

  return (
    <div className="grid gap-2" style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(140px, 1fr))' }}>
      {stats.map(([label, value, color], i) => (
        <div
          key={i}
          style={{
            padding: '10px 14px',
            background: 'var(--server-rack)',
            border: '1px solid var(--burnt-brass-dim)',
          }}
        >
          <div
            className="font-mono uppercase"
            style={{ fontSize: 9, color: 'var(--burnt-brass)', letterSpacing: '0.14em' }}
          >
            {label}
          </div>
          <div
            style={{
              fontFamily: 'var(--font-display)',
              fontSize: 24,
              color: color ?? 'var(--bone)',
              fontWeight: 600,
              marginTop: 2,
              letterSpacing: '0.03em',
            }}
          >
            {value}
          </div>
        </div>
      ))}
    </div>
  )
}

// ─── full technical field table ──────────────────────────────────────────

function FieldTable({ card }: { card: Card }) {
  const rows: [string, unknown][] = []
  for (const [k, v] of Object.entries(card)) {
    if (['id', 'display_name', 'description', 'artwork', 'tags', 'card_type', 'target_type', 'rarity', 'character_class'].includes(k)) continue
    if (v === 0 || v === false || v === '' || v == null) continue
    rows.push([k, v])
  }
  if (rows.length === 0) {
    return (
      <div
        className="terminal-frame px-6 py-4 font-mono"
        style={{ color: 'var(--bone-faint)', fontSize: 12 }}
      >
        &nbsp;&nbsp;(no non-zero fields)
      </div>
    )
  }
  return (
    <div className="terminal-frame scanlines-soft" style={{ padding: '14px 18px' }}>
      <table className="w-full font-mono" style={{ fontSize: 12, letterSpacing: '0.02em' }}>
        <tbody>
          {rows.map(([key, value], i) => (
            <tr
              key={key}
              style={{
                borderBottom: i < rows.length - 1 ? '1px dotted var(--burnt-brass-dim)' : 'none',
              }}
            >
              <td
                className="py-[5px]"
                style={{ color: 'var(--burnt-brass)', width: '2.5rem', textAlign: 'right' }}
              >
                {pad(i + 1)}
              </td>
              <td
                className="py-[5px] pl-4 pr-2"
                style={{ color: 'var(--bone-dim)' }}
              >
                {key}
              </td>
              <td
                className="py-[5px] pl-2"
                style={{ color: 'var(--oxidized-gold)' }}
              >
                {String(value)}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
