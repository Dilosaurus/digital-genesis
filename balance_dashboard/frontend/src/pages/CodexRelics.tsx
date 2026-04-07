import { useMemo, useState } from 'react'
import { useRelics } from '../hooks/useCodex'
import { SectionHeader } from '../components/codex/SectionHeader'
import { FilterBar, FilterChip, FilterGroup, SearchInput } from '../components/codex/FilterBar'
import { ItemTile } from '../components/codex/ItemTile'
import { RARITY_COLORS, RARITY_ORDER } from '../lib/assets'
import type { Rarity, Relic } from '../types/game'
import { withSign } from '../lib/format'

/**
 * /codex/relics — the relic catalog. Relics are passive effects that
 * persist across combats. Each relic has a handful of discrete bonus
 * fields rather than a modifier list.
 */
export function CodexRelics() {
  const { data: relics, isLoading, error } = useRelics()
  const [search, setSearch] = useState('')
  const [rarity, setRarity] = useState<Rarity | null>(null)

  const filtered = useMemo(() => {
    if (!relics) return []
    const q = search.trim().toLowerCase()
    return relics
      .filter(r => {
        if (q && !r.display_name.toLowerCase().includes(q) && !r.description.toLowerCase().includes(q)) return false
        if (rarity && r.rarity !== rarity) return false
        return true
      })
      .sort((a, b) => {
        const ro = ['COMMON', 'UNCOMMON', 'RARE', 'LEGENDARY']
        const d = ro.indexOf(a.rarity) - ro.indexOf(b.rarity)
        return d !== 0 ? d : a.display_name.localeCompare(b.display_name)
      })
  }, [relics, search, rarity])

  return (
    <section className="relative pb-20">
      <SectionHeader
        chapter="IV."
        heading="THE RELICS"
        filename="codex/relics/"
        count={relics?.length ?? '—'}
        subtitle="weight the pirate carries between rites."
      />

      <div className="reveal reveal-3">
        <FilterBar
          counter={
            <>
              showing&nbsp;<span style={{ color: 'var(--halo)' }}>{filtered.length}</span>
              &nbsp;/&nbsp;<span style={{ color: 'var(--bone-dim)' }}>{relics?.length ?? 0}</span>
            </>
          }
        >
          <SearchInput value={search} onChange={setSearch} />
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
          <span className="prompt" />&nbsp;parsing codex/relics/*.tres<span className="caret" />
        </div>
      )}
      {error && (
        <div className="mx-[clamp(1rem,6vw,6rem)] terminal-frame p-6 font-mono text-[12px]" style={{ color: 'var(--blood-bright)' }}>
          ERR · {String(error)}
        </div>
      )}

      <div
        className="reveal reveal-4 mx-[clamp(1rem,6vw,6rem)] grid gap-3 md:gap-4"
        style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(min(100%, 300px), 1fr))' }}
      >
        {filtered.map(r => (
          <ItemTile
            key={r.id}
            id={r.id}
            displayName={r.display_name}
            description={r.description}
            rarity={r.rarity}
            icon={r.icon}
            glyph="✚"
            accentColor="#D9B05F"
            footer={<RelicBonuses relic={r} />}
          />
        ))}
      </div>
    </section>
  )
}

function RelicBonuses({ relic }: { relic: Relic }) {
  const chips: { label: string; value: string; color: string }[] = []
  if (relic.start_combat_strength) chips.push({ label: 'Strength', value: withSign(relic.start_combat_strength), color: '#B13340' })
  if (relic.start_combat_dexterity) chips.push({ label: 'Dexterity', value: withSign(relic.start_combat_dexterity), color: '#33D9F2' })
  if (relic.start_combat_block) chips.push({ label: 'Start Block', value: `+${relic.start_combat_block}`, color: '#33D9F2' })
  if (relic.bonus_draw) chips.push({ label: 'Draw', value: `+${relic.bonus_draw}`, color: '#87C464' })
  if (relic.bonus_max_energy) chips.push({ label: 'Energy', value: `+${relic.bonus_max_energy}`, color: '#F2D94C' })
  if (relic.bonus_max_hp) chips.push({ label: 'Max HP', value: `+${relic.bonus_max_hp}`, color: '#F5E6A8' })
  if (relic.heal_on_combat_end) chips.push({ label: 'Post-combat Heal', value: `+${relic.heal_on_combat_end}`, color: '#F5E6A8' })
  if (relic.corruption_resistance) chips.push({ label: 'Corr. Resist', value: `${relic.corruption_resistance}`, color: '#5C1B7A' })
  if (relic.auto_revive) chips.push({ label: 'Auto-Revive', value: '✓', color: '#87C464' })
  if (chips.length === 0) return null
  return (
    <>
      {chips.map((c, i) => (
        <div
          key={i}
          className="flex items-center gap-2 font-mono"
          style={{
            padding: '5px 9px',
            background: 'rgba(217, 176, 95, 0.04)',
            border: '1px solid rgba(217, 176, 95, 0.18)',
            fontSize: 11,
          }}
        >
          <span
            className="uppercase"
            style={{ color: 'var(--bone-dim)', letterSpacing: '0.12em', fontSize: 9 }}
          >
            {c.label}
          </span>
          <span style={{ color: c.color, fontWeight: 500 }}>{c.value}</span>
        </div>
      ))}
    </>
  )
}
