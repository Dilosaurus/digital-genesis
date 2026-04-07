import { useMemo, useState } from 'react'
import { useEnemies } from '../hooks/useCodex'
import { SectionHeader } from '../components/codex/SectionHeader'
import { FilterBar, SearchInput, FilterGroup, FilterChip } from '../components/codex/FilterBar'
import { resolveAsset } from '../lib/assets'
import type { Enemy, EnemyIntentType } from '../types/game'

/**
 * Heuristic: is this enemy a boss? Bosses have phases, more HP, and named
 * display_names in caps. We fall back to "has phases".
 */
function isBoss(e: Enemy): boolean {
  return (e.phases?.length ?? 0) > 0 || e.max_hp >= 250
}

/**
 * Heuristic act grouping. The current data doesn't tag enemies by act;
 * we bucket by HP as a crude proxy until the backend surfaces act.
 */
function act(e: Enemy): 1 | 2 | 3 | 'boss' {
  if (isBoss(e)) return 'boss'
  if (e.max_hp < 50) return 1
  if (e.max_hp < 120) return 2
  return 3
}

const ACT_LABELS: Record<1 | 2 | 3 | 'boss', { label: string; sub: string; color: string; chapter: string }> = {
  1:    { label: 'THE OUTER NEXUS',      sub: 'server farm · act i',      color: '#87C464', chapter: 'I.' },
  2:    { label: 'THE RIFT',              sub: 'neural cathedral · act ii', color: '#D9B05F', chapter: 'II.' },
  3:    { label: 'THE VOID CORE',        sub: 'deep nexus · act iii',      color: '#E633CC', chapter: 'III.' },
  boss: { label: 'ANGELIC PROCESSES',    sub: 'bosses · all acts',         color: '#B13340', chapter: '✚' },
}

const INTENT_COLORS: Record<EnemyIntentType, string> = {
  ATTACK:  '#B13340',
  DEFEND:  '#33D9F2',
  BUFF:    '#F5E6A8',
  DEBUFF:  '#E633CC',
  HACK:    '#87C464',
  UNKNOWN: '#7F6640',
}

