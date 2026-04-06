import { useState, useMemo } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useEquipment, useGems, useRelics } from '../hooks/useApi'
import type { Equipment, Gem, Relic, EquipSlot, ModifierData } from '../types'

// ---------------------------------------------------------------------------
// Unified item wrapper — normalizes equipment/gem/relic into one browsable type
// ---------------------------------------------------------------------------

type ItemType = 'equipment' | 'gem' | 'relic'
type RarityLabel = 'COMMON' | 'UNCOMMON' | 'RARE'

interface UnifiedItem {
  id: string
  display_name: string
  description: string
  item_type: ItemType
  rarity: RarityLabel
  slot?: EquipSlot
  modifiers?: ModifierData[]
  // Relic-specific
  start_combat_strength?: number
  start_combat_dexterity?: number
  start_combat_block?: number
  bonus_draw?: number
  bonus_max_energy?: number
  bonus_max_hp?: number
  heal_on_combat_end?: number
  corruption_resistance?: number
}

function unifyEquipment(e: Equipment): UnifiedItem {
  return {
    id: e.id,
    display_name: e.display_name,
    description: e.description,
    item_type: 'equipment',
    rarity: (e.rarity?.toUpperCase() ?? 'COMMON') as RarityLabel,
    slot: e.slot,
    modifiers: e.modifiers,
  }
}

function unifyGem(g: Gem): UnifiedItem {
  return {
    id: g.id,
    display_name: g.display_name,
    description: g.description,
    item_type: 'gem',
    rarity: (g.rarity?.toUpperCase() ?? 'COMMON') as RarityLabel,
    modifiers: g.on_play_modifiers,
  }
}

function unifyRelic(r: Relic): UnifiedItem {
  return {
    id: r.id,
    display_name: r.display_name,
    description: r.description,
    item_type: 'relic',
    rarity: (r.rarity?.toUpperCase() ?? 'COMMON') as RarityLabel,
    start_combat_strength: r.start_combat_strength,
    start_combat_dexterity: r.start_combat_dexterity,
    start_combat_block: r.start_combat_block,
    bonus_draw: r.bonus_draw,
    bonus_max_energy: r.bonus_max_energy,
    bonus_max_hp: r.bonus_max_hp,
    heal_on_combat_end: r.heal_on_combat_end,
    corruption_resistance: r.corruption_resistance,
  }
}

// ---------------------------------------------------------------------------
// Color constants
// ---------------------------------------------------------------------------

const TYPE_COLORS: Record<ItemType, { bg: string; border: string; glow: string; text: string; strip: string; icon: string }> = {
  equipment: {
    bg: 'from-cyan-950/80 to-cyan-900/40',
    border: 'border-cyan-700/50',
    glow: 'shadow-[0_0_12px_rgba(6,182,212,0.25)]',
    text: 'text-cyan-300',
    strip: 'bg-cyan-600',
    icon: '\u2699',  // gear
  },
  gem: {
    bg: 'from-purple-950/80 to-purple-900/40',
    border: 'border-purple-700/50',
    glow: 'shadow-[0_0_12px_rgba(168,85,247,0.25)]',
    text: 'text-purple-300',
    strip: 'bg-purple-600',
    icon: '\u25C6',  // diamond
  },
  relic: {
    bg: 'from-amber-950/80 to-amber-900/40',
    border: 'border-amber-700/50',
    glow: 'shadow-[0_0_12px_rgba(245,158,11,0.25)]',
    text: 'text-amber-300',
    strip: 'bg-amber-600',
    icon: '\u2726',  // star
  },
}

const RARITY_COLORS: Record<RarityLabel, { badge: string; glow: string }> = {
  COMMON: {
    badge: 'bg-gray-800/60 text-gray-300 border-gray-600/30',
    glow: '',
  },
  UNCOMMON: {
    badge: 'bg-cyan-900/60 text-cyan-300 border-cyan-700/30',
    glow: 'shadow-[0_0_8px_rgba(6,182,212,0.15)]',
  },
  RARE: {
    badge: 'bg-amber-900/60 text-amber-300 border-amber-600/30',
    glow: 'shadow-[0_0_12px_rgba(245,158,11,0.3)]',
  },
}

