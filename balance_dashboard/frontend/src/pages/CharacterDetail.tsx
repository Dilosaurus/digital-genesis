import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useCharacter, useCards } from '../hooks/useCodex'
import { CardTile } from '../components/codex/CardTile'
import { pad } from '../lib/format'
import {
  ANIMATION_POSES,
  POSE_LABELS,
  animationUrl,
  characterCallsign,
} from '../lib/assets'

/**
 * /characters/:id — operator dossier.
 *
 * Long-form in-universe personnel file. Large icon_text display, title,
 * class, HP/NRG stats, passive description, full backstory as prose,
 * then the starter deck rendered as CardTiles.
 *
 * Per-character color accent dominates the page.
 */
export function CharacterDetail() {
  const { id } = useParams()
  const { data: c, isLoading, isError } = useCharacter(id)
  const { data: allCards } = useCards()

  if (isLoading) {
    return (
      <div className="p-16 font-mono text-[12px]" style={{ color: 'var(--bone-faint)' }}>
        <span className="prompt" />&nbsp;cat characters/{id}.tres<span className="caret" />
      </div>
    )
  }
  if (isError || !c) {
    return (
      <div className="p-16 terminal-frame mx-12 font-mono text-[12px]">
        <div style={{ color: 'var(--blood-bright)', letterSpacing: '0.18em' }} className="mb-2">
          ERR · OPERATOR NOT FOUND
        </div>
        <Link
          to="/characters"
          className="sacred-underline inline-block mt-2"
          style={{ color: 'var(--oxidized-gold)' }}
        >
          ← return to crew
        </Link>
      </div>
    )
  }

  const starterDeck = c.starter_deck
    .map(cardId => allCards?.find(card => card.id === cardId))
    .filter((x): x is NonNullable<typeof x> => !!x)

  return (
    <article className="relative pb-20" style={{ ['--char-color' as string]: c.color_primary }}>
      {/* large colored radial that bleeds from the top-left */}
      <div
        aria-hidden
        className="absolute top-0 left-0 right-0 pointer-events-none"
        style={{
          height: '80vh',
          background: `radial-gradient(ellipse 60% 70% at 18% 0%, ${c.color_primary}22 0%, transparent 60%)`,
        }}
      />

      {/* breadcrumb */}
      <div
        className="reveal reveal-0 pt-8 md:pt-10 px-[clamp(1rem,6vw,6rem)] mb-6 font-mono text-[11px]"
        style={{ color: 'var(--bone-faint)', letterSpacing: '0.02em' }}
      >
        <Link to="/characters" className="sacred-underline" style={{ color: 'var(--bone-dim)' }}>
          bible/characters/
        </Link>
        <span style={{ color: c.color_primary }}>{c.id}</span>
      </div>

      {/* hero — stacks on mobile */}
      <section
        className="relative px-[clamp(1rem,6vw,6rem)] flex flex-col md:grid gap-8 md:gap-[clamp(2rem,5vw,5rem)]"
        style={{ gridTemplateColumns: 'minmax(200px, 280px) minmax(0, 1fr)' }}
      >
        {/* icon block — capped width on mobile to keep the icon proportional */}
        <div className="reveal reveal-1 flex flex-col items-start w-full max-w-[280px] mx-auto md:max-w-none md:mx-0">
          <CharacterPortrait c={c} />

          {/* stats */}
          <div className="w-full grid grid-cols-2 gap-3">
            <StatBlock label="HP" value={c.starting_hp} color={c.color_primary} />
            <StatBlock label="NRG" value={c.starting_energy} color={c.color_primary} />
          </div>
        </div>

        {/* text */}
        <div className="min-w-0 reveal reveal-2">
          <div
            className="mb-2 font-mono text-[10px] uppercase"
            style={{ color: 'var(--burnt-brass)', letterSpacing: '0.18em' }}
          >
            <span style={{ color: c.color_primary }}>█</span>&nbsp;&nbsp;
            PERSONNEL FILE · {c.character_class}
          </div>

          <h1
            style={{
              fontFamily: 'var(--font-display)',
              fontSize: 'clamp(2rem, 9vw, 6.5rem)',
              lineHeight: 0.92,
              letterSpacing: '0.04em',
              color: 'var(--bone)',
              fontWeight: 600,
              wordBreak: 'break-word',
              overflowWrap: 'anywhere',
            }}
          >
            {c.display_name}
          </h1>
          <div
            className="mt-2 mb-6"
            style={{
              fontFamily: 'var(--font-body)',
              fontStyle: 'italic',
              fontSize: 'clamp(1.1rem, 1.8vw, 1.4rem)',
              color: c.color_primary,
              letterSpacing: '0.02em',
            }}
          >
            &ldquo;{c.title}&rdquo;
          </div>

          {/* passive */}
          <div
            className="mb-8 p-5"
            style={{
              background: 'var(--server-rack)',
              border: '1px solid var(--burnt-brass-dim)',
              borderLeft: `3px solid ${c.color_primary}`,
            }}
          >
            <div
              className="mb-1 font-mono uppercase"
              style={{ fontSize: 10, color: 'var(--burnt-brass)', letterSpacing: '0.18em' }}
            >
              PASSIVE RITE
            </div>
            <div
              style={{
                fontFamily: 'var(--font-display)',
                fontSize: 18,
                color: c.color_primary,
                letterSpacing: '0.04em',
                textTransform: 'uppercase',
                fontWeight: 600,
              }}
            >
              {c.passive_name}
            </div>
            <p
              className="mt-2"
              style={{
                fontFamily: 'var(--font-body)',
                fontSize: 16,
                color: 'var(--bone-dim)',
                lineHeight: 1.55,
              }}
            >
              {c.passive_description}
            </p>
          </div>

          {/* backstory */}
          <div>
            <div
              className="mb-2 font-mono uppercase"
              style={{ fontSize: 10, color: 'var(--burnt-brass)', letterSpacing: '0.18em' }}
            >
              DOSSIER — BACKSTORY
            </div>
            <p
              className="dropcap max-w-[62ch]"
              style={{
                fontFamily: 'var(--font-body)',
                fontSize: 18,
                color: 'var(--ink)',
                lineHeight: 1.62,
              }}
            >
              {c.backstory}
            </p>
          </div>
        </div>
      </section>

      {/* starter deck */}
      {starterDeck.length > 0 && (
        <section className="reveal reveal-5 mt-14 md:mt-20 px-[clamp(1rem,6vw,6rem)]">
          <div className="mb-6 flex items-baseline gap-4">
            <div
              style={{
                fontFamily: 'var(--font-display)',
                fontSize: 40,
                color: c.color_primary,
                letterSpacing: 0,
                lineHeight: 1,
              }}
            >
              §
            </div>
            <div>
              <div
                style={{
                  fontFamily: 'var(--font-display)',
                  fontSize: 'clamp(1.6rem, 3vw, 2.4rem)',
                  color: 'var(--bone)',
                  letterSpacing: '0.12em',
                  fontWeight: 600,
                  textTransform: 'uppercase',
                }}
              >
                STARTER DECK
              </div>
              <div className="font-mono" style={{ fontSize: 10, color: 'var(--burnt-brass)', letterSpacing: '0.12em' }}>
                {starterDeck.length} rites issued on contract
              </div>
            </div>
          </div>

          <div
            className="grid gap-3 md:gap-5"
            style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(150px, 1fr))' }}
          >
            {starterDeck.map((card, i) => (
              <CardTile key={`${card.id}-${i}`} card={card} index={i + 1} />
            ))}
          </div>
        </section>
      )}
    </article>
  )
}

