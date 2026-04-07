import ReactMarkdown from 'react-markdown'
import type { Components } from 'react-markdown'

/**
 * MarkdownPage — the manuscript-voice renderer.
 *
 * Maps each markdown element to a deus.exe-styled component:
 *   h1  → giant Cinzel display
 *   h2  → smaller Cinzel with hairline decoration
 *   h3  → mono terminal heading
 *   p   → Cormorant Garamond body prose (first paragraph gets dropcap)
 *   blockquote → italic pull quote with double-brass border
 *   strong → halo-colored emphasis
 *   em  → oxidized-gold italic
 *   code → mono inline code
 *   hr  → double brass separator
 *   ul / ol → dotted gutters
 */
interface Props {
  body: string
  accentColor?: string
}

export function MarkdownPage({ body, accentColor }: Props) {
  const components: Components = {
    h1: ({ children }) => (
      <h1
        className="mt-14 mb-6"
        style={{
          fontFamily: 'var(--font-display)',
          fontSize: 'clamp(2.6rem, 6vw, 5rem)',
          lineHeight: 0.95,
          letterSpacing: '0.05em',
          color: 'var(--bone)',
          fontWeight: 600,
          textTransform: 'uppercase',
        }}
      >
        {children}
      </h1>
    ),
    h2: ({ children }) => (
      <h2
        className="mt-14 mb-5 flex items-baseline gap-4"
        style={{
          fontFamily: 'var(--font-display)',
          fontSize: 'clamp(1.8rem, 3.2vw, 2.6rem)',
          lineHeight: 1,
          letterSpacing: '0.1em',
          color: accentColor ?? 'var(--oxidized-gold)',
          fontWeight: 600,
          textTransform: 'uppercase',
        }}
      >
        <span
          aria-hidden
          style={{
            display: 'inline-block',
            width: 36,
            borderTop: `2px solid ${accentColor ?? 'var(--oxidized-gold)'}`,
          }}
        />
        {children}
      </h2>
    ),
    h3: ({ children }) => (
      <h3
        className="mt-10 mb-3"
        style={{
          fontFamily: 'var(--font-mono)',
          fontSize: 14,
          letterSpacing: '0.18em',
          color: 'var(--bone-dim)',
          textTransform: 'uppercase',
          fontWeight: 500,
        }}
      >
        <span style={{ color: 'var(--burnt-brass)' }}>&gt;</span>&nbsp;&nbsp;{children}
      </h3>
    ),
    p: ({ children }) => (
      <p
        style={{
          fontFamily: 'var(--font-body)',
          fontSize: 19,
          lineHeight: 1.62,
          color: 'var(--ink)',
          marginBottom: '1.4em',
          maxWidth: '66ch',
        }}
      >
        {children}
      </p>
    ),
    blockquote: ({ children }) => (
      <blockquote
        className="my-8 py-2 pl-8 pr-6"
        style={{
          borderLeft: '3px double var(--burnt-brass)',
          fontFamily: 'var(--font-body)',
          fontStyle: 'italic',
          fontSize: 'clamp(1.15rem, 1.8vw, 1.4rem)',
          lineHeight: 1.4,
          color: 'var(--halo)',
          maxWidth: '60ch',
        }}
      >
        {children}
      </blockquote>
    ),
    strong: ({ children }) => (
      <strong style={{ color: 'var(--halo)', fontWeight: 600 }}>{children}</strong>
    ),
    em: ({ children }) => (
      <em style={{ color: accentColor ?? 'var(--oxidized-gold)', fontStyle: 'italic' }}>
        {children}
      </em>
    ),
    code: ({ children }) => (
      <code
        style={{
          fontFamily: 'var(--font-mono)',
          fontSize: '0.85em',
          padding: '1px 6px',
          background: 'rgba(217, 176, 95, 0.08)',
          border: '1px solid rgba(217, 176, 95, 0.2)',
          color: 'var(--oxidized-gold)',
          letterSpacing: '0.02em',
        }}
      >
        {children}
      </code>
    ),
    hr: () => (
      <hr
        className="my-10"
        style={{
          border: 'none',
          borderTop: '3px double var(--burnt-brass)',
          maxWidth: '60ch',
          marginLeft: 0,
        }}
      />
    ),
    ul: ({ children }) => (
      <ul
        className="mb-6 pl-0"
        style={{
          listStyle: 'none',
          fontFamily: 'var(--font-body)',
          fontSize: 17,
          color: 'var(--bone-dim)',
          lineHeight: 1.55,
          maxWidth: '66ch',
        }}
      >
        {children}
      </ul>
    ),
    ol: ({ children }) => (
      <ol
        className="mb-6 pl-0"
        style={{
          listStyle: 'none',
          counterReset: 'item',
          fontFamily: 'var(--font-body)',
          fontSize: 17,
          color: 'var(--bone-dim)',
          lineHeight: 1.55,
          maxWidth: '66ch',
        }}
      >
        {children}
      </ol>
    ),
    li: ({ children }) => (
      <li
        className="mb-2 pl-7 relative"
        style={{ counterIncrement: 'item' }}
      >
        <span
          aria-hidden
          className="absolute left-0 font-mono"
          style={{ color: 'var(--burnt-brass)', fontSize: 14, top: '0.1em' }}
        >
          ◇
        </span>
        {children}
      </li>
    ),
    a: ({ href, children }) => (
      <a
        href={href}
        className="sacred-underline"
        style={{ color: accentColor ?? 'var(--oxidized-gold)' }}
      >
        {children}
      </a>
    ),
  }

  return (
    <div className="manuscript-page max-w-[clamp(60ch,70vw,80ch)]">
      <ReactMarkdown components={components}>{body}</ReactMarkdown>
    </div>
  )
}
