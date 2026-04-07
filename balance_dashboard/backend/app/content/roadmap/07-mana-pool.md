---
title: Mana pool system
status: planned
order: 7
phase: 5
tag: combat
---

## mana pool

The current combat system uses a flat **3 energy per turn** (4 for Technomancer). The designed system replaces this with a **mana pool**: a maximum of 10 mana that regenerates at 3/turn. Cards cost mana rather than energy. Mana carries over between turns if unspent.

The implications are:
- **Burst turns are possible.** Holding mana for a full turn lets you unload a huge combo on the next.
- **Low-cost chain cards become stronger** because every card played is a fraction of a full turn, not a discrete event.
- **The Cryptomancer's kit is rebalanced** — her mana regen scales with corruption.
- **The Scourge's contraband mechanic** interacts better with a pool because mana-per-contraband trades have granularity.

Design is complete (in `mechanics.gd`), schema additions (`MANA_REGEN` stat) are already in `enums.gd`. Implementation is deferred until after Phase 8 (meta pages) ships so we can track the rollout publicly in the changelog.
