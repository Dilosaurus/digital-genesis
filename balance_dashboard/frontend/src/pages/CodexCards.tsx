import { useMemo, useState } from 'react'
import { useCards } from '../hooks/useCodex'
import { SectionHeader } from '../components/codex/SectionHeader'
import {
  FilterBar, FilterGroup, FilterChip, SearchInput,
} from '../components/codex/FilterBar'
import { CardTile } from '../components/codex/CardTile'
import {
  CARD_TYPE_ORDER, CARD_TYPE_COLORS, RARITY_ORDER, RARITY_COLORS,
  TAG_ORDER, TAG_COLORS, CHARACTER_COLORS,
} from '../lib/assets'
import type { Card, CardType, Rarity, CardTag } from '../types/game'

/**
 * /codex/cards — the full card catalog.
 *
 * Filters (all combinable):
 *   - search (display_name or description)
 *   - character class (-1 shared or 0..5)
 *   - card type
 *   - rarity
 *   - tag
 *   - energy cost bucket
 *   - has-art toggle
 *
 * Sort: by character class index, then by rarity, then alphabetical.
 */
export function CodexCards() {
  const { data: cards, isLoading, error } = useCards()

  const [search, setSearch] = useState('')
  const [classFilter, setClassFilter] = useState<number | null>(null)
  const [typeFilter, setTypeFilter] = useState<CardType | null>(null)
  const [rarityFilter, setRarityFilter] = useState<Rarity | null>(null)
  const [tagFilter, setTagFilter] = useState<CardTag | null>(null)
  const [costFilter, setCostFilter] = useState<number | null>(null)

  const filtered = useMemo(() => {
    if (!cards) return []
    const q = search.trim().toLowerCase()
    return cards
      .filter(c => {
        if (q && !c.display_name.toLowerCase().includes(q) && !c.description.toLowerCase().includes(q) && !c.id.toLowerCase().includes(q)) return false
        if (classFilter != null && c.character_class !== classFilter) return false
        if (typeFilter && c.card_type !== typeFilter) return false
        if (rarityFilter && c.rarity !== rarityFilter) return false
        if (tagFilter && !c.tags.includes(tagFilter)) return false
        if (costFilter != null) {
          if (costFilter === 3) {
            if (c.energy_cost < 3) return false
          } else if (c.energy_cost !== costFilter) return false
        }
        return true
      })
      .sort((a, b) => {
        if (a.character_class !== b.character_class) return a.character_class - b.character_class
        const rarityOrder = ['COMMON', 'UNCOMMON', 'RARE', 'LEGENDARY']
        const ar = rarityOrder.indexOf(a.rarity)
        const br = rarityOrder.indexOf(b.rarity)
        if (ar !== br) return ar - br
        return a.display_name.localeCompare(b.display_name)
      })
  }, [cards, search, classFilter, typeFilter, rarityFilter, tagFilter, costFilter])

  const clearAll = () => {
    setSearch('')
    setClassFilter(null)
    setTypeFilter(null)
    setRarityFilter(null)
    setTagFilter(null)
    setCostFilter(null)
  }

  const hasAny = search || classFilter != null || typeFilter || rarityFilter || tagFilter || costFilter != null

  return (
    <section className="relative pb-20">
      <SectionHeader
        chapter="II."
        heading="THE CATALOG"
        filename="codex/cards/"
        count={cards?.length ?? '—'}
        subtitle="every rite the crew can carry."
        rightSlot={
          <div
            className="font-mono text-[10px] uppercase hidden lg:block"
            style={{ color: 'var(--burnt-brass)', letterSpacing: '0.18em', textAlign: 'right' }}
          >
            sorted by
            <br />
            <span style={{ color: 'var(--bone-dim)' }}>
              class&nbsp;·&nbsp;rarity&nbsp;·&nbsp;name
            </span>
          </div>
        }
      />

      {/* ─── filter bar ─────────────────────────────────────────────── */}
      <div className="reveal reveal-3">
        <FilterBar
          counter={
            <>
              showing&nbsp;
              <span style={{ color: 'var(--halo)' }}>{filtered.length}</span>
              &nbsp;/&nbsp;
              <span style={{ color: 'var(--bone-dim)' }}>{cards?.length ?? 0}</span>
              {hasAny && (
                <>
                  &nbsp;·&nbsp;
                  <button
                    onClick={clearAll}
                    className="sacred-underline font-mono"
                    style={{ color: 'var(--blood-bright)' }}
                  >
                    clear
                  </button>
                </>
              )}
            </>
          }
        >
          <SearchInput value={search} onChange={setSearch} placeholder="name, desc, id..." />

          <FilterGroup label="class">
            {[-1, 0, 1, 2, 3, 4, 5].map(cls => {
              const info = CHARACTER_COLORS[cls]
              return (
                <FilterChip
                  key={cls}
                  label={info.code}
                  color={info.color}
                  active={classFilter === cls}
                  onClick={() => setClassFilter(classFilter === cls ? null : cls)}
                  size="xs"
                />
              )
            })}
          </FilterGroup>

          <FilterGroup label="type">
            {CARD_TYPE_ORDER.map(t => (
              <FilterChip
                key={t}
                label={t}
                color={CARD_TYPE_COLORS[t]}
                active={typeFilter === t}
                onClick={() => setTypeFilter(typeFilter === t ? null : t)}
                size="xs"
              />
            ))}
          </FilterGroup>

          <FilterGroup label="rarity">
            {RARITY_ORDER.map(r => (
              <FilterChip
                key={r}
                label={r}
                color={RARITY_COLORS[r].fg}
                active={rarityFilter === r}
                onClick={() => setRarityFilter(rarityFilter === r ? null : r)}
                size="xs"
              />
            ))}
          </FilterGroup>

          <FilterGroup label="cost">
            {[0, 1, 2, 3].map(cost => (
              <FilterChip
                key={cost}
                label={cost === 3 ? '3+' : String(cost)}
                active={costFilter === cost}
                onClick={() => setCostFilter(costFilter === cost ? null : cost)}
                size="xs"
              />
            ))}
          </FilterGroup>

          <FilterGroup label="tag">
            {TAG_ORDER.map(t => (
              <FilterChip
                key={t}
                label={t}
                color={TAG_COLORS[t]}
                active={tagFilter === t}
                onClick={() => setTagFilter(tagFilter === t ? null : t)}
                size="xs"
              />
            ))}
          </FilterGroup>
        </FilterBar>
      </div>

      {/* ─── status / error ─────────────────────────────────────────── */}
      {isLoading && <LoadingBlock />}
      {error && (
        <div
          className="mx-[clamp(1rem,6vw,6rem)] terminal-frame p-6 font-mono text-[12px]"
          style={{ color: 'var(--blood-bright)' }}
        >
          ERR · failed to load catalog: {String(error)}
        </div>
      )}

      {/* ─── grid ───────────────────────────────────────────────────── */}
      {cards && (
        <div
          className="reveal reveal-4 mx-[clamp(1rem,6vw,6rem)] grid gap-3 md:gap-5"
          style={{
            gridTemplateColumns: 'repeat(auto-fill, minmax(min(100%, 140px), 1fr))',
          }}
        >
          {filtered.map((card, i) => (
            <CardTile key={card.id} card={card} index={i + 1} />
          ))}
        </div>
      )}

      {/* ─── empty state ────────────────────────────────────────────── */}
      {cards && filtered.length === 0 && <EmptyState onClear={clearAll} />}
    </section>
  )
}

