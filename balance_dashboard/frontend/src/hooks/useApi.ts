import { useState, useEffect, useCallback, useRef } from 'react'
import type {
  Card,
  Relic,
  Equipment,
  Gem,
  SkillNode,
  Enemy,
  CorruptionData,
  GraphData,
  Loadout,
  SimulationResult,
} from '../types'

// ---------------------------------------------------------------------------
// Generic fetching hook
// ---------------------------------------------------------------------------

interface ApiState<T> {
  data: T | null
  loading: boolean
  error: string | null
}

interface ApiResult<T> extends ApiState<T> {
  refetch: () => void
}

function useApiData<T>(endpoint: string): ApiResult<T> {
  const [state, setState] = useState<ApiState<T>>({
    data: null,
    loading: true,
    error: null,
  })
  // Use a counter to trigger re-fetches without recreating the effect
  const [fetchTick, setFetchTick] = useState(0)
  const abortRef = useRef<AbortController | null>(null)

  useEffect(() => {
    // Cancel any in-flight request
    abortRef.current?.abort()
    const controller = new AbortController()
    abortRef.current = controller

    setState(prev => ({ ...prev, loading: true, error: null }))

    fetch(endpoint, { signal: controller.signal })
      .then(res => {
        if (!res.ok) {
          throw new Error(`HTTP ${res.status}: ${res.statusText}`)
        }
        return res.json() as Promise<T>
      })
      .then(data => {
        setState({ data, loading: false, error: null })
      })
      .catch(err => {
        if (err instanceof Error && err.name === 'AbortError') return
        setState({ data: null, loading: false, error: String(err) })
      })

    return () => {
      controller.abort()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [endpoint, fetchTick])

  const refetch = useCallback(() => setFetchTick(t => t + 1), [])

  return { ...state, refetch }
}

// ---------------------------------------------------------------------------
// Entity hooks — each maps to a backend endpoint
// ---------------------------------------------------------------------------

export function useCards(): ApiResult<Card[]> {
  return useApiData<Card[]>('/api/cards')
}

export function useRelics(): ApiResult<Relic[]> {
  return useApiData<Relic[]>('/api/relics')
}

export function useEquipment(): ApiResult<Equipment[]> {
  return useApiData<Equipment[]>('/api/equipment')
}

export function useGems(): ApiResult<Gem[]> {
  return useApiData<Gem[]>('/api/gems')
}

export function useSkillTree(): ApiResult<SkillNode[]> {
  return useApiData<SkillNode[]>('/api/skill-tree')
}

export function useEnemies(): ApiResult<Enemy[]> {
  return useApiData<Enemy[]>('/api/enemies')
}

export function useCorruption(): ApiResult<CorruptionData> {
  return useApiData<CorruptionData>('/api/corruption')
}

export function useGraph(): ApiResult<GraphData> {
  return useApiData<GraphData>('/api/graph')
}

// ---------------------------------------------------------------------------
// Simulator hook — POST to /api/simulate
// ---------------------------------------------------------------------------

interface SimulateState {
  results: SimulationResult[] | null
  loading: boolean
  error: string | null
}

interface SimulateResult extends SimulateState {
  simulate: (loadout: Loadout) => Promise<void>
}

export function useSimulate(): SimulateResult {
  const [state, setState] = useState<SimulateState>({
    results: null,
    loading: false,
    error: null,
  })
  const abortRef = useRef<AbortController | null>(null)

  const simulate = useCallback(async (loadout: Loadout): Promise<void> => {
    abortRef.current?.abort()
    const controller = new AbortController()
    abortRef.current = controller

    setState({ results: null, loading: true, error: null })

    try {
      const res = await fetch('/api/simulate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(loadout),
        signal: controller.signal,
      })

      if (!res.ok) {
        throw new Error(`HTTP ${res.status}: ${res.statusText}`)
      }

      const results = (await res.json()) as SimulationResult[]
      setState({ results, loading: false, error: null })
    } catch (err) {
      if (err instanceof Error && err.name === 'AbortError') return
      setState({ results: null, loading: false, error: String(err) })
    }
  }, [])

  return { ...state, simulate }
}

// ---------------------------------------------------------------------------
// Reload hook — POST to /api/reload to re-parse Godot data files
// ---------------------------------------------------------------------------

interface ReloadResult {
  reload: () => Promise<void>
  loading: boolean
  error: string | null
}

export function useReload(): ReloadResult {
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const reload = useCallback(async (): Promise<void> => {
    setLoading(true)
    setError(null)
    try {
      const res = await fetch('/api/reload', { method: 'POST' })
      if (!res.ok) {
        throw new Error(`HTTP ${res.status}: ${res.statusText}`)
      }
    } catch (err) {
      setError(String(err))
    } finally {
      setLoading(false)
    }
  }, [])

  return { reload, loading, error }
}
