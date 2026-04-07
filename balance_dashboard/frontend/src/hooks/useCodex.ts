/**
 * deus.exe // codex — React Query hooks for all codex entities.
 *
 * Every entity is fetched once per session and cached. Individual detail
 * pages use the list cache when possible (find by id) to avoid round-trips.
 */

import { useQuery } from '@tanstack/react-query'
import type {
  Card, Character, Gem, Relic, Equipment, Enemy,
} from '../types/game'

const JSON_HEADERS = { 'Content-Type': 'application/json' } as const

async function getJson<T>(path: string): Promise<T> {
  const res = await fetch(path, { headers: JSON_HEADERS })
  if (!res.ok) throw new Error(`[${res.status}] ${path}: ${res.statusText}`)
  return res.json() as Promise<T>
}

// ─── Lists ────────────────────────────────────────────────────────────────

export function useCards() {
  return useQuery({
    queryKey: ['codex', 'cards'],
    queryFn: () => getJson<Card[]>('/api/codex/cards'),
  })
}

export function useCharacters() {
  return useQuery({
    queryKey: ['codex', 'characters'],
    queryFn: () => getJson<Character[]>('/api/codex/characters'),
  })
}

export function useGems() {
  return useQuery({
    queryKey: ['codex', 'gems'],
    queryFn: () => getJson<Gem[]>('/api/codex/gems'),
  })
}

export function useRelics() {
  return useQuery({
    queryKey: ['codex', 'relics'],
    queryFn: () => getJson<Relic[]>('/api/codex/relics'),
  })
}

export function useEquipment() {
  return useQuery({
    queryKey: ['codex', 'equipment'],
    queryFn: () => getJson<Equipment[]>('/api/codex/equipment'),
  })
}

export function useEnemies() {
  return useQuery({
    queryKey: ['codex', 'enemies'],
    queryFn: () => getJson<Enemy[]>('/api/codex/enemies'),
  })
}

// ─── Details (use the list cache when possible) ──────────────────────────

export function useCard(id: string | undefined) {
  const list = useCards()
  const found = id ? list.data?.find(c => c.id === id) : undefined
  return { ...list, data: found }
}

export function useCharacter(id: string | undefined) {
  const list = useCharacters()
  const found = id ? list.data?.find(c => c.id === id) : undefined
  return { ...list, data: found }
}
