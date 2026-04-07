import { Link, useLocation } from 'react-router-dom'
import { crumbs } from '../../lib/nav'

/**
 * Path-style breadcrumb. Renders as `~ / codex / cards / strike` where each
 * segment is a link except the last. Spacing is loose — the breadcrumb is
 * read like a filesystem path. Mono throughout.
 */
export function Breadcrumb() {
  const { pathname } = useLocation()
  const segments = crumbs(pathname)

  return (
    <nav
      aria-label="breadcrumb"
      className="flex items-center gap-[0.35em] font-mono text-[12px] tracking-[0.02em]"
      style={{ color: 'var(--bone-faint)' }}
    >
      <Link
        to="/"
        className="sacred-underline hover:no-underline"
        style={{ color: 'var(--bone-faint)' }}
      >
        ~
      </Link>
      {segments.map((seg, i) => {
        const isLast = i === segments.length - 1
        return (
          <span key={seg.path} className="flex items-center gap-[0.35em]">
            <span style={{ color: 'var(--burnt-brass)' }}>/</span>
            {isLast ? (
              <span style={{ color: 'var(--halo)' }} className="chromatic-hover">
                {seg.label}
              </span>
            ) : (
              <Link
                to={seg.path}
                className="sacred-underline hover:no-underline"
                style={{ color: 'var(--bone-dim)' }}
              >
                {seg.label}
              </Link>
            )}
          </span>
        )
      })}
    </nav>
  )
}
