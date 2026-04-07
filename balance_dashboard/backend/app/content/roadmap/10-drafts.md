---
title: Draft edit layer
status: planned
order: 10
phase: 7
tag: backend
---

## draft layer

Edits in the lab should go to a **draft layer** — a SQLite store of pending changes that overlay the `.tres` source data without writing to it. This preserves the source-of-truth principle (`.tres` files are never modified by the dashboard during normal operation) while still letting designers experiment.

Scope:
- **Draft** and **DraftEdit** tables in SQLite via SQLModel.
- **Overlay service** that merges active draft edits on top of parser output when serving `/api/codex/*`.
- **DraftBanner** component shown on every page when overlay is active.
- **Drafts page** showing diff vs source, with discard and rename actions.
- **Promote-to-tres** CLI tool (explicit, opt-in, separate binary) that writes a named draft back to `.tres`. This is the ONLY path from drafts to source, and it's intentionally not exposed in the web UI.

Deferred until after auth (Phase 9) so drafts can be scoped per-user on a multi-user deployment.
