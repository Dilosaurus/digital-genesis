---
title: Mana pool system
status: parked
order: 7
phase: 5
tag: combat
---

> **Note (2026-04-07):** Parked by the persistent-progression pivot (see roadmap item 13 and ADR-0003). In a game with persistent stash, crafting, and map-tier progression, the combat economy is shifted by the rolled-affix system rather than by a mana pool. May be revisited once the pivot systems ship and we see whether 3-energy still feels constraining.


## mana pool

The current combat system uses a flat **3 energy per turn** (4 for Technomancer). The designed system replaces this with a **mana pool**: a maximum of 10 mana that regenerates at 3/turn. Cards cost mana rather than energy. Mana carries over between turns if unspent.

The implications are:
- **Burst turns are possible.** Holding mana for a full turn lets you unload a huge combo on the next.
- **Low-cost chain cards become stronger** because every card played is a fraction of a full turn, not a discrete event.
- **The Cryptomancer's kit is rebalanced** — her mana regen scales with corruption.
- **The Scourge's contraband mechanic** interacts better with a pool because mana-per-contraband trades have granularity.

Design is complete (in `mechanics.gd`), schema additions (`MANA_REGEN` stat) are already in `enums.gd`. Implementation is deferred until after Phase 8 (meta pages) ships so we can track the rollout publicly in the changelog.
