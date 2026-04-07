import type { Modifier } from '../../types/game'
import { opLabel, titleCase } from '../../lib/format'

interface Props {
  mod: Modifier
}

/**
 * Compact modifier display: [STAT] [operation-math] [conditions]
 *
 * Example renders:
 *   DAMAGE  +3      (permanent)
 *   DAMAGE  x1.25   (only vs vulnerable)
 *   BLOCK   +50%    (this combat)
 */
export function ModifierChip({ mod }: Props) {
  const math = opLabel(mod.operation, mod.value)

  const conditions: string[] = []
  if (mod.lifecycle !== 'PERMANENT') conditions.push(titleCase(mod.lifecycle))
  if (mod.only_vs_vulnerable) conditions.push('vs Vulnerable')
  if (mod.only_when_hp_below_pct != null) conditions.push(`HP < ${Math.round(mod.only_when_hp_below_pct * 100)}%`)
  if (mod.required_card_type) conditions.push(`on ${titleCase(mod.required_card_type)}`)
  if (mod.required_card_tags?.length) conditions.push(`tagged ${mod.required_card_tags.map(titleCase).join('/')}`)

  return (
    <div
      className="flex items-center gap-3 font-mono"
      style={{
        fontSize: 12,
        padding: '6px 10px',
        background: 'rgba(217, 176, 95, 0.04)',
        border: '1px solid rgba(217, 176, 95, 0.18)',
        letterSpacing: '0.02em',
      }}
    >
      <span
        className="uppercase"
        style={{
          color: 'var(--bone-dim)',
          minWidth: '5.5em',
          letterSpacing: '0.12em',
          fontSize: 10,
        }}
      >
        {titleCase(mod.stat)}
      </span>
      <span style={{ color: 'var(--oxidized-gold)', minWidth: '3.5em' }}>{math}</span>
      {conditions.length > 0 && (
        <span style={{ color: 'var(--bone-faint)', fontSize: 10 }}>
          {conditions.join(' · ')}
        </span>
      )}
    </div>
  )
}
