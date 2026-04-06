import { useState, useMemo } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useCards } from '../hooks/useApi'
import type { Card, CardType, CardTag } from '../types'

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const TYPE_COLORS: Record<CardType, { bg: string; border: string; glow: string; text: string; strip: string }> = {
  ATTACK: {
    bg: 'from-red-950/80 to-red-900/40',
    border: 'border-red-700/50',
    glow: 'shadow-[0_0_12px_rgba(239,68,68,0.25)]',
    text: 'text-red-300',
    strip: 'bg-red-600',
  },
  SKILL: {
    bg: 'from-blue-950/80 to-blue-900/40',
    border: 'border-blue-700/50',
    glow: 'shadow-[0_0_12px_rgba(59,130,246,0.25)]',
    text: 'text-blue-300',
    strip: 'bg-blue-600',
  },
  POWER: {
    bg: 'from-amber-950/80 to-amber-900/40',
    border: 'border-amber-700/50',
    glow: 'shadow-[0_0_12px_rgba(245,158,11,0.25)]',
    text: 'text-amber-300',
    strip: 'bg-amber-600',
  },
  STATUS: {
    bg: 'from-gray-800/80 to-gray-700/40',
    border: 'border-gray-600/50',
    glow: 'shadow-[0_0_12px_rgba(156,163,175,0.15)]',
    text: 'text-gray-300',
    strip: 'bg-gray-500',
  },
  CURSE: {
    bg: 'from-purple-950/80 to-purple-900/40',
    border: 'border-purple-700/50',
    glow: 'shadow-[0_0_12px_rgba(168,85,247,0.25)]',
    text: 'text-purple-300',
    strip: 'bg-purple-600',
  },
}

const TAG_BADGE: Record<CardTag, string> = {
  MELEE:   'bg-orange-900/60 text-orange-300 border-orange-700/30',
  RANGED:  'bg-cyan-900/60 text-cyan-300 border-cyan-700/30',
  FIRE:    'bg-red-900/60 text-red-300 border-red-700/30',
  ICE:     'bg-sky-900/60 text-sky-300 border-sky-700/30',
  HOLY:    'bg-yellow-800/60 text-yellow-200 border-yellow-600/30',
  SHADOW:  'bg-violet-900/60 text-violet-300 border-violet-700/30',
  TECH:    'bg-teal-900/60 text-teal-300 border-teal-700/30',
  EXPLOIT: 'bg-pink-900/60 text-pink-300 border-pink-700/30',
  CURSE:   'bg-purple-900/60 text-purple-300 border-purple-700/30',
}

// ---------------------------------------------------------------------------
// Sub-components
// ---------------------------------------------------------------------------

function GameCard({ card, selected, onClick }: { card: Card; selected: boolean; onClick: () => void }) {
  const colors = TYPE_COLORS[card.card_type] ?? TYPE_COLORS.SKILL
  const [imgLoaded, setImgLoaded] = useState(false)
  const [imgError, setImgError] = useState(false)

  return (
    <button
      onClick={onClick}
      className={[
        'group relative flex flex-col rounded-xl overflow-hidden border-2 transition-all duration-200 cursor-pointer w-[160px] shrink-0',
        `bg-gradient-to-b ${colors.bg} ${colors.border}`,
        selected ? `${colors.glow} ring-2 ring-white/20 scale-[1.03]` : 'hover:scale-[1.03]',
      ].join(' ')}
    >
      {/* Energy cost orb */}
      <div className={`absolute top-1.5 left-1.5 z-10 w-7 h-7 rounded-full flex items-center justify-center text-sm font-bold text-white border-2 ${colors.border} bg-black/70`}>
        {card.energy_cost}
      </div>

      {/* Card art area — 2:3 portrait ratio to match 512x768 source art */}
      <div className="relative w-full aspect-[2/3] bg-black/30 overflow-hidden">
        {!imgError && (
          <img
            src={`/api/card-art/${card.id}`}
            alt=""
            loading="lazy"
            onLoad={() => setImgLoaded(true)}
            onError={() => setImgError(true)}
            className={`w-full h-full object-contain transition-opacity duration-300 ${imgLoaded ? 'opacity-100' : 'opacity-0'}`}
          />
        )}
        {(!imgLoaded || imgError) && (
          <div className="absolute inset-0 flex items-center justify-center">
            <span className={`text-3xl opacity-20 ${colors.text}`}>
              {card.card_type === 'ATTACK' ? '\u2694' : card.card_type === 'SKILL' ? '\u26E8' : card.card_type === 'POWER' ? '\u2B50' : '\u2620'}
            </span>
          </div>
        )}
        {/* Type strip */}
        <div className={`absolute bottom-0 left-0 right-0 h-[3px] ${colors.strip}`} />
      </div>

      {/* Card info */}
      <div className="flex flex-col gap-1 px-2.5 py-2 flex-1">
        <span className={`text-xs font-bold leading-tight line-clamp-1 ${colors.text}`}>
          {card.display_name}
        </span>

        {/* Stats row */}
        <div className="flex items-center gap-1.5 flex-wrap">
          {card.damage > 0 && (
            <span className="text-[10px] font-mono text-red-400">
              {card.damage}{card.hits > 1 ? `x${card.hits}` : ''} dmg
            </span>
          )}
          {card.block > 0 && (
            <span className="text-[10px] font-mono text-blue-400">{card.block} blk</span>
          )}
          {card.heal > 0 && (
            <span className="text-[10px] font-mono text-green-400">{card.heal} heal</span>
          )}
          {card.draw > 0 && (
            <span className="text-[10px] font-mono text-yellow-400">+{card.draw} draw</span>
          )}
        </div>

        {/* Description */}
        <p className="text-[9px] text-gray-400 leading-tight line-clamp-2 mt-auto">
          {card.description}
        </p>
      </div>

      {/* Exhaust / Sockets badge row */}
      <div className="flex items-center gap-1 px-2 pb-1.5">
        {card.exhaust && (
          <span className="text-[8px] font-semibold uppercase text-red-400/70 tracking-wider">Exhaust</span>
        )}
        {card.gem_sockets > 0 && (
          <span className="text-[8px] font-semibold text-purple-400/70 ml-auto">
            {Array.from({ length: card.gem_sockets }, () => '\u25C6').join('')}
          </span>
        )}
      </div>
    </button>
  )
}

