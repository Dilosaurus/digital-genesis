import { useLocation } from 'react-router-dom'
import { NAV_BY_PATH } from '../lib/nav'

/**
 * Stub page — shown for routes that are planned but not yet built. Sets the
 * aesthetic for the rest of the bible so visiting these routes still feels
 * like part of the app, not a 404.
 *
 * Terminal chrome. A "file not indexed" notice in the manuscript voice.
 * The actual content arrives in Phase 3 and later.
 */
export function Stub() {
  const { pathname } = useLocation()
  const match = NAV_BY_PATH.get(pathname)
  const filename = match?.entry.label ?? pathname
  const heading = match?.group.heading ?? 'CODEX'
  const subheading = match?.group.subheading ?? '~/deus.exe/'

  return (
    <section
      className="relative min-h-[calc(100dvh-120px)] flex flex-col"
      style={{ padding: 'clamp(3rem, 8vw, 5rem) clamp(1rem, 6vw, 6rem)' }}
    >
      <div
        className="reveal reveal-0 mb-4 font-mono text-[11px]"
        style={{ color: 'var(--burnt-brass)', letterSpacing: '0.18em' }}
      >
        {subheading}
      </div>

      <h1
        className="reveal reveal-1"
        style={{
          fontFamily: 'var(--font-display)',
          fontSize: 'clamp(3rem, 7vw, 6rem)',
          lineHeight: 0.95,
          letterSpacing: '0.06em',
          color: 'var(--bone)',
          fontWeight: 600,
          marginBottom: '0.3em',
        }}
      >
        {heading}
      </h1>

      <div
        className="reveal reveal-2 mb-12 font-mono text-[13px]"
        style={{ color: 'var(--oxidized-gold)', letterSpacing: '0.02em' }}
      >
        <span className="prompt" />&nbsp;stat {filename}
      </div>

      <div
        className="reveal reveal-3 terminal-frame max-w-[60ch]"
        style={{ padding: '1.5rem 2rem' }}
      >
        <div
          className="font-mono text-[12px] mb-3"
          style={{ color: 'var(--blood-bright)', letterSpacing: '0.04em' }}
        >
          ERR&nbsp;&nbsp;·&nbsp;&nbsp;FILE NOT INDEXED
        </div>
        <p
          style={{
            fontFamily: 'var(--font-body)',
            fontSize: 'var(--fs-body-md)',
            lineHeight: 1.55,
            color: 'var(--bone-dim)',
          }}
        >
          <em>This section of the codex has not yet been scribed.</em> The
          parser for <span className="mono" style={{ color: 'var(--oxidized-gold)' }}>{filename}</span>{' '}
          is ready in the backend — the page that reads it will be built in a
          later rite.
        </p>
        <div
          className="mt-4 font-mono text-[11px]"
          style={{ color: 'var(--bone-faint)' }}
        >
          expected: <span style={{ color: 'var(--bone-dim)' }}>phase 3 — codex pages</span>
        </div>
      </div>
    </section>
  )
}
