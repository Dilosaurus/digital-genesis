import { Link } from 'react-router-dom'
import { useCharacters } from '../hooks/useCodex'
import { SectionHeader } from '../components/codex/SectionHeader'
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
  return (
    <Link
      to={`/characters/${c.id}`}
      className="group relative block"
      style={{ textDecoration: 'none', aspectRatio: '5 / 6' }}
    >
      {/* outer frame */}
      <div
        className="absolute inset-0 transition-transform duration-200 ease-out group-hover:translate-y-[-2px]"
        style={{
          background: 'var(--server-rack)',
          border: '1px solid var(--burnt-brass)',
          boxShadow:
            'inset 0 1px 0 rgba(235, 224, 200, 0.03), 0 1px 0 rgba(0, 0, 0, 0.4)',
        }}
      />

      {/* radial glow from class color */}
      <div
        className="absolute inset-0 opacity-40 group-hover:opacity-70 transition-opacity"
        style={{
          background: `radial-gradient(ellipse 80% 60% at 50% 20%, ${c.color_primary}22 0%, transparent 65%)`,
        }}
      />

      {/* left accent */}
      <div
        className="absolute top-0 bottom-0 left-0 w-[4px] group-hover:w-[6px] transition-[width]"
        style={{ background: c.color_primary }}
      />

      {/* top-right: class code + numeric */}
      <div
        className="absolute right-5 top-5 font-mono text-right"
        style={{ color: 'var(--burnt-brass)', fontSize: 10, letterSpacing: '0.14em' }}
      >
        <div style={{ color: c.color_primary }}>#{String(index).padStart(3, '0')}</div>
        <div>{c.icon_text}</div>
      </div>

      {/* icon_text centered at top */}
      <div
        className="absolute top-6 left-0 right-0 flex flex-col items-center pointer-events-none"
      >
        <div
          style={{
            fontFamily: 'var(--font-display)',
            fontSize: 'clamp(4.2rem, 8vw, 6rem)',
            fontWeight: 700,
            color: c.color_primary,
            letterSpacing: '0.06em',
            lineHeight: 1,
            filter: `drop-shadow(0 0 22px ${c.color_primary}55)`,
          }}
        >
          {c.icon_text}
        </div>
      </div>

      {/* title block (center) */}
      <div
        className="absolute left-0 right-0 px-6 text-center"
        style={{ top: '48%' }}
      >
        <div
          style={{
            fontFamily: 'var(--font-display)',
            fontSize: 'clamp(1.7rem, 3vw, 2.4rem)',
            color: 'var(--bone)',
            letterSpacing: '0.14em',
            fontWeight: 600,
            textTransform: 'uppercase',
            lineHeight: 1,
          }}
        >
          {c.display_name}
        </div>
        <div
          className="mt-2"
          style={{
            fontFamily: 'var(--font-body)',
            fontStyle: 'italic',
            fontSize: 14,
            color: 'var(--bone-dim)',
            letterSpacing: '0.01em',
          }}
        >
          {c.title}
        </div>
      </div>

      {/* bottom info strip */}
      <div
        className="absolute left-0 right-0 bottom-0 px-5 pb-5 pt-4"
        style={{ borderTop: '1px dotted var(--burnt-brass-dim)' }}
      >
        <div
          className="font-mono uppercase mb-2"
          style={{ fontSize: 9, color: 'var(--burnt-brass)', letterSpacing: '0.14em' }}
        >
          CLASS / {c.character_class}
        </div>

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

      {/* hover halo */}
      <div
        aria-hidden
        className="absolute inset-0 pointer-events-none opacity-0 group-hover:opacity-100 transition-opacity duration-200"
        style={{
          boxShadow: `inset 0 0 0 1px ${c.color_primary}, 0 0 24px -6px ${c.color_primary}`,
        }}
      />
    </Link>
  )
}
