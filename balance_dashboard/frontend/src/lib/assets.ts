/**
 * deus.exe // codex — asset + taxonomy helpers
 *
 * Central lookup table for:
 *  - res:// → /assets/ URL conversion
 *  - per-class character accent colors
 *  - per-rarity palette
 *  - per-card-type palette
 *  - human-readable stat / tag / target labels
 */

import type {
  CardType, Rarity, CardTag, TargetType, CharacterClassName, EquipSlot,
} from '../types/game'

// ─── res:// asset resolution ─────────────────────────────────────────────
// .tres files store paths like "res://assets/cards/illustrations/strike/strike_base.png".
// The FastAPI backend mounts card_game/assets/ at /media/ (not /assets/,
// because Vite's built JS/CSS ships under /assets/ and we don't want the
// mounts to collide in production). We rewrite res://assets/... → /media/...

export function resolveAsset(resPath: string | undefined | null): string | null {
  if (!resPath) return null
  if (resPath.startsWith('res://assets/')) {
    return '/media/' + resPath.slice('res://assets/'.length)
  }
  if (resPath.startsWith('res://')) {
    return '/media/' + resPath.slice('res://'.length)
  }
  if (resPath.startsWith('/media/') || resPath.startsWith('/assets/')) return resPath
  return null
}

// ─── Character class palette ─────────────────────────────────────────────
// Fallback colors matching the .tres color_primary values. Prefer the live
// character.color_primary when available — this is just a fallback for when
// we know the class index but not the character object.

export const CHARACTER_COLORS: Record<number, { name: string; color: string; code: string }> = {
  [-1]: { name: 'SHARED',       color: '#D9B05F', code: 'SH' },
  0:    { name: 'NETRUNNER',    color: '#33D9F2', code: 'NR' },
  1:    { name: 'SYSADMIN',     color: '#7399CC', code: 'SA' },
  2:    { name: 'CRYPTOMANCER', color: '#8C26BF', code: 'CM' },
  3:    { name: 'WHITE_HAT',    color: '#F2D94C', code: 'WH' },
  4:    { name: 'HERETIC',      color: '#E633CC', code: 'HR' },
  5:    { name: 'SCOURGE',      color: '#8C1A33', code: 'SC' },
}

export const CHARACTER_SLUG: Record<number, string> = {
  [-1]: 'shared',
  0:    'netrunner',
  1:    'sysadmin',
  2:    'cryptomancer',
  3:    'white-hat',
  4:    'technomancer',
  5:    'scourge',
}

export function charClassColor(idx: number): string {
  return CHARACTER_COLORS[idx]?.color ?? '#D9B05F'
}
export function charClassName(idx: number): string {
  return CHARACTER_COLORS[idx]?.name ?? 'SHARED'
}
export function charClassCode(idx: number): string {
  return CHARACTER_COLORS[idx]?.code ?? '--'
}

// ─── Rarity palette ───────────────────────────────────────────────────────

export const RARITY_COLORS: Record<Rarity, { fg: string; bg: string; border: string }> = {
  COMMON:    { fg: '#A89B7D', bg: 'rgba(168, 155, 125, 0.10)', border: 'rgba(168, 155, 125, 0.35)' },
  UNCOMMON:  { fg: '#D9B05F', bg: 'rgba(217, 176, 95, 0.10)', border: 'rgba(217, 176, 95, 0.45)' },
  RARE:      { fg: '#F5E6A8', bg: 'rgba(245, 230, 168, 0.12)', border: 'rgba(245, 230, 168, 0.55)' },
  LEGENDARY: { fg: '#B13340', bg: 'rgba(177, 51, 64, 0.14)',   border: 'rgba(177, 51, 64, 0.60)' },
}

export const RARITY_ORDER: Rarity[] = ['COMMON', 'UNCOMMON', 'RARE', 'LEGENDARY']

// ─── Card type palette ────────────────────────────────────────────────────