/**
 * The square portrait box at the top of the dossier. When the operator has
 * sprite-sheet GIFs available (under /anim/<callsign>_<pose>_loop.gif), this
 * shows the live animation with a pose tab strip below it. Otherwise it
 * falls back to the giant text-icon glyph.
 */
function CharacterPortrait({ c }: { c: import('../types/game').Character }) {
  const callsign = characterCallsign(c.display_name)
  const poses = ANIMATION_POSES[callsign] ?? []
  const hasAnimation = poses.length > 0
  const [pose, setPose] = useState(poses[0] ?? 'idle')
  // Re-mount the GIF on pose change so the loop restarts cleanly. The
  // browser otherwise reuses the cached decode and the animation looks like
  // it picks up mid-stride.
  const gifKey = `${callsign}-${pose}`

  return (
    <>
      <div
        className="relative mb-3"
        style={{
          width: '100%',
          aspectRatio: '1 / 1',
          background: 'var(--void-deeper)',
          border: `1px solid ${c.color_primary}`,
          boxShadow: `inset 0 1px 0 rgba(235, 224, 200, 0.04), 0 0 40px -10px ${c.color_primary}66`,
        }}
      >
        {hasAnimation ? (
          <img
            key={gifKey}
            src={animationUrl(callsign, pose)}
            alt={`${c.display_name} ${pose}`}
            className="absolute inset-0 w-full h-full"
            style={{
              objectFit: 'contain',
              imageRendering: 'auto',
              filter: `drop-shadow(0 0 24px ${c.color_primary}44)`,
            }}
          />
        ) : (
          <div
            className="absolute inset-0 flex items-center justify-center"
            style={{
              fontFamily: 'var(--font-display)',
              fontSize: 'clamp(6rem, 14vw, 12rem)',
              color: c.color_primary,
              fontWeight: 700,
              letterSpacing: '0.06em',
              lineHeight: 1,
              filter: `drop-shadow(0 0 28px ${c.color_primary}55)`,
            }}
          >
            {c.icon_text}
          </div>
        )}

        {/* corner hatches */}
        {['tl', 'tr', 'bl', 'br'].map(p => (
          <span
            key={p}
            className="absolute pointer-events-none"
            style={{
              width: 14,
              height: 14,
              borderColor: c.color_primary,
              ...(p === 'tl' && { top: 4, left: 4, borderTop: `1.5px solid`, borderLeft: `1.5px solid` }),
              ...(p === 'tr' && { top: 4, right: 4, borderTop: `1.5px solid`, borderRight: `1.5px solid` }),
              ...(p === 'bl' && { bottom: 4, left: 4, borderBottom: `1.5px solid`, borderLeft: `1.5px solid` }),
              ...(p === 'br' && { bottom: 4, right: 4, borderBottom: `1.5px solid`, borderRight: `1.5px solid` }),
            }}
          />
        ))}
      </div>

      {/* pose tabs — only render if there's more than one pose to switch between */}
      {hasAnimation && poses.length > 1 && (
        <div className="w-full mb-4 flex flex-wrap gap-1">
          {poses.map(p => {
            const active = p === pose
            return (
              <button
                key={p}
                type="button"
                onClick={() => setPose(p)}
                className="font-mono uppercase transition-colors"
                style={{
                  fontSize: 9,
                  letterSpacing: '0.12em',
                  padding: '6px 9px',
                  background: active ? `${c.color_primary}22` : 'var(--server-rack)',
                  border: `1px solid ${active ? c.color_primary : 'var(--burnt-brass-dim)'}`,
                  color: active ? c.color_primary : 'var(--bone-dim)',
                  cursor: 'pointer',
                }}
              >
                {POSE_LABELS[p] ?? p.toUpperCase()}
              </button>
            )
          })}
        </div>
      )}
      {hasAnimation && poses.length === 1 && <div className="mb-1" />}
    </>
  )
}

function StatBlock({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <div
      style={{
        background: 'var(--server-rack)',
        border: '1px solid var(--burnt-brass-dim)',
        padding: '10px 12px',
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
          fontSize: 32,
          color,
          fontWeight: 600,
          letterSpacing: '0.03em',
        }}
      >
        {value}
      </div>
    </div>
  )
}
