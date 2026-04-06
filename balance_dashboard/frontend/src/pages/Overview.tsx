import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import {
  useCards,
  useRelics,
  useEquipment,
  useGems,
  useSkillTree,
  useEnemies,
  useReload,
} from '../hooks/useApi'
import type { Card, Equipment } from '../types'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface OutlierAlert {
  key: string
  name: string
  stat: string
  value: string
  severity: 'warn' | 'danger'
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function dpe(card: Card): number {
  if (card.energy_cost <= 0) return Infinity
  return (card.damage * card.hits) / card.energy_cost
}

function bpe(card: Card): number {
  if (card.energy_cost <= 0) return Infinity
  return card.block / card.energy_cost
}

function computeAlerts(
  cards: Card[],
  equipment: Equipment[],
): OutlierAlert[] {
  const alerts: OutlierAlert[] = []

  for (const card of cards) {
    const d = dpe(card)
    if (d !== Infinity && d > 8.0) {
      alerts.push({
        key: `dpe-${card.id}`,
        name: card.display_name,
        stat: 'DPE',
        value: d.toFixed(1),
        severity: d > 12 ? 'danger' : 'warn',
      })
    }

    const b = bpe(card)
    if (b !== Infinity && b > 8.0) {
      alerts.push({
        key: `bpe-${card.id}`,
        name: card.display_name,
        stat: 'BPE',
        value: b.toFixed(1),
        severity: b > 12 ? 'danger' : 'warn',
      })
    }

    const totalDamage = card.damage * card.hits
    if (card.energy_cost === 0 && totalDamage > 0) {
      alerts.push({
        key: `free-${card.id}`,
        name: card.display_name,
        stat: 'Free damage',
        value: `${totalDamage} dmg @ 0 cost`,
        severity: 'danger',
      })
    }
  }

  for (const equip of equipment) {
    if (equip.modifiers.length >= 3) {
      alerts.push({
        key: `mods-${equip.id}`,
        name: equip.display_name,
        stat: 'Modifier count',
        value: `${equip.modifiers.length} modifiers`,
        severity: equip.modifiers.length >= 4 ? 'danger' : 'warn',
      })
    }
  }

  return alerts
}

// ---------------------------------------------------------------------------
// Sub-components
// ---------------------------------------------------------------------------

interface SkeletonCardProps {
  wide?: boolean
}

function SkeletonCard({ wide }: SkeletonCardProps) {
  return (
    <div
      className={`panel p-5 animate-pulse${wide ? ' col-span-full' : ''}`}
    >
      <div className="h-3 w-24 bg-gray-700 rounded mb-4" />
      <div className="h-8 w-16 bg-gray-700 rounded" />
    </div>
  )
}

interface ErrorCardProps {
  message: string
  onRetry: () => void
  wide?: boolean
}

function ErrorCard({ message, onRetry, wide }: ErrorCardProps) {
  return (
    <div
      className={`panel panel-accent-red p-5 flex flex-col gap-2${wide ? ' col-span-full' : ''}`}
    >
      <span className="text-red-400 text-sm font-medium">Error</span>
      <span className="text-gray-400 text-xs">{message}</span>
      <button
        onClick={onRetry}
        className="mt-1 self-start text-xs text-purple-400 hover:text-purple-300 underline underline-offset-2"
      >
        Retry
      </button>
    </div>
  )
}

interface StatCardProps {
  label: string
  count: number | null
  loading: boolean
  error: string | null
  onRetry: () => void
  accentClass: string
  glowClass: string
  icon: React.ReactNode
  to?: string
}

function StatCard({
  label,
  count,
  loading,
  error,
  onRetry,
  accentClass,
  glowClass,
  icon,
  to,
}: StatCardProps) {
  const [hovered, setHovered] = useState(false)
  const navigate = useNavigate()

  if (loading) return <SkeletonCard />
  if (error) return <ErrorCard message={error} onRetry={onRetry} />

  const handleClick = to ? () => navigate(to) : undefined

  return (
    <div
      className={[
        'panel p-5 flex items-start gap-4',
        hovered ? glowClass : '',
        to ? 'cursor-pointer' : '',
      ].join(' ')}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onClick={handleClick}
      role={to ? 'link' : undefined}
    >
      <div
        className={`w-11 h-11 rounded-lg flex items-center justify-center shrink-0 ${accentClass}`}
      >
        {icon}
      </div>
      <div className="flex flex-col min-w-0">
        <span className="text-gray-500 text-[11px] font-semibold uppercase tracking-[0.1em]">
          {label}
        </span>
        <span className="text-4xl font-extrabold text-purple-300 leading-tight mt-0.5 font-mono">
          {count ?? '\u2014'}
        </span>
        {to && (
          <span className="text-[10px] text-purple-500 mt-1 group-hover:text-purple-400">
            Click to browse &rarr;
          </span>
        )}
      </div>
    </div>
  )
}

interface AlertRowProps {
  alert: OutlierAlert
}

function AlertRow({ alert }: AlertRowProps) {
  const borderColor =
    alert.severity === 'danger' ? 'border-l-red-500' : 'border-l-yellow-500'
  const valueColor =
    alert.severity === 'danger' ? 'text-red-400' : 'text-yellow-400'
  const dotColor =
    alert.severity === 'danger' ? 'bg-red-500' : 'bg-yellow-500'

  return (
    <li
      className={`flex items-center gap-3 py-3 px-3 -mx-3 rounded-lg border-l-4 ${borderColor} border-b border-b-white/[0.03] last:border-b-0 hover:bg-white/[0.02] cursor-default`}
    >
      <span className={`w-2 h-2 rounded-full shrink-0 ${dotColor} shadow-[0_0_6px_currentColor]`} />
      <span className="text-gray-200 text-sm font-medium truncate flex-1">
        {alert.name}
      </span>
      <span className="text-gray-500 text-xs shrink-0">{alert.stat}</span>
      <span className={`text-xs font-mono font-semibold shrink-0 ${valueColor}`}>
        {alert.value}
      </span>
    </li>
  )
}

interface QuickNavCardProps {
  to: string
  title: string
  description: string
  icon: React.ReactNode
  glowClass: string
}

function QuickNavCard({ to, title, description, icon, glowClass }: QuickNavCardProps) {
  const [hovered, setHovered] = useState(false)

  return (
    <Link
      to={to}
      className={`group panel p-5 flex gap-4 items-start${hovered ? ` ${glowClass}` : ''}`}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      <div className="w-11 h-11 rounded-lg bg-purple-950/60 border border-purple-800/40 flex items-center justify-center shrink-0 group-hover:bg-purple-900/40 group-hover:border-purple-700/50">
        {icon}
      </div>
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <p className="text-gray-100 font-bold text-sm group-hover:text-purple-300">
            {title}
          </p>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 20 20"
            fill="currentColor"
            className="w-4 h-4 text-gray-600 group-hover:text-purple-400 translate-x-0 group-hover:translate-x-1 transition-transform duration-200"
            aria-hidden
          >
            <path
              fillRule="evenodd"
              d="M5 10a.75.75 0 01.75-.75h6.638L10.23 7.29a.75.75 0 111.04-1.08l3.5 3.25a.75.75 0 010 1.08l-3.5 3.25a.75.75 0 11-1.04-1.08l2.158-1.96H5.75A.75.75 0 015 10z"
              clipRule="evenodd"
            />
          </svg>
        </div>
        <p className="text-gray-400 text-xs mt-1 leading-relaxed">
          {description}
        </p>
      </div>
    </Link>
  )
}

// ---------------------------------------------------------------------------
// Section header with colored dot
// ---------------------------------------------------------------------------

function SectionHeader({ color, children }: { color: string; children: React.ReactNode }) {
  return (
    <div className="flex items-center gap-2.5 mb-4">
      <span className={`w-2 h-2 rounded-full ${color}`} />
      <h2 className="text-sm font-semibold text-gray-400 uppercase tracking-widest">
        {children}
      </h2>
    </div>
  )
}

// ---------------------------------------------------------------------------
// SVG icons (inline, no external dependency)
// ---------------------------------------------------------------------------

const IconCards = () => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth={1.8}
    strokeLinecap="round"
    strokeLinejoin="round"
    className="w-5 h-5"
    aria-hidden
  >
    <rect x="2" y="4" width="13" height="17" rx="2" />
    <path d="M6 2h13a2 2 0 0 1 2 2v13" />
  </svg>
)

