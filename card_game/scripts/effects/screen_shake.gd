## Autoload singleton for screen shake effects.
##
## Register as an autoload named "ScreenShake" in Project Settings.
## Uses viewport canvas_transform so it works with or without a Camera2D.
##
## Usage:
##   ScreenShake.shake()          # default shake
##   ScreenShake.shake_light()    # subtle hit feedback
##   ScreenShake.shake_heavy()    # boss attack / big impact
extends Node

var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0
var _shake_decay: bool = true
var _initial_intensity: float = 0.0

## The original canvas transform origin, captured once per shake so we can
## restore it cleanly even if the viewport moves between shakes.
var _origin_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Run during pause so UI shakes still play if the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if _shake_timer <= 0.0:
		return

	_shake_timer -= delta

	if _shake_timer <= 0.0:
		_current_offset = Vector2.ZERO
		_stop_shake()
		return

	# Decay intensity linearly toward zero over the full duration.
	if _shake_decay and _shake_duration > 0.0:
		var progress: float = _shake_timer / _shake_duration
		_shake_intensity = _initial_intensity * progress

	# Random offset within a circle of current intensity.
	var offset := Vector2(
		randf_range(-_shake_intensity, _shake_intensity),
		randf_range(-_shake_intensity, _shake_intensity),
	)

	_current_offset = offset
	_apply_offset(offset)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Standard shake. Good for card plays, taking damage, etc.
func shake(intensity: float = 10.0, duration: float = 0.3, decay: bool = true) -> void:
	_start_shake(intensity, duration, decay)


## Heavy shake for boss attacks, critical hits, or big moments.
func shake_heavy(intensity: float = 20.0, duration: float = 0.5) -> void:
	_start_shake(intensity, duration, true)


## Light shake for minor hits, card discards, small feedback.
func shake_light(intensity: float = 5.0, duration: float = 0.15) -> void:
	_start_shake(intensity, duration, true)


## Returns the current shake offset (for parallax backgrounds, etc.)
var _current_offset: Vector2 = Vector2.ZERO

func get_current_offset() -> Vector2:
	return _current_offset


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _start_shake(intensity: float, duration: float, decay: bool) -> void:
	# If a stronger shake is already running, keep the stronger one.
	if intensity < _shake_intensity:
		return

	_shake_intensity = intensity
	_initial_intensity = intensity
	_shake_duration = duration
	_shake_timer = duration
	_shake_decay = decay

	# Snapshot the current canvas origin so we restore correctly.
	var vp := get_viewport()
	if vp:
		_origin_offset = vp.canvas_transform.origin


func _apply_offset(offset: Vector2) -> void:
	var vp := get_viewport()
	if not vp:
		return

	var xform := vp.canvas_transform
	xform.origin = _origin_offset + offset
	vp.canvas_transform = xform


func _stop_shake() -> void:
	_shake_timer = 0.0
	_shake_intensity = 0.0
	_initial_intensity = 0.0

	# Restore the canvas transform to its pre-shake origin.
	var vp := get_viewport()
	if not vp:
		return

	var xform := vp.canvas_transform
	xform.origin = _origin_offset
	vp.canvas_transform = xform
