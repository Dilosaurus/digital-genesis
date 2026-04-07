import { useQuery } from '@tanstack/react-query'
import type { ContentDoc } from '../types/content'

export interface Commit {
  sha: string
  short_sha: string
  subject: string
  body: string
  author: string
  iso: string
  date: string
  tags: string[]
}

async function getJson<T>(path: string): Promise<T> {
  const res = await fetch(path, { headers: { 'Content-Type': 'application/json' } })
  if (!res.ok) throw new Error(`[${res.status}] ${path}: ${res.statusText}`)
  return res.json() as Promise<T>
}

export function useChangelog(limit = 80) {
  return useQuery({
    queryKey: ['meta', 'changelog', limit],
    queryFn: () => getJson<Commit[]>(`/api/meta/changelog?limit=${limit}`),
  })
}

export function useRoadmap() {
  return useQuery({
    queryKey: ['meta', 'roadmap'],
    queryFn: () => getJson<ContentDoc[]>('/api/meta/roadmap'),
  })
}

export function useDecisions() {
  return useQuery({
    queryKey: ['meta', 'decisions'],
    queryFn: () => getJson<ContentDoc[]>('/api/meta/decisions'),
  })
}
