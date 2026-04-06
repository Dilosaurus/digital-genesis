import { Fragment, useState, useMemo } from 'react'
import type { Loadout, SimulationResult, CardType } from '../../types'
import { useCards, useRelics, useEquipment, useGems, useSkillTree } from '../../hooks/useApi'
import { simulateDeck } from '../../utils/modifierPipeline'

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const CARD_TYPE_BADGE: Record<CardType, string> = {
  ATTACK: 'bg-gradient-to-r from-red-900/80 to-red-800/60 text-red-300 border border-red-700/30',
  SKILL: 'bg-gradient-to-r from-blue-900/80 to-blue-800/60 text-blue-300 border border-blue-700/30',
  POWER: 'bg-gradient-to-r from-purple-900/80 to-purple-800/60 text-purple-300 border border-purple-700/30',
  STATUS: 'bg-gradient-to-r from-gray-800/80 to-gray-700/60 text-gray-300 border border-gray-600/30',
  CURSE: 'bg-gradient-to-r from-yellow-900/80 to-yellow-800/60 text-yellow-300 border border-yellow-700/30',
}

// SVG chevron icon
function ChevronIcon({ expanded }: { expanded: boolean }) {
  return (
    <svg
      className={`w-3.5 h-3.5 text-gray-500 transition-transform ${expanded ? 'rotate-90' : ''}`}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      strokeWidth={2.5}
    >
      <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
    </svg>
  )
}

function StatDelta({
  base,
  final,
  label,
}: {
  base: number
  final: number
  label: string
}) {
  if (base === 0 && final === 0) return <span className="text-gray-600">--</span>

  const changed = final !== base
  const better = final > base

  return (
    <span className="inline-flex items-center gap-1 font-mono text-xs">
      <span className="text-gray-400">{base}</span>
      {changed && (
        <>
          <span className="text-gray-600">-&gt;</span>
          <span className={better ? 'text-green-400 font-semibold' : 'text-red-400 font-semibold'}>
            {final}
          </span>
        </>
      )}
      {!changed && <span className="text-gray-300">{final}</span>}
    </span>
  )
}

function formatOp(op: string, value: number): string {
  if (op === 'FLAT_ADD') return value >= 0 ? `+${value}` : `${value}`
  if (op === 'PERCENT_ADD') return `${value >= 0 ? '+' : ''}${(value * 100).toFixed(0)}%`
  if (op === 'PERCENT_MULT') return `x${value.toFixed(2)}`
  if (op === 'OVERRIDE') return `override -> ${value}`
  return String(value)
}

// ---------------------------------------------------------------------------
// Expanded breakdown panel
// ---------------------------------------------------------------------------

interface BreakdownPanelProps {
  result: SimulationResult
  vulnerableActive: boolean
  weakActive: boolean
}

