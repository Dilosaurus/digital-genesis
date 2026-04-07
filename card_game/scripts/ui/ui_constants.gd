## ui_constants.gd
## Centralised color, font, and layout constants for the deus.exe UI.
## All hardcoded values scattered across scenes should eventually reference this file.
class_name UIConstants

# ---------------------------------------------------------------------------
# Background colors
# ---------------------------------------------------------------------------

## Deepest background — main scene fill (almost-black purple)
const COLOR_BG_PRIMARY    := Color(0.04, 0.03, 0.10, 1.0)

## Secondary background — panels, cards, modal containers
const COLOR_BG_SECONDARY  := Color(0.06, 0.04, 0.12, 1.0)

## Tertiary background — nested panels, slightly lighter
const COLOR_BG_TERTIARY   := Color(0.08, 0.06, 0.16, 1.0)

## HUD panel background — semi-transparent, used in combat overlay panels
const COLOR_BG_HUD        := Color(0.05, 0.04, 0.12, 0.82)

## Accent gradient top — dark violet strip used at top of combat scene
const COLOR_BG_ACCENT_TOP := Color(0.08, 0.04, 0.16, 0.60)

# ---------------------------------------------------------------------------
# Border colors
# ---------------------------------------------------------------------------

## Subtle panel border — low-alpha purple-grey
const COLOR_BORDER_SUBTLE   := Color(0.30, 0.25, 0.50, 0.70)

## Normal button border — medium purple
const COLOR_BORDER_NORMAL   := Color(0.35, 0.30, 0.60, 0.80)

## Hovered button border — bright purple
const COLOR_BORDER_HOVER    := Color(0.55, 0.45, 0.90, 1.00)

## Modal / result panel border — vivid purple
const COLOR_BORDER_MODAL    := Color(0.50, 0.40, 0.80, 1.00)

## Intent / info box border — blue-grey
const COLOR_BORDER_INFO     := Color(0.40, 0.40, 0.60, 0.80)

# ---------------------------------------------------------------------------
# Text colors
# ---------------------------------------------------------------------------

## Primary body text — near-white with slight warm tint
const COLOR_TEXT_PRIMARY    := Color(0.92, 0.90, 0.88, 1.00)

## Secondary / subtitle text — muted blue-grey
const COLOR_TEXT_SECONDARY  := Color(0.55, 0.60, 0.72, 0.90)

## Disabled / flavour text — dark grey
const COLOR_TEXT_DISABLED   := Color(0.40, 0.40, 0.50, 0.70)

## Title accent text — bright cyan (game logo / headers)
const COLOR_TEXT_TITLE      := Color(0.45, 0.85, 1.00, 1.00)

## Subtitle label — light blue tint
const COLOR_TEXT_SUBTITLE   := Color(0.50, 0.60, 0.75, 0.80)

## Version / watermark text — dark grey
const COLOR_TEXT_VERSION    := Color(0.40, 0.40, 0.55, 0.80)

## Status / info text — light blue
const COLOR_TEXT_STATUS     := Color(0.60, 0.80, 1.00, 0.90)

# ---------------------------------------------------------------------------
# Game-stat colors
# ---------------------------------------------------------------------------

## HP fill — vivid green
const COLOR_HP              := Color(0.15, 0.82, 0.30, 1.00)

## HP preview / damage shadow — dark crimson, semi-transparent
const COLOR_HP_DAMAGE       := Color(0.60, 0.15, 0.10, 0.70)

## HP bar background — near-black navy
const COLOR_HP_BG           := Color(0.08, 0.08, 0.14, 1.00)

## Block / shield — bright cyan
const COLOR_BLOCK           := Color(0.40, 0.75, 1.00, 1.00)

## Energy orb — electric cyan
const COLOR_ENERGY          := Color(0.30, 0.85, 1.00, 1.00)

## Corruption — deep violet / magenta
const COLOR_CORRUPTION      := Color(0.60, 0.10, 0.75, 1.00)

## Sin — amber / gold
const COLOR_SIN             := Color(0.95, 0.70, 0.15, 1.00)

# ---------------------------------------------------------------------------
# Card-type accent colors — matches TYPE_COLORS in card_visual.gd
# These are the border/highlight accent for each type (index [2] in that array)
# ---------------------------------------------------------------------------

