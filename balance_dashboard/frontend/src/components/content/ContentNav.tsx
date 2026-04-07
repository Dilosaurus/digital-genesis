import type { ContentDoc } from '../../types/content'

interface Props {
  docs: ContentDoc[]
  activeSlug: string
  onSelect: (slug: string) => void
  /** Header label shown on desktop (e.g. "ls content/lore/") */
  lsLabel: string
  /** Glyph rendered next to each nav item (e.g. "§", "⚙") */
  glyph?: string
  /** Optional accent override — defaults to oxidized-gold */
  defaultAccent?: string
}

/**
 * Shared nav for the two-column content pages (Lore / Mechanics / Decisions).
 *
 * Desktop (md+): vertical list on the left, sacred-gold active state,
 * filesystem-style header.
 *
 * Mobile (< md): horizontal tab row that scrolls. Each tab is a filesystem
 * chip with the index, glyph, and slug. Active tab has a gold fill.
 */
export function ContentNav({
  docs,
  activeSlug,
  onSelect,
  lsLabel,
  glyph = '§',
  defaultAccent,
}: Props) {
  return (
    <nav>
      {/* ─── mobile: horizontal scrolling tab row ────────────────── */}
      <div className="md:hidden">
        <div
          className="mb-3 font-mono text-[10px] uppercase"
          style={{ color: 'var(--burnt-brass)', letterSpacing: '0.18em' }}
        >
          {lsLabel}
        </div>
        <div
          className="flex gap-2 overflow-x-auto no-scrollbar pb-1"
          style={{ scrollSnapType: 'x mandatory' }}
        >
          {docs.map((d, i) => {
            const isActive = d.slug === activeSlug
            const accent = (d.meta.accent as string) ?? defaultAccent ?? 'var(--oxidized-gold)'
            return (
              <button
                key={d.slug}
                type="button"
                onClick={() => onSelect(d.slug)}
                className="shrink-0 font-mono transition-colors duration-150"
                style={{
                  scrollSnapAlign: 'start',
                  padding: '8px 12px',
                  fontSize: 11,
                  letterSpacing: '0.02em',
                  color: isActive ? 'var(--void)' : 'var(--bone-dim)',
                  background: isActive ? accent : 'transparent',
                  border: `1px solid ${isActive ? accent : 'var(--burnt-brass-dim)'}`,
                  lineHeight: 1.2,
                  cursor: 'pointer',
                }}
              >
                <span
                  className="mr-2"
                  style={{
                    color: isActive ? 'var(--void-deeper)' : 'var(--burnt-brass)',
                    fontSize: 9,
                  }}
                >
                  {String(i + 1).padStart(2, '0')}
                </span>
                <span
                  className="mr-2"
                  style={{
                    color: isActive ? 'var(--void-deeper)' : accent,
                    fontSize: 13,
                  }}
                >
                  {glyph}
                </span>
                <span style={{ letterSpacing: '0.01em' }}>{d.slug}.md</span>
              </button>
            )
          })}
        </div>
      </div>

      {/* ─── desktop: vertical list ──────────────────────────────── */}
      <div className="hidden md:block">
        <div
          className="mb-4 font-mono text-[10px] uppercase"
          style={{ color: 'var(--burnt-brass)', letterSpacing: '0.18em' }}
        >
          {lsLabel}
        </div>
        <ul className="space-y-[2px]">
          {docs.map((d, i) => {
            const isActive = d.slug === activeSlug
            const accent = (d.meta.accent as string) ?? defaultAccent ?? 'var(--oxidized-gold)'
            return (
              <li key={d.slug}>
                <button
                  type="button"
                  onClick={() => onSelect(d.slug)}
                  className="w-full text-left transition-colors duration-150 flex items-baseline gap-3 py-[8px] pl-4 pr-3"
                  style={{
                    background: isActive
                      ? 'linear-gradient(90deg, rgba(217, 176, 95, 0.10), transparent 80%)'
                      : 'transparent',
                    borderLeft: isActive ? `2px solid ${accent}` : '2px solid transparent',
                    color: isActive ? 'var(--halo)' : 'var(--bone-dim)',
                    fontFamily: 'var(--font-mono)',
                    fontSize: 12.5,
                    cursor: 'pointer',
                  }}
                >
                  <span
                    style={{ color: 'var(--burnt-brass)', fontSize: 10, width: '1.6em' }}
                  >
                    {String(i + 1).padStart(2, '0')}
                  </span>
                  <span
                    style={{
                      color: isActive ? accent : 'var(--burnt-brass)',
                      fontSize: 14,
                    }}
                  >
                    {glyph}
                  </span>
                  <span className="flex-1 truncate">{d.slug}.md</span>
                </button>
              </li>
            )
          })}
        </ul>
      </div>
    </nav>
  )
}
