@tool
extends Control
## Reusable resource orb (HP, Mana, etc.) driven by the liquid_orb shader.
##
## Usage:
##   var orb = preload("res://scenes/ui/resource_orb.tscn").instantiate()
##   orb.max_value   = 100
##   orb.orb_color   = Color(0.18, 0.55, 1.0)  # blue for mana
##   orb.label_text  = "MP"
##   orb.set_value(67)

# ── Signals ───────────────────────────────────────────────────────────────────
signal value_changed(new_value: int, old_value: int)
signal value_depleted()
signal value_full()

# ── Exports ───────────────────────────────────────────────────────────────────
@export var max_value: int = 100 :
	set(v):
		max_value = maxi(1, v)
		_refresh_shader()
		_refresh_label()

@export var current_value: int = 100 :
	set(v):
		current_value = clampi(v, 0, max_value)
		_refresh_shader()
		_refresh_label()

## Tint applied to the orb's fill colour.
@export var orb_color: Color = Color(0.18, 0.55, 1.0) :
	set(v):
		orb_color = v
		_apply_orb_color()

## Short label shown below the numeric readout (e.g. "HP" or "MP").
@export var label_text: String = "HP" :
	set(v):
		label_text = v
		if _label:
			_label.text = v

## Ornate frame texture overlaid on top of the liquid orb. Set per-instance
## (e.g. health.png for HP, mp.png for mana). The transparent glass center of
## the frame lets the liquid fill show through.
@export var frame_texture: Texture2D = null :
	set(v):
		frame_texture = v
		if _frame:
			_frame.texture = v

# ── Internal ──────────────────────────────────────────────────────────────────
@onready var _orb_rect : ColorRect = $OrbRect
@onready var _value_label : Label  = $ValueLabel
@onready var _label       : Label  = $TypeLabel
@onready var _frame       : TextureRect = $FrameOverlay

var _material : ShaderMaterial
var _tween    : Tween

# fill_value uniform: maps ratio [0,1] → shader range [−1, 1].
# fill_value = −1 → empty, +1 → full, 0 → half.
const _SHADER_EMPTY : float = -1.0
const _SHADER_FULL  : float =  1.0

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	# In the editor, don't duplicate the material — that would mark the scene
	# dirty on every open. Just bind the existing one so colors/fill preview.
	if Engine.is_editor_hint():
		_material = _orb_rect.material as ShaderMaterial
	else:
		# CRITICAL: duplicate the material so each orb instance has its own shader state.
		# Without this, all orbs share one ShaderMaterial and overwrite each other's fill/color.
		_orb_rect.material = _orb_rect.material.duplicate()
		_material = _orb_rect.material as ShaderMaterial
	_apply_orb_color()
	_refresh_shader()
	_refresh_label()
	if _label:
		_label.text = label_text
	# Apply the per-instance frame texture if one was assigned before _ready.
	if _frame and frame_texture != null:
		_frame.texture = frame_texture

# ── Public API ────────────────────────────────────────────────────────────────

## Set the current value instantly (no animation).
func set_value(new_val: int) -> void:
	var old = current_value
	current_value = clampi(new_val, 0, max_value)
	_refresh_shader()
	_refresh_label()
	if current_value != old:
		value_changed.emit(current_value, old)
	if current_value <= 0:
		value_depleted.emit()
	elif current_value >= max_value:
		value_full.emit()

## Animate the orb draining by `amount`.  Returns the actual damage taken.
func take_damage(amount: int) -> int:
	var old    := current_value
	var actual := mini(amount, current_value)
	var target := current_value - actual
	_animate_to(target, old)
	return actual

## Animate the orb filling by `amount`.  Returns the actual heal applied.
func heal(amount: int) -> int:
	var old    := current_value
	var actual := mini(amount, max_value - current_value)
	var target := current_value + actual
	_animate_to(target, old)
	return actual

# ── Private helpers ───────────────────────────────────────────────────────────

func _ratio() -> float:
	if max_value <= 0:
		return 0.0
	return float(current_value) / float(max_value)

func _ratio_to_shader(ratio: float) -> float:
	# Map [0, 1] → [SHADER_EMPTY, SHADER_FULL]
	return lerpf(_SHADER_EMPTY, _SHADER_FULL, ratio)

func _refresh_shader() -> void:
	if not _material:
		return
	_material.set_shader_parameter("fill_value", _ratio_to_shader(_ratio()))

func _refresh_label() -> void:
	if _value_label:
		_value_label.text = "%d/%d" % [current_value, max_value]

func _apply_orb_color() -> void:
	if not _material:
		return
	# Drive ALL colours from orb_color so each orb matches its theme (red for HP, blue for MP).
	var inner := orb_color.lightened(0.18)
	var outer  := orb_color.darkened(0.25)
	var back   := orb_color.lightened(0.35)
	_material.set_shader_parameter("front_fill_inner_colour", Vector3(inner.r, inner.g, inner.b))
	_material.set_shader_parameter("front_fill_outer_colour", Vector3(outer.r, outer.g, outer.b))
	_material.set_shader_parameter("back_fill_colour",        Vector3(back.r,  back.g,  back.b))
	# Ring, fresnel, and glow — derive from orb_color so the whole orb matches
	var ring := orb_color.darkened(0.7)
	var fresnel := orb_color.lightened(0.4)
	var glow := orb_color.lightened(0.2)
	_material.set_shader_parameter("ring_colour",             Vector3(ring.r, ring.g, ring.b))
	_material.set_shader_parameter("fresnel_colour",          Vector3(fresnel.r, fresnel.g, fresnel.b))
	_material.set_shader_parameter("inner_ring_glow_colour",  Vector3(glow.r, glow.g, glow.b))

func _animate_to(target: int, old_value: int) -> void:
	# Kill any running tween so animations don't stack.
	if _tween and _tween.is_valid():
		_tween.kill()

	var start_ratio  := _ratio()
	var target_ratio := float(clampi(target, 0, max_value)) / float(max_value)

	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Animate the shader fill_value uniform.
	var _anim_cb := func(r: float) -> void:
		_material.set_shader_parameter("fill_value", _ratio_to_shader(r))
		# Keep the label in sync during animation.
		var display_val: int = int(round(r * max_value))
		if _value_label:
			_value_label.text = "%d/%d" % [display_val, max_value]
	_tween.tween_method(_anim_cb, start_ratio, target_ratio, 0.45)

	# Commit final state after tween completes.
	_tween.tween_callback(func() -> void:
		current_value = clampi(target, 0, max_value)
		_refresh_label()
		value_changed.emit(current_value, old_value)
		if current_value <= 0:
			value_depleted.emit()
		elif current_value >= max_value:
			value_full.emit()
	)
