## deaths_door_overlay.gd
## Full-screen overlay that intensifies as player HP drops.
##
## Three HP thresholds drive visual escalation:
##   > 50% HP  — invisible
##   25–50% HP — dim red vignette, status text shown
##   10–25% HP — brighter vignette, faster pulse
##   < 10% HP  — heartbeat pulse at critical rate
##
## Original public API (show_deaths_door, hide_overlay, show_dead) preserved.
extends Control

# HP thresholds (fractions)
const THRESHOLD_WARN     := 0.50   # vignette appears
const THRESHOLD_CRITICAL := 0.10   # heartbeat starts

# Vignette colours
const VIGNETTE_WARN_COLOR     := Color(0.25, 0.0, 0.0, 0.0)
const VIGNETTE_CRITICAL_COLOR := Color(0.35, 0.0, 0.0, 0.0)
const VIGNETTE_DEAD_COLOR     := Color(0.20, 0.0, 0.0, 0.0)

const MAX_VIGNETTE_ALPHA := 0.55
const DIM_ALPHA_MAX      := 0.30

# Heartbeat timing
const HEARTBEAT_PULSE_ALPHA := 0.70   # peak alpha during beat
const HEARTBEAT_FAST_TIME   := 0.35   # interval at critical HP
const HEARTBEAT_SLOW_TIME   := 0.70   # interval at warning HP

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

@onready var _dim_layer:       ColorRect     = $DimLayer
@onready var _vign_top:        ColorRect     = $VignetteTop
@onready var _vign_bottom:     ColorRect     = $VignetteBottom
@onready var _vign_left:       ColorRect     = $VignetteLeft
@onready var _vign_right:      ColorRect     = $VignetteRight
@onready var _status_container: PanelContainer = $StatusContainer
@onready var _status_label:    Label         = $StatusContainer/StatusLabel

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var pulse_tween: Tween  = null   # kept as var for back-compat with callers
var _hp_ratio:   float  = 1.0


func _ready() -> void:
	visible = false
	_set_vignette_alpha(0.0)


# ---------------------------------------------------------------------------
# Public API — original signatures preserved
# ---------------------------------------------------------------------------

## Called each time HP changes. hp_ratio is current_hp / max_hp (0.0–1.0).
func update_hp(hp_ratio: float) -> void:
	_hp_ratio = clampf(hp_ratio, 0.0, 1.0)

	if _hp_ratio > THRESHOLD_WARN:
		hide_overlay()
		return

	visible = true

	# Intensity ramps from 0 at THRESHOLD_WARN down to 1.0 at 0 HP
	var intensity := 1.0 - (_hp_ratio / THRESHOLD_WARN)

	_apply_vignette(intensity)

	if _hp_ratio <= THRESHOLD_CRITICAL:
		_start_heartbeat(HEARTBEAT_FAST_TIME, intensity)
	else:
		_start_heartbeat(HEARTBEAT_SLOW_TIME, intensity * 0.6)


## Legacy: show the overlay for a "Death's Door" turns-remaining message.
func show_deaths_door(turns_remaining: int) -> void:
	visible = true
	_status_label.text  = "DEATH'S DOOR  —  %d turn%s remain" % [
		turns_remaining,
		"s" if turns_remaining != 1 else ""
	]
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.30, 0.25, 1.0))
	_status_container.visible = true
	_apply_vignette(0.75)
	_start_heartbeat(HEARTBEAT_SLOW_TIME, 0.50)


## Hide the overlay entirely.
func hide_overlay() -> void:
	_stop_pulse()
	_status_container.visible = false

	if not visible:
		return

	# Fade out smoothly
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.30).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		visible      = false
		modulate.a   = 1.0
		_set_vignette_alpha(0.0)
	)


## Show eliminated state — static heavy vignette, no pulse.
func show_dead() -> void:
	_stop_pulse()
	visible = true
	modulate.a = 1.0

	_dim_layer.color = Color(0.05, 0.0, 0.0, DIM_ALPHA_MAX)
	_set_vignette_color_and_alpha(VIGNETTE_DEAD_COLOR, MAX_VIGNETTE_ALPHA * 0.7)

	_status_label.text = "ELIMINATED"
	_status_label.add_theme_color_override("font_color", Color(0.50, 0.10, 0.10, 1.0))
	_status_container.visible = true


# ---------------------------------------------------------------------------
# Internal — vignette
# ---------------------------------------------------------------------------

func _apply_vignette(intensity: float) -> void:
	var a := clampf(intensity * MAX_VIGNETTE_ALPHA, 0.0, MAX_VIGNETTE_ALPHA)
	_dim_layer.color = Color(0.0, 0.0, 0.0, intensity * DIM_ALPHA_MAX)
	_set_vignette_alpha(a)


func _set_vignette_alpha(a: float) -> void:
	var base := VIGNETTE_WARN_COLOR
	base.a    = a
	_vign_top.color    = base
	_vign_bottom.color = base
	_vign_left.color   = base
	_vign_right.color  = base


func _set_vignette_color_and_alpha(base: Color, a: float) -> void:
	var c  := base
	c.a    = a
	_vign_top.color    = c
	_vign_bottom.color = c
	_vign_left.color   = c
	_vign_right.color  = c


# ---------------------------------------------------------------------------
# Internal — heartbeat pulse
# ---------------------------------------------------------------------------

func _start_heartbeat(beat_time: float, peak_alpha: float) -> void:
	_stop_pulse()

	pulse_tween = create_tween().set_loops()

	# Quick double-thump: dim → bright → dim → bright → long rest
	pulse_tween.tween_property(_dim_layer, "color:a",
		peak_alpha, beat_time * 0.20).set_ease(Tween.EASE_OUT)
	pulse_tween.tween_property(_dim_layer, "color:a",
		peak_alpha * 0.30, beat_time * 0.15).set_ease(Tween.EASE_IN)
	pulse_tween.tween_property(_dim_layer, "color:a",
		peak_alpha * 0.80, beat_time * 0.18).set_ease(Tween.EASE_OUT)
	pulse_tween.tween_property(_dim_layer, "color:a",
		0.0, beat_time * 0.47).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)


func _stop_pulse() -> void:
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
		pulse_tween = null