## Attack cards — warm red
const COLOR_CARD_ATTACK     := Color(0.85, 0.25, 0.20, 1.00)

## Skill cards — electric blue
const COLOR_CARD_SKILL      := Color(0.25, 0.50, 0.95, 1.00)

## Power cards — golden yellow
const COLOR_CARD_POWER      := Color(0.95, 0.75, 0.15, 1.00)

## Curse / corrupted cards — vivid purple
const COLOR_CARD_CURSE      := Color(0.60, 0.10, 0.75, 1.00)

# Card-type background (dark variant, index [0])
const COLOR_CARD_ATTACK_BG  := Color(0.22, 0.08, 0.08, 1.00)
const COLOR_CARD_SKILL_BG   := Color(0.08, 0.12, 0.28, 1.00)
const COLOR_CARD_POWER_BG   := Color(0.18, 0.14, 0.06, 1.00)
const COLOR_CARD_CURSE_BG   := Color(0.12, 0.05, 0.18, 1.00)

# ---------------------------------------------------------------------------
# Rarity colors
# ---------------------------------------------------------------------------

const COLOR_RARITY_COMMON     := Color(0.75, 0.75, 0.78, 1.00)   # silver-grey
const COLOR_RARITY_UNCOMMON   := Color(0.35, 0.80, 0.45, 1.00)   # green
const COLOR_RARITY_RARE       := Color(0.30, 0.55, 1.00, 1.00)   # blue
const COLOR_RARITY_LEGENDARY  := Color(1.00, 0.75, 0.15, 1.00)   # gold

# ---------------------------------------------------------------------------
# Combat feedback colors
# ---------------------------------------------------------------------------

## Victory label — vivid green
const COLOR_COMBAT_VICTORY  := Color(0.20, 1.00, 0.40, 1.00)

## Defeat label — bright red
const COLOR_COMBAT_DEFEAT   := Color(1.00, 0.25, 0.25, 1.00)

## Intent label (enemy attack) — vivid red
const COLOR_INTENT_ATTACK   := Color(1.00, 0.30, 0.30, 1.00)

## Intent label (enemy buff) — warm gold
const COLOR_INTENT_BUFF     := Color(1.00, 0.80, 0.30, 1.00)

## Intent label (enemy defend) — cyan
const COLOR_INTENT_DEFEND   := Color(0.40, 0.75, 1.00, 1.00)

## End-turn button normal bg — dark green
const COLOR_END_TURN_BG          := Color(0.15, 0.35, 0.15, 1.00)
const COLOR_END_TURN_BG_HOVER    := Color(0.20, 0.55, 0.20, 1.00)
const COLOR_END_TURN_BORDER      := Color(0.30, 0.85, 0.30, 1.00)
const COLOR_END_TURN_BORDER_HOVER := Color(0.40, 1.00, 0.40, 1.00)
const COLOR_END_TURN_TEXT        := Color(0.85, 1.00, 0.85, 1.00)

## Solo / primary action button — green variant
const COLOR_BTN_PRIMARY_BG       := Color(0.08, 0.20, 0.10, 0.90)
const COLOR_BTN_PRIMARY_BG_HOVER := Color(0.12, 0.32, 0.15, 1.00)
const COLOR_BTN_PRIMARY_BORDER   := Color(0.25, 0.65, 0.30, 0.80)
const COLOR_BTN_PRIMARY_BORDER_HOVER := Color(0.35, 0.90, 0.40, 1.00)
const COLOR_BTN_PRIMARY_TEXT     := Color(0.70, 1.00, 0.75, 1.00)

## Secondary / navigation button — purple variant
const COLOR_BTN_SECONDARY_BG       := Color(0.10, 0.08, 0.20, 0.90)
const COLOR_BTN_SECONDARY_BG_HOVER := Color(0.18, 0.14, 0.35, 1.00)
const COLOR_BTN_SECONDARY_BORDER   := Color(0.35, 0.30, 0.60, 0.80)
const COLOR_BTN_SECONDARY_BORDER_HOVER := Color(0.55, 0.45, 0.90, 1.00)
const COLOR_BTN_SECONDARY_TEXT     := Color(0.80, 0.85, 1.00, 1.00)

