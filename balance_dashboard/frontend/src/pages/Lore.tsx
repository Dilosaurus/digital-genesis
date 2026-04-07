import { useState } from 'react'
import { useContentSection } from '../hooks/useContent'
import { MarkdownPage } from '../components/content/MarkdownPage'
import { SectionHeader } from '../components/codex/SectionHeader'
import { ContentNav } from '../components/content/ContentNav'

/**
 * /lore — the bible's cosmology.
 *
 * Desktop: two-column — nav left, prose right.
 * Mobile: horizontal tab row up top, prose below.
 */
export function Lore() {
  const { data: docs, isLoading, error } = useContentSection('lore')
  const [activeSlug, setActiveSlug] = useState<string | null>(null)

  const active = docs?.find(d => d.slug === (activeSlug ?? docs?.[0]?.slug))

  return (
    <section className="relative pb-20">
      <SectionHeader
        chapter="I."
        heading="LORE"
        filename="bible/lore.txt"
        count={docs?.length ?? '—'}
        subtitle="cosmology of the sealed cathedral."
      />

      {isLoading && (
        <div className="mx-[clamp(1rem,6vw,6rem)] terminal-frame p-4 md:p-6 font-mono text-[12px]" style={{ color: 'var(--bone-faint)' }}>
          <span className="prompt" />&nbsp;cat content/lore/*.md<span className="caret" />
        </div>
      )}
      {error && (
        <div className="mx-[clamp(1rem,6vw,6rem)] terminal-frame p-4 md:p-6 font-mono text-[12px]" style={{ color: 'var(--blood-bright)' }}>
          ERR · {String(error)}
        </div>
      )}

      {docs && active && (
        <div className="mx-[clamp(1rem,6vw,6rem)]">
          {/* Grid on desktop, stacked on mobile */}
          <div
            className="grid gap-8 md:gap-[clamp(2rem,5vw,5rem)]"
            style={{ gridTemplateColumns: 'minmax(0, 1fr)' }}
          >
            <div className="md:grid md:gap-[clamp(2rem,5vw,5rem)]" style={{ gridTemplateColumns: 'minmax(220px, 280px) minmax(0, 1fr)' }}>
              {/* nav */}
              <aside className="reveal reveal-3 mb-8 md:mb-0">
                <ContentNav
                  docs={docs}
                  activeSlug={active.slug}
                  onSelect={setActiveSlug}
                  lsLabel="ls content/lore/"
                  glyph="§"
                />
                <div
                  className="hidden md:block mt-8 pt-6 font-mono text-[10px]"
                  style={{ borderTop: '1px solid var(--burnt-brass-dim)', color: 'var(--burnt-brass)', letterSpacing: '0.14em', lineHeight: 1.7 }}
                >
                  <div className="mb-2 uppercase">chapter · {active.meta.chapter ?? '—'}</div>
                  <div className="uppercase" style={{ color: 'var(--bone-faint)' }}>{active.meta.subtitle ?? ''}</div>
                </div>
              </aside>

              {/* prose */}
              <div key={active.slug} className="reveal reveal-4 min-w-0">
                <MarkdownPage body={active.body} accentColor={active.meta.accent as string | undefined} />
              </div>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}