const IconRelics = () => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth={1.8}
    strokeLinecap="round"
    strokeLinejoin="round"
    className="w-5 h-5"
    aria-hidden
  >
    <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" />
  </svg>
)

const IconEquipment = () => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth={1.8}
    strokeLinecap="round"
    strokeLinejoin="round"
    className="w-5 h-5"
    aria-hidden
  >
    <path d="M14.5 2.5l7 7-10 10-7-7 10-10z" />
    <path d="M2 22l4-4" />
  </svg>
)

const IconGems = () => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth={1.8}
    strokeLinecap="round"
    strokeLinejoin="round"
    className="w-5 h-5"
    aria-hidden
  >
    <path d="M6 3h12l4 6-10 13L2 9z" />
    <path d="M2 9h20" />
    <path d="M9 3l3 6 3-6" />
  </svg>
)

const IconSkills = () => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth={1.8}
    strokeLinecap="round"
    strokeLinejoin="round"
    className="w-5 h-5"
    aria-hidden
  >
    <circle cx="12" cy="12" r="3" />
    <circle cx="5" cy="5" r="2" />
    <circle cx="19" cy="5" r="2" />
    <circle cx="5" cy="19" r="2" />
    <circle cx="19" cy="19" r="2" />
    <line x1="7" y1="7" x2="10" y2="10" />
    <line x1="17" y1="7" x2="14" y2="10" />
    <line x1="7" y1="17" x2="10" y2="14" />
    <line x1="17" y1="17" x2="14" y2="14" />
  </svg>
)

