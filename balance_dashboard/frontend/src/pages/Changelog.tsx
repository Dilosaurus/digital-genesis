import { useChangelog, type Commit } from '../hooks/useMeta'
import { SectionHeader } from '../components/codex/SectionHeader'

/**
 * /changelog — the git log of card_game/, parsed and rendered as a devlog.
 * Each commit is a terminal-style entry with its short SHA, date, subject,
 * extracted tags, and body when present.
 */
export function Changelog() {
  const { data: commits, isLoading, error } = useChangelog(80)

  // Group by month (YYYY-MM) for scannable browsing
  const groups = groupByMonth(commits ?? [])

  return (
    <section className="relative pb-20">
      <SectionHeader
        chapter="I."
        heading="THE CHANGELOG"
        filename="meta/changelog.commit"
        count={commits?.length ?? '—'}
        subtitle="every rite committed to the spine."
      />

      {isLoading && (
        <div className="mx-[clamp(1rem,6vw,6rem)] terminal-frame p-6 font-mono text-[12px]" style={{ color: 'var(--bone-faint)' }}>
          <span className="prompt" />&nbsp;git log --format=delta<span className="caret" />
        </div>
      )}
      {error && (
        <div className="mx-[clamp(1rem,6vw,6rem)] terminal-frame p-6 font-mono text-[12px]" style={{ color: 'var(--blood-bright)' }}>
          ERR · {String(error)}
        </div>
      )}

      {commits && (
        <div className="reveal reveal-3 mx-[clamp(1rem,6vw,6rem)] space-y-14">
          {groups.map(([month, list]) => (
            <MonthGroup key={month} month={month} commits={list} />
          ))}
        </div>
      )}
    </section>
  )
}

function groupByMonth(commits: Commit[]): Array<[string, Commit[]]> {
  const bucket = new Map<string, Commit[]>()
  for (const c of commits) {
    const ym = c.date.slice(0, 7)  // "2026-04"
    if (!bucket.has(ym)) bucket.set(ym, [])
    bucket.get(ym)!.push(c)
  }
  return Array.from(bucket.entries()).sort((a, b) => b[0].localeCompare(a[0]))
}

const MONTH_NAMES = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
]

const TAG_COLORS: Record<string, string> = {
  scourge:     '#8C1A33',
  cards:       '#EBE0C8',
  gems:        '#33D9F2',
  relics:      '#D9B05F',
  equipment:   '#F2D94C',
  enemies:     '#E633CC',
  bosses:      '#B13340',
  multiplayer: '#87C464',
  combat:      '#B13340',
  corruption:  '#5C1B7A',
  modifiers:   '#D9B05F',
  ui:          '#F5E6A8',
  shaders:     '#33D9F2',
  dashboard:   '#87C464',
  art:         '#E633CC',
  '3d':        '#F2D94C',
  schema:      '#D9B05F',
  fix:         '#B13340',
  refactor:    '#7F6640',
  docs:        '#A89B7D',
}

function MonthGroup({ month, commits }: { month: string; commits: Commit[] }) {
  const [year, monthNum] = month.split('-')
  const monthLabel = MONTH_NAMES[parseInt(monthNum, 10) - 1] ?? monthNum
  return (
    <div>
      <div className="flex items-baseline gap-5 mb-6">
        <div
          style={{
            fontFamily: 'var(--font-display)',
            fontSize: 'clamp(2.4rem, 4vw, 3.4rem)',
            color: 'transparent',
            WebkitTextStroke: '1.5px var(--burnt-brass)',
            lineHeight: 0.85,
            letterSpacing: '0.04em',
            marginLeft: '-0.05em',
          }}
        >
          {monthLabel}
        </div>
        <div>
          <div
            style={{
              fontFamily: 'var(--font-display)',
              fontSize: 'clamp(1.1rem, 2vw, 1.7rem)',
              color: 'var(--bone-dim)',
              letterSpacing: '0.12em',
              fontWeight: 500,
              textTransform: 'uppercase',
            }}
          >
            {year}
          </div>
          <div
            className="font-mono"
            style={{ fontSize: 10, color: 'var(--burnt-brass)', letterSpacing: '0.12em' }}
          >
            {commits.length} commit{commits.length !== 1 ? 's' : ''}
          </div>
        </div>
      </div>

      <div className="space-y-3">
        {commits.map(c => (
          <CommitRow key={c.sha} commit={c} />
        ))}
      </div>
    </div>
  )
}

function CommitRow({ commit }: { commit: Commit }) {
  return (
    <article
      className="p-5 relative"
      style={{
        background: 'var(--server-rack)',
        border: '1px solid var(--burnt-brass-dim)',
        borderLeft: '2px solid var(--burnt-brass)',
      }}
    >
      <header className="flex items-baseline gap-4 flex-wrap mb-2">
        <span
          className="font-mono"
          style={{
            fontSize: 11,
            color: 'var(--oxidized-gold)',
            letterSpacing: '0.02em',
            padding: '1px 6px',
            border: '1px solid rgba(217, 176, 95, 0.3)',
            background: 'rgba(217, 176, 95, 0.06)',
          }}
        >
          {commit.short_sha}
        </span>
        <span
          className="font-mono"
          style={{ fontSize: 10, color: 'var(--bone-faint)', letterSpacing: '0.02em' }}
        >
          {commit.date}
        </span>
        <span
          className="font-mono"
          style={{ fontSize: 10, color: 'var(--burnt-brass)', letterSpacing: '0.02em' }}
        >
          · {commit.author}
        </span>
        {commit.tags.length > 0 && (
          <div className="flex flex-wrap gap-[4px] ml-auto">
            {commit.tags.slice(0, 6).map(tag => (
              <span
                key={tag}
                className="font-mono uppercase"
                style={{
                  fontSize: 8,
                  letterSpacing: '0.14em',
                  padding: '2px 5px',
                  color: TAG_COLORS[tag] ?? 'var(--bone-faint)',
                  border: `1px solid ${TAG_COLORS[tag] ?? 'var(--burnt-brass-dim)'}`,
                  lineHeight: 1,
                }}
              >
                {tag}
              </span>
            ))}
          </div>
        )}
      </header>

      <div
        style={{
          fontFamily: 'var(--font-display)',
          fontSize: 17,
          color: 'var(--bone)',
          fontWeight: 500,
          letterSpacing: '0.02em',
          lineHeight: 1.35,
        }}
      >
        {commit.subject}
      </div>

      {commit.body && (
        <pre
          className="mt-3 whitespace-pre-wrap"
          style={{
            fontFamily: 'var(--font-mono)',
            fontSize: 11,
            color: 'var(--bone-dim)',
            letterSpacing: '0.02em',
            lineHeight: 1.5,
            maxHeight: '200px',
            overflow: 'hidden',
          }}
        >
          {commit.body}
        </pre>
      )}
    </article>
  )
}