const SLOT_BADGE: Record<EquipSlot, string> = {
  HEAD: 'bg-blue-900/60 text-blue-300 border-blue-700/30',
  CHEST: 'bg-green-900/60 text-green-300 border-green-700/30',
  WEAPON: 'bg-red-900/60 text-red-300 border-red-700/30',
  ACCESSORY: 'bg-pink-900/60 text-pink-300 border-pink-700/30',
}

const RARITY_ORDER: Record<RarityLabel, number> = { COMMON: 0, UNCOMMON: 1, RARE: 2 }

// ---------------------------------------------------------------------------
// Sub-components
// ---------------------------------------------------------------------------

function ItemCard({ item, selected, onClick }: { item: UnifiedItem; selected: boolean; onClick: () => void }) {
  const colors = TYPE_COLORS[item.item_type]
  const rarityColors = RARITY_COLORS[item.rarity]
  const [imgLoaded, setImgLoaded] = useState(false)
  const [imgError, setImgError] = useState(false)

  return (
    <button
      onClick={onClick}
      className={[
        'group relative flex flex-col rounded-xl overflow-hidden border-2 transition-all duration-200 cursor-pointer w-[160px] shrink-0',
        `bg-gradient-to-b ${colors.bg} ${colors.border}`,
        rarityColors.glow,
        selected ? `${colors.glow} ring-2 ring-white/20 scale-[1.03]` : 'hover:scale-[1.03]',
      ].join(' ')}
    >
      {/* Type icon orb */}
      <div className={`absolute top-1.5 left-1.5 z-10 w-7 h-7 rounded-full flex items-center justify-center text-sm font-bold text-white border-2 ${colors.border} bg-black/70`}>
        {colors.icon}
      </div>

      {/* Item art — 1:1 square ratio for 512x512 source art */}
      <div className="relative w-full aspect-square bg-black/30 overflow-hidden">
        {!imgError && (
          <img
            src={`/api/item-art/${item.id}`}
            alt=""
            loading="lazy"
            onLoad={() => setImgLoaded(true)}
            onError={() => setImgError(true)}
            className={`w-full h-full object-contain transition-opacity duration-300 ${imgLoaded ? 'opacity-100' : 'opacity-0'}`}
          />
        )}
        {(!imgLoaded || imgError) && (
          <div className="absolute inset-0 flex items-center justify-center">
            <span className={`text-3xl opacity-20 ${colors.text}`}>{colors.icon}</span>
          </div>
        )}
        {/* Type strip */}
        <div className={`absolute bottom-0 left-0 right-0 h-[3px] ${colors.strip}`} />
      </div>

      {/* Item info */}
      <div className="flex flex-col gap-1 px-2.5 py-2 flex-1">
        <span className={`text-xs font-bold leading-tight line-clamp-1 ${colors.text}`}>
          {item.display_name}
        </span>

        {/* Badges row */}
        <div className="flex items-center gap-1 flex-wrap">
          <span className={`inline-block rounded-full px-1.5 py-0 text-[8px] font-semibold border ${rarityColors.badge}`}>
            {item.rarity}
          </span>
          {item.slot && (
            <span className={`inline-block rounded-full px-1.5 py-0 text-[8px] font-semibold border ${SLOT_BADGE[item.slot]}`}>
              {item.slot}
            </span>
          )}
        </div>

        {/* Description */}
        <p className="text-[9px] text-gray-400 leading-tight line-clamp-2 mt-auto">
          {item.description}
        </p>
      </div>
    </button>
  )
}

