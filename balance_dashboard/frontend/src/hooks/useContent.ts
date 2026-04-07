import { useQuery } from '@tanstack/react-query'
import type { ContentDoc } from '../types/content'

async function getJson<T>(path: string): Promise<T> {
  const res = await fetch(path, { headers: { 'Content-Type': 'application/json' } })
  if (!res.ok) throw new Error(`[${res.status}] ${path}: ${res.statusText}`)
  return res.json() as Promise<T>
}

export function useContentSection(section: string) {
  return useQuery({
    queryKey: ['content', section],
    queryFn: () => getJson<ContentDoc[]>(`/api/content/${section}`),
  })
}

export function useContentDoc(section: string, slug: string | undefined) {
  const q = useContentSection(section)
  const found = slug ? q.data?.find(d => d.slug === slug) : undefined
  return { ...q, data: found }
}
