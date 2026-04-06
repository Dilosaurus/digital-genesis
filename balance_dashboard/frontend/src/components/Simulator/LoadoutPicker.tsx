import { useMemo } from 'react'
import type { Loadout, EquipSlot } from '../../types'
import { useRelics, useEquipment, useGems, useCards, useSkillTree } from '../../hooks/useApi'

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const ACTUAL_EQUIP_SLOTS: EquipSlot[] = ['WEAPON', 'ACCESSORY', 'HEAD', 'CHEST']

const SLOT_LABELS: Record<string, string> = {
  WEAPON: 'Weapon',
  ACCESSORY: 'Accessory',
  HEAD: 'Head',
  CHEST: 'Chest',
}

const CORRUPTION_LABELS = ['None', 'Tier 1: x1.1', 'Tier 2: x1.25', 'Tier 3: x1.5']
const CORRUPTION_COLORS = ['text-green-400', 'text-yellow-400', 'text-orange-400', 'text-red-400']

// ---------------------------------------------------------------------------
// Props
// ---------------------------------------------------------------------------

interface LoadoutPickerProps {
  loadout: Loadout
  label?: string
  onUpdate: (partial: Partial<Loadout>) => void
}

// ---------------------------------------------------------------------------
// Section icons (inline SVGs)
// ---------------------------------------------------------------------------

const SECTION_ICON: Record<string, React.ReactNode> = {
  relics: (
    <svg className="w-3.5 h-3.5 text-purple-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M20.618 5.984A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
    </svg>
  ),
  equipment: (
    <svg className="w-3.5 h-3.5 text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M14.828 14.828a4 4 0 01-5.656 0M9.172 9.172a4 4 0 015.656 0M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
  ),
  gems: (
    <svg className="w-3.5 h-3.5 text-cyan-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M12 3l2.5 4.5L20 9l-3.5 4 .5 5-5-2-5 2 .5-5L4 9l5.5-1.5L12 3z" />
    </svg>
  ),
  skills: (
    <svg className="w-3.5 h-3.5 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
    </svg>
  ),
  corruption: (
    <svg className="w-3.5 h-3.5 text-orange-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M17.657 18.657A8 8 0 016.343 7.343S7 9 9 10c0-2 .5-5 2.986-7C14 5 16.09 5.777 17.656 7.343A7.975 7.975 0 0120 13a7.975 7.975 0 01-2.343 5.657z" />
      <path strokeLinecap="round" strokeLinejoin="round" d="M9.879 16.121A3 3 0 1012.015 11L11 14H9c0 .768.293 1.536.879 2.121z" />
    </svg>
  ),
  stats: (
    <svg className="w-3.5 h-3.5 text-yellow-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
    </svg>
  ),
  context: (
    <svg className="w-3.5 h-3.5 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
    </svg>
  ),
}

// ---------------------------------------------------------------------------
// Rarity color mapping
// ---------------------------------------------------------------------------

const RARITY_COLOR: Record<string, string> = {
  common: 'text-gray-400',
  uncommon: 'text-blue-400',
  rare: 'text-yellow-400',
}

const RARITY_DOT_COLOR: Record<string, string> = {
  common: 'bg-gray-500',
  uncommon: 'bg-blue-500',
  rare: 'bg-yellow-500',
}

// ---------------------------------------------------------------------------
// Sub-components
// ---------------------------------------------------------------------------

function SectionHeader({ title, icon }: { title: string; icon?: string }) {
  return (
    <h3 className="text-xs font-semibold uppercase tracking-wider text-gray-400 mb-2 flex items-center gap-1.5">
      {icon && SECTION_ICON[icon]}
      {title}
    </h3>
  )
}

function InputLabel({ children }: { children: React.ReactNode }) {
  return (
    <span className="text-sm text-gray-300">{children}</span>
  )
}

// ---------------------------------------------------------------------------
// LoadoutPicker
// ---------------------------------------------------------------------------

