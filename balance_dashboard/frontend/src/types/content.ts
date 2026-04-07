/**
 * Content section — server-side markdown doc.
 */
export interface ContentDoc {
  section: string
  slug: string
  meta: {
    title?: string
    chapter?: string | number
    subtitle?: string
    order?: number
    accent?: string
    danger?: string
    hp_range?: string
    [key: string]: unknown
  }
  body: string
}
