/**
 * deus.exe // codex — text & number formatting helpers
 */

/** Pad a number with leading zeros (inode-style). */
export function pad(n: number, width = 3): string {
  return String(n).padStart(width, '0')
}

/** Convert SCREAMING_SNAKE to Title Case for display. */
export function titleCase(screaming: string): string {
  return screaming
    .toLowerCase()
    .split('_')
    .map(w => w[0]?.toUpperCase() + w.slice(1))
    .join(' ')
}

/** Number with sign prefix. Used for stat deltas. */
export function withSign(n: number): string {
  if (n > 0) return `+${n}`
  return String(n)
}

/** Format a floating-point stat nicely. Strips trailing zeros. */
export function fmtFloat(n: number, decimals = 2): string {
  const s = n.toFixed(decimals)
  return s.replace(/\.?0+$/, '')
}

/** Describe a modifier operation mathematically. */
export function opLabel(op: string, value: number): string {
  switch (op) {
    case 'OVERRIDE':     return `= ${value}`
    case 'FLAT_ADD':     return withSign(value)
    case 'PERCENT_ADD':  return `${withSign(value * 100)}%`
    case 'PERCENT_MULT': return `x${fmtFloat(value)}`
    default:             return `${op} ${value}`
  }
}
