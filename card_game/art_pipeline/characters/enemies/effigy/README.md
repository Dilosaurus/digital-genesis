# THE EFFIGY — Compiled in Prayer

First enemy built on the Phase 2 per-character anchor pipeline (Nano Banana 2
with reference-image conditioning).

Mechanical role: early-act debuff caster. See `card_game/data/enemies/effigy.tres`
for stats and `lore`.

## What's in this directory

- `prompt.txt` — Nano Banana 2 prompt in the locked deus.exe art direction.
- `reference.png` — visual ground truth for the figure. **USER-PROVIDED** — see
  below. Not in git until saved.
- `anchor.png` — output of `generate_character_anchor.py`. Not yet generated.
- `_report.txt` — log from the last anchor generation run.

## How to generate the anchor

1. **Save the reference image** as `reference.png` in this directory. The
   reference should depict the figure as it's meant to look — the script uses
   it as visual ground truth and `prompt.txt` describes how to render it in
   house style.

2. **Set `GEMINI_API_KEY`** in the environment.

3. From the `art_pipeline/` directory:
   ```
   python generate_character_anchor.py --char-dir characters/enemies/effigy
   ```

4. Inspect `anchor.png` and iterate on `prompt.txt` until the output matches
   `art_pipeline/ART_DIRECTION.md`. Re-run the script to regenerate.

5. If the reference is deliberately unavailable (pure text-to-image
   generation), pass `--no-reference` to skip loading `reference.png`.

## Phase 1 vs Phase 2 anchors

- **Phase 1** (`generate_anchors.py`) — three global locked anchors
  (character / background / prop) that define the house style. These are
  text-only and must stay rock-stable.
- **Phase 2** (`generate_character_anchor.py`, this dir) — per-character
  anchors for every operator and enemy. Reads a per-character `prompt.txt`
  and an optional `reference.png`. These are iterated per-character.