export function LoadoutPicker({ loadout, label, onUpdate }: LoadoutPickerProps) {
  const relicsApi = useRelics()
  const equipmentApi = useEquipment()
  const gemsApi = useGems()
  const cardsApi = useCards()
  const skillTreeApi = useSkillTree()

  // Cards that have sockets
  const socketableCards = useMemo(
    () => (cardsApi.data ?? []).filter(c => c.gem_sockets > 0),
    [cardsApi.data],
  )

  // Equipment grouped by slot
  const equipBySlot = useMemo(() => {
    const map: Record<string, typeof equipmentApi.data> = {}
    for (const slot of ACTUAL_EQUIP_SLOTS) {
      map[slot] = (equipmentApi.data ?? []).filter(e => e.slot === slot)
    }
    return map
  }, [equipmentApi.data])

  // Skill prerequisite checking
  const allSkills = skillTreeApi.data ?? []

  function isSkillAvailable(skillId: string): boolean {
    const skill = allSkills.find(s => s.id === skillId)
    if (!skill) return false
    return skill.prerequisites.every(prereqId => loadout.skills.includes(prereqId))
  }

  const totalSkillCost = useMemo(
    () =>
      loadout.skills.reduce((sum, id) => {
        const skill = allSkills.find(s => s.id === id)
        return sum + (skill?.cost ?? 0)
      }, 0),
    [loadout.skills, allSkills],
  )

  // ---------------------------------------------------------------------------
  // Handlers
  // ---------------------------------------------------------------------------

  function toggleRelic(relicId: string) {
    const next = loadout.relics.includes(relicId)
      ? loadout.relics.filter(id => id !== relicId)
      : [...loadout.relics, relicId]
    onUpdate({ relics: next })
  }

  function setEquipSlot(slot: EquipSlot, equipId: string) {
    const next = { ...loadout.equipment }
    if (equipId === '') {
      delete next[slot]
    } else {
      next[slot] = equipId
    }
    onUpdate({ equipment: next })
  }

  function setGemSocket(cardId: string, socketIndex: number, gemId: string) {
    const card = socketableCards.find(c => c.id === cardId)
    if (!card) return
    const current = loadout.gems[cardId] ?? Array(card.gem_sockets).fill('')
    const next = [...current]
    next[socketIndex] = gemId
    onUpdate({ gems: { ...loadout.gems, [cardId]: next } })
  }

  function toggleSkill(skillId: string) {
    const isSelected = loadout.skills.includes(skillId)
    if (isSelected) {
      // Removing: also remove any skills that depend on this one
      const dependents = allSkills
        .filter(s => s.prerequisites.includes(skillId))
        .map(s => s.id)
      const next = loadout.skills.filter(
        id => id !== skillId && !dependents.includes(id),
      )
      onUpdate({ skills: next })
    } else {
      if (!isSkillAvailable(skillId)) return
      onUpdate({ skills: [...loadout.skills, skillId] })
    }
  }

  function setContext(key: keyof Loadout['context'], value: boolean | number) {
    onUpdate({ context: { ...loadout.context, [key]: value } })
  }

  // ---------------------------------------------------------------------------
  // Render
  // ---------------------------------------------------------------------------

  const selectClass =
    'w-full bg-[var(--bg-elevated)] border border-purple-500/20 text-gray-100 text-sm rounded-lg px-2.5 py-1.5 focus:outline-none focus:border-purple-500/60 focus:ring-1 focus:ring-purple-500/30'
  const checkboxRowClass = 'flex items-center gap-2 py-0.5'
  const spinnerClass =
    'w-20 bg-[var(--bg-elevated)] border border-purple-500/20 text-gray-100 text-sm rounded-lg px-2.5 py-1.5 focus:outline-none focus:border-purple-500/60 focus:ring-1 focus:ring-purple-500/30 font-mono'

  return (
    <div className="flex flex-col gap-5">
      {label && (
        <div className="flex items-center justify-between">
          <span className="text-base font-semibold text-purple-300">{label}</span>
        </div>
      )}

      {/* ---- Relics ---- */}
      <div>
        <SectionHeader title="Relics" icon="relics" />
        {relicsApi.loading && (
          <p className="text-xs text-gray-500">Loading relics...</p>
        )}
        {relicsApi.error && (
          <p className="text-xs text-red-400">Error: {relicsApi.error}</p>
        )}
        {!relicsApi.loading && (relicsApi.data ?? []).length === 0 && (
          <p className="text-xs text-gray-500">No relics available.</p>
        )}
        <div className="grid grid-cols-1 gap-0.5 max-h-40 overflow-y-auto pr-1">
          {(relicsApi.data ?? []).map(relic => {
            const rarityKey = relic.rarity.toLowerCase()
            return (
              <label key={relic.id} className={checkboxRowClass + ' cursor-pointer group'}>
                <input
                  type="checkbox"
                  checked={loadout.relics.includes(relic.id)}
                  onChange={() => toggleRelic(relic.id)}
                  className="accent-purple-500 w-3.5 h-3.5"
                />
                <span className={`w-1.5 h-1.5 rounded-full ${RARITY_DOT_COLOR[rarityKey] ?? 'bg-gray-500'} shrink-0`} />
                <span className="text-sm text-gray-200 group-hover:text-white">{relic.display_name}</span>
                <span className={`text-xs ml-auto capitalize ${RARITY_COLOR[rarityKey] ?? 'text-gray-500'}`}>{rarityKey}</span>
              </label>
            )
          })}
        </div>
      </div>

      {/* ---- Equipment ---- */}
      <div>
        <SectionHeader title="Equipment" icon="equipment" />
        <div className="flex flex-col gap-2">
          {ACTUAL_EQUIP_SLOTS.map(slot => (
            <div key={slot} className="flex items-center gap-3">
              <InputLabel>{SLOT_LABELS[slot]}</InputLabel>
              <div className="flex-1">
                <select
                  value={loadout.equipment[slot] ?? ''}
                  onChange={e => setEquipSlot(slot, e.target.value)}
                  className={selectClass}
                >
                  <option value="">-- None --</option>
                  {(equipBySlot[slot] ?? []).map(equip => (
                    <option key={equip.id} value={equip.id}>
                      {equip.display_name}
                    </option>
                  ))}
                </select>
              </div>
            </div>
          ))}
          {equipmentApi.loading && (
            <p className="text-xs text-gray-500">Loading equipment...</p>
          )}
        </div>
      </div>

      {/* ---- Gems ---- */}
      <div>
        <SectionHeader title="Gems" icon="gems" />
        {cardsApi.loading || gemsApi.loading ? (
          <p className="text-xs text-gray-500">Loading...</p>
        ) : socketableCards.length === 0 ? (
          <p className="text-xs text-gray-500">No socketable cards in the deck.</p>
        ) : (
          <div className="flex flex-col gap-2">
            {socketableCards.map(card => (
              <div key={card.id} className="flex flex-col gap-1">
                <span className="text-xs text-gray-400">{card.display_name}</span>
                <div className="flex gap-2 flex-wrap">
                  {Array.from({ length: card.gem_sockets }, (_, i) => {
                    const currentGemId = loadout.gems[card.id]?.[i] ?? ''
                    return (
                      <div key={i} className="flex items-center gap-1">
                        <span className="text-xs text-gray-500">Socket {i + 1}</span>
                        <select
                          value={currentGemId}
                          onChange={e => setGemSocket(card.id, i, e.target.value)}
                          className="bg-[var(--bg-elevated)] border border-purple-500/20 text-gray-100 text-xs rounded-lg px-2 py-1 focus:outline-none focus:border-purple-500/60 focus:ring-1 focus:ring-purple-500/30"
                        >
                          <option value="">-- Empty --</option>
                          {(gemsApi.data ?? []).map(gem => (
                            <option key={gem.id} value={gem.id}>
                              {gem.display_name}
                            </option>
                          ))}
                        </select>
                      </div>
                    )
                  })}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* ---- Skills ---- */}
      <div>
        <SectionHeader title={`Skills (Cost: ${totalSkillCost})`} icon="skills" />
        {skillTreeApi.loading && (
          <p className="text-xs text-gray-500">Loading skills...</p>
        )}
        {skillTreeApi.error && (
          <p className="text-xs text-red-400">Error: {skillTreeApi.error}</p>
        )}
        <div className="flex flex-col gap-0.5 max-h-48 overflow-y-auto pr-1">
          {allSkills.map(skill => {
            const selected = loadout.skills.includes(skill.id)
            const available = isSkillAvailable(skill.id)
            const disabled = !selected && !available
            return (
              <label
                key={skill.id}
                className={[
                  checkboxRowClass,
                  disabled ? 'opacity-40 cursor-not-allowed' : 'cursor-pointer',
                ].join(' ')}
                title={
                  disabled
                    ? `Requires: ${skill.prerequisites.join(', ')}`
                    : skill.description
                }
              >
                <input
                  type="checkbox"
                  checked={selected}
                  disabled={disabled}
                  onChange={() => toggleSkill(skill.id)}
                  className="accent-purple-500 w-3.5 h-3.5"
                />
                <span className={['text-sm', selected ? 'text-purple-200' : 'text-gray-200'].join(' ')}>
                  {skill.display_name}
                </span>
                <span className="text-xs text-gray-500 ml-auto font-mono">
                  T{skill.tier} · {skill.cost}pt
                </span>
              </label>
            )
          })}
        </div>
      </div>

      {/* ---- Corruption Tier ---- */}
      <div>
        <SectionHeader title="Corruption Tier" icon="corruption" />
        <div className="flex flex-col gap-2">
          <input
            type="range"
            min={0}
            max={3}
            step={1}
            value={loadout.corruption_tier}
            onChange={e => onUpdate({ corruption_tier: Number(e.target.value) })}
            className="w-full accent-purple-500 h-2 rounded-lg cursor-pointer"
          />
          <div className="flex justify-between text-xs">
            {CORRUPTION_LABELS.map((lbl, i) => (
              <span
                key={i}
                className={[
                  loadout.corruption_tier === i
                    ? `${CORRUPTION_COLORS[i]} font-semibold text-sm`
                    : 'text-gray-500',
                ].join(' ')}
              >
                {lbl}
              </span>
            ))}
          </div>
        </div>
      </div>

      {/* ---- Strength / Dexterity ---- */}
      <div>
        <SectionHeader title="Base Stats" icon="stats" />
        <div className="flex gap-6">
          <div className="flex items-center gap-2">
            <InputLabel>Strength</InputLabel>
            <input
              type="number"
              min={0}
              max={20}
              value={loadout.strength}
              onChange={e => onUpdate({ strength: Math.max(0, Math.min(20, Number(e.target.value))) })}
              className={spinnerClass}
            />
          </div>
          <div className="flex items-center gap-2">
            <InputLabel>Dexterity</InputLabel>
            <input
              type="number"
              min={0}
              max={20}
              value={loadout.dexterity}
              onChange={e => onUpdate({ dexterity: Math.max(0, Math.min(20, Number(e.target.value))) })}
              className={spinnerClass}
            />
          </div>
        </div>
      </div>

      {/* ---- Context ---- */}
      <div>
        <SectionHeader title="Combat Context" icon="context" />
        <div className="flex flex-col gap-3">
          <label className="flex items-center justify-between cursor-pointer">
            <span className="text-sm text-gray-300">
              Target Vulnerable <span className="text-xs text-gray-500">(x1.5 damage)</span>
            </span>
            <button
              role="switch"
              aria-checked={loadout.context.vulnerable}
              onClick={() => setContext('vulnerable', !loadout.context.vulnerable)}
              className={[
                'relative inline-flex items-center h-6 w-11 rounded-full transition-all',
                loadout.context.vulnerable
                  ? 'bg-green-600 shadow-[0_0_10px_rgba(34,197,94,0.3)]'
                  : 'bg-[var(--bg-elevated)] border border-gray-600',
              ].join(' ')}
            >
              <span
                className={[
                  'inline-block h-4 w-4 rounded-full shadow transition-transform',
                  loadout.context.vulnerable
                    ? 'translate-x-5.5 bg-white'
                    : 'translate-x-1 bg-gray-400',
                ].join(' ')}
              />
            </button>
          </label>

          <label className="flex items-center justify-between cursor-pointer">
            <span className="text-sm text-gray-300">
              Player Weak <span className="text-xs text-gray-500">(x0.75 damage)</span>
            </span>
            <button
              role="switch"
              aria-checked={loadout.context.weak}
              onClick={() => setContext('weak', !loadout.context.weak)}
              className={[
                'relative inline-flex items-center h-6 w-11 rounded-full transition-all',
                loadout.context.weak
                  ? 'bg-red-600 shadow-[0_0_10px_rgba(239,68,68,0.3)]'
                  : 'bg-[var(--bg-elevated)] border border-gray-600',
              ].join(' ')}
            >
              <span
                className={[
                  'inline-block h-4 w-4 rounded-full shadow transition-transform',
                  loadout.context.weak
                    ? 'translate-x-5.5 bg-white'
                    : 'translate-x-1 bg-gray-400',
                ].join(' ')}
              />
            </button>
          </label>
        </div>
      </div>
    </div>
  )
}
