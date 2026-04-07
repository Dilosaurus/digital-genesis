import { useState } from 'react'
import { Outlet } from 'react-router-dom'
import { Sidebar } from './Sidebar'
import { Wordmark } from './Wordmark'
import { Breadcrumb } from './Breadcrumb'

/**
 * Frame — the outer chrome of deus.exe // codex.
 *
 * Desktop (md and wider): sidebar pinned left, main column right with
 * header strip + content + footer.
 *
 * Mobile (< md): sidebar is hidden as a slide-in drawer. The header strip
 * collapses to three rows (wordmark + ls button on top, breadcrumb below,
 * stats below that on two lines if needed). The `ls ~/` button opens the
 * drawer. The whole top strip stays scanlined + brass-bordered.
 */
export function Frame() {
  const [drawerOpen, setDrawerOpen] = useState(false)

  return (
    <div className="flex min-h-dvh">
      <Sidebar open={drawerOpen} onClose={() => setDrawerOpen(false)} />

      <div className="relative flex-1 flex flex-col min-w-0">
        {/* ─── top strip ──────────────────────────────────────────────
         * Desktop: single row — wordmark | breadcrumb | stats
         * Mobile:  two rows — [ls ~/] wordmark | stats on second row
         */}
        <header
          className="relative scanlines-soft"
          style={{
            background: 'var(--void-deeper)',
            borderBottom: '1px solid var(--burnt-brass-dim)',
          }}
        >
          {/* Row 1: ls button (mobile only) + wordmark + breadcrumb (md+) */}
          <div className="flex items-center justify-between gap-4 px-4 md:px-8 h-[60px] md:h-[68px]">
            <div className="flex items-center gap-3 md:gap-8 min-w-0">
              {/* ls ~/ button — mobile only */}
              <button
                type="button"
                onClick={() => setDrawerOpen(true)}
                aria-label="open navigation"
                className="md:hidden shrink-0 font-mono uppercase chromatic-hover"
                style={{
                  color: 'var(--oxidized-gold)',
                  fontSize: 11,
                  letterSpacing: '0.14em',
                  padding: '8px 11px',
                  border: '1px solid var(--burnt-brass)',
                  background: 'rgba(217, 176, 95, 0.05)',
                  lineHeight: 1,
                  cursor: 'pointer',
                }}
              >
                ls ~/
              </button>

              <Wordmark size="md" caret />

              {/* // CODEX label — desktop only */}
              <div
                className="hidden md:block font-mono text-[10px]"
                style={{ color: 'var(--burnt-brass)', letterSpacing: '0.18em' }}
              >
                //&nbsp;CODEX
              </div>
            </div>

            <div className="hidden md:flex items-center gap-8">
              <Breadcrumb />
              <div
                className="flex items-center gap-4 font-mono text-[10px]"
                style={{ color: 'var(--bone-faint)', letterSpacing: '0.02em' }}
              >
                <span>
                  <span style={{ color: 'var(--oxidized-gold)' }}>175</span>&nbsp;cards
                </span>
                <span style={{ color: 'var(--burnt-brass)' }}>·</span>
                <span>
                  <span style={{ color: 'var(--oxidized-gold)' }}>6</span>&nbsp;chars
                </span>
                <span style={{ color: 'var(--burnt-brass)' }}>·</span>
                <span>
                  draft&nbsp;
                  <span style={{ color: 'var(--bone-dim)' }}>clean</span>
                </span>
              </div>
            </div>
          </div>

          {/* Row 2: mobile-only breadcrumb strip */}
          <div
            className="md:hidden flex items-center justify-between gap-3 px-4 pb-2 -mt-1"
            style={{ minHeight: 22 }}
          >
            <div className="min-w-0 overflow-x-auto no-scrollbar">
              <Breadcrumb />
            </div>
            <div
              className="shrink-0 font-mono text-[9px]"
              style={{ color: 'var(--burnt-brass)', letterSpacing: '0.12em' }}
            >
              175c · 6ch
            </div>
          </div>
        </header>

        {/* ─── content ─────────────────────────────────────────────── */}
        <main className="flex-1 relative overflow-x-hidden">
          <Outlet />
        </main>

        {/* ─── footer ──────────────────────────────────────────────── */}
        <footer
          className="flex flex-col md:flex-row md:items-center md:justify-between gap-1 md:gap-0 px-4 md:px-8 py-3 font-mono text-[9px] md:text-[10px]"
          style={{
            background: 'var(--void-deeper)',
            borderTop: '1px solid var(--burnt-brass-dim)',
            color: 'var(--burnt-brass)',
            letterSpacing: '0.02em',
          }}
        >
          <span>
            deus.exe // codex&nbsp;&nbsp;·&nbsp;&nbsp;v0.1.0&nbsp;&nbsp;·&nbsp;&nbsp;
            <span style={{ color: 'var(--bone-faint)' }}>rite of 2026-04-07</span>
          </span>
          <span>
            <span style={{ color: 'var(--bone-faint)' }}>source:</span>&nbsp;
            <span style={{ color: 'var(--bone-dim)' }}>.tres</span>
            &nbsp;·&nbsp;
            <span style={{ color: 'var(--bone-faint)' }}>overlay:</span>&nbsp;
            <span style={{ color: 'var(--bone-dim)' }}>off</span>
          </span>
        </footer>
      </div>
    </div>
  )
}
