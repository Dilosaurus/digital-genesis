/**
 * deus.exe // codex — API client
 *
 * Thin wrapper around fetch. Backend is FastAPI on :8000, proxied through
 * Vite in dev. All endpoints under /api/codex/* return game data loaded
 * live from .tres source files.
 */

const JSON_HEADERS = { 'Content-Type': 'application/json' } as const

class ApiError extends Error {
  status: number
  endpoint: string
  constructor(status: number, endpoint: string, message: string) {
    super(`[${status}] ${endpoint}: ${message}`)
    this.name = 'ApiError'
    this.status = status
    this.endpoint = endpoint
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(path, {
    headers: JSON_HEADERS,
    ...init,
  })
  if (!res.ok) {
    const text = await res.text().catch(() => '')
    throw new ApiError(res.status, path, text || res.statusText)
  }
  return res.json() as Promise<T>
}

// ─── Codex endpoints ──────────────────────────────────────────────────────

export const api = {
  health: () => request<{ status: string; enums: Record<string, string[]> }>('/api/health'),

  cards: () => request<unknown[]>('/api/codex/cards'),
  card: (id: string) => request<unknown>(`/api/codex/cards/${id}`),

  characters: () => request<unknown[]>('/api/codex/characters'),
  character: (id: string) => request<unknown>(`/api/codex/characters/${id}`),

  gems: () => request<unknown[]>('/api/codex/gems'),
  gem: (id: string) => request<unknown>(`/api/codex/gems/${id}`),

  relics: () => request<unknown[]>('/api/codex/relics'),
  relic: (id: string) => request<unknown>(`/api/codex/relics/${id}`),

  equipment: () => request<unknown[]>('/api/codex/equipment'),
  equipmentPiece: (id: string) => request<unknown>(`/api/codex/equipment/${id}`),

  enemies: () => request<unknown[]>('/api/codex/enemies'),
  enemy: (id: string) => request<unknown>(`/api/codex/enemies/${id}`),

  dungeons: () => request<unknown[]>('/api/codex/dungeons'),
  skillTrees: () => request<unknown[]>('/api/codex/skill-trees'),
  corruption: () => request<unknown>('/api/codex/corruption'),
}

export { ApiError }
