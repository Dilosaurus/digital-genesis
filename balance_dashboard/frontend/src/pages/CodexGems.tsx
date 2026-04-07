import { useMemo, useState } from 'react'
import { useGems } from '../hooks/useCodex'
import { SectionHeader } from '../components/codex/SectionHeader'
import { FilterBar, FilterGroup, FilterChip, SearchInput } from '../components/codex/FilterBar'
import { ItemTile } from '../components/codex/ItemTile'
import { ModifierChip } from '../components/codex/ModifierChip'
import { RARITY_COLORS, RARITY_ORDER } from '../lib/assets'
import type { Rarity, Gem } from '../types/game'

/**
 * Classify a gem into a functional tier based on its fields. The tiers
 * match the gem catalog design in SYSTEM_DESIGN.md:
 *   amplify    — adds raw stat via on_play_modifiers
 *   convert    — transforms stat (e.g. damage → heal)
 *   trigger    — reactive effect (trigger_event present)
 *   sustain    — heals / recovers
 *   corrupt    — corruption-related
 *   utility    — everything else
 */
function gemTier(g: Gem): 'amplify' | 'convert' | 'trigger' | 'sustain' | 'corrupt' | 'utility' {
  if (g.trigger_event && g.trigger_event !== '') return 'trigger'
  if (g.convert_damage_to_heal > 0) return 'convert'
  if (g.on_play_modifiers?.some(m => m.stat === 'HEAL')) return 'sustain'
  const hasCorruption = g.description?.toLowerCase().includes('corruption')
  if (hasCorruption) return 'corrupt'
  if (g.on_play_modifiers?.length > 0) return 'amplify'
  return 'utility'
}

const TIER_COLORS: Record<string, string> = {
  amplify:  '#D9B05F',
  convert:  '#33D9F2',
  trigger:  '#F2D94C',
  sustain:  '#87C464',
  corrupt:  '#5C1B7A',
  utility:  '#A89B7D',
}

const TIER_GLYPH: Record<string, string> = {
  amplify: '◆',
  convert: '⟐',
  trigger: '✦',
  sustain: '♥',
  corrupt: '⌬',
  utility: '⊹',
}

const TIER_ORDER = ['amplify', 'convert', 'trigger', 'sustain', 'corrupt', 'utility'] as const