function ItemDetailPanel({ item }: { item: UnifiedItem }) {
  const colors = TYPE_COLORS[item.item_type]
  const rarityColors = RARITY_COLORS[item.rarity]
  const [imgLoaded, setImgLoaded] = useState(false)
  const [imgError, setImgError] = useState(false)

  return (
    <div className={`panel p-5 flex flex-col gap-4 border-2 ${colors.border}`}>
      {/* Large art — 1:1 square */}
      <div className="relative w-full aspect-square rounded-lg overflow-hidden bg-black/40">
        {!imgError && (
          <img
            src={`/api/item-art/${item.id}`}
            alt={item.display_name}
            onLoad={() => setImgLoaded(true)}
            onError={() => setImgError(true)}
            className={`w-full h-full object-contain transition-opacity duration-300 ${imgLoaded ? 'opacity-100' : 'opacity-0'}`}
          />
        )}
        {(!imgLoaded || imgError) && (
          <div className="absolute inset-0 flex items-center justify-center">
            <span className={`text-6xl opacity-20 ${colors.text}`}>{colors.icon}</span>
          </div>
        )}
        {/* Type badge */}
        <span className={`absolute top-2 right-2 text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full border bg-black/60 ${colors.text} ${colors.border}`}>
          {item.item_type}
        </span>
      </div>

      {/* Name */}
      <div>
        <h3 className={`text-lg font-extrabold ${colors.text}`}>{item.display_name}</h3>
        <span className="text-xs text-gray-500 font-mono">{item.id}</span>
      </div>

      {/* Badges */}
      <div className="flex flex-wrap gap-1.5">
        <span className={`inline-block rounded-full px-2.5 py-0.5 text-[10px] font-semibold border ${rarityColors.badge}`}>
          {item.rarity}
        </span>
        {item.slot && (
          <span className={`inline-block rounded-full px-2.5 py-0.5 text-[10px] font-semibold border ${SLOT_BADGE[item.slot]}`}>
            {item.slot}
          </span>
        )}
      </div>

      {/* Description */}
      <p className="text-sm text-gray-300 leading-relaxed">{item.description}</p>

      {/* Modifiers (equipment & gems) */}
      {item.modifiers && item.modifiers.length > 0 && (
        <div>
          <h4 className="text-[10px] uppercase tracking-widest text-gray-500 font-semibold mb-2">Modifiers</h4>
          <div className="flex flex-col gap-1.5">
            {item.modifiers.map((mod, i) => (
              <ModifierChip key={mod.id ?? i} mod={mod} />
            ))}
          </div>
        </div>
      )}

      {/* Relic bonuses */}
      {item.item_type === 'relic' && (
        <div>
          <h4 className="text-[10px] uppercase tracking-widest text-gray-500 font-semibold mb-2">Bonuses</h4>
          <div className="grid grid-cols-2 gap-x-4 gap-y-2">
            {item.start_combat_strength! > 0 && <StatRow label="Strength" value={`+${item.start_combat_strength}`} color="text-red-400" />}
            {item.start_combat_dexterity! > 0 && <StatRow label="Dexterity" value={`+${item.start_combat_dexterity}`} color="text-blue-400" />}
            {item.start_combat_block! > 0 && <StatRow label="Block" value={`+${item.start_combat_block}`} color="text-blue-300" />}
            {item.bonus_draw! > 0 && <StatRow label="Draw" value={`+${item.bonus_draw}`} color="text-yellow-400" />}
            {item.bonus_max_energy! > 0 && <StatRow label="Max Energy" value={`+${item.bonus_max_energy}`} color="text-amber-400" />}
            {item.bonus_max_hp! > 0 && <StatRow label="Max HP" value={`+${item.bonus_max_hp}`} color="text-green-400" />}
            {item.heal_on_combat_end! > 0 && <StatRow label="Heal on Win" value={`+${item.heal_on_combat_end}`} color="text-green-300" />}
            {item.corruption_resistance! > 0 && <StatRow label="Corruption Resist" value={`+${item.corruption_resistance}`} color="text-purple-400" />}
          </div>
        </div>
      )}
    </div>
  )
}

