import { useState } from 'react'
import { useContentSection } from '../hooks/useContent'
import { MarkdownPage } from '../components/content/MarkdownPage'
import { SectionHeader } from '../components/codex/SectionHeader'
import type { ContentDoc } from '../types/content'

/**
 * /depths — the three rites of descent.
 *
 * Visual: chapter tabs at the top (I, II, III), current depth rendered
 * as long-form prose with a danger badge and the HP range under the title.
 */
export function Depths() {
  const { data: docs, isLoading, error } = useContentSection('depths')
  const [activeIdx, setActiveIdx] = useState(0)

  const active = docs?.[activeIdx]

  return (
    <section className="relative pb-20">
      <SectionHeader
        chapter="II."
        heading="THE DEPTHS"
        filename="bible/depths.log"
        count={docs?.length ?? '—'}
        subtitle="three rites. one descent."
      />

      {isLoading && (
        <div className="mx-[clamp(2rem,6vw,6rem)] terminal-frame p-6 font-mono text-[12px]" style={{ color: 'var(--bone-faint)' }}>
          <span className="prompt" />&nbsp;cat content/depths/*.md<span className="caret" />
        </div>
      )}
      {error && (
        <div className="mx-[clamp(2rem,6vw,6rem)] terminal-frame p-6 font-mono text-[12px]" style={{ color: 'var(--blood-bright)' }}>
          ERR · {String(error)}
        </div>
      )}

      {docs && active && (
        <>
          {/* rite selector */}
          <div className="mx-[clamp(2rem,6vw,6rem)] mb-10 reveal reveal-3">
            <div
              className="mb-3 font-mono text-[10px] uppercase"
              style={{ color: 'var(--burnt-brass)', letterSpacing: '0.18em' }}
            >
              SELECT RITE /
            </div>
            <div className="flex flex-wrap gap-3">
              {docs.map((d, i) => (
                <RiteTab
                  key={d.slug}
                  doc={d}
                  active={i === activeIdx}
                  onClick={() => setActiveIdx(i)}
                />
              ))}
            </div>
          </div>

          {/* prose */}
          <div
            key={active.slug}
            className="mx-[clamp(2rem,6vw,6rem)] reveal reveal-4"
          >
            <DangerBadge doc={active} />
            <MarkdownPage body={active.body} accentColor={active.meta.accent as string | undefined} />
          </div>
        </>
      )}
    </section>
  )
}

function RiteTab({ doc, active, onClick }: { doc: ContentDoc; active: boolean; onClick: () => void }) {
  const accent = (doc.meta.accent as string) ?? '#D9B05F'
  return (
    <button
      onClick={onClick}
      className="group text-left transition-all duration-200"
      style={{
        background: active ? 'var(--server-rack)' : 'transparent',
        border: active ? `1px solid ${accent}` : '1px solid var(--burnt-brass-dim)',
        padding: '16px 22px',
        cursor: 'pointer',
        boxShadow: active ? `0 0 24px -8px ${accent}66` : 'none',
      }}
    >
      <div
        className="font-mono uppercase mb-1"
        style={{ fontSize: 9, color: active ? accent : 'var(--burnt-brass)', letterSpacing: '0.14em' }}
      >
        rite {doc.meta.chapter ?? '—'}
      </div>
      <div
        style={{
          fontFamily: 'var(--font-display)',
          fontSize: 20,
          color: active ? 'var(--bone)' : 'var(--bone-dim)',
          letterSpacing: '0.08em',
          textTransform: 'uppercase',
          fontWeight: 600,
          lineHeight: 1.1,
        }}
      >
        {doc.meta.title}
      </div>
      <div
        className="font-mono mt-1"
        style={{ fontSize: 10, color: 'var(--burnt-brass)', letterSpacing: '0.02em' }}
      >
        {doc.meta.subtitle}
      </div>
    </button>
  )
}

function DangerBadge({ doc }: { doc: ContentDoc }) {
  const danger = (doc.meta.danger as string) ?? ''
  const hp = (doc.meta.hp_range as string) ?? ''
  if (!danger && !hp) return null
  const dangerColor = danger === 'extreme' ? '#E633CC' : danger === 'medium' ? '#D9B05F' : '#87C464'
  return (
    <div
      className="inline-flex items-center gap-4 mb-6 font-mono px-4 py-2"
      style={{
        border: '1px solid var(--burnt-brass-dim)',
        background: 'var(--server-rack)',
        fontSize: 11,
      }}
    >
      {danger && (
        <span>
          <span style={{ color: 'var(--burnt-brass)', letterSpacing: '0.14em' }}>DANGER</span>&nbsp;
          <span style={{ color: dangerColor, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.08em' }}>
            {danger}
          </span>
        </span>
      )}
      {hp && (
        <>
          <span style={{ color: 'var(--burnt-brass)' }}>·</span>
          <span>
            <span style={{ color: 'var(--burnt-brass)', letterSpacing: '0.14em' }}>HP</span>&nbsp;
            <span style={{ color: 'var(--halo)', fontWeight: 500 }}>{hp}</span>
          </span>
        </>
      )}
    </div>
  )
}
