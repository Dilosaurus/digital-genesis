---
title: Full rewrite of the balance dashboard as the game bible
status: accepted
date: 2026-04-07
order: 2
tag: architecture
---

## context

The old balance dashboard was framed as a **developer tool** — editable tables, a combat simulator, a card dependency graph. It did its job competently. The visual design was generic dark-mode-plus-purple-gradients, which was a cliché even before the frontend-design skill explicitly called it out as the #1 AI-slop aesthetic to avoid.

The bigger problem: nowhere in the dashboard was there any place for the **vision** of the game. There was nowhere for the story, the design philosophy, the roadmap, the decision history, the lore, or the mechanics-as-design-rationale. If a new collaborator walked in and asked "what is this game?" the dashboard could show them every card's damage value but none of what the game *was*.

## decision

Full rewrite of `balance_dashboard/`, both frontend and backend. The rewrite:

- Treats `.tres` files in `card_game/` as **read-only source of truth** — the dashboard never writes to them during normal operation.
- Replaces Flask with **FastAPI**, reusing the parser logic from `export_from_tres.py` but expanding field coverage from ~22 fields per card to 50+.
- Completely redesigns the frontend with a **gothic-tech aesthetic** — sacred machine horror, cursed illuminated codex × corrupted terminal.
- Turns the dashboard into a **game bible first**, balance tool second. The bible (vision, lore, characters, depths, codex, mechanics) is the front door. The lab (balance tools) is one room inside.
- Introduces a **draft edit layer** (Phase 7) so designers can experiment without touching source data.

## consequences

**Good:**
- The bible becomes the single source of truth for "what is deus.exe?" — usable by Chris, collaborators, and eventually documentation.
- The source-of-truth principle (`.tres` files never written) de-risks future editing features — a bug in the draft layer cannot corrupt game data.
- The aesthetic is distinctive enough to be recognizable. No other card game dashboard looks like this.
- The new backend structure is cleaner, more typed (pydantic), and exposes auto-generated OpenAPI docs at `/docs`.

**Bad:**
- The old dashboard's UI and tooling are thrown out. Tables, simulator, graph — all need to be ported (Phase 6). This is substantial work.
- The new backend introduces a new stack for Chris to maintain (FastAPI, SQLModel, pydantic). Manageable but more to learn.
- Some features the old dashboard had don't have a migration plan yet (real-time Godot telemetry, for example).

**Neutral:**
- Rewriting in phases means the dashboard is usable throughout. At no point does the app go dark for weeks while a rewrite is in progress.
- Git history preserves the old codebase; nothing is lost.

## when we would revisit

Never, probably. The decision is load-bearing and the rebuild is already half-complete. A future "rewrite the rewrite" is possible but unlikely — the architecture here is solid enough to last.