function BreakdownPanel({ result, vulnerableActive, weakActive }: BreakdownPanelProps) {
  const hasDamage = result.base_damage > 0
  const hasBlock = result.base_block > 0
  const hasHeal = result.final_heal > 0

  function renderStatBreakdown(
    label: string,
    base: number,
    adjusted: number,
    flatAdds: SimulationResult['damage_flat_adds'],
    pctAdds: SimulationResult['damage_pct_adds'],
    pctMults: SimulationResult['damage_pct_mults'],
    final: number,
    isAttack: boolean,
  ) {
    let running = adjusted

    const rows: React.ReactNode[] = []

    rows.push(
      <div key="base" className="flex items-center gap-2 text-xs">
        <span className="w-1.5 h-1.5 rounded-full bg-gray-500 shrink-0" />
        <span className="text-gray-500 w-32">Base {label}</span>
        <span className="text-gray-400 font-mono">{base}</span>
      </div>,
    )

    if (adjusted !== base) {
      rows.push(
        <div key="adjusted" className="flex items-center gap-2 text-xs pl-3">
          <span className="w-1.5 h-1.5 rounded-full bg-blue-500 shrink-0" />
          <span className="text-gray-500 w-28">+ Stat bonus</span>
          <span className="text-blue-400 font-mono">+{adjusted - base} -&gt; {adjusted}</span>
        </div>,
      )
    }

    if (flatAdds.length > 0) {
      for (const contrib of flatAdds) {
        running += contrib.value
        rows.push(
          <div key={`flat-${contrib.source}`} className="flex items-center gap-2 text-xs pl-3">
            <span className="w-1.5 h-1.5 rounded-full bg-blue-400 shrink-0" />
            <span className="text-gray-500 w-28">+ Flat add</span>
            <span className="text-blue-400 font-mono">{contrib.value >= 0 ? '+' : ''}{contrib.value}</span>
            <span className="text-gray-600">from {contrib.source.replace(':', ': ')}</span>
            <span className="text-gray-400 font-mono ml-auto">-&gt; {running.toFixed(1)}</span>
          </div>,
        )
      }
    }

    if (pctAdds.length > 0) {
      for (const contrib of pctAdds) {
        const addAmount = adjusted * contrib.value
        running = running + addAmount
        rows.push(
          <div key={`pctadd-${contrib.source}`} className="flex items-center gap-2 text-xs pl-3">
            <span className="w-1.5 h-1.5 rounded-full bg-green-400 shrink-0" />
            <span className="text-gray-500 w-28">x Pct add</span>
            <span className="text-green-400 font-mono">{contrib.value >= 0 ? '+' : ''}{(contrib.value * 100).toFixed(0)}%</span>
            <span className="text-gray-600">from {contrib.source.replace(':', ': ')}</span>
            <span className="text-gray-400 font-mono ml-auto">-&gt; {running.toFixed(1)}</span>
          </div>,
        )
      }
    }

    if (pctMults.length > 0) {
      for (const contrib of pctMults) {
        running *= contrib.value
        rows.push(
          <div key={`pctmult-${contrib.source}`} className="flex items-center gap-2 text-xs pl-3">
            <span className="w-1.5 h-1.5 rounded-full bg-purple-400 shrink-0" />
            <span className="text-gray-500 w-28">x Pct mult</span>
            <span className="text-purple-400 font-mono">x{contrib.value.toFixed(2)}</span>
            <span className="text-gray-600">from {contrib.source.replace(':', ': ')}</span>
            <span className="text-gray-400 font-mono ml-auto">-&gt; {running.toFixed(1)}</span>
          </div>,
        )
      }
    }

    if (isAttack && vulnerableActive) {
      running *= 1.5
      rows.push(
        <div key="vulnerable" className="flex items-center gap-2 text-xs pl-3">
          <span className="w-1.5 h-1.5 rounded-full bg-yellow-400 shrink-0" />
          <span className="text-gray-500 w-28">x Vulnerable</span>
          <span className="text-yellow-400 font-mono">x1.5</span>
          <span className="text-gray-600">target vulnerable</span>
          <span className="text-gray-400 font-mono ml-auto">-&gt; {running.toFixed(1)}</span>
        </div>,
      )
    }

    if (isAttack && weakActive) {
      running *= 0.75
      rows.push(
        <div key="weak" className="flex items-center gap-2 text-xs pl-3">
          <span className="w-1.5 h-1.5 rounded-full bg-red-400 shrink-0" />
          <span className="text-gray-500 w-28">x Weak</span>
          <span className="text-red-400 font-mono">x0.75</span>
          <span className="text-gray-600">player weak</span>
          <span className="text-gray-400 font-mono ml-auto">-&gt; {running.toFixed(1)}</span>
        </div>,
      )
    }

    rows.push(
      <div key="final" className="flex items-center gap-2 text-xs border-t border-purple-500/20 pt-1.5 mt-1.5">
        <span className="w-1.5 h-1.5 rounded-full bg-white shrink-0" />
        <span className="text-gray-200 font-semibold w-32">Final {label}</span>
        <span className="text-white font-mono font-bold">{final}</span>
      </div>,
    )

    return (
      <div className="mb-3">
        <div className="text-xs text-gray-400 font-semibold uppercase tracking-wider mb-1.5">
          {label} Pipeline
        </div>
        <div className="flex flex-col gap-0.5 bg-[var(--bg-base)] rounded-lg p-3">{rows}</div>
      </div>
    )
  }

  return (
    <div className="px-4 py-3 bg-[var(--bg-base)] border-l-2 border-purple-500/30">
      {hasDamage &&
        renderStatBreakdown(
          'Damage',
          result.base_damage,
          result.adjusted_base_damage,
          result.damage_flat_adds,
          result.damage_pct_adds,
          result.damage_pct_mults,
          result.final_damage,
          true,
        )}
      {hasBlock &&
        renderStatBreakdown(
          'Block',
          result.base_block,
          result.adjusted_base_block,
          result.block_flat_adds,
          result.block_pct_adds,
          result.block_pct_mults,
          result.final_block,
          false,
        )}
      {hasHeal && (
        <div>
          <div className="text-xs text-gray-400 font-semibold uppercase tracking-wider mb-1.5">
            Heal
          </div>
          <div className="flex flex-col gap-0.5 bg-[var(--bg-base)] rounded-lg p-3">
            <div className="flex items-center gap-2 text-xs">
              <span className="w-1.5 h-1.5 rounded-full bg-green-400 shrink-0" />
              <span className="text-gray-200 font-semibold">Final Heal</span>
              <span className="text-white font-mono font-bold">{result.final_heal}</span>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

// ---------------------------------------------------------------------------
// Props
// ---------------------------------------------------------------------------

interface CardCalculatorProps {
  loadout: Loadout
}

// ---------------------------------------------------------------------------
// CardCalculator
// ---------------------------------------------------------------------------

export function CardCalculator({ loadout }: CardCalculatorProps) {
  const cardsApi = useCards()
  const relicsApi = useRelics()
  const equipmentApi = useEquipment()
  const gemsApi = useGems()
  const skillTreeApi = useSkillTree()

  const [expandedRows, setExpandedRows] = useState<Set<string>>(new Set())

  const loading =
    cardsApi.loading ||
    relicsApi.loading ||
    equipmentApi.loading ||
    gemsApi.loading ||
    skillTreeApi.loading

  const results = useMemo(() => {
    if (
      !cardsApi.data ||
      !relicsApi.data ||
      !equipmentApi.data ||
      !gemsApi.data ||
      !skillTreeApi.data
    ) {
      return []
    }
    return simulateDeck(
      cardsApi.data,
      loadout,
      relicsApi.data,
      equipmentApi.data,
      gemsApi.data,
      skillTreeApi.data,
    )
  }, [loadout, cardsApi.data, relicsApi.data, equipmentApi.data, gemsApi.data, skillTreeApi.data])

  function toggleRow(cardId: string) {
    setExpandedRows(prev => {
      const next = new Set(prev)
      if (next.has(cardId)) {
        next.delete(cardId)
      } else {
        next.add(cardId)
      }
      return next
    })
  }

  if (loading) {
    return <div className="text-sm text-gray-500 text-center py-6">Calculating...</div>
  }

  if (results.length === 0) {
    return (
      <div className="text-sm text-gray-500 text-center py-6">
        No card data available.
      </div>
    )
  }

  const cards = cardsApi.data ?? []

  return (
    <div className="overflow-x-auto panel rounded-xl">
      <table className="w-full text-sm border-collapse">
        <thead className="bg-[var(--bg-base)] sticky top-0 z-10">
          <tr>
            <th className="px-3 py-2.5 text-left text-xs font-semibold text-gray-400 uppercase tracking-wide whitespace-nowrap border-b border-purple-500/10 w-4" />
            <th className="px-3 py-2.5 text-left text-xs font-semibold text-gray-400 uppercase tracking-wide whitespace-nowrap border-b border-purple-500/10">
              Card
            </th>
            <th className="px-3 py-2.5 text-left text-xs font-semibold text-gray-400 uppercase tracking-wide whitespace-nowrap border-b border-purple-500/10">
              Type
            </th>
            <th className="px-3 py-2.5 text-center text-xs font-semibold text-gray-400 uppercase tracking-wide whitespace-nowrap border-b border-purple-500/10">
              Energy
            </th>
            <th className="px-3 py-2.5 text-center text-xs font-semibold text-gray-400 uppercase tracking-wide whitespace-nowrap border-b border-purple-500/10">
              Damage
            </th>
            <th className="px-3 py-2.5 text-center text-xs font-semibold text-gray-400 uppercase tracking-wide whitespace-nowrap border-b border-purple-500/10">
              Block
            </th>
            <th className="px-3 py-2.5 text-center text-xs font-semibold text-gray-400 uppercase tracking-wide whitespace-nowrap border-b border-purple-500/10">
              Heal
            </th>
            <th className="px-3 py-2.5 text-center text-xs font-semibold text-gray-400 uppercase tracking-wide whitespace-nowrap border-b border-purple-500/10">
              DPE
            </th>
          </tr>
        </thead>
        <tbody>
          {results.map((result, rowIndex) => {
            const card = cards.find(c => c.id === result.card_id)
            const cardType = card?.card_type ?? 'ATTACK'
            const expanded = expandedRows.has(result.card_id)
            const energyCost = card?.energy_cost ?? 1
            const dpe = energyCost > 0 ? (result.final_damage / energyCost).toFixed(1) : '--'

            return (
              <Fragment key={result.card_id}>
                <tr
                  onClick={() => toggleRow(result.card_id)}
                  className={[
                    'cursor-pointer border-b border-[var(--bg-elevated)] transition-all group',
                    expanded ? 'bg-[var(--bg-elevated)]' : 'hover:bg-[var(--bg-hover)]',
                  ].join(' ')}
                >
                  {/* Expand chevron */}
                  <td className="px-2 py-2 text-center select-none">
                    <ChevronIcon expanded={expanded} />
                  </td>

                  {/* Card name */}
                  <td className="px-3 py-2 text-gray-200 font-medium whitespace-nowrap border-l-2 border-transparent group-hover:border-purple-500/50">
                    {result.card_name}
                  </td>

                  {/* Type badge */}
                  <td className="px-3 py-2 whitespace-nowrap">
                    <span
                      className={[
                        'text-xs px-2 py-0.5 rounded-md font-semibold uppercase tracking-wide',
                        CARD_TYPE_BADGE[cardType],
                      ].join(' ')}
                    >
                      {cardType}
                    </span>
                  </td>

                  {/* Energy */}
                  <td className="px-3 py-2 text-center">
                    <span className="font-mono text-xs text-yellow-400">{energyCost}</span>
                  </td>

                  {/* Damage */}
                  <td className="px-3 py-2 text-center">
                    <StatDelta
                      base={result.base_damage}
                      final={result.final_damage}
                      label="dmg"
                    />
                  </td>

                  {/* Block */}
                  <td className="px-3 py-2 text-center">
                    <StatDelta
                      base={result.base_block}
                      final={result.final_block}
                      label="block"
                    />
                  </td>

                  {/* Heal */}
                  <td className="px-3 py-2 text-center">
                    <StatDelta
                      base={card?.heal ?? 0}
                      final={result.final_heal}
                      label="heal"
                    />
                  </td>

                  {/* DPE */}
                  <td className="px-3 py-2 text-center">
                    <span className="font-mono text-xs text-gray-300">{dpe}</span>
                  </td>
                </tr>

                {/* Expanded breakdown */}
                {expanded && (
                  <tr className="border-b border-[var(--bg-elevated)]">
                    <td colSpan={8} className="p-0">
                      <BreakdownPanel
                        result={result}
                        vulnerableActive={loadout.context.vulnerable}
                        weakActive={loadout.context.weak}
                      />
                    </td>
                  </tr>
                )}
              </Fragment>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}