function ModifierChip({ mod }: { mod: ModifierData }) {
  const opLabel = mod.operation === 'FLAT_ADD' ? '+' : mod.operation === 'PERCENT_ADD' ? '+%' : mod.operation === 'PERCENT_MULT' ? 'x' : '='
  const valueStr = mod.operation === 'PERCENT_ADD'
    ? `${(mod.value * 100).toFixed(0)}%`
    : mod.operation === 'PERCENT_MULT'
      ? `${mod.value.toFixed(2)}x`
      : `${mod.value}`

  return (
    <div className="flex items-center gap-2 px-2.5 py-1.5 rounded-lg bg-black/30 border border-white/[0.06]">
      <span className="text-[10px] font-mono text-purple-400">{opLabel}</span>
      <span className="text-xs text-gray-200">{valueStr} {mod.stat}</span>
      <span className="text-[9px] text-gray-500 ml-auto">{mod.lifecycle}</span>
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

const ALL_TYPES: ItemType[] = ['equipment', 'gem', 'relic']
const ALL_RARITIES: RarityLabel[] = ['COMMON', 'UNCOMMON', 'RARE']
const ALL_SLOTS: EquipSlot[] = ['HEAD', 'CHEST', 'WEAPON', 'ACCESSORY']

type SortKey = 'name' | 'rarity' | 'type'

function sortItems(items: UnifiedItem[], key: SortKey): UnifiedItem[] {
  const sorted = [...items]
  switch (key) {
    case 'name':
      sorted.sort((a, b) => a.display_name.localeCompare(b.display_name))
      break
    case 'rarity':
      sorted.sort((a, b) => RARITY_ORDER[b.rarity] - RARITY_ORDER[a.rarity])
      break
    case 'type':
      sorted.sort((a, b) => a.item_type.localeCompare(b.item_type))
      break
  }
  return sorted
}

// ---------------------------------------------------------------------------
// Main page
// ---------------------------------------------------------------------------

export default function ItemGallery() {
  const { data: equipment, loading: loadEq } = useEquipment()
  const { data: gems, loading: loadGem } = useGems()
  const { data: relics, loading: loadRelic } = useRelics()

  const [searchParams] = useSearchParams()

  const [search, setSearch] = useState('')
  const [typeFilter, setTypeFilter] = useState<ItemType | 'ALL'>(
    (searchParams.get('type') as ItemType) ?? 'ALL'
  )
  const [rarityFilter, setRarityFilter] = useState<RarityLabel | 'ALL'>('ALL')
  const [slotFilter, setSlotFilter] = useState<EquipSlot | 'ALL'>('ALL')
  const [sort, setSort] = useState<SortKey>('name')
  const [selectedId, setSelectedId] = useState<string | null>(null)

  const loading = loadEq || loadGem || loadRelic

  // Merge all items into unified list
  const allItems = useMemo(() => {
    const items: UnifiedItem[] = []
    if (equipment) items.push(...equipment.map(unifyEquipment))
    if (gems) items.push(...gems.map(unifyGem))
    if (relics) items.push(...relics.map(unifyRelic))
    return items
  }, [equipment, gems, relics])

  // Apply filters
  const filtered = useMemo(() => {
    let items = allItems

    if (search) {
      const q = search.toLowerCase()
      items = items.filter(i =>
        i.display_name.toLowerCase().includes(q) ||
        i.id.toLowerCase().includes(q) ||
        i.description.toLowerCase().includes(q)
      )
    }

    if (typeFilter !== 'ALL') {
      items = items.filter(i => i.item_type === typeFilter)
    }

    if (rarityFilter !== 'ALL') {
      items = items.filter(i => i.rarity === rarityFilter)
    }

    if (slotFilter !== 'ALL') {
      items = items.filter(i => i.slot === slotFilter)
    }

    return sortItems(items, sort)
  }, [allItems, search, typeFilter, rarityFilter, slotFilter, sort])

  const selectedItem = useMemo(
    () => filtered.find(i => i.id === selectedId) ?? null,
    [filtered, selectedId]
  )

  if (loading) {
    return (
      <div className="flex items-center justify-center flex-1">
        <div className="text-gray-500 text-sm animate-pulse">Loading items...</div>
      </div>
    )
  }

  return (
    <div className="flex flex-col flex-1 min-h-0">
      {/* Header */}
      <div className="px-6 pt-6 pb-5 gradient-header shrink-0">
        <h1 className="text-2xl font-bold text-gray-100 mb-1">Item Gallery</h1>
        <p className="text-sm text-gray-400 mb-5">
          {filtered.length} item{filtered.length !== 1 ? 's' : ''}{' '}
          {typeFilter !== 'ALL' ? `(${typeFilter})` : ''} — click any item to inspect
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
            <FilterPill active={typeFilter === 'ALL'} onClick={() => { setTypeFilter('ALL'); setSlotFilter('ALL') }}>All</FilterPill>
            {ALL_TYPES.map(t => (
              <FilterPill key={t} active={typeFilter === t} onClick={() => { setTypeFilter(t); if (t !== 'equipment') setSlotFilter('ALL') }}>
                {t.charAt(0).toUpperCase() + t.slice(1)}
              </FilterPill>
            ))}
          </div>

          {/* Rarity pills */}
          <div className="flex gap-1.5">
            <FilterPill active={rarityFilter === 'ALL'} onClick={() => setRarityFilter('ALL')}>Any Rarity</FilterPill>
            {ALL_RARITIES.map(r => (
              <FilterPill key={r} active={rarityFilter === r} onClick={() => setRarityFilter(r)}>
                {r.charAt(0) + r.slice(1).toLowerCase()}
              </FilterPill>
            ))}
          </div>

          {/* Slot filter — only visible when equipment is selected */}
          {(typeFilter === 'equipment' || typeFilter === 'ALL') && (
            <div className="flex gap-1.5">
              <FilterPill active={slotFilter === 'ALL'} onClick={() => setSlotFilter('ALL')}>Any Slot</FilterPill>
              {ALL_SLOTS.map(s => (
                <FilterPill key={s} active={slotFilter === s} onClick={() => setSlotFilter(s)}>
                  {s}
                </FilterPill>
              ))}
            </div>
          )}

          {/* Sort */}
          <select
            value={sort}
            onChange={e => setSort(e.target.value as SortKey)}
            className="bg-[var(--bg-elevated)] border border-white/[0.08] rounded-lg px-3 py-1.5 text-sm text-gray-300 focus:outline-none focus:border-purple-600/50 ml-auto"
          >
            <option value="name">Sort: Name</option>
            <option value="rarity">Sort: Rarity</option>
            <option value="type">Sort: Type</option>
          </select>
        </div>
      </div>

      {/* Body: grid + detail */}
      <div className="flex flex-1 min-h-0 overflow-hidden">
        {/* Item grid */}
        <div className="flex-1 overflow-y-auto p-6">
          <div className="flex flex-wrap gap-4 content-start">
            {filtered.map(item => (
              <ItemCard
                key={item.id}
                item={item}
                selected={item.id === selectedId}
                onClick={() => setSelectedId(prev => prev === item.id ? null : item.id)}
              />
            ))}
            {filtered.length === 0 && (
              <div className="text-gray-500 text-sm py-12 w-full text-center">
                No items match your filters.
              </div>
            )}
          </div>
        </div>

        {/* Detail sidebar */}
        {selectedItem && (
          <div className="w-[340px] shrink-0 border-l border-white/[0.06] overflow-y-auto bg-[var(--bg-base)]">
            <div className="p-4">
              <div className="flex items-center justify-between mb-3">
                <span className="text-[10px] uppercase tracking-widest text-gray-500 font-semibold">Item Detail</span>
                <button
                  onClick={() => setSelectedId(null)}
                  className="text-gray-500 hover:text-gray-300 text-sm"
                >
                  {'\u2715'}
                </button>
              </div>
              <ItemDetailPanel item={selectedItem} />
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
