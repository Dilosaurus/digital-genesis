import { useState } from 'react'
import { useDecisions } from '../hooks/useMeta'
import { SectionHeader } from '../components/codex/SectionHeader'
import { MarkdownPage } from '../components/content/MarkdownPage'
import type { ContentDoc } from '../types/content'

/**
 * /decisions — Architecture Decision Records.
 *
 * Desktop: ADR list on left, selected ADR rendered on right.
 * Mobile: ADR list becomes a horizontal scrolling row with wider tiles
 * (since ADR titles are long); active ADR renders below.
 */
export function Decisions() {
  const { data: docs, isLoading, error } = useDecisions()
  const [activeSlug, setActiveSlug] = useState<string | null>(null)
  const active = docs?.find(d => d.slug === (activeSlug ?? docs?.[0]?.slug))

  return (
    <section className="relative pb-20">
      <SectionHeader
        chapter="III."
        heading="DECISIONS"
        filename="meta/decisions.log"
        count={docs?.length ?? '—'}
        subtitle="the reasons behind the code."
      />

      {isLoading && (
        <div className="mx-[clamp(1rem,6vw,6rem)] terminal-frame p-4 md:p-6 font-mono text-[12px]" style={{ color: 'var(--bone-faint)' }}>
          <span className="prompt" />&nbsp;cat content/decisions/*.md<span className="caret" />
        </div>
      )}
      {error && (
        <div className="mx-[clamp(1rem,6vw,6rem)] terminal-frame p-4 md:p-6 font-mono text-[12px]" style={{ color: 'var(--blood-bright)' }}>
          ERR · {String(error)}
        </div>
      )}

      {docs && active && (
        <div className="mx-[clamp(1rem,6vw,6rem)]">
          <div
            className="md:grid md:gap-[clamp(2rem,5vw,5rem)]"
            style={{ gridTemplateColumns: 'minmax(260px, 320px) minmax(0, 1fr)' }}
          >
            {/* nav — desktop vertical, mobile horizontal scroll */}
            <aside className="reveal reveal-3 mb-10 md:mb-0">
              <div
                className="mb-4 font-mono text-[10px] uppercase"
                style={{ color: 'var(--burnt-brass)', letterSpacing: '0.18em' }}
              >
                ls content/decisions/
              </div>

              {/* mobile: horizontal scroll */}
              <div className="md:hidden flex gap-2 overflow-x-auto no-scrollbar pb-2">
                {docs.map((d) => (
                  <DecisionChip
                    key={d.slug}
                    doc={d}
                    active={d.slug === active.slug}
                    onClick={() => setActiveSlug(d.slug)}
                  />
                ))}
              </div>

              {/* desktop: vertical list */}
              <ul className="hidden md:block space-y-[2px]">
                {docs.map((d) => {
                  const isActive = d.slug === active.slug
                  const adrNumber = d.slug.match(/^(\d+)/)?.[1] ?? '000'
                  return (
                    <li key={d.slug}>
                      <button
                        type="button"
                        onClick={() => setActiveSlug(d.slug)}
                        className="w-full text-left block transition-colors duration-150 cursor-pointer"
                        style={{
                          background: isActive
                            ? 'linear-gradient(90deg, rgba(217, 176, 95, 0.10), transparent 80%)'
                            : 'transparent',
                          borderLeft: isActive ? '2px solid var(--oxidized-gold)' : '2px solid transparent',
                          padding: '10px 14px',
                        }}
                      >
                        <div
                          className="font-mono text-[10px] uppercase mb-1 flex items-center gap-2"
                          style={{
                            color: isActive ? 'var(--oxidized-gold)' : 'var(--burnt-brass)',
                            letterSpacing: '0.18em',
                          }}
                        >
                          <span>ADR-{adrNumber}</span>
                          <span>·</span>
                          <StatusChip status={d.meta.status as string} small />
                        </div>
                        <div
                          style={{
                            fontFamily: 'var(--font-display)',
                            fontSize: 14,
                            color: isActive ? 'var(--halo)' : 'var(--bone-dim)',
                            fontWeight: 500,
                            lineHeight: 1.2,
                            textTransform: 'uppercase',
                            letterSpacing: '0.04em',
                          }}
                        >
                          {d.meta.title as string}
                        </div>
                        <div
                          className="font-mono"
                          style={{ fontSize: 9, color: 'var(--burnt-brass)', letterSpacing: '0.08em', marginTop: 3 }}
                        >
                          {d.meta.date as string}
                        </div>
                      </button>
                    </li>
                  )
                })}
              </ul>
            </aside>

            {/* prose */}
            <div key={active.slug} className="reveal reveal-4 min-w-0">
              <DecisionHeader doc={active} />
              <MarkdownPage body={active.body} />
            </div>
          </div>
        </div>
      )}
    </section>
  )
}

