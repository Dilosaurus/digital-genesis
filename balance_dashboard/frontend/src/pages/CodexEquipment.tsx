import { useMemo, useState } from 'react'
import { useEquipment } from '../hooks/useCodex'
import { SectionHeader } from '../components/codex/SectionHeader'
import { FilterBar, FilterChip, FilterGroup, SearchInput } from '../components/codex/FilterBar'
import { ItemTile } from '../components/codex/ItemTile'
import { ModifierChip } from '../components/codex/ModifierChip'
import { RARITY_COLORS, RARITY_ORDER, SLOT_ORDER, SLOT_GLYPH } from '../lib/assets'
import type { Rarity, EquipSlot, Equipment } from '../types/game'

const SLOT_COLORS: Record<EquipSlot, string> = {
  WEAPON:   '#B13340',
  ARMOR:    '#33D9F2',
  TRINKET:  '#F5E6A8',
  AMULET:   '#D9B05F',
  RING:     '#E633CC',
}

/**
 * /codex/equipment — wearable gear grouped by slot. Each piece carries
 * one or more Modifier sub-resources which are rendered as chips in the
 * footer.
 */
export function CodexEquipment() {
  const { data: items, isLoading, error } = useEquipment()
  const [search, setSearch] = useState('')
  const [rarity, setRarity] = useState<Rarity | null>(null)
  const [slot, setSlot] = useState<EquipSlot | null>(null)

  const grouped = useMemo(() => {
    if (!items) return []
    const q = search.trim().toLowerCase()
    const filtered = items.filter(e => {
      if (q && !e.display_name.toLowerCase().includes(q) && !e.description.toLowerCase().includes(q)) return false
      if (rarity && e.rarity !== rarity) return false
      if (slot && e.slot !== slot) return false
      return true
    })
    const bySlot = new Map<EquipSlot, Equipment[]>()
    for (const e of filtered) {
      if (!bySlot.has(e.slot)) bySlot.set(e.slot, [])
      bySlot.get(e.slot)!.push(e)
    }
    return SLOT_ORDER
      .filter(s => bySlot.has(s))
      .map(s => [s, bySlot.get(s)!] as const)
  }, [items, search, rarity, slot])

  return (
    <section className="relative pb-20">
      <SectionHeader
        chapter="V."
        heading="THE EQUIPMENT"
        filename="codex/equipment/"
        count={items?.length ?? '—'}
        subtitle="what the operator wears into the nexus."
      />

      <div className="reveal reveal-3">
        <FilterBar
          counter={
            <>
              showing&nbsp;
              <span style={{ color: 'var(--halo)' }}>{grouped.reduce((a, [, g]) => a + g.length, 0)}</span>
              &nbsp;/&nbsp;
              <span style={{ color: 'var(--bone-dim)' }}>{items?.length ?? 0}</span>
            </>
          }
        >
          <SearchInput value={search} onChange={setSearch} />
          <FilterGroup label="slot">
            {SLOT_ORDER.map(s => (
              <FilterChip
                key={s}
                label={s}
                color={SLOT_COLORS[s]}
                active={slot === s}
                onClick={() => setSlot(slot === s ? null : s)}
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
                active={rarity === r}
                onClick={() => setRarity(rarity === r ? null : r)}
                size="xs"
              />
            ))}
          </FilterGroup>
        </FilterBar>
      </div>

      {isLoading && (
        <div className="mx-[clamp(1rem,6vw,6rem)] terminal-frame p-6 font-mono text-[12px]" style={{ color: 'var(--bone-faint)' }}>
          <span className="prompt" />&nbsp;parsing codex/equipment/*.tres<span className="caret" />
        </div>
      )}
      {error && (
        <div className="mx-[clamp(1rem,6vw,6rem)] terminal-frame p-6 font-mono text-[12px]" style={{ color: 'var(--blood-bright)' }}>
          ERR · {String(error)}
        </div>
      )}

      <div className="reveal reveal-4 mx-[clamp(1rem,6vw,6rem)] space-y-14">
        {grouped.map(([slotName, gear]) => (
          <div key={slotName}>
            <div className="flex items-baseline gap-4 mb-5">
              <div
                style={{
                  fontFamily: 'var(--font-display)',
                  fontSize: 36,
                  color: SLOT_COLORS[slotName],
                  lineHeight: 1,
                  filter: `drop-shadow(0 0 8px ${SLOT_COLORS[slotName]}44)`,
                }}
              >
                {SLOT_GLYPH[slotName]}
              </div>
              <div>
                <div
                  style={{
                    fontFamily: 'var(--font-display)',
                    fontSize: 24,
                    color: 'var(--bone)',
                    letterSpacing: '0.14em',
                    fontWeight: 600,
                    textTransform: 'uppercase',
                  }}
                >
                  {slotName}
                </div>
                <div className="font-mono" style={{ fontSize: 10, color: 'var(--burnt-brass)', letterSpacing: '0.12em' }}>
                  slot/{slotName.toLowerCase()} · {gear.length}&nbsp;entries
                </div>
              </div>
            </div>

            <div
              className="grid gap-4"
              style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(min(100%, 320px), 1fr))' }}
            >
              {gear.map(e => (
                <ItemTile
                  key={e.id}
                  id={e.id}
                  displayName={e.display_name}
                  description={e.description}
                  rarity={e.rarity}
                  icon={e.icon}
                  glyph={SLOT_GLYPH[e.slot]}
                  accentColor={SLOT_COLORS[e.slot]}
                  topRightLabel={e.slot}
                  topRightColor={SLOT_COLORS[e.slot]}
                  footer={
                    e.modifiers.length > 0
                      ? e.modifiers.map((m, i) => <ModifierChip key={i} mod={m} />)
                      : null
                  }
                />
              ))}
            </div>
          </div>
        ))}
      </div>
    </section>
  )
}