const IconEnemies = () => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth={1.8}
    strokeLinecap="round"
    strokeLinejoin="round"
    className="w-5 h-5"
    aria-hidden
  >
    <path d="M12 2a5 5 0 0 1 5 5v2a5 5 0 0 1-10 0V7a5 5 0 0 1 5-5z" />
    <path d="M4 20c0-4 3.6-7 8-7s8 3 8 7" />
    <line x1="9" y1="9" x2="9.01" y2="9" strokeWidth={3} strokeLinecap="round" />
    <line x1="15" y1="9" x2="15.01" y2="9" strokeWidth={3} strokeLinecap="round" />
  </svg>
)

const IconTable = () => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth={1.8}
    strokeLinecap="round"
    strokeLinejoin="round"
    className="w-5 h-5 text-purple-400"
    aria-hidden
  >
    <rect x="3" y="3" width="18" height="18" rx="2" />
    <line x1="3" y1="9" x2="21" y2="9" />
    <line x1="3" y1="15" x2="21" y2="15" />
    <line x1="9" y1="9" x2="9" y2="21" />
  </svg>
)

const IconGraph = () => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth={1.8}
    strokeLinecap="round"
    strokeLinejoin="round"
    className="w-5 h-5 text-purple-400"
    aria-hidden
  >
    <circle cx="5" cy="12" r="2" />
    <circle cx="19" cy="5" r="2" />
    <circle cx="19" cy="19" r="2" />
    <line x1="7" y1="11" x2="17" y2="6" />
    <line x1="7" y1="13" x2="17" y2="18" />
  </svg>
)

const IconSimulator = () => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth={1.8}
    strokeLinecap="round"
    strokeLinejoin="round"
    className="w-5 h-5 text-purple-400"
    aria-hidden
  >
    <polyline points="22 12 18 12 15 21 9 3 6 12 2 12" />
  </svg>
)

const IconRefresh = ({ spinning }: { spinning: boolean }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth={2}
    strokeLinecap="round"
    strokeLinejoin="round"
    className={`w-4 h-4${spinning ? ' animate-spin' : ''}`}
    aria-hidden
  >
    <polyline points="23 4 23 10 17 10" />
    <path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10" />
  </svg>
)

