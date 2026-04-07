---
title: FastAPI codex backend
status: shipped
order: 2
phase: 1
tag: backend
shipped: 2026-04-07
---

## codex backend

Replaced the legacy Flask exporter with a **FastAPI** service that reads `.tres` files from the Godot project as the source of truth. Full coverage of 175 cards, 6 characters, 20 gems, 25 relics, 20 equipment pieces, 18 enemies, 3 dungeon variants, 6 skill trees with 72 nodes, and 21 corruption tables.

Live enum sync from `enums.gd` — the backend will never drift from the game's enum definitions again. All previously-missing fields (PIRACY mechanics, daemon fragments, party/co-op, character data, art refs) are now exposed.
