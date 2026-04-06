# Fix Combat Visuals + Card Dealing Timing Bug

## Problem 1: Cards dealt before enemy turn finishes
In `combat_scene.gd`, `_on_state_changed()` (line 1320) calls `_refresh_all_ui()` on EVERY state change (line 1338). When the engine transitions synchronously through ENEMY_TURN → PLAYER_TURN (drawing new cards), `_refresh_all_ui()` immediately updates the hand display with the new hand — but `_play_enemy_actions()` is still running its async animation loop. The player sees their next hand dealt while enemies haven't finished acting.

**Fix**: Guard `_refresh_all_ui()` in `_on_state_changed()` — skip the hand update when `_playing_enemy_turn` is true and phase just changed to PLAYER_TURN. `_play_enemy_actions()` already calls `_refresh_all_ui()` at line 1433 after animations finish.

File: `scripts/scenes/combat_scene.gd` ~line 1326-1338

## Problem 2: Script-based StyleBoxFlat overrides nuke all .tscn texture styles

Multiple GDScript files create `StyleBoxFlat.new()` at runtime and call `add_theme_stylebox_override()`, completely overriding whatever textures are set in the .tscn scenes. Key offenders:

1. **`combat_scene.gd:1208`** — `_style_end_turn_button()` creates flat End Turn button styles
2. **`card_visual.gd:197`** — `_apply_card_colors()` casts style to StyleBoxFlat, duplicates and overrides. Since I changed card_bg to StyleBoxTexture, the `as StyleBoxFlat` cast returns null, so the type coloring silently fails.
3. **`relic_display.gd:148`** — Creates flat relic slot styles in code

**Fix for combat_scene.gd**: Delete `_style_end_turn_button()` entirely — the .tscn already has the correct texture-based styles.

**Fix for card_visual.gd**: Revert card_bg to a polished StyleBoxFlat (the FrameSquare texture at 128x128 doesn't look good stretched to 185x260). Update `_apply_card_colors()` to use warmer base colors that fit the dark fantasy palette.

**Fix for relic_display.gd**: Update the code-created styles to use warm tones instead of purple/cyan.

## Files to edit

1. `scripts/scenes/combat_scene.gd` — Guard _refresh_all_ui during enemy turn; delete _style_end_turn_button
2. `scenes/cards/card_visual.tscn` — Revert card_bg to polished StyleBoxFlat
3. `scripts/ui/card_visual.gd` — Update TYPE_COLORS to warm dark fantasy palette
4. `scripts/ui/relic_display.gd` — Warm up code-created slot styles