const IconWarning = () => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth={1.8}
    strokeLinecap="round"
    strokeLinejoin="round"
    className="w-5 h-5 text-yellow-400"
    aria-hidden
  >
    <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
    <line x1="12" y1="9" x2="12" y2="13" />
    <line x1="12" y1="17" x2="12.01" y2="17" />
  </svg>
)

// ---------------------------------------------------------------------------
// Main page
// ---------------------------------------------------------------------------

export default function Overview() {
  const cards = useCards()
  const relics = useRelics()
  const equipment = useEquipment()
  const gems = useGems()
  const skillTree = useSkillTree()
  const enemies = useEnemies()
  const { reload, loading: reloading, error: reloadError } = useReload()

  const alerts =
    cards.data && equipment.data
      ? computeAlerts(cards.data, equipment.data)
      : null

  const alertsLoading = cards.loading || equipment.loading
  const alertsError = cards.error ?? equipment.error

  const hasDanger = alerts?.some(a => a.severity === 'danger') ?? false

  const statCards = [
    {
      label: 'Total Cards',
      count: cards.data?.length ?? null,
      loading: cards.loading,
      error: cards.error,
      onRetry: cards.refetch,
      accentClass: 'bg-purple-950/60 border border-purple-800/40 text-purple-400 shadow-[0_0_8px_rgba(168,85,247,0.15)]',
      glowClass: 'glow-purple',
      icon: <IconCards />,
      to: '/gallery',
    },
    {
      label: 'Total Relics',
      count: relics.data?.length ?? null,
      loading: relics.loading,
      error: relics.error,
      onRetry: relics.refetch,
      accentClass: 'bg-yellow-950/60 border border-yellow-800/40 text-yellow-400 shadow-[0_0_8px_rgba(234,179,8,0.15)]',
      glowClass: 'glow-yellow',
      icon: <IconRelics />,
      to: '/items?type=relic',
    },
    {
      label: 'Total Equipment',
      count: equipment.data?.length ?? null,
      loading: equipment.loading,
      error: equipment.error,
      onRetry: equipment.refetch,
      accentClass: 'bg-sky-950/60 border border-sky-800/40 text-sky-400 shadow-[0_0_8px_rgba(56,189,248,0.15)]',
      glowClass: 'glow-cyan',
      icon: <IconEquipment />,
      to: '/items?type=equipment',
    },
    {
      label: 'Total Gems',
      count: gems.data?.length ?? null,
      loading: gems.loading,
      error: gems.error,
      onRetry: gems.refetch,
      accentClass: 'bg-emerald-950/60 border border-emerald-800/40 text-emerald-400 shadow-[0_0_8px_rgba(34,197,94,0.15)]',
      glowClass: 'glow-green',
      icon: <IconGems />,
      to: '/items?type=gem',
    },
    {
      label: 'Skill Nodes',
      count: skillTree.data?.length ?? null,
      loading: skillTree.loading,
      error: skillTree.error,
      onRetry: skillTree.refetch,
      accentClass: 'bg-rose-950/60 border border-rose-800/40 text-rose-400 shadow-[0_0_8px_rgba(244,63,94,0.15)]',
      glowClass: 'glow-red',
      icon: <IconSkills />,
    },
    {
      label: 'Total Enemies',
      count: enemies.data?.length ?? null,
      loading: enemies.loading,
      error: enemies.error,
      onRetry: enemies.refetch,
      accentClass: 'bg-orange-950/60 border border-orange-800/40 text-orange-400 shadow-[0_0_8px_rgba(249,115,22,0.15)]',
      glowClass: 'glow-orange',
      icon: <IconEnemies />,
    },
  ]

  return (
    <div className="flex flex-col gap-10 p-6 max-w-6xl w-full mx-auto">
      {/* Hero header */}
      <div className="gradient-header rounded-2xl p-6 -m-1">
        <div className="flex items-start justify-between gap-4 flex-wrap">
          <div>
            <h1 className="text-3xl font-extrabold text-gray-100 tracking-tight">
              Overview
            </h1>
            <p className="text-gray-400 text-sm mt-1.5 max-w-md">
              Balance health summary for the card game data files. Monitor content counts, flag outliers, and jump to tools.
            </p>
          </div>

          <div className="flex flex-col items-end gap-1.5">
            <button
              onClick={reload}
              disabled={reloading}
              className="reload-btn flex items-center gap-2 px-5 py-2.5 gradient-purple disabled:opacity-50 disabled:cursor-not-allowed rounded-lg text-sm text-white font-semibold shadow-lg"
            >
              <IconRefresh spinning={reloading} />
              {reloading ? 'Reloading\u2026' : 'Reload data'}
            </button>
            {reloadError && (
              <span className="text-red-400 text-xs">{reloadError}</span>
            )}
          </div>
        </div>
      </div>

      {/* Stat cards grid */}
      <section aria-label="Summary statistics">
        <SectionHeader color="bg-purple-500">Content counts</SectionHeader>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {statCards.map(card => (
            <StatCard key={card.label} {...card} />
          ))}
        </div>
      </section>

      {/* Outlier alerts */}
      <section aria-label="Balance alerts">
        <div className="flex items-center gap-3 mb-4">
          <div className="flex items-center gap-2.5">
            <span className="w-2 h-2 rounded-full bg-yellow-500" />
            <h2 className="text-sm font-semibold text-gray-400 uppercase tracking-widest">
              Balance concerns
            </h2>
          </div>
          {alerts && alerts.length > 0 && (
            <span className="badge badge-rare text-[10px]">
              {alerts.length}
            </span>
          )}
        </div>

        <div className={`panel ${hasDanger ? 'panel-accent-red' : 'panel-accent-purple'}`}>
          {alertsLoading ? (
            <div className="p-5 space-y-3 animate-pulse">
              {Array.from({ length: 4 }, (_, i) => (
                <div key={i} className="h-4 bg-gray-700/50 rounded w-full" />
              ))}
            </div>
          ) : alertsError ? (
            <div className="p-5 flex flex-col gap-2">
              <span className="text-red-400 text-sm">
                Failed to compute alerts: {alertsError}
              </span>
              <button
                onClick={() => {
                  cards.refetch()
                  equipment.refetch()
                }}
                className="self-start text-xs text-purple-400 hover:text-purple-300 underline underline-offset-2"
              >
                Retry
              </button>
            </div>
          ) : alerts && alerts.length === 0 ? (
            <div className="p-5 flex items-center gap-3 text-gray-400 text-sm">
              <span className="w-2.5 h-2.5 rounded-full bg-emerald-500 shadow-[0_0_8px_rgba(34,197,94,0.4)] shrink-0" />
              No balance concerns detected. All thresholds within range.
            </div>
          ) : (
            <div className="px-5 pb-2">
              <div className="flex items-center gap-3 py-3.5 border-b border-white/[0.04]">
                <IconWarning />
                <span className="text-xs text-gray-400 font-medium">
                  Items exceeding thresholds — DPE &gt; 8, BPE &gt; 8, 3+ modifiers, or free damage
                </span>
              </div>
              <ul className="pt-1">
                {alerts?.map(alert => (
                  <AlertRow key={alert.key} alert={alert} />
                ))}
              </ul>
            </div>
          )}
        </div>
      </section>

      {/* Quick navigation */}
      <section aria-label="Navigation shortcuts">
        <SectionHeader color="bg-cyan-500">Tools</SectionHeader>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <QuickNavCard
            to="/tables"
            title="Balance Tables"
            description="Browse and sort all cards, relics, equipment, gems, and skill nodes with raw stat columns."
            icon={<IconTable />}
            glowClass="glow-purple"
          />
          <QuickNavCard
            to="/graph"
            title="Dependency Graph"
            description="Visualise modifier sources and stat relationships as an interactive node graph."
            icon={<IconGraph />}
            glowClass="glow-blue"
          />
          <QuickNavCard
            to="/simulator"
            title="Scenario Simulator"
            description="Configure a loadout and run Monte Carlo simulations to stress-test damage and block values."
            icon={<IconSimulator />}
            glowClass="glow-cyan"
          />
        </div>
      </section>
    </div>
  )
}