export const CARD_TYPE_COLORS: Record<CardType, string> = {
  ATTACK: '#B13340',  // blood bright
  SKILL:  '#EBE0C8',  // bone
  POWER:  '#D9B05F',  // oxidized gold
  STATUS: '#7F6640',  // burnt brass
  CURSE:  '#5C1B7A',  // cipher purple — the ONE place we use it
}

export const CARD_TYPE_ORDER: CardType[] = ['ATTACK', 'SKILL', 'POWER', 'STATUS', 'CURSE']

export const CARD_TYPE_GLYPH: Record<CardType, string> = {
  ATTACK: '†',
  SKILL:  '◇',
  POWER:  '✦',
  STATUS: '⊘',
  CURSE:  '✖',
}

// ─── Tag labels ───────────────────────────────────────────────────────────

export const TAG_COLORS: Record<CardTag, string> = {
  MELEE:   '#B13340',
  RANGED:  '#D9B05F',
  FIRE:    '#E85C2B',
  ICE:     '#33D9F2',
  HOLY:    '#F5E6A8',
  SHADOW:  '#5C1B7A',
  TECH:    '#87C464',
  EXPLOIT: '#E633CC',
  PIRACY:  '#8C1A33',
  CURSE:   '#5C1B7A',
}

export const TAG_ORDER: CardTag[] = [
  'MELEE', 'RANGED', 'FIRE', 'ICE', 'HOLY', 'SHADOW', 'TECH', 'EXPLOIT', 'PIRACY', 'CURSE',
]

// ─── Equipment slot labels ────────────────────────────────────────────────

export const SLOT_ORDER: EquipSlot[] = ['WEAPON', 'ARMOR', 'TRINKET', 'AMULET', 'RING']

export const SLOT_GLYPH: Record<EquipSlot, string> = {
  WEAPON: '†',
  ARMOR:  '⛨',
  TRINKET: '✦',
  AMULET: '☍',
  RING:   '◯',
}

// ─── Target labels ────────────────────────────────────────────────────────

export const TARGET_LABEL: Record<TargetType, string> = {
  ENEMY:         'single',
  ALL_ENEMIES:   'AoE',
  SELF:          'self',
  NONE:          '—',
  ALLY:          'ally',
  ALL_ALLIES:    'party',
  PARTY:         'party',
  MARKED_ENEMY:  'marked',
}

// ─── Character class name → slug ──────────────────────────────────────────

export const CLASS_TO_IDX: Record<CharacterClassName, number> = {
  NETRUNNER:    0,
  SYSADMIN:     1,
  CRYPTOMANCER: 2,
  WHITE_HAT:    3,
  TECHNOMANCER: 4,
  SCOURGE:      5,
}

// ─── Character animation registry ────────────────────────────────────────
// Maps a character callsign (Character.display_name.toLowerCase()) to the
// list of poses available under /anim/<callsign>_<pose>_loop.gif. The first
// entry is the default pose shown when the character is first viewed. Add
// new poses here as the Grok Imagine pipeline produces them.

export const ANIMATION_POSES: Record<string, string[]> = {
  abyss:    ['idle', 'attack_cast', 'attack_cast_heavy', 'attack_quick', 'attack_ultimate'],
  paladin:  ['idle'],
  corsayre: ['idle'],
  flux:     ['idle'],
  ghost:    ['idle'],
  aegis:    ['idle'],
}

// Human-readable pose labels for the dossier tab strip.
export const POSE_LABELS: Record<string, string> = {
  idle:               'IDLE',
  attack_cast:        'CAST',
  attack_cast_heavy:  'CAST·HEAVY',
  attack_quick:       'QUICK',
  attack_ultimate:    'ULTIMATE',
}

export function characterCallsign(displayName: string): string {
  return displayName.toLowerCase()
}

export function animationUrl(callsign: string, pose: string): string {
  return `/anim/${callsign}_${pose}_loop.gif`
}

export function hasAnimation(displayName: string): boolean {
  return (ANIMATION_POSES[characterCallsign(displayName)]?.length ?? 0) > 0
}
