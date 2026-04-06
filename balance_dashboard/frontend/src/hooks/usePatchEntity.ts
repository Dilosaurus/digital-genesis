import { useState, useCallback } from 'react'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type EntityType = 'cards' | 'relics' | 'equipment' | 'gems' | 'enemies'
type ModifierEntityType = 'equipment' | 'gems'

interface MutationResult<TArgs extends unknown[]> {
  mutate: (...args: TArgs) => Promise<unknown>
  loading: boolean
  error: string | null
}

// ---------------------------------------------------------------------------
// Internal helper — generic mutation hook
// ---------------------------------------------------------------------------

function useMutation<TArgs extends unknown[]>(
  buildRequest: (...args: TArgs) => { url: string; method: string; body?: unknown },
): MutationResult<TArgs> {
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const mutate = useCallback(
    async (...args: TArgs): Promise<unknown> => {
      setLoading(true)
      setError(null)

      const { url, method, body } = buildRequest(...args)

      try {
        const res = await fetch(url, {
          method,
          headers: { 'Content-Type': 'application/json' },
          ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
        })

        if (!res.ok) {
          const text = await res.text().catch(() => res.statusText)
          throw new Error(`HTTP ${res.status}: ${text}`)
        }

        const json = await res.json()
        setLoading(false)
        return json
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err)
        setError(message)
        setLoading(false)
        throw err
      }
    },
    // buildRequest is expected to be stable (inline arrow in each hook below)
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [],
  )

  return { mutate, loading, error }
}

// ---------------------------------------------------------------------------
// usePatchEntity — PATCH a top-level entity field
// ---------------------------------------------------------------------------

interface PatchResult {
  patch: (id: string, updates: Record<string, unknown>) => Promise<unknown>
  loading: boolean
  error: string | null
}

export function usePatchEntity(entityType: EntityType): PatchResult {
  const { mutate, loading, error } = useMutation(
    (id: string, updates: Record<string, unknown>) => ({
      url: `/api/${entityType}/${id}`,
      method: 'PATCH',
      body: updates,
    }),
  )

  return { patch: mutate, loading, error }
}

// ---------------------------------------------------------------------------
// useAddModifier — POST a new modifier to an equipment or gem
// ---------------------------------------------------------------------------

interface AddModifierResult {
  add: (id: string, modifier: Record<string, unknown>) => Promise<unknown>
  loading: boolean
  error: string | null
}

export function useAddModifier(entityType: ModifierEntityType): AddModifierResult {
  const { mutate, loading, error } = useMutation(
    (id: string, modifier: Record<string, unknown>) => ({
      url: `/api/${entityType}/${id}/modifiers`,
      method: 'POST',
      body: modifier,
    }),
  )

  return { add: mutate, loading, error }
}

// ---------------------------------------------------------------------------
// useEditModifier — PATCH an existing modifier on an equipment or gem
// ---------------------------------------------------------------------------

interface EditModifierResult {
  edit: (id: string, modId: string, updates: Record<string, unknown>) => Promise<unknown>
  loading: boolean
  error: string | null
}

export function useEditModifier(entityType: ModifierEntityType): EditModifierResult {
  const { mutate, loading, error } = useMutation(
    (id: string, modId: string, updates: Record<string, unknown>) => ({
      url: `/api/${entityType}/${id}/modifiers/${modId}`,
      method: 'PATCH',
      body: updates,
    }),
  )

  return { edit: mutate, loading, error }
}

// ---------------------------------------------------------------------------
// useDeleteModifier — DELETE a modifier from an equipment or gem
// ---------------------------------------------------------------------------

interface DeleteModifierResult {
  remove: (id: string, modId: string) => Promise<unknown>
  loading: boolean
  error: string | null
}

export function useDeleteModifier(entityType: ModifierEntityType): DeleteModifierResult {
  const { mutate, loading, error } = useMutation(
    (id: string, modId: string) => ({
      url: `/api/${entityType}/${id}/modifiers/${modId}`,
      method: 'DELETE',
    }),
  )

  return { remove: mutate, loading, error }
}

// ---------------------------------------------------------------------------
// useUpdateIntents — PUT the full intent pool for an enemy
// ---------------------------------------------------------------------------

interface UpdateIntentsResult {
  update: (id: string, intents: unknown[]) => Promise<unknown>
  loading: boolean
  error: string | null
}

export function useUpdateIntents(): UpdateIntentsResult {
  const { mutate, loading, error } = useMutation(
    (id: string, intents: unknown[]) => ({
      url: `/api/enemies/${id}/intents`,
      method: 'PUT',
      body: intents,
    }),
  )

  return { update: mutate, loading, error }
}
