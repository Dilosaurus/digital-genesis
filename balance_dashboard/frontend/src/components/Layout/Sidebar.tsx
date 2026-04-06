import { NavLink } from 'react-router-dom'
import { useState, useEffect } from 'react'

// ---------------------------------------------------------------------------
// Icons
// ---------------------------------------------------------------------------

const OverviewIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" className="w-5 h-5 shrink-0" aria-hidden>
    <rect x="3" y="3" width="7" height="7" rx="1" />
    <rect x="14" y="3" width="7" height="7" rx="1" />
    <rect x="3" y="14" width="7" height="7" rx="1" />
    <rect x="14" y="14" width="7" height="7" rx="1" />
  </svg>
)

const TablesIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" className="w-5 h-5 shrink-0" aria-hidden>
    <rect x="3" y="3" width="18" height="18" rx="2" />
    <line x1="3" y1="9" x2="21" y2="9" />
    <line x1="3" y1="15" x2="21" y2="15" />
    <line x1="9" y1="3" x2="9" y2="21" />
  </svg>
)

const GraphIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" className="w-5 h-5 shrink-0" aria-hidden>
    <circle cx="5" cy="12" r="2" />
    <circle cx="19" cy="5" r="2" />
    <circle cx="19" cy="19" r="2" />
    <line x1="7" y1="11.5" x2="17" y2="6.5" />
    <line x1="7" y1="12.5" x2="17" y2="17.5" />
  </svg>
)

const SimulatorIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" className="w-5 h-5 shrink-0" aria-hidden>
    <polyline points="22 12 18 12 15 21 9 3 6 12 2 12" />
  </svg>
)

const GalleryIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" className="w-5 h-5 shrink-0" aria-hidden>
    <rect x="2" y="4" width="13" height="17" rx="2" />
    <path d="M6 2h13a2 2 0 0 1 2 2v13" />
    <circle cx="8.5" cy="11.5" r="1.5" />
    <path d="M5 18l3-3 2.5 2.5" />
  </svg>
)

const ItemsIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" className="w-5 h-5 shrink-0" aria-hidden>
    <path d="M12 2l-5.5 9h11L12 2z" />
    <circle cx="12" cy="17" r="5" />
  </svg>
)

// ---------------------------------------------------------------------------
// Nav config
// ---------------------------------------------------------------------------

interface NavItem {
  to: string
  label: string
  icon: React.ReactNode
  end?: boolean
}

const NAV_ITEMS: NavItem[] = [
  { to: '/', label: 'Overview', icon: <OverviewIcon />, end: true },
  { to: '/gallery', label: 'Card Gallery', icon: <GalleryIcon /> },
  { to: '/items', label: 'Item Gallery', icon: <ItemsIcon /> },
  { to: '/tables', label: 'Balance Tables', icon: <TablesIcon /> },
  { to: '/graph', label: 'Dependency Graph', icon: <GraphIcon /> },
  { to: '/simulator', label: 'Scenario Simulator', icon: <SimulatorIcon /> },
]

// ---------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------

export function Sidebar() {
  const [apiStatus, setApiStatus] = useState<'checking' | 'connected' | 'disconnected'>('checking')

  useEffect(() => {
    fetch('/api/cards', { method: 'HEAD' })
      .then(res => setApiStatus(res.ok ? 'connected' : 'disconnected'))
      .catch(() => setApiStatus('disconnected'))
  }, [])

  return (
    <aside
      className="flex flex-col w-60 min-h-screen shrink-0"
      style={{ background: 'var(--bg-base)', borderRight: '1px solid rgba(139, 92, 246, 0.08)' }}
    >
      {/* Logo / Brand */}
      <div className="px-5 py-5" style={{ background: 'linear-gradient(135deg, rgba(124, 58, 237, 0.12), rgba(59, 130, 246, 0.06), transparent)' }}>
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-lg gradient-purple flex items-center justify-center shrink-0 glow-purple">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5 text-white" aria-hidden>
              <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z" />
            </svg>
          </div>
          <div className="flex flex-col">
            <span className="text-xs font-bold tracking-[0.15em] uppercase text-purple-300">
              Digital Genesis
            </span>
            <span className="text-[11px] text-gray-500 font-medium">
              Balance Dashboard
            </span>
          </div>
        </div>
      </div>

      {/* Gradient divider */}
      <div className="h-px mx-4" style={{ background: 'linear-gradient(90deg, transparent, rgba(139, 92, 246, 0.2), transparent)' }} />

      {/* Navigation */}
      <nav className="flex flex-col gap-0.5 px-3 py-4 flex-1" aria-label="Main navigation">
        {NAV_ITEMS.map(item => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.end}
            className={({ isActive }) =>
              [
                'group flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium no-transition',
                'transition-all duration-200',
                isActive
                  ? 'text-purple-300 border-l-[3px] border-purple-500 ml-0 pl-2.5'
                  : 'text-gray-400 hover:text-gray-200 border-l-[3px] border-transparent ml-0 pl-2.5',
              ].join(' ')
            }
            style={({ isActive }) => ({
              background: isActive
                ? 'rgba(139, 92, 246, 0.1)'
                : undefined,
            })}
          >
            <span className="group-[.active]:text-purple-400">{item.icon}</span>
            {item.label}
          </NavLink>
        ))}
      </nav>

      {/* Gradient divider */}
      <div className="h-px mx-4" style={{ background: 'linear-gradient(90deg, transparent, rgba(139, 92, 246, 0.15), transparent)' }} />

      {/* Footer */}
      <div className="px-5 py-3 flex items-center justify-between">
        <span className="text-[11px] text-gray-600">v1.0</span>
        <div className="flex items-center gap-1.5">
          <span
            className={[
              'w-1.5 h-1.5 rounded-full',
              apiStatus === 'connected' ? 'bg-emerald-400' : apiStatus === 'disconnected' ? 'bg-red-400' : 'bg-yellow-400 animate-pulse',
            ].join(' ')}
          />
          <span className="text-[11px] text-gray-600">
            {apiStatus === 'connected' ? 'API Connected' : apiStatus === 'disconnected' ? 'Disconnected' : 'Checking...'}
          </span>
        </div>
      </div>
    </aside>
  )
}