export function CodexGems() {
  const { data: gems, isLoading, error } = useGems()
  const [search, setSearch] = useState('')
  const [rarity, setRarity] = useState<Rarity | null>(null)
  const [tier, setTier] = useState<string | null>(null)

  const grouped = useMemo(() => {
    if (!gems) return []
    const q = search.trim().toLowerCase()
    const filtered = gems.filter(g => {
      if (q && !g.display_name.toLowerCase().includes(q) && !g.description.toLowerCase().includes(q)) return false
      if (rarity && g.rarity !== rarity) return false
      const t = gemTier(g)
      if (tier && t !== tier) return false
      return true
    })
    const byTier = new Map<string, Gem[]>()
    for (const g of filtered) {
      const t = gemTier(g)
      if (!byTier.has(t)) byTier.set(t, [])
      byTier.get(t)!.push(g)
    }
    // Preserve TIER_ORDER
    return TIER_ORDER
      .filter(t => byTier.has(t))
      .map(t => [t, byTier.get(t)!] as const)
  }, [gems, search, rarity, tier])

  const clearAll = () => { setSearch(''); setRarity(null); setTier(null) }
  const hasAny = search || rarity || tier

  return (
    <section className="relative pb-20">
      <SectionHeader
        chapter="III."
        heading="THE GEMS"
        filename="codex/gems/"
        count={gems?.length ?? '—'}
        subtitle="sockets that bend the stack."
      />

      <div className="reveal reveal-3">
        <FilterBar
          counter={
            <>
              showing&nbsp;
              <span style={{ color: 'var(--halo)' }}>{grouped.reduce((a, [_, items]) => a + items.length, 0)}</span>
              &nbsp;/&nbsp;
              <span style={{ color: 'var(--bone-dim)' }}>{gems?.length ?? 0}</span>
              {hasAny && (
                <>
                  &nbsp;·&nbsp;
                  <button onClick={clearAll} className="sacred-underline" style={{ color: 'var(--blood-bright)' }}>
                    clear
                  </button>
                </>
              )}
            </>
          }
        >
          <SearchInput value={search} onChange={setSearch} />
          <FilterGroup label="tier">
            {TIER_ORDER.map(t => (
              <FilterChip
                key={t}
                label={t.toUpperCase()}
                color={TIER_COLORS[t]}
                active={tier === t}
                onClick={() => setTier(tier === t ? null : t)}
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
          <span className="prompt" />&nbsp;parsing codex/gems/*.tres<span className="caret" />
        </div>
      )}
      {error && (
        <div className="mx-[clamp(1rem,6vw,6rem)] terminal-frame p-6 font-mono text-[12px]" style={{ color: 'var(--blood-bright)' }}>
          ERR · {String(error)}
        </div>
      )}

      {/* Grouped by tier */}
      <div className="reveal reveal-4 mx-[clamp(1rem,6vw,6rem)] space-y-10 md:space-y-14">
        {grouped.map(([tierName, items]) => (
          <TierSection
            key={tierName}
            tierName={tierName}
            items={items}
          />
        ))}
      </div>

      {gems && grouped.length === 0 && (
        <div
          className="mx-[clamp(1rem,6vw,6rem)] terminal-frame p-8 text-center"
          style={{ color: 'var(--bone-dim)' }}
        >
          <div className="font-mono text-[11px] mb-2" style={{ color: 'var(--blood-bright)', letterSpacing: '0.18em' }}>
            NO MATCHES
          </div>
          <p style={{ fontFamily: 'var(--font-body)', fontStyle: 'italic', fontSize: 15 }}>
            The jeweller has no gems under those constraints.
          </p>
        </div>
      )}
    </section>
  )
}

function TierSection({ tierName, items }: { tierName: string; items: Gem[] }) {
  const color = TIER_COLORS[tierName]
  const glyph = TIER_GLYPH[tierName]
  return (
    <div className="min-w-0">
      <div className="flex items-baseline gap-3 md:gap-4 mb-4 md:mb-5 min-w-0">
        <div
          className="shrink-0"
          style={{
            fontFamily: 'var(--font-display)',
            fontSize: 'clamp(28px, 8vw, 36px)',
            color,
            letterSpacing: 0,
            lineHeight: 1,
            filter: `drop-shadow(0 0 8px ${color}44)`,
          }}
        >
          {glyph}
        </div>
        <div className="min-w-0 flex-1">
          <div
            style={{
              fontFamily: 'var(--font-display)',
              fontSize: 'clamp(18px, 5.6vw, 24px)',
              color: 'var(--bone)',
              letterSpacing: '0.12em',
              fontWeight: 600,
              textTransform: 'uppercase',
              lineHeight: 1.1,
              wordBreak: 'break-word',
            }}
          >
            {tierName}
          </div>
          <div
            className="font-mono truncate"
            style={{ fontSize: 10, color: 'var(--burnt-brass)', letterSpacing: '0.1em' }}
          >
            tier/{tierName} · {items.length}&nbsp;entries
          </div>
        </div>
      </div>

      <div
        className="grid gap-3 md:gap-4"
        style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(min(100%, 300px), 1fr))' }}
      >
        {items.map(g => (
          <ItemTile
            key={g.id}
            id={g.id}
            displayName={g.display_name}
            description={g.description}
            rarity={g.rarity}
            icon={g.icon}
            glyph={glyph}
            accentColor={color}
            topRightLabel={tierName.toUpperCase()}
            topRightColor={color}
            footer={
              g.on_play_modifiers && g.on_play_modifiers.length > 0 ? (
                <>
                  {g.on_play_modifiers.map((m, i) => (
                    <ModifierChip key={i} mod={m} />
                  ))}
                </>
              ) : g.trigger_event ? (
                <div
                  className="font-mono text-[11px]"
                  style={{ color: 'var(--bone-faint)', letterSpacing: '0.02em' }}
                >
                  <span style={{ color: 'var(--oxidized-gold)' }}>on {g.trigger_event}:</span>&nbsp;
                  {g.trigger_effect} {g.trigger_value ? `(${g.trigger_value})` : ''}
                </div>
              ) : null
            }
          />
        ))}
      </div>
    </div>
  )
}
