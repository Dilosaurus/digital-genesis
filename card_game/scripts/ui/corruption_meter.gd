## corruption_meter.gd
## Displays corruption level as a coloured horizontal bar with tier label.
##
## Preserves the original update_corruption() signature.
## Adds:
##   - Animated bar width changes
##   - Warning glow pulse at high corruption (tiers 2+)
##   - Tooltip explaining the mechanic
extends Control

# ---------------------------------------------------------------------------
# Tier definitions — mirrored from original
# ---------------------------------------------------------------------------

const TIER_NAMES  := ["PURE", "TAINTED", "CORRUPTED", "DEMONIC"]
const TIER_COLORS := [
	Color(0.25, 0.75, 1.00),   # Pure:      cyan
	Color(0.85, 0.60, 0.15),   # Tainted:   amber
	Color(0.65, 0.10, 0.80),   # Corrupted: purple
	Color(0.90, 0.10, 0.10),   # Demonic:   red
]
const TIER_DESCS := [
	"PURE\nNo corruption effects active.",
	"TAINTED\nMild corruption: cards occasionally misfire.",
	"CORRUPTED\nSevere corruption: card costs increase,\nrandom debuffs each turn.",
	"DEMONIC\nCritical corruption: lose HP each turn,\ncards may become Curses permanently.",
]

# Glow threshold: start pulsing at tier 2 (CORRUPTED) and above
const GLOW_THRESHOLD_TIER := 2

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

@onready var _outer_panel:   Panel  = $OuterPanel
@onready var _tier_label:    Label  = $OuterPanel/HeaderRow/TierLabel
@onready var _value_label:   Label  = $OuterPanel/HeaderRow/ValueLabel
@onready var _bar_track:     Panel  = $OuterPanel/BarTrack
@onready var _bar_fill:      Panel  = $OuterPanel/BarTrack/BarFill
@onready var _tooltip_panel: Panel  = $OuterPanel/TooltipPanel
@onready var _tooltip_popup: Panel  = $OuterPanel/TooltipPanel/TooltipPopup
@onready var _tooltip_label: Label  = $OuterPanel/TooltipPanel/TooltipPopup/TooltipLabel

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _glow_tween:  Tween = null
var _bar_tween:   Tween = null
var _current_tier: int  = 0


func _ready() -> void:
	_tooltip_popup.visible = false
	_tooltip_panel.mouse_entered.connect(_show_tooltip)
	_tooltip_panel.mouse_exited.connect(_hide_tooltip)
	# Initial render at zero
	update_corruption(0, 100, 0)


# ---------------------------------------------------------------------------
# Public API — original signature preserved, fully re-implemented
# ---------------------------------------------------------------------------

func update_corruption(corruption: int, max_corruption: int, tier: int) -> void:
	var clamped_tier := clampi(tier, 0, 3)
	_current_tier    = clamped_tier

	var pct    := clampf(float(corruption) / maxf(max_corruption, 1), 0.0, 1.0)
	var color: Color = TIER_COLORS[clamped_tier]
	var track_w: float = _bar_track.size.x

	# Animate bar fill width
	if _bar_tween and _bar_tween.is_valid():
		_bar_tween.kill()
	_bar_tween = create_tween()
	_bar_tween.tween_property(_bar_fill, "size:x", track_w * pct, 0.25)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Update bar fill colour
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = color
	for r in ["corner_radius_top_left", "corner_radius_top_right",
			"corner_radius_bottom_right", "corner_radius_bottom_left"]:
		fill_style.set(r, 4)
	_bar_fill.add_theme_stylebox_override("panel", fill_style)

	# Update labels
	_tier_label.text = TIER_NAMES[clamped_tier]
	_tier_label.add_theme_color_override("font_color", color)
	_value_label.text = "%d/%d" % [corruption, max_corruption]

	# Warning glow
	if clamped_tier >= GLOW_THRESHOLD_TIER:
		_start_glow(color)
	else:
		_stop_glow()


# ---------------------------------------------------------------------------
# Glow animation
# ---------------------------------------------------------------------------

func _start_glow(color: Color) -> void:
	if _glow_tween and _glow_tween.is_valid():
		return  # already running at the same tier

	_stop_glow()

	# Animate the outer panel border colour
	_glow_tween = create_tween().set_loops()

	var bright := color
	bright.a    = 0.90
	var dim     := color
	dim.a       = 0.20

	# We animate modulate on the outer panel to get a pulsing glow without
	# constantly creating new StyleBoxes (cheaper than tween_method on color).
	_glow_tween.tween_property(_outer_panel, "modulate",
		Color(1.0 + color.r * 0.35, 1.0 + color.g * 0.20, 1.0 + color.b * 0.35, 1.0), 0.65)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_glow_tween.tween_property(_outer_panel, "modulate",
		Color(1.0, 1.0, 1.0, 1.0), 0.65)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _stop_glow() -> void:
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
		_glow_tween = null
	_outer_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)


# ---------------------------------------------------------------------------
# Tooltip
# ---------------------------------------------------------------------------

func _show_tooltip() -> void:
	_tooltip_label.text    = TIER_DESCS[_current_tier]
	_tooltip_popup.visible = true


func _hide_tooltip() -> void:
	_tooltip_popup.visible = false
