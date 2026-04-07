import { useEffect } from 'react'
import { NavLink, useLocation } from 'react-router-dom'
import { NAV } from '../../lib/nav'

interface SidebarProps {
  open: boolean
  onClose: () => void
}

/**
 * Filesystem sidebar. Five groups: ROOT, BIBLE, CODEX, META, LAB, DRAFTS.
 * Each group has a sacred heading (Cinzel, oxidized gold) and a filesystem
 * subheading (mono, bone-faint, path-style). Entries render as:
 *
 *   [index]  glyph  filename/                    [count]
 *
 * Active state: oxidized gold + a small blood-relic pip in the gutter.
 * Hover state: halo text with a sacred underline animated in.
 *
 * ─── Mobile behavior ────────────────────────────────────────────────────
 * On screens narrower than `md` (768px), the sidebar is a drawer that
 * slides in from the left over the content. Closed by default. Opens via
 * a `ls ~/` button in the Frame header. The backdrop closes on click.
 * Navigating to a new route auto-closes the drawer.
 *
 * On `md` and wider, it's a persistent flex child as before.
 */
export function Sidebar({ open, onClose }: SidebarProps) {
  const { pathname } = useLocation()
  const location = useLocation()
  let globalIndex = 0

  // Auto-close drawer on navigation
  useEffect(() => {
    onClose()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [location.pathname])

  // Lock body scroll when drawer is open on mobile
  useEffect(() => {
    if (open && typeof document !== 'undefined') {
      const prev = document.body.style.overflow
      document.body.style.overflow = 'hidden'
      return () => {
        document.body.style.overflow = prev
      }
    }
  }, [open])

  return (
    <>
      {/* ── backdrop — mobile only, when drawer is open ─────────────── */}
      <div
        onClick={onClose}
        aria-hidden
        className={`fixed inset-0 z-40 transition-opacity duration-200 md:hidden ${
          open ? 'opacity-100 pointer-events-auto' : 'opacity-0 pointer-events-none'
        }`}
        style={{
          background: 'rgba(5, 3, 3, 0.82)',
          backdropFilter: 'blur(2px)',
        }}
      />

      {/* ── sidebar ─────────────────────────────────────────────────── */}
      <aside
        className="flex flex-col scanlines-soft phosphor-glow
          fixed top-0 bottom-0 left-0 z-50
          md:sticky md:top-0 md:z-auto md:h-dvh md:self-start
          transition-transform duration-300 ease-out"
        style={{
          background: 'var(--void-deeper)',
          borderRight: '1px solid var(--burnt-brass)',
          minHeight: '100dvh',
          width: 'clamp(260px, 22vw, 300px)',
          maxWidth: '85vw',
          // Use the modern `translate` CSS property (independent from
          // `transform`) because Tailwind v4 uses it for its translate
          // utilities and our previous attempts to set `transform` were
          // being shadowed. On desktop (md+) a CSS media query resets it.
          translate: open ? '0 0' : '-100% 0',
        }}
        data-drawer-open={open ? 'true' : 'false'}
      >
        {/* Sidebar chrome header */}
        <div
          className="relative px-6 py-5 flex items-start justify-between gap-4"
          style={{ borderBottom: '1px solid var(--burnt-brass-dim)' }}
        >
          <div>
            <div
              className="font-mono text-[10px] uppercase mb-2"
              style={{ color: 'var(--bone-faint)', letterSpacing: '0.18em' }}
            >
              ls ~/deus.exe
            </div>
            <div
              className="font-mono text-[11px]"
              style={{ color: 'var(--bone-dim)', letterSpacing: '0.02em' }}
            >
              <span style={{ color: 'var(--oxidized-gold)' }}>6</span> groups,&nbsp;
              <span style={{ color: 'var(--oxidized-gold)' }}>269</span> entries
            </div>
          </div>

          {/* Close button — mobile only */}
          <button
            type="button"
            onClick={onClose}
            aria-label="close navigation"
            className="md:hidden shrink-0 font-mono text-[11px] uppercase chromatic-hover"
            style={{
              color: 'var(--blood-bright)',
              letterSpacing: '0.14em',
              padding: '6px 10px',
              border: '1px solid var(--burnt-brass)',
              background: 'transparent',
              cursor: 'pointer',
              lineHeight: 1,
            }}
          >
            [ q ]
          </button>
        </div>

        {/* Scrollable nav body */}
        <div className="flex-1 overflow-y-auto overflow-x-hidden py-4">
          {NAV.map((group, gi) => (
            <div key={group.id} className={`mb-7 ${gi === 0 ? 'mt-1' : ''}`}>
              {/* Group heading: sacred Cinzel + mono path */}
              <div className="px-6 mb-2">
                <div
                  className="font-display text-[11px] font-semibold"
                  style={{
                    fontFamily: 'var(--font-display)',
                    letterSpacing: '0.28em',
                    color: 'var(--oxidized-gold)',
                  }}
                >
                  {group.heading}
                </div>
                <div
                  className="font-mono text-[10px] mt-[2px]"
                  style={{ color: 'var(--burnt-brass)', letterSpacing: '0.02em' }}
                >
                  {group.subheading}
                </div>
              </div>

              <ul className="space-y-[2px]">
                {group.entries.map((entry) => {
                  const idx = ++globalIndex
                  const isActive = pathname === entry.path
                  return (
                    <li key={entry.path}>
                      <NavLink
                        to={entry.path}
                        end={entry.path === '/'}
                        className="group relative flex items-baseline gap-3 pl-6 pr-5 py-[7px] font-mono text-[12.5px] transition-colors duration-150"
                        style={{
                          color: isActive ? 'var(--halo)' : 'var(--bone-dim)',
                          background: isActive
                            ? 'linear-gradient(90deg, rgba(217,176,95,0.10), transparent 80%)'
                            : 'transparent',
                          borderLeft: isActive
                            ? '2px solid var(--oxidized-gold)'
                            : '2px solid transparent',
                        }}
                      >
                        {isActive && (
                          <span
                            aria-hidden
                            className="absolute left-[2px] top-1/2 -translate-y-1/2 w-1 h-1 rounded-none"
                            style={{ background: 'var(--blood-bright)' }}
                          />
                        )}

                        <span
                          className="w-6 text-right text-[10px] tabular-nums"
                          style={{ color: 'var(--burnt-brass)' }}
                        >
                          {String(idx).padStart(3, '0')}
                        </span>

                        <span
                          className="text-[13px]"
                          style={{
                            color: isActive ? 'var(--oxidized-gold)' : 'var(--burnt-brass)',
                            width: '0.9em',
                          }}
                        >
                          {entry.glyph}
                        </span>

                        <span
                          className="flex-1 transition-colors duration-150 group-hover:text-[color:var(--halo)]"
                          style={{ letterSpacing: '0.01em' }}
                        >
                          {entry.label}
                        </span>

                        {entry.count != null && (
                          <span
                            className="text-[10px] tabular-nums"
                            style={{ color: 'var(--burnt-brass)' }}
                          >
                            {entry.count}
                          </span>
                        )}
                      </NavLink>
                    </li>
                  )
                })}
              </ul>
            </div>
          ))}
        </div>

        {/* Sidebar footer — session indicator */}
        <div
          className="px-6 py-4 font-mono text-[10px]"
          style={{
            borderTop: '1px solid var(--burnt-brass-dim)',
            color: 'var(--bone-faint)',
            letterSpacing: '0.02em',
          }}
        >
          <div className="flex items-center justify-between">
            <span>
              <span style={{ color: 'var(--terminal-phosphor)' }}>●</span>&nbsp;
              <span className="prompt" style={{ color: 'var(--bone-dim)' }}>
                chris@nexus
              </span>
            </span>
            <span style={{ color: 'var(--burnt-brass)' }}>v0.1.0</span>
          </div>
          <div className="mt-1" style={{ color: 'var(--burnt-brass)' }}>
            uptime: unknown
          </div>
        </div>
      </aside>
    </>
  )
}