function DetailPanel({ card }: { card: Card }) {
  const colors = TYPE_COLORS[card.card_type] ?? TYPE_COLORS.SKILL
  const [imgLoaded, setImgLoaded] = useState(false)
  const [imgError, setImgError] = useState(false)

  const dpe = card.damage > 0 ? (card.damage * card.hits) / Math.max(card.energy_cost, 1) : 0
  const bpe = card.block > 0 ? card.block / Math.max(card.energy_cost, 1) : 0
  const totalDmg = card.damage * card.hits

  return (
    <div className={`panel p-5 flex flex-col gap-4 border-2 ${colors.border}`}>
      {/* Large art — 2:3 portrait to show full illustration */}
      <div className="relative w-full aspect-[2/3] rounded-lg overflow-hidden bg-black/40">
        {!imgError && (
          <img
            src={`/api/card-art/${card.id}`}
            alt={card.display_name}
            onLoad={() => setImgLoaded(true)}
            onError={() => setImgError(true)}
            className={`w-full h-full object-contain transition-opacity duration-300 ${imgLoaded ? 'opacity-100' : 'opacity-0'}`}
          />
        )}
        {(!imgLoaded || imgError) && (
          <div className="absolute inset-0 flex items-center justify-center">
            <span className={`text-6xl opacity-20 ${colors.text}`}>
              {card.card_type === 'ATTACK' ? '\u2694' : card.card_type === 'SKILL' ? '\u26E8' : card.card_type === 'POWER' ? '\u2B50' : '\u2620'}
            </span>
          </div>
        )}
        {/* Type badge */}
        <span className={`absolute top-2 right-2 text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full border ${TAG_BADGE[card.card_type as CardTag] ?? 'bg-gray-800 text-gray-300'} bg-black/60`}>
          {card.card_type}
        </span>
        {/* Cost */}
        <div className={`absolute top-2 left-2 w-9 h-9 rounded-full flex items-center justify-center text-base font-extrabold text-white border-2 ${colors.border} bg-black/80`}>
          {card.energy_cost}
        </div>
      </div>

      {/* Name */}
      <div>
        <h3 className={`text-lg font-extrabold ${colors.text}`}>{card.display_name}</h3>
        <span className="text-xs text-gray-500 font-mono">{card.id}</span>
      </div>

      {/* Description */}
      <p className="text-sm text-gray-300 leading-relaxed">{card.description}</p>

      {/* Stat grid */}
      <div className="grid grid-cols-2 gap-x-4 gap-y-2">
        {card.damage > 0 && (
          <StatRow label="Damage" value={`${card.damage}${card.hits > 1 ? ` x ${card.hits} = ${totalDmg}` : ''}`} color="text-red-400" />
        )}
        {card.block > 0 && (
          <StatRow label="Block" value={String(card.block)} color="text-blue-400" />
        )}
        {card.heal > 0 && (
          <StatRow label="Heal" value={String(card.heal)} color="text-green-400" />
        )}
        {card.draw > 0 && (
          <StatRow label="Draw" value={`+${card.draw}`} color="text-yellow-400" />
        )}
        {card.apply_vulnerable > 0 && (
          <StatRow label="Vulnerable" value={String(card.apply_vulnerable)} color="text-orange-400" />
        )}
        {card.apply_weak > 0 && (
          <StatRow label="Weak" value={String(card.apply_weak)} color="text-orange-400" />
        )}
        {card.gain_strength > 0 && (
          <StatRow label="Strength" value={`+${card.gain_strength}`} color="text-red-300" />
        )}
        {card.gain_dexterity > 0 && (
          <StatRow label="Dexterity" value={`+${card.gain_dexterity}`} color="text-blue-300" />
        )}
        {card.corruption_gain > 0 && (
          <StatRow label="Corruption" value={`+${card.corruption_gain}`} color="text-purple-400" />
        )}
      </div>

      {/* Efficiency */}
      {(dpe > 0 || bpe > 0) && (
        <div className="border-t border-white/[0.06] pt-3 flex gap-6">
          {dpe > 0 && (
            <div className="flex flex-col">
              <span className="text-[10px] uppercase tracking-wider text-gray-500 font-semibold">DPE</span>
              <span className={`text-lg font-bold font-mono ${dpe > 8 ? 'text-red-400' : 'text-gray-200'}`}>{dpe.toFixed(1)}</span>
            </div>
          )}
          {bpe > 0 && (
            <div className="flex flex-col">
              <span className="text-[10px] uppercase tracking-wider text-gray-500 font-semibold">BPE</span>
              <span className={`text-lg font-bold font-mono ${bpe > 8 ? 'text-red-400' : 'text-gray-200'}`}>{bpe.toFixed(1)}</span>
            </div>
          )}
        </div>
      )}

      {/* Tags */}
      {card.tags.length > 0 && (
        <div className="flex flex-wrap gap-1.5">
          {card.tags.map(tag => (
            <span
              key={tag}
              className={`inline-block rounded-full px-2.5 py-0.5 text-[10px] font-semibold border ${TAG_BADGE[tag] ?? 'bg-gray-800 text-gray-300'}`}
            >
              {tag}
            </span>
          ))}
        </div>
      )}

      {/* Footer chips */}
      <div className="flex items-center gap-2 text-[10px] text-gray-500">
        <span>Target: {card.target_type.replace(/_/g, ' ')}</span>
        {card.exhaust && <span className="text-red-400 font-semibold">EXHAUST</span>}
        {card.upgraded && <span className="text-green-400 font-semibold">UPGRADED</span>}
        {card.gem_sockets > 0 && (
          <span className="text-purple-400 font-semibold">
            {card.gem_sockets} socket{card.gem_sockets > 1 ? 's' : ''}
          </span>
        )}
      </div>
    </div>
  )
}

