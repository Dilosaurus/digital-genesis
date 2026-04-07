---
title: Multiplayer lobby UI
status: parked
order: 12
phase: game
tag: multiplayer
---

## multiplayer lobby

The Godot game has working 1–4 player LAN co-op via ENet. Enemy HP scales with party size, the vote system works, the party manager maintains per-player decks, and the network layer was verified on 2026-03-31.

What does not work yet: **matchmaking, lobby UI, reconnection, in-game chat.** Players currently join by typing IP addresses at each other, which is fine for LAN testing and impossible for anything else.

This is **parked** — it's a substantial piece of work (a lobby UI alone is a week of sustained effort), it's outside the scope of the dashboard rebuild, and Chris has not prioritized it. When the game is otherwise ready to ship, this becomes the last major blocker and gets its own phase.
