---
title: Lab — balance tools reskinned
status: planned
order: 9
phase: 6
tag: tools
---

## lab

The old balance dashboard had three tools: **Tables** (editable data tables), **Simulator** (damage calculator and comparison mode), and **Graph** (dependency visualization). All three still exist in the old Flask codebase but are not wired into the new FastAPI backend or the new frontend shell.

Phase 6 ports them:
- **/lab/tables** — TanStack Table-based editable data grids for every entity type. Writes go to the draft layer (Phase 7), not to `.tres`.
- **/lab/simulator** — pipeline trace view. Build a hypothetical combat scenario, see every modifier source that touched every number. Essential for deep build construction.
- **/lab/graph** — React Flow + Dagre visualization of card/gem/modifier dependencies. Repurposable for mechanics diagrams too.

The visual treatment is intentionally different from the public-facing codex — the lab should feel like terminal output, not manuscript. Monospace dominant, scanlines on everything, less decorative flourish. It's the *back room* of the bible.