export function CodexEnemies() {
  const { data: enemies, isLoading, error } = useEnemies()
  const [search, setSearch] = useState('')
  const [actFilter, setActFilter] = useState<1 | 2 | 3 | 'boss' | null>(null)

  const grouped = useMemo(() => {
    if (!enemies) return []
    const q = search.trim().toLowerCase()
    const filtered = enemies.filter(e => {
      if (q && !e.display_name.toLowerCase().includes(q) && !e.description.toLowerCase().includes(q)) return false
      const a = act(e)
      if (actFilter && a !== actFilter) return false
      return true
    })
    const byAct = new Map<1 | 2 | 3 | 'boss', Enemy[]>()
    for (const e of filtered) {
      const a = act(e)
      if (!byAct.has(a)) byAct.set(a, [])
      byAct.get(a)!.push(e)
    }
    const order: (1 | 2 | 3 | 'boss')[] = [1, 2, 3, 'boss']
    return order
      .filter(a => byAct.has(a))
      .map(a => [a, byAct.get(a)!.sort((x, y) => x.max_hp - y.max_hp)] as const)
  }, [enemies, search, actFilter])

  return (
    <section className="relative pb-20">
      <SectionHeader
        chapter="VI."
        heading="THE BESTIARY"
        filename="codex/enemies.bst"
        count={enemies?.length ?? '—'}
        subtitle="processes hostile to the crew."
      />

      <div className="reveal reveal-3">
        <FilterBar
          counter={
            <>
              showing&nbsp;
              <span style={{ color: 'var(--halo)' }}>{grouped.reduce((a, [, items]) => a + items.length, 0)}</span>
              &nbsp;/&nbsp;
              <span style={{ color: 'var(--bone-dim)' }}>{enemies?.length ?? 0}</span>
            </>
          }
        >
          <SearchInput value={search} onChange={setSearch} />
          <FilterGroup label="act">
            {([1, 2, 3, 'boss'] as const).map(a => (
              <FilterChip
                key={String(a)}
                label={a === 'boss' ? 'BOSS' : `ACT ${a}`}
                color={ACT_LABELS[a].color}
                active={actFilter === a}
                onClick={() => setActFilter(actFilter === a ? null : a)}
                size="xs"
              />
            ))}
          </FilterGroup>
        </FilterBar>
      </div>

      {isLoading && (
        <div className="mx-[clamp(1rem,6vw,6rem)] terminal-frame p-6 font-mono text-[12px]" style={{ color: 'var(--bone-faint)' }}>
          <span className="prompt" />&nbsp;parsing codex/enemies/*.tres<span className="caret" />
        </div>
      )}
      {error && (
        <div className="mx-[clamp(1rem,6vw,6rem)] terminal-frame p-6 font-mono text-[12px]" style={{ color: 'var(--blood-bright)' }}>
          ERR · {String(error)}
        </div>
      )}

      <div className="reveal reveal-4 mx-[clamp(1rem,6vw,6rem)] space-y-12 md:space-y-16">
        {grouped.map(([actName, list]) => {
          const meta = ACT_LABELS[actName]
          return (
            <div key={String(actName)} className="min-w-0">
              <div className="flex items-baseline gap-3 md:gap-5 mb-5 md:mb-6 min-w-0">
                <div
                  className="shrink-0"
                  style={{
                    fontFamily: 'var(--font-display)',
                    fontSize: 'clamp(2.6rem, 11vw, 4rem)',
                    color: 'transparent',
                    WebkitTextStroke: `1.5px ${meta.color}`,
                    lineHeight: 0.85,
                    letterSpacing: 0,
                    marginLeft: '-0.05em',
                  }}
                >
                  {meta.chapter}
                </div>
                <div className="min-w-0 flex-1">
                  <div
                    style={{
                      fontFamily: 'var(--font-display)',
                      fontSize: 'clamp(1.35rem, 5.4vw, 2.6rem)',
                      color: 'var(--bone)',
                      letterSpacing: '0.1em',
                      fontWeight: 600,
                      textTransform: 'uppercase',
                      lineHeight: 1,
                      wordBreak: 'break-word',
                    }}
                  >
                    {meta.label}
                  </div>
                  <div
                    className="font-mono mt-1"
                    style={{ fontSize: 10, color: meta.color, letterSpacing: '0.1em' }}
                  >
                    {meta.sub}&nbsp;&nbsp;·&nbsp;&nbsp;{list.length} entries
                  </div>
                </div>
              </div>

              <div
                className="grid gap-4 md:gap-5"
                style={{
                  gridTemplateColumns:
                    actName === 'boss'
                      ? 'minmax(0, 1fr)'
                      : 'repeat(auto-fill, minmax(min(100%, 300px), 1fr))',
                }}
              >
                {list.map(e => (
                  <EnemyCard key={e.id} enemy={e} color={meta.color} />
                ))}
              </div>
            </div>
          )
        })}
      </div>
    </section>
  )
}

function EnemyCard({ enemy, color }: { enemy: Enemy; color: string }) {
  const art = resolveAsset(enemy.artwork)
  const boss = isBoss(enemy)
  // Unique intents in pool, with max value
  const intentSummary = new Map<EnemyIntentType, number>()
  for (const i of enemy.intent_pool ?? []) {
    const prev = intentSummary.get(i.intent as EnemyIntentType) ?? 0
    if (i.value > prev) intentSummary.set(i.intent as EnemyIntentType, i.value)
  }

  return (
    <div
      className="relative group min-w-0"
      style={{
        background: 'var(--server-rack)',
        border: '1px solid var(--burnt-brass)',
        boxShadow: 'inset 0 1px 0 rgba(235, 224, 200, 0.03), 0 1px 0 rgba(0, 0, 0, 0.4)',
      }}
    >
      <div
        className="absolute top-0 bottom-0 left-0 w-[3px] group-hover:w-[5px] transition-[width]"
        style={{ background: color }}
      />

      <div className="flex items-start gap-3 md:gap-4 p-4 md:p-5 pl-5 md:pl-6 min-w-0">
        {/* portrait */}
        <div
          className="shrink-0 overflow-hidden scanlines-soft relative"
          style={{
            width: boss ? 'clamp(80px, 22vw, 128px)' : 'clamp(64px, 18vw, 88px)',
            aspectRatio: '1 / 1',
            background: 'var(--void-deeper)',
            border: '1px solid var(--burnt-brass-dim)',
          }}
        >
          {art ? (
            <img src={art} alt="" className="w-full h-full object-cover" style={{ filter: 'contrast(1.05) saturate(0.95)' }} />
          ) : (
            <div className="w-full h-full flex items-center justify-center">
              <span
                style={{
                  fontFamily: 'var(--font-display)',
                  fontSize: boss ? 'clamp(36px, 10vw, 56px)' : 'clamp(28px, 8vw, 40px)',
                  color: 'var(--burnt-brass)',
                  lineHeight: 1,
                }}
              >
                ✸
              </span>
            </div>
          )}
        </div>

        <div className="flex-1 min-w-0">
          {/* name row */}
          <div className="flex items-start justify-between gap-2 mb-1">
            <div className="min-w-0 flex-1">
              <div
                style={{
                  fontFamily: 'var(--font-display)',
                  fontSize: boss ? 'clamp(15px, 4.4vw, 22px)' : 'clamp(13px, 3.8vw, 16px)',
                  letterSpacing: '0.05em',
                  color: 'var(--bone)',
                  fontWeight: 600,
                  textTransform: 'uppercase',
                  lineHeight: 1.1,
                  overflow: 'hidden',
                  display: '-webkit-box',
                  WebkitLineClamp: 2,
                  WebkitBoxOrient: 'vertical',
                  wordBreak: 'break-word',
                  overflowWrap: 'anywhere',
                }}
              >
                {enemy.display_name}
              </div>
              <div
                className="mt-[3px] font-mono truncate"
                style={{ fontSize: 9, color: 'var(--bone-faint)', letterSpacing: '0.12em' }}
              >
                {enemy.id}&nbsp;·&nbsp;{enemy.max_hp} HP&nbsp;·&nbsp;{enemy.xp_reward} XP
              </div>
            </div>
            {boss && (
              <span
                className="font-mono uppercase shrink-0"
                style={{
                  fontSize: 9,
                  letterSpacing: '0.16em',
                  color: '#B13340',
                  padding: '3px 6px',
                  border: '1px solid #B13340',
                }}
              >
                BOSS
              </span>
            )}
          </div>

          {/* description / lore */}
          <p
            className="mt-2"
            style={{
              fontFamily: 'var(--font-body)',
              fontSize: 14,
              lineHeight: 1.45,
              color: 'var(--bone-dim)',
              overflow: 'hidden',
              display: '-webkit-box',
              WebkitLineClamp: boss ? 4 : 3,
              WebkitBoxOrient: 'vertical',
              wordBreak: 'break-word',
              overflowWrap: 'anywhere',
            }}
          >
            {enemy.description || enemy.lore || '—'}
          </p>

          {/* intents row */}
          {intentSummary.size > 0 && (
            <div className="mt-3 flex flex-wrap gap-[6px]">
              {Array.from(intentSummary.entries()).map(([intent, value]) => (
                <span
                  key={intent}
                  className="inline-flex items-center gap-1 font-mono"
                  style={{
                    padding: '2px 6px',
                    fontSize: 9,
                    letterSpacing: '0.1em',
                    color: INTENT_COLORS[intent],
                    border: `1px solid ${INTENT_COLORS[intent]}`,
                    textTransform: 'uppercase',
                    whiteSpace: 'nowrap',
                  }}
                >
                  {intent}
                  {value ? <span style={{ color: 'var(--bone)', fontWeight: 500 }}>&nbsp;{value}</span> : null}
                </span>
              ))}
              {enemy.phases?.length > 0 && (
                <span
                  className="inline-flex items-center font-mono"
                  style={{
                    padding: '2px 6px',
                    fontSize: 9,
                    letterSpacing: '0.1em',
                    color: '#F5E6A8',
                    border: '1px solid #F5E6A8',
                    textTransform: 'uppercase',
                    whiteSpace: 'nowrap',
                  }}
                >
                  {enemy.phases.length}-PHASE
                </span>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