function LoadingBlock() {
  return (
    <div
      className="mx-[clamp(1rem,6vw,6rem)] terminal-frame p-6 font-mono text-[12px]"
      style={{ color: 'var(--bone-faint)' }}
    >
      <span className="prompt" />&nbsp;parsing codex/cards/*.tres
      <span className="caret" />
    </div>
  )
}

function EmptyState({ onClear }: { onClear: () => void }) {
  return (
    <div
      className="mx-[clamp(1rem,6vw,6rem)] terminal-frame p-8 text-center"
      style={{ color: 'var(--bone-dim)' }}
    >
      <div
        className="font-mono text-[11px] mb-2"
        style={{ color: 'var(--blood-bright)', letterSpacing: '0.18em' }}
      >
        NO MATCHES — CATALOG EMPTY UNDER CURRENT FILTERS
      </div>
      <p style={{ fontFamily: 'var(--font-body)', fontStyle: 'italic', fontSize: 15 }}>
        Every card in the codex has been hidden by your predicates.
      </p>
      <button
        onClick={onClear}
        className="mt-4 font-mono text-[11px] uppercase sacred-underline"
        style={{ color: 'var(--oxidized-gold)', letterSpacing: '0.14em' }}
      >
        $ clear all filters
      </button>
    </div>
  )
}
