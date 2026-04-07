import { useState } from 'react'
import { useContentSection } from '../hooks/useContent'
import { MarkdownPage } from '../components/content/MarkdownPage'
import { SectionHeader } from '../components/codex/SectionHeader'
import { ContentNav } from '../components/content/ContentNav'

/**
 * /mechanics — design rationale for combat, modifiers, corruption, sins,
 * pacts, and gems.
 *
 * Desktop: TOC left, prose right.
 * Mobile: horizontal tab row up top, prose below.
 */
export function Mechanics() {
  const { data: docs, isLoading, error } = useContentSection('mechanics')
  const [activeSlug, setActiveSlug] = useState<string | null>(null)

  const active = docs?.find(d => d.slug === (activeSlug ?? docs?.[0]?.slug))

  return (
    <section className="relative pb-20">
      <SectionHeader
        chapter="III."
        heading="THE MECHANICS"
        filename="bible/mechanics.gd"
        count={docs?.length ?? '—'}
        subtitle="design rationale, not rules text."
      />

      {isLoading && (
        <div className="mx-[clamp(1rem,6vw,6rem)] terminal-frame p-4 md:p-6 font-mono text-[12px]" style={{ color: 'var(--bone-faint)' }}>
          <span className="prompt" />&nbsp;cat content/mechanics/*.md<span className="caret" />
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
            style={{ gridTemplateColumns: 'minmax(240px, 300px) minmax(0, 1fr)' }}
          >
            <aside className="reveal reveal-3 mb-8 md:mb-0">
              <ContentNav
                docs={docs}
                activeSlug={active.slug}
                onSelect={setActiveSlug}
                lsLabel="ls content/mechanics/"
                glyph="⚙"
              />
            </aside>

            <div key={active.slug} className="reveal reveal-4 min-w-0">
              <MarkdownPage body={active.body} accentColor={active.meta.accent as string | undefined} />
            </div>
          </div>
        </div>
      )}
    </section>
  )
}
