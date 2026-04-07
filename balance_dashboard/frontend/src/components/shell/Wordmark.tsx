import { Link } from 'react-router-dom'

/**
 * deus.exe — the wordmark. Lowercase always. JetBrains Mono. The dot-exe
 * is the punchline. Subtle chromatic-aberration slip fires on a 14s loop
 * via the `wordmark-glitch` keyframes.
 *
 * Two halves: `deus` in bone, `.exe` in oxidized gold. A blinking caret
 * trails the whole thing. The outer wrapper carries the glitch.
 */
interface WordmarkProps {
  size?: 'sm' | 'md' | 'lg'
  caret?: boolean
  asLink?: boolean
}

const SIZES = {
  sm: { base: 'text-[15px]', ext: 'text-[15px]' },
  md: { base: 'text-[22px]', ext: 'text-[22px]' },
  lg: { base: 'text-[34px]', ext: 'text-[34px]' },
} as const

export function Wordmark({ size = 'md', caret = true, asLink = true }: WordmarkProps) {
  const s = SIZES[size]

  const content = (
    <span
      className={`wordmark-glitch inline-flex items-baseline font-mono font-bold tracking-[0.02em] select-none ${caret ? 'caret' : ''}`}
      aria-label="deus.exe"
    >
      <span className={`${s.base}`} style={{ color: 'var(--bone)' }}>
        deus
      </span>
      <span className={`${s.ext}`} style={{ color: 'var(--oxidized-gold)' }}>
        .exe
      </span>
    </span>
  )

  if (!asLink) return content
  return (
    <Link to="/" className="inline-block no-underline hover:no-underline">
      {content}
    </Link>
  )
}
