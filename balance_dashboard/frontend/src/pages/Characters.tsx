import { Link } from 'react-router-dom'
import { useCharacters } from '../hooks/useCodex'
import { SectionHeader } from '../components/codex/SectionHeader'
import {
  ANIMATION_POSES,
  animationUrl,
  characterCallsign,
} from '../lib/assets'
import type { Character } from '../types/game'

/**
 * /characters — operator roster. Six large dossier tiles, each laid out
 * as an in-universe personnel record. Per-character color accent pulled
 * from character.color_primary.
 *
 * Asymmetric grid — the six operators are not equally-sized boxes; the
 * grid breaks symmetry with a feature tile (larger) and secondary tiles.
 */
export function Characters() {
  const { data: characters, isLoading, error } = useCharacters()

  return (
    <section className="relative pb-20">
      <SectionHeader
        chapter="I."
        heading="THE CREW"
        filename="bible/characters.dat"
        count={characters?.length ?? '—'}
        subtitle="six pirates the nexus could not keep."
      />

      {isLoading && (
        <div className="mx-[clamp(1rem,6vw,6rem)] terminal-frame p-6 font-mono text-[12px]" style={{ color: 'var(--bone-faint)' }}>
          <span className="prompt" />&nbsp;parsing characters/*.tres<span className="caret" />
        </div>
      )}
      {error && (
        <div className="mx-[clamp(1rem,6vw,6rem)] terminal-frame p-6 font-mono text-[12px]" style={{ color: 'var(--blood-bright)' }}>
          ERR · {String(error)}
        </div>
      )}

      {characters && (
        <div
          className="reveal reveal-3 mx-[clamp(1rem,6vw,6rem)] grid gap-4 md:gap-5"
          style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 280px), 1fr))' }}
        >
          {characters.map((c, i) => (
            <CharacterCard key={c.id} c={c} index={i + 1} />
          ))}
        </div>
      )}
    </section>
  )
}

function CharacterCard({ c, index }: { c: Character; index: number }) {
  const callsign = characterCallsign(c.display_name)
  const hasAnim = (ANIMATION_POSES[callsign]?.length ?? 0) > 0

  return (
    <Link
      to={`/characters/${c.id}`}
      className="group relative block transition-transform duration-200 ease-out hover:translate-y-[-2px]"
      style={{ textDecoration: 'none' }}
    >
      <div
        className="relative flex flex-col h-full"
        style={{
          background: 'var(--server-rack)',
          border: '1px solid var(--burnt-brass)',
          boxShadow:
            'inset 0 1px 0 rgba(235, 224, 200, 0.03), 0 1px 0 rgba(0, 0, 0, 0.4)',
        }}
      >
        {/* radial glow from class color */}
        <div
          aria-hidden
          className="absolute inset-0 pointer-events-none opacity-50 group-hover:opacity-90 transition-opacity"
          style={{
            background: `radial-gradient(ellipse 90% 50% at 50% 38%, ${c.color_primary}22 0%, transparent 65%)`,
          }}
        />

        {/* left accent */}
        <div
          aria-hidden
          className="absolute top-0 bottom-0 left-0 w-[4px] group-hover:w-[6px] transition-[width] z-10"
          style={{ background: c.color_primary }}
        />

        {/* hover halo */}
        <div
          aria-hidden
          className="absolute inset-0 pointer-events-none opacity-0 group-hover:opacity-100 transition-opacity duration-200 z-20"
          style={{
            boxShadow: `inset 0 0 0 1px ${c.color_primary}, 0 0 24px -6px ${c.color_primary}`,
          }}
        />

        {/* ── header strip — file-system slug + index ─────────────────── */}
        <div
          className="relative flex items-baseline justify-between px-5 pt-4 pb-2 font-mono"
          style={{ fontSize: 9, letterSpacing: '0.14em' }}
        >
          <span style={{ color: 'var(--burnt-brass)' }}>
            crew/{c.id}.tres
          </span>
          <span style={{ color: c.color_primary }}>
            #{String(index).padStart(3, '0')}
          </span>
        </div>

        {/* ── square portrait — animation OR fallback text icon ────────── */}
        <div
          className="relative mx-3"
          style={{
            aspectRatio: '1 / 1',
            background: 'var(--void-deeper)',
            borderTop: `1px solid ${c.color_primary}55`,
            borderBottom: `1px solid ${c.color_primary}55`,
            overflow: 'hidden',
          }}
        >
          {/* faint scan-line texture so empty backgrounds don't read as a void */}
          <div
            aria-hidden
            className="absolute inset-0 pointer-events-none"
            style={{
              backgroundImage: `repeating-linear-gradient(0deg, transparent, transparent 2px, ${c.color_primary}07 2px, ${c.color_primary}07 3px)`,
            }}
          />

          {hasAnim ? (
            <img
              src={animationUrl(callsign, 'idle')}
              alt={`${c.display_name} idle`}
              className="absolute inset-0 w-full h-full"
              style={{
                objectFit: 'contain',
                imageRendering: 'auto',
                filter: `drop-shadow(0 0 18px ${c.color_primary}55)`,
              }}
            />
          ) : (
            <div
              className="absolute inset-0 flex items-center justify-center"
              style={{
                fontFamily: 'var(--font-display)',
                fontSize: 'clamp(4.5rem, 9vw, 6.5rem)',
                fontWeight: 700,
                color: c.color_primary,
                letterSpacing: '0.06em',
                lineHeight: 1,
                filter: `drop-shadow(0 0 22px ${c.color_primary}55)`,
              }}
            >
              {c.icon_text}
            </div>
          )}

          {/* corner hatches */}
          {['tl', 'tr', 'bl', 'br'].map(p => (
            <span
              key={p}
              aria-hidden
              className="absolute pointer-events-none"
              style={{
                width: 10,
                height: 10,
                borderColor: c.color_primary,
                ...(p === 'tl' && { top: 3, left: 3, borderTop: '1.5px solid', borderLeft: '1.5px solid' }),
                ...(p === 'tr' && { top: 3, right: 3, borderTop: '1.5px solid', borderRight: '1.5px solid' }),
                ...(p === 'bl' && { bottom: 3, left: 3, borderBottom: '1.5px solid', borderLeft: '1.5px solid' }),
                ...(p === 'br' && { bottom: 3, right: 3, borderBottom: '1.5px solid', borderRight: '1.5px solid' }),
              }}
            />
          ))}

          {/* class label — bottom-left of the portrait area */}
          <div
            className="absolute left-2 bottom-2 px-2 py-[3px] font-mono uppercase pointer-events-none"
            style={{
              fontSize: 9,
              letterSpacing: '0.16em',
              color: c.color_primary,
              background: 'rgba(8, 8, 12, 0.85)',
              border: `1px solid ${c.color_primary}66`,
            }}
          >
            {c.character_class}
          </div>
        </div>

        {/* ── name + title — flex grow so cards align with bottom strip ── */}
        <div className="relative flex-grow px-5 pt-4 pb-3">
          <div
            style={{
              fontFamily: 'var(--font-display)',
              fontSize: 'clamp(1.6rem, 2.6vw, 2.1rem)',
              color: 'var(--bone)',
              letterSpacing: '0.12em',
              fontWeight: 600,
              textTransform: 'uppercase',
              lineHeight: 1,
            }}
          >
            {c.display_name}
          </div>
          <div
            className="mt-1.5"
            style={{
              fontFamily: 'var(--font-body)',
              fontStyle: 'italic',
              fontSize: 13,
              color: 'var(--bone-dim)',
              letterSpacing: '0.01em',
              lineHeight: 1.3,
            }}
          >
            {c.title}
          </div>
        </div>

        {/* ── bottom info strip ────────────────────────────────────────── */}
        <div
          className="relative px-5 pt-3 pb-4"
          style={{ borderTop: '1px dotted var(--burnt-brass-dim)' }}
        >
          <div
            className="flex items-baseline justify-between font-mono mb-2"
            style={{ fontSize: 11, letterSpacing: '0.02em' }}
          >
            <span style={{ color: 'var(--bone-dim)' }}>
              HP <span style={{ color: 'var(--halo)', fontSize: 14 }}>{c.starting_hp}</span>
            </span>
            <span style={{ color: 'var(--bone-dim)' }}>
              NRG <span style={{ color: 'var(--halo)', fontSize: 14 }}>{c.starting_energy}</span>
            </span>
          </div>

          <div
            className="truncate font-mono"
            style={{
              fontSize: 10,
              color: c.color_primary,
              letterSpacing: '0.02em',
            }}
          >
            ▣&nbsp;{c.passive_name}
          </div>
        </div>
      </div>
    </Link>
  )
}
