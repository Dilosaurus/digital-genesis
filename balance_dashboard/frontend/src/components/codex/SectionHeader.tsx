interface Props {
  chapter: string           // "II." — roman or other gutter marker
  heading: string           // "CARDS"
  filename: string          // "codex/cards/"
  count?: number | string
  subtitle?: string         // small descriptor line under the heading
  rightSlot?: React.ReactNode
}

/**
 * Codex page header. Sets the sacred-display-heading + terminal-filename
 * voice. Used at the top of every codex catalog page.
 *
 * Desktop: roman chapter on the left, heading + subtitle column, optional
 * right slot.
 *
 * Mobile: chapter numeral shrinks or hides, heading takes full width,
 * padding collapses from 6vw to 1rem.
 */
export function SectionHeader({ chapter, heading, filename, count, subtitle, rightSlot }: Props) {
  return (
    <header
      className="relative flex items-start justify-between gap-4 md:gap-6 pt-8 md:pt-14 pb-5 md:pb-8"
      style={{ paddingLeft: 'clamp(1rem, 6vw, 6rem)', paddingRight: 'clamp(1rem, 6vw, 6rem)' }}
    >
      <div className="flex items-start gap-4 md:gap-6 min-w-0 flex-1">
        {/* Roman numeral — hidden on mobile, big outlined stroke on desktop */}
        <div
          aria-hidden
          className="hidden md:block shrink-0"
          style={{
            fontFamily: 'var(--font-display)',
            fontSize: 'clamp(5rem, 9vw, 9rem)',
            lineHeight: 0.82,
            letterSpacing: 0,
            color: 'transparent',
            WebkitTextStroke: '1.5px var(--burnt-brass-dim)',
            fontWeight: 400,
            userSelect: 'none',
            marginTop: '-0.1em',
            marginLeft: '-0.05em',
          }}
        >
          {chapter}
        </div>

        <div className="min-w-0 flex-1">
          <div
            className="reveal reveal-0 mb-2 font-mono text-[9px] md:text-[10px] flex items-center gap-2 md:gap-3"
            style={{ color: 'var(--burnt-brass)', letterSpacing: '0.18em' }}
          >
            <span className="shrink-0" style={{ color: 'var(--blood-bright)' }}>█</span>
            <span className="shrink-0">OPEN CATALOG</span>
            <span className="shrink-0">·</span>
            <span className="truncate min-w-0">{filename}</span>
          </div>

          <h1
            className="reveal reveal-1"
            style={{
              fontFamily: 'var(--font-display)',
              fontSize: 'clamp(1.9rem, 9.5vw, 6rem)',
              lineHeight: 0.95,
              letterSpacing: '0.04em',
              color: 'var(--bone)',
              fontWeight: 600,
              wordBreak: 'break-word',
              overflowWrap: 'anywhere',
            }}
          >
            {heading}
          </h1>

          {(count != null || subtitle) && (
            <div
              className="reveal reveal-2 mt-3 flex items-baseline gap-3 md:gap-4 font-mono text-[10px] md:text-[12px] flex-wrap"
              style={{ color: 'var(--bone-faint)', letterSpacing: '0.02em' }}
            >
              {count != null && (
                <span>
                  <span style={{ color: 'var(--oxidized-gold)' }}>{count}</span>
                  &nbsp;entries
                </span>
              )}
              {subtitle && (
                <>
                  <span style={{ color: 'var(--burnt-brass)' }}>·</span>
                  <span>{subtitle}</span>
                </>
              )}
            </div>
          )}
        </div>
      </div>

      {rightSlot && <div className="reveal reveal-2 shrink-0 hidden lg:block">{rightSlot}</div>}
    </header>
  )
}
