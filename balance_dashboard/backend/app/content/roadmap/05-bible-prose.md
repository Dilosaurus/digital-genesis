---
title: Bible prose — lore, depths, mechanics
status: shipped
order: 5
phase: 4
tag: content
shipped: 2026-04-07
---

## bible prose

Written **13 documents** of long-form in-voice prose across three sections:

- **Lore** (4) — The Nexus, Metatron, The Angels, GENESIS
- **Depths** (3) — The Outer Nexus, The Rift, The Void Core
- **Mechanics** (6) — Combat Loop, Modifier Pipeline, Corruption, Sins, Pacts & Tithes, Gems & Sockets

Backend markdown content endpoint with hand-rolled frontmatter parsing (no new dependencies). Frontend renderer uses `react-markdown` with full component overrides — every `<h2>`, `<p>`, `<blockquote>`, `<em>` mapped to the deus.exe manuscript typography. First paragraph of each document gets an illuminated drop cap.

Mechanics docs double as **design rationale**, not rules text. They explain *why* the modifier pipeline runs OVERRIDE → FLAT_ADD → PERCENT_ADD → PERCENT_MULT and what that means for deck construction.