function StatRow({ label, value, color }: { label: string; value: string; color: string }) {
  return (
    <div className="flex items-baseline justify-between">
      <span className="text-xs text-gray-500">{label}</span>
      <span className={`text-sm font-bold font-mono ${color}`}>{value}</span>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Filter bar
// ---------------------------------------------------------------------------

const ALL_TYPES: CardType[] = ['ATTACK', 'SKILL', 'POWER', 'STATUS', 'CURSE']

type SortKey = 'name' | 'cost' | 'damage' | 'block' | 'dpe' | 'bpe'

function sortCards(cards: Card[], key: SortKey): Card[] {
  const sorted = [...cards]
  switch (key) {
    case 'name':
      sorted.sort((a, b) => a.display_name.localeCompare(b.display_name))
      break
    case 'cost':
      sorted.sort((a, b) => a.energy_cost - b.energy_cost)
      break
    case 'damage':
      sorted.sort((a, b) => (b.damage * b.hits) - (a.damage * a.hits))
      break
    case 'block':
      sorted.sort((a, b) => b.block - a.block)
      break
    case 'dpe':
      sorted.sort((a, b) => {
        const da = a.damage > 0 ? (a.damage * a.hits) / Math.max(a.energy_cost, 1) : 0
        const db = b.damage > 0 ? (b.damage * b.hits) / Math.max(b.energy_cost, 1) : 0
        return db - da
      })
      break
    case 'bpe':
      sorted.sort((a, b) => {
        const ba = a.block > 0 ? a.block / Math.max(a.energy_cost, 1) : 0
        const bb = b.block > 0 ? b.block / Math.max(b.energy_cost, 1) : 0
        return bb - ba
      })
      break
  }
  return sorted
}

// ---------------------------------------------------------------------------
// Main page
// ---------------------------------------------------------------------------

export default function CardGallery() {
  const { data, loading, error } = useCards()
  const [searchParams] = useSearchParams()

  const [search, setSearch] = useState('')
  const [typeFilter, setTypeFilter] = useState<CardType | 'ALL'>(
    (searchParams.get('type') as CardType) ?? 'ALL'
  )
  const [sort, setSort] = useState<SortKey>('name')
  const [selectedId, setSelectedId] = useState<string | null>(null)

  const filtered = useMemo(() => {
    if (!data) return []
    let cards = data

    if (search) {
      const q = search.toLowerCase()
      cards = cards.filter(c =>
        c.display_name.toLowerCase().includes(q) ||
        c.id.toLowerCase().includes(q) ||
        c.description.toLowerCase().includes(q)
      )
    }

    if (typeFilter !== 'ALL') {
      cards = cards.filter(c => c.card_type === typeFilter)
    }

    return sortCards(cards, sort)
  }, [data, search, typeFilter, sort])

  const selectedCard = useMemo(
    () => filtered.find(c => c.id === selectedId) ?? null,
    [filtered, selectedId]
  )

  if (loading) {
    return (
      <div className="flex items-center justify-center flex-1">
        <div className="text-gray-500 text-sm animate-pulse">Loading cards...</div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="flex items-center justify-center flex-1">
        <div className="text-red-400 text-sm">Error: {error}</div>
      </div>
    )
  }

  return (
    <div className="flex flex-col flex-1 min-h-0">
      {/* Header */}
      <div className="px-6 pt-6 pb-5 gradient-header shrink-0">
        <h1 className="text-2xl font-bold text-gray-100 mb-1">Card Gallery</h1>
        <p className="text-sm text-gray-400 mb-5">
          {filtered.length} card{filtered.length !== 1 ? 's' : ''} {typeFilter !== 'ALL' ? `(${typeFilter})` : ''} — click any card to inspect
        </p>

        {/* Filter bar */}
        <div className="flex items-center gap-3 flex-wrap">
          {/* Search */}
          <input
            type="text"
            placeholder="Search name, id, or description..."
            value={search}
            onChange={e => setSearch(e.target.value)}
            className="bg-[var(--bg-elevated)] border border-white/[0.08] rounded-lg px-3 py-1.5 text-sm text-gray-200 placeholder:text-gray-600 focus:outline-none focus:border-purple-600/50 w-64"
          />

          {/* Type pills */}
          <div className="flex gap-1.5">
            <FilterPill active={typeFilter === 'ALL'} onClick={() => setTypeFilter('ALL')}>All</FilterPill>
            {ALL_TYPES.map(t => (
              <FilterPill key={t} active={typeFilter === t} onClick={() => setTypeFilter(t)}>
                {t}
              </FilterPill>
            ))}
          </div>

          {/* Sort */}
          <select
            value={sort}
            onChange={e => setSort(e.target.value as SortKey)}
            className="bg-[var(--bg-elevated)] border border-white/[0.08] rounded-lg px-3 py-1.5 text-sm text-gray-300 focus:outline-none focus:border-purple-600/50 ml-auto"
          >
            <option value="name">Sort: Name</option>
            <option value="cost">Sort: Cost</option>
            <option value="damage">Sort: Damage</option>
            <option value="block">Sort: Block</option>
            <option value="dpe">Sort: DPE</option>
            <option value="bpe">Sort: BPE</option>
          </select>
        </div>
      </div>

      {/* Body: grid + detail */}
      <div className="flex flex-1 min-h-0 overflow-hidden">
        {/* Card grid */}
        <div className="flex-1 overflow-y-auto p-6">
          <div className="flex flex-wrap gap-4 content-start">
            {filtered.map(card => (
              <GameCard
                key={card.id}
                card={card}
                selected={card.id === selectedId}
                onClick={() => setSelectedId(prev => prev === card.id ? null : card.id)}
              />
            ))}
            {filtered.length === 0 && (
              <div className="text-gray-500 text-sm py-12 w-full text-center">
                No cards match your filters.
              </div>
            )}
          </div>
        </div>

        {/* Detail sidebar */}
        {selectedCard && (
          <div className="w-[340px] shrink-0 border-l border-white/[0.06] overflow-y-auto bg-[var(--bg-base)]">
            <div className="p-4">
              <div className="flex items-center justify-between mb-3">
                <span className="text-[10px] uppercase tracking-widest text-gray-500 font-semibold">Card Detail</span>
                <button
                  onClick={() => setSelectedId(null)}
                  className="text-gray-500 hover:text-gray-300 text-sm"
                >
                  {'\u2715'}
                </button>
              </div>
              <DetailPanel card={selectedCard} />
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

function FilterPill({ active, onClick, children }: { active: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <button
      onClick={onClick}
      className={[
        'px-3 py-1 text-xs font-medium rounded-full transition-all duration-200',
        active
          ? 'gradient-purple text-white glow-purple'
          : 'text-gray-400 hover:text-gray-200 hover:bg-[var(--bg-elevated)] border border-white/[0.06]',
      ].join(' ')}
    >
      {children}
    </button>
  )
}
