## turn_banner.gd
## Displays a full-width cinematic turn announcement banner.
##
## Slide-in from off-screen right, hold, then slide out to off-screen left.
## Auto-dismisses after HOLD_TIME seconds. Supports optional colour tinting.
## All mouse input is passed through (mouse_filter = IGNORE throughout).
extends Control

# Timing
const SLIDE_IN_TIME  := 0.4
const HOLD_TIME      := 2.2
const SLIDE_OUT_TIME := 0.35
const SCALE_PUNCH    := 1.04   # brief scale overshoot on arrival

# Color presets
const COLOR_PLAYER_TURN := Color(0.92, 0.88, 0.60, 1.0)  # warm gold
const COLOR_ENEMY_TURN  := Color(0.95, 0.40, 0.35, 1.0)  # vivid red-orange
const COLOR_SYSTEM      := Color(0.55, 0.85, 1.00, 1.0)  # cyan info

@onready var _band:       Panel  = $BannerContainer/BandPanel
@onready var _label:      Label  = $BannerContainer/BandPanel/TurnLabel
@onready var _top_line:   HSeparator = $BannerContainer/BandPanel/TopLine
@onready var _bot_line:   HSeparator = $BannerContainer/BandPanel/BottomLine
@onready var _deco_line:  HSeparator = $BannerContainer/BandPanel/DecoLine

var _active_tween: Tween = null

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Show the banner with given text and optional color tint.
## Calling while already visible restarts the animation.
func show_banner(text: String, color: Color = COLOR_PLAYER_TURN) -> void:
	# Kill any running animation
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	_label.text = text
	_label.add_theme_color_override("font_color", color)
	# Ensure label fills the band and is centered
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Tint the separator lines to match
	var line_color := color.darkened(0.3)
	line_color.a = 0.60
	_apply_separator_color(_top_line, line_color)
	_apply_separator_color(_bot_line, line_color)
	_apply_separator_color(_deco_line, color * Color(1, 1, 1, 0.70))

	visible = true

	# --- Initial state: band off-screen right, fully transparent ---
	var viewport_w: float = get_viewport_rect().size.x
	var viewport_h: float = get_viewport_rect().size.y
	var band_w:     float = _band.size.x   # 1921 px wide
	var band_h:     float = _band.size.y   # ~140 px tall
	# Center the band vertically on screen
	_band.position.y = (viewport_h - band_h) / 2.0 - _band.get_parent().position.y
	_band.position.x  = viewport_w          # start just off the right edge
	_band.modulate.a  = 0.0
	_band.scale       = Vector2(1.0, 0.85)  # slightly squashed vertically

	_active_tween = create_tween().set_parallel(false)

	# Phase 1: slide in + fade in + vertical scale expand
	var slide_in := _active_tween.parallel()
	slide_in.tween_property(_band, "position:x",  _band_center_x(), SLIDE_IN_TIME)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	slide_in.tween_property(_band, "modulate:a",  1.0, SLIDE_IN_TIME * 0.6)\
		.set_ease(Tween.EASE_OUT)
	slide_in.tween_property(_band, "scale", Vector2(1.0, SCALE_PUNCH), SLIDE_IN_TIME * 0.5)\
		.set_ease(Tween.EASE_OUT)

	# Phase 1b: settle scale back to 1.0
	_active_tween.tween_property(_band, "scale", Vector2(1.0, 1.0), SLIDE_IN_TIME * 0.4)\
		.set_ease(Tween.EASE_IN_OUT)

	# Phase 2: hold
	_active_tween.tween_interval(HOLD_TIME)

	# Phase 3: slide out left + fade out
	var slide_out := _active_tween.parallel()
	slide_out.tween_property(_band, "position:x", -band_w, SLIDE_OUT_TIME)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	slide_out.tween_property(_band, "modulate:a", 0.0, SLIDE_OUT_TIME * 0.7)\
		.set_ease(Tween.EASE_IN)

	_active_tween.tween_callback(_on_animation_finished)


## Convenience wrappers for common banner types
func show_player_turn(turn_number: int = 0) -> void:
	var text: String = "YOUR TURN" if turn_number <= 0 else "TURN  %d" % turn_number
	show_banner(text, COLOR_PLAYER_TURN)


func show_enemy_turn() -> void:
	show_banner("ENEMY TURN", COLOR_ENEMY_TURN)


func show_message(text: String) -> void:
	show_banner(text, COLOR_SYSTEM)


# ---------- internal helpers ----------

func _band_center_x() -> float:
	# Center the band horizontally within the viewport
	var viewport_w := get_viewport_rect().size.x
	return (viewport_w - _band.size.x) / 2.0


func _apply_separator_color(sep: HSeparator, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_top    = 1.0
	style.content_margin_bottom = 1.0
	sep.add_theme_stylebox_override("separator", style)


func _on_animation_finished() -> void:
	visible = false
	_active_tween = null