## Destructive / negative button — red variant
const COLOR_BTN_DANGER_BG       := Color(0.20, 0.05, 0.05, 0.90)
const COLOR_BTN_DANGER_BG_HOVER := Color(0.35, 0.08, 0.08, 1.00)
const COLOR_BTN_DANGER_BORDER   := Color(0.70, 0.20, 0.20, 0.80)
const COLOR_BTN_DANGER_TEXT     := Color(1.00, 0.70, 0.70, 1.00)

## Disabled button
const COLOR_BTN_DISABLED_BG     := Color(0.07, 0.06, 0.10, 0.60)
const COLOR_BTN_DISABLED_TEXT   := Color(0.40, 0.38, 0.45, 0.60)

# ---------------------------------------------------------------------------
# Input field colors
# ---------------------------------------------------------------------------

const COLOR_INPUT_BG          := Color(0.06, 0.05, 0.14, 0.90)
const COLOR_INPUT_BORDER      := Color(0.30, 0.28, 0.50, 0.70)
const COLOR_INPUT_FOCUS_BORDER := Color(0.30, 0.85, 1.00, 0.90)  # cyan when focused
const COLOR_INPUT_TEXT        := Color(0.88, 0.88, 0.92, 1.00)
const COLOR_INPUT_PLACEHOLDER := Color(0.45, 0.45, 0.55, 0.65)

# ---------------------------------------------------------------------------
# Scrollbar colors
# ---------------------------------------------------------------------------

const COLOR_SCROLL_BG         := Color(0.06, 0.05, 0.12, 0.80)
const COLOR_SCROLL_GRABBER    := Color(0.28, 0.22, 0.48, 0.80)
const COLOR_SCROLL_GRABBER_HOVER := Color(0.42, 0.35, 0.68, 1.00)

# ---------------------------------------------------------------------------
# Font sizes
# ---------------------------------------------------------------------------

## Game title / large headings
const FONT_SIZE_TITLE   := 46

## Section headers
const FONT_SIZE_HEADER  := 28

## Sub-headers / prominent labels
const FONT_SIZE_SUBHEAD := 18

## Standard body text
const FONT_SIZE_BODY    := 14

## Small labels, tooltips, version strings
const FONT_SIZE_SMALL   := 12

## Stat readouts (HP numbers, energy, block)
const FONT_SIZE_STAT    := 13

## Card name labels
const FONT_SIZE_CARD_NAME := 13

## Card cost label
const FONT_SIZE_CARD_COST := 15

## Card description / RichTextLabel
const FONT_SIZE_CARD_DESC := 11

## HP bar overlay number
const FONT_SIZE_HP_BAR  := 11

# ---------------------------------------------------------------------------
# Layout constants
# ---------------------------------------------------------------------------

## Standard inner padding for panels and containers
const PADDING_XS  := 4
const PADDING_SM  := 6
const PADDING_MD  := 10
const PADDING_LG  := 16
const PADDING_XL  := 24

## Standard margins between UI sections
const MARGIN_XS   := 4
const MARGIN_SM   := 8
const MARGIN_MD   := 14
const MARGIN_LG   := 20
const MARGIN_XL   := 32

## Corner radii
const CORNER_SM   := 4    ## Input fields, small chips
const CORNER_MD   := 6    ## HUD panels, most buttons
const CORNER_LG   := 8    ## End-turn button, cards
const CORNER_XL   := 10   ## Modal / result panel

## Border widths
const BORDER_THIN   := 1
const BORDER_NORMAL := 2
const BORDER_THICK  := 3

## Standard button heights
const BTN_HEIGHT_SM  := 36
const BTN_HEIGHT_MD  := 40
const BTN_HEIGHT_LG  := 44

## Standard animation durations (seconds)
const ANIM_FAST   := 0.10
const ANIM_NORMAL := 0.18
const ANIM_SLOW   := 0.35

## Card dimensions
const CARD_WIDTH  := 120
const CARD_HEIGHT := 180

## HP bar default width
const HP_BAR_WIDTH  := 200
const HP_BAR_HEIGHT := 22