function DecisionChip({ doc, active, onClick }: { doc: ContentDoc; active: boolean; onClick: () => void }) {
  const adrNumber = doc.slug.match(/^(\d+)/)?.[1] ?? '000'
  return (
    <button
      type="button"
      onClick={onClick}
      className="shrink-0 text-left"
      style={{
        padding: '10px 14px',
        minWidth: 240,
        background: active ? 'rgba(217, 176, 95, 0.10)' : 'transparent',
        border: `1px solid ${active ? 'var(--oxidized-gold)' : 'var(--burnt-brass-dim)'}`,
        cursor: 'pointer',
      }}
    >
      <div
        className="font-mono text-[9px] uppercase mb-1 flex items-center gap-2"
        style={{
          color: active ? 'var(--oxidized-gold)' : 'var(--burnt-brass)',
          letterSpacing: '0.18em',
        }}
      >
        <span>ADR-{adrNumber}</span>
        <span>·</span>
        <StatusChip status={doc.meta.status as string} small />
      </div>
      <div
        style={{
          fontFamily: 'var(--font-display)',
          fontSize: 13,
          color: active ? 'var(--halo)' : 'var(--bone-dim)',
          fontWeight: 500,
          lineHeight: 1.2,
          textTransform: 'uppercase',
          letterSpacing: '0.03em',
        }}
      >
        {doc.meta.title as string}
      </div>
    </button>
  )
}

function DecisionHeader({ doc }: { doc: ContentDoc }) {
  const adrNumber = doc.slug.match(/^(\d+)/)?.[1] ?? '000'
  return (
    <div className="mb-8">
      <div
        className="mb-2 font-mono text-[10px] uppercase"
        style={{ color: 'var(--burnt-brass)', letterSpacing: '0.18em' }}
      >
        ADR-{adrNumber}&nbsp;&nbsp;·&nbsp;&nbsp;{doc.meta.date as string}
      </div>
      <h1
        style={{
          fontFamily: 'var(--font-display)',
          fontSize: 'clamp(1.7rem, 4.5vw, 3.4rem)',
          lineHeight: 1,
          color: 'var(--bone)',
          fontWeight: 600,
          letterSpacing: '0.05em',
          textTransform: 'uppercase',
        }}
      >
        {doc.meta.title as string}
      </h1>
      <div className="mt-3">
        <StatusChip status={doc.meta.status as string} />
      </div>
    </div>
  )
}

function StatusChip({ status, small = false }: { status?: string; small?: boolean }) {
  if (!status) return null
  const colors: Record<string, string> = {
    accepted:   '#87C464',
    proposed:   '#F2D94C',
    superseded: '#7F6640',
    deprecated: '#B13340',
  }
  const color = colors[status] ?? '#D9B05F'
  return (
    <span
      className="inline-block font-mono uppercase"
      style={{
        fontSize: small ? 9 : 10,
        padding: small ? '1px 5px' : '3px 8px',
        color,
        border: `1px solid ${color}`,
        letterSpacing: '0.14em',
      }}
    >
      {status}
    </span>
  )
}
