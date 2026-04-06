import { useMemo } from 'react'
import type { Loadout } from '../../types'
import { useSimulatorStore } from '../../stores/simulatorStore'
import { useCards, useRelics, useEquipment, useGems, useSkillTree } from '../../hooks/useApi'
import { simulateDeck } from '../../utils/modifierPipeline'
import { LoadoutPicker } from './LoadoutPicker'

// ---------------------------------------------------------------------------
// Delta cell
// ---------------------------------------------------------------------------

function DeltaCell({ a, b }: { a: number; b: number }) {
  const delta = b - a
  if (delta === 0) {
    return <span className="text-gray-500 font-mono text-xs">--</span>
  }
  const sign = delta > 0 ? '+' : ''
  const color = delta > 0 ? 'text-green-400' : 'text-red-400'
  return (
    <span className={['font-mono text-xs font-semibold', color].join(' ')}>
      {sign}{delta}
    </span>
  )
}

// ---------------------------------------------------------------------------
// ComparisonMode
// ---------------------------------------------------------------------------

export function ComparisonMode() {
  const { loadoutA, loadoutB, comparisonMode, toggleComparison, setLoadoutA, setLoadoutB } =
    useSimulatorStore()

  const cardsApi = useCards()
  const relicsApi = useRelics()
  const equipmentApi = useEquipment()
  const gemsApi = useGems()
  const skillTreeApi = useSkillTree()

  const ready =
    !cardsApi.loading &&
    !relicsApi.loading &&
    !equipmentApi.loading &&
    !gemsApi.loading &&
    !skillTreeApi.loading &&
    cardsApi.data != null

  const resultsA = useMemo(() => {
    if (!ready) return []
    return simulateDeck(
      cardsApi.data!,
      loadoutA,
      relicsApi.data!,
      equipmentApi.data!,
      gemsApi.data!,
      skillTreeApi.data!,
    )
  }, [loadoutA, ready, cardsApi.data, relicsApi.data, equipmentApi.data, gemsApi.data, skillTreeApi.data])

  const resultsB = useMemo(() => {
    if (!ready) return []
    return simulateDeck(
      cardsApi.data!,
      loadoutB,
      relicsApi.data!,
      equipmentApi.data!,
      gemsApi.data!,
      skillTreeApi.data!,
    )
  }, [loadoutB, ready, cardsApi.data, relicsApi.data, equipmentApi.data, gemsApi.data, skillTreeApi.data])

  // Build comparison rows aligned by card_id
  const comparisonRows = useMemo(() => {
    const mapA = new Map(resultsA.map(r => [r.card_id, r]))
    const mapB = new Map(resultsB.map(r => [r.card_id, r]))
    const allIds = Array.from(new Set([...mapA.keys(), ...mapB.keys()]))

    return allIds.map(id => {
      const a = mapA.get(id)
      const b = mapB.get(id)
      return {
        card_id: id,
        card_name: a?.card_name ?? b?.card_name ?? id,
        damage_a: a?.final_damage ?? 0,
        damage_b: b?.final_damage ?? 0,
        block_a: a?.final_block ?? 0,
        block_b: b?.final_block ?? 0,
      }
    })
  }, [resultsA, resultsB])

  // ---------------------------------------------------------------------------
  // Toggle button (always rendered)
  // ---------------------------------------------------------------------------

  return (
    <div className="flex flex-col gap-4">
      {/* Toggle */}
      <div className="flex items-center gap-3">
        <button
          onClick={toggleComparison}
          className={[
            'px-4 py-2 rounded-lg text-sm font-medium transition-all flex items-center gap-2',
            comparisonMode
              ? 'gradient-purple text-white glow-purple hover:glow-purple-md'
              : 'bg-[var(--bg-elevated)] text-gray-300 border border-purple-500/20 hover:border-purple-500/40 hover:bg-[var(--bg-hover)]',
          ].join(' ')}
        >
          {/* Compare icon */}
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
          </svg>
          {comparisonMode ? 'Comparison Mode: ON' : 'Enable Comparison Mode'}
        </button>
        {comparisonMode && (
          <span className="text-xs text-gray-500">
            Configure Loadout A and B below, then see the delta table.
          </span>
        )}
      </div>

      {/* Content */}
      {comparisonMode && (
        <>
          {/* Side-by-side pickers */}
          <div className="grid grid-cols-2 gap-4">
            <div className="panel panel-accent-purple p-4">
              <div className="flex items-center gap-2 mb-3">
                <span className="text-xs font-bold uppercase tracking-wider text-purple-400 bg-purple-500/10 px-2 py-0.5 rounded">Loadout A</span>
              </div>
              <LoadoutPicker
                loadout={loadoutA}
                onUpdate={(partial) => setLoadoutA(partial)}
              />
            </div>
            <div className="panel panel-accent-blue p-4">
              <div className="flex items-center gap-2 mb-3">
                <span className="text-xs font-bold uppercase tracking-wider text-blue-400 bg-blue-500/10 px-2 py-0.5 rounded">Loadout B</span>
              </div>
              <LoadoutPicker
                loadout={loadoutB}
                onUpdate={(partial) => setLoadoutB(partial)}
              />
            </div>
          </div>

          {/* Comparison table */}
          <div>
            <h3 className="text-xs font-semibold uppercase tracking-wider text-gray-400 mb-2">
              Card Damage Comparison
            </h3>
            {!ready ? (
              <div className="text-sm text-gray-500 text-center py-4">Loading data...</div>
            ) : (
              <div className="overflow-x-auto panel rounded-xl">
                <table className="w-full text-sm border-collapse">
                  <thead className="bg-[var(--bg-base)]">
                    <tr>
                      <th className="px-3 py-2.5 text-left text-xs font-semibold text-gray-400 uppercase tracking-wide border-b border-purple-500/10 whitespace-nowrap">
                        Card
                      </th>
                      <th className="px-3 py-2.5 text-center text-xs font-semibold text-purple-400 uppercase tracking-wide border-b border-purple-500/10 whitespace-nowrap">
                        A Dmg
                      </th>
                      <th className="px-3 py-2.5 text-center text-xs font-semibold text-blue-400 uppercase tracking-wide border-b border-purple-500/10 whitespace-nowrap">
                        B Dmg
                      </th>
                      <th className="px-3 py-2.5 text-center text-xs font-semibold text-yellow-400 uppercase tracking-wide border-b border-purple-500/10 whitespace-nowrap">
                        Delta Dmg
                      </th>
                      <th className="px-3 py-2.5 text-center text-xs font-semibold text-purple-400 uppercase tracking-wide border-b border-purple-500/10 whitespace-nowrap">
                        A Block
                      </th>
                      <th className="px-3 py-2.5 text-center text-xs font-semibold text-blue-400 uppercase tracking-wide border-b border-purple-500/10 whitespace-nowrap">
                        B Block
                      </th>
                      <th className="px-3 py-2.5 text-center text-xs font-semibold text-yellow-400 uppercase tracking-wide border-b border-purple-500/10 whitespace-nowrap">
                        Delta Block
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    {comparisonRows.length === 0 ? (
                      <tr>
                        <td colSpan={7} className="px-3 py-6 text-center text-gray-500 text-sm">
                          No cards to compare.
                        </td>
                      </tr>
                    ) : (
                      comparisonRows.map((row, i) => {
                        const hasDamageDelta = row.damage_b !== row.damage_a
                        const hasBlockDelta = row.block_b !== row.block_a
                        const hasAnyDelta = hasDamageDelta || hasBlockDelta
                        return (
                          <tr
                            key={row.card_id}
                            className={[
                              'border-b border-[var(--bg-elevated)] transition-all group',
                              hasAnyDelta ? 'bg-purple-500/[0.03]' : '',
                              'hover:bg-[var(--bg-hover)]',
                            ].join(' ')}
                          >
                            <td className="px-3 py-2 text-gray-200 font-medium whitespace-nowrap border-l-2 border-transparent group-hover:border-purple-500/50">
                              {row.card_name}
                            </td>
                            <td className="px-3 py-2 text-center">
                              <span className="font-mono text-xs text-gray-300">{row.damage_a}</span>
                            </td>
                            <td className="px-3 py-2 text-center">
                              <span className="font-mono text-xs text-gray-300">{row.damage_b}</span>
                            </td>
                            <td className="px-3 py-2 text-center">
                              <DeltaCell a={row.damage_a} b={row.damage_b} />
                            </td>
                            <td className="px-3 py-2 text-center">
                              <span className="font-mono text-xs text-gray-300">{row.block_a}</span>
                            </td>
                            <td className="px-3 py-2 text-center">
                              <span className="font-mono text-xs text-gray-300">{row.block_b}</span>
                            </td>
                            <td className="px-3 py-2 text-center">
                              <DeltaCell a={row.block_a} b={row.block_b} />
                            </td>
                          </tr>
                        )
                      })
                    )}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </>
      )}
    </div>
  )
}
