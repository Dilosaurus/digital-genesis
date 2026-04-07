import { useRoadmap } from '../hooks/useMeta'
import { SectionHeader } from '../components/codex/SectionHeader'
import { MarkdownPage } from '../components/content/MarkdownPage'
import type { ContentDoc } from '../types/content'

type Status = 'shipped' | 'in-flight' | 'planned' | 'parked'

const STATUS_ORDER: Status[] = ['shipped', 'in-flight', 'planned', 'parked']

const STATUS_META: Record<Status, { label: string; color: string; glyph: string; sub: string }> = {
  shipped:     { label: 'SHIPPED',    color: '#87C464', glyph: '✓', sub: 'merged to spine' },
  'in-flight': { label: 'IN-FLIGHT',  color: '#F2D94C', glyph: '◈', sub: 'currently underway' },
  planned:     { label: 'PLANNED',    color: '#D9B05F', glyph: '→', sub: 'in the queue' },
  parked:      { label: 'PARKED',     color: '#7F6640', glyph: '◌', sub: 'deferred indefinitely' },
}

/**
 * /roadmap — curated development vision. Not auto-generated from commits;
 * each item is a hand-written markdown file in content/roadmap/ with a
 * `status` frontmatter field.
 *
 * Groups by status (shipped → in-flight → planned → parked). Each item
 * is a collapsible accordion-style card; click to expand the full body.
 */
export function Roadmap() {
  const { data: items, isLoading, error } = useRoadmap()

  const grouped = STATUS_ORDER
    .map(status => [
      status,
      (items ?? []).filter(i => i.meta.status === status),
    ] as const)
    .filter(([, list]) => list.length > 0)

  return (
    <section className="relative pb-20">
      <SectionHeader
        chapter="II."
        heading="THE ROADMAP"
        filename="meta/roadmap.todo"
        count={items?.length ?? '—'}
        subtitle="what is done, what is coming, what is parked."
      />

      {isLoading && (
        <div className="mx-[clamp(1rem,6vw,6rem)] terminal-frame p-6 font-mono text-[12px]" style={{ color: 'var(--bone-faint)' }}>
          <span className="prompt" />&nbsp;cat content/roadmap/*.md<span className="caret" />
        </div>
      )}
      {error && (
        <div className="mx-[clamp(1rem,6vw,6rem)] terminal-frame p-6 font-mono text-[12px]" style={{ color: 'var(--blood-bright)' }}>
          ERR · {String(error)}
        </div>
      )}

      {items && (
        <div className="reveal reveal-3 mx-[clamp(1rem,6vw,6rem)] space-y-14">
          {grouped.map(([status, list]) => (
            <StatusGroup key={status} status={status} items={list} />
          ))}
        </div>
      )}
    </section>
  )
}

function StatusGroup({ status, items }: { status: Status; items: ContentDoc[] }) {
  const meta = STATUS_META[status]
  return (
    <div>
      <div className="flex items-baseline gap-4 mb-6">
        <div
          style={{
            fontFamily: 'var(--font-display)',
            fontSize: 42,
            color: meta.color,
            letterSpacing: 0,
            lineHeight: 1,
            filter: `drop-shadow(0 0 8px ${meta.color}44)`,
          }}
        >
          {meta.glyph}
        </div>
        <div>
          <div
            style={{
              fontFamily: 'var(--font-display)',
              fontSize: 'clamp(1.6rem, 3vw, 2.4rem)',
              color: 'var(--bone)',
              letterSpacing: '0.14em',
              fontWeight: 600,
              textTransform: 'uppercase',
            }}
          >
            {meta.label}
          </div>
          <div
            className="font-mono"
            style={{ fontSize: 10, color: meta.color, letterSpacing: '0.12em' }}
          >
            {meta.sub} · {items.length} item{items.length !== 1 ? 's' : ''}
          </div>
        </div>
      </div>

      <div className="space-y-4">
        {items.map(item => (
          <RoadmapItem key={item.slug} item={item} statusColor={meta.color} />
        ))}
      </div>
    </div>
  )
}

function RoadmapItem({ item, statusColor }: { item: ContentDoc; statusColor: string }) {
  const tag = item.meta.tag as string | undefined
  const shipped = item.meta.shipped as string | undefined
  const phase = item.meta.phase as string | number | undefined
  return (
    <details
      className="group"
      style={{
        background: 'var(--server-rack)',
        border: '1px solid var(--burnt-brass-dim)',
        borderLeft: `3px solid ${statusColor}`,
      }}
    >
      <summary
        className="cursor-pointer list-none flex items-center gap-4 p-5"
        style={{ userSelect: 'none' }}
      >
        <span
          className="font-mono shrink-0"
          style={{ color: statusColor, fontSize: 14 }}
        >
          ▸
        </span>
        <div className="flex-1 min-w-0">
          <div
            className="truncate"
            style={{
              fontFamily: 'var(--font-display)',
              fontSize: 17,
              color: 'var(--bone)',
              fontWeight: 600,
              letterSpacing: '0.04em',
              textTransform: 'uppercase',
            }}
          >
            {item.meta.title as string}
          </div>
          <div
            className="font-mono mt-1 flex flex-wrap items-center gap-2"
            style={{ fontSize: 9, color: 'var(--bone-faint)', letterSpacing: '0.12em' }}
          >
            {phase != null && (
              <span>PHASE {String(phase).toUpperCase()}</span>
            )}
            {tag && (
              <>
                <span style={{ color: 'var(--burnt-brass)' }}>·</span>
                <span style={{ color: statusColor }}>{tag.toUpperCase()}</span>
              </>
            )}
            {shipped && (
              <>
                <span style={{ color: 'var(--burnt-brass)' }}>·</span>
                <span>SHIPPED {shipped}</span>
              </>
            )}
          </div>
        </div>
      </summary>

      <div
        className="px-5 pb-6 pt-2"
        style={{ borderTop: '1px dotted var(--burnt-brass-dim)' }}
      >
        <div className="pt-4">
          <MarkdownPage body={item.body} accentColor={statusColor} />
        </div>
      </div>
    </details>
  )
}
