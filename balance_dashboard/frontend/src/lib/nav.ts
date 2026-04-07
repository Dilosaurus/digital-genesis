/**
 * deus.exe // codex — navigation tree
 *
 * The sidebar renders the app as a filesystem. Each section is a filename
 * with an inode-style index and (eventually) a live entity count.
 *
 * The groups mirror how a manuscript or a cursed software archive would be
 * organized: BIBLE (prose), CODEX (tabular data), META (process artifacts),
 * LAB (tools), DRAFTS (pending edits).
 */

export interface NavEntry {
  path: string
  label: string       // display text — always a filename
  glyph?: string      // mono glyph prefix (file type)
  count?: number      // filesize-style count — static for now, live in Phase 3
  tag?: 'corruption' | 'scourge' | 'new'
}

export interface NavGroup {
  id: string
  heading: string     // uppercase display heading (Cinzel)
  subheading: string  // filesystem-style path
  entries: NavEntry[]
}

export const NAV: NavGroup[] = [
  {
    id: 'root',
    heading: 'ROOT',
    subheading: '~/deus.exe',
    entries: [
      { path: '/',        label: 'vision.md',   glyph: '†', count: 1 },
    ],
  },
  {
    id: 'bible',
    heading: 'BIBLE',
    subheading: '~/deus.exe/bible/',
    entries: [
      { path: '/lore',        label: 'lore.txt',        glyph: '§', count: 4 },
      { path: '/characters',  label: 'characters.dat',  glyph: '✶', count: 6 },
      { path: '/depths',      label: 'depths.log',      glyph: '▼', count: 3 },
      { path: '/mechanics',   label: 'mechanics.gd',    glyph: '⚙', count: 6 },
    ],
  },
  {
    id: 'codex',
    heading: 'CODEX',
    subheading: '~/deus.exe/codex/',
    entries: [
      { path: '/codex/cards',     label: 'cards/',      glyph: '▢', count: 175 },
      { path: '/codex/gems',      label: 'gems/',       glyph: '◆', count: 20 },
      { path: '/codex/relics',    label: 'relics/',     glyph: '✚', count: 25 },
      { path: '/codex/equipment', label: 'equipment/',  glyph: '⧫', count: 20 },
      { path: '/codex/enemies',   label: 'enemies.bst', glyph: '✸', count: 18 },
    ],
  },
  {
    id: 'meta',
    heading: 'META',
    subheading: '~/deus.exe/meta/',
    entries: [
      { path: '/roadmap',    label: 'roadmap.todo',     glyph: '→', count: 9 },
      { path: '/changelog',  label: 'changelog.commit', glyph: '◷', count: 5 },
      { path: '/decisions',  label: 'decisions.log',    glyph: '⌘', count: 0 },
    ],
  },
  {
    id: 'lab',
    heading: 'LAB',
    subheading: '~/deus.exe/lab/',
    entries: [
      { path: '/lab/tables',    label: 'tables.sh',      glyph: '≡' },
      { path: '/lab/simulator', label: 'simulator.py',   glyph: '∞' },
      { path: '/lab/graph',     label: 'graph.dot',      glyph: '⊹' },
    ],
  },
  {
    id: 'drafts',
    heading: 'DRAFTS',
    subheading: '~/deus.exe/drafts/',
    entries: [
      { path: '/drafts', label: 'pending.diff', glyph: '◌', count: 0 },
    ],
  },
]

/** Flatten the tree so we can look up an entry by path (for breadcrumbs). */
export const NAV_BY_PATH = new Map<string, { group: NavGroup; entry: NavEntry }>()
for (const group of NAV) {
  for (const entry of group.entries) {
    NAV_BY_PATH.set(entry.path, { group, entry })
  }
}

/** Break a URL path into breadcrumb segments. */
export interface Crumb {
  label: string
  path: string
  mono: boolean
}

export function crumbs(pathname: string): Crumb[] {
  if (pathname === '/') {
    return [{ label: 'vision.md', path: '/', mono: true }]
  }
  const parts = pathname.split('/').filter(Boolean)
  const out: Crumb[] = []
  let acc = ''
  for (const part of parts) {
    acc += `/${part}`
    out.push({ label: part, path: acc, mono: true })
  }
  return out
}
