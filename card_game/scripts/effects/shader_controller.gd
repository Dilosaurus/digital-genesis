## Controls dissolve and chromatic-aberration shaders on a puppet rig.
##
## Add as a child of the puppet node, then call setup(puppet_root).
##
## Usage:
##   shader_controller.setup(puppet_node)
##   shader_controller.play_dissolve(1.5)
##   shader_controller.flash_aberration(10.0, 0.2)
##   shader_controller.reset_shaders()
extends Node

var puppet: Node2D

var _dissolve_shader: Shader
var _aberration_shader: Shader

## Every Sprite2D descendant that received a dissolve material.
var _dissolve_sprites: Array[Sprite2D] = []

## The ShaderMaterial applied to the puppet root for chromatic aberration.
var _aberration_material: ShaderMaterial

## Active tweens so we can kill them when resetting.
var _dissolve_tween: Tween
var _aberration_tween: Tween


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

## Store the target puppet, pre-load shaders, and apply materials.
func setup(target: Node2D) -> void:
	puppet = target

	_dissolve_shader = load("res://shaders/dissolve.gdshader") as Shader
	_aberration_shader = load("res://shaders/chromatic_aberration.gdshader") as Shader

	_apply_dissolve_materials()
	_apply_aberration_material()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Dissolve all sprite children from fully visible to fully dissolved.
func play_dissolve(duration: float = 1.0) -> void:
	_kill_tween(_dissolve_tween)

	_dissolve_tween = create_tween().set_parallel(true)

	for sprite in _dissolve_sprites:
		if not is_instance_valid(sprite):
			continue
		var mat := sprite.material as ShaderMaterial
		if not mat:
			continue

		# Reset to fully visible before animating
		mat.set_shader_parameter("dissolve_amount", 0.0)

		_dissolve_tween.tween_property(
			sprite,
			"material:shader_parameter/dissolve_amount",
			1.0,
			duration
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	# Pulse the edge color brightness over the dissolve duration
	if not _dissolve_sprites.is_empty():
		var pulse_tween := create_tween()
		pulse_tween.set_loops(ceili(duration / 0.3))
		for sprite in _dissolve_sprites:
			if not is_instance_valid(sprite):
				continue
			var mat := sprite.material as ShaderMaterial
			if not mat:
				continue
			# Bright pulse
			pulse_tween.parallel().tween_property(
				sprite,
				"material:shader_parameter/edge_color",
				Color(0.9, 0.5, 1.0, 1.0),
				0.15
			)
		for sprite in _dissolve_sprites:
			if not is_instance_valid(sprite):
				continue
			var mat := sprite.material as ShaderMaterial
			if not mat:
				continue
			# Return to base purple
			pulse_tween.parallel().tween_property(
				sprite,
				"material:shader_parameter/edge_color",
				Color(0.6, 0.3, 1.0, 1.0),
				0.15
			)


## Quick chromatic aberration punch for hit feedback.
func flash_aberration(intensity: float = 8.0, duration: float = 0.15) -> void:
	_kill_tween(_aberration_tween)

	if not _aberration_material:
		return

	_aberration_material.set_shader_parameter("aberration_amount", intensity)

	_aberration_tween = create_tween()
	_aberration_tween.tween_property(
		puppet,
		"material:shader_parameter/aberration_amount",
		0.0,
		duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


## Reset every shader parameter to its default (no visible effect).
func reset_shaders() -> void:
	_kill_tween(_dissolve_tween)
	_kill_tween(_aberration_tween)

	for sprite in _dissolve_sprites:
		if not is_instance_valid(sprite):
			continue
		var mat := sprite.material as ShaderMaterial
		if not mat:
			continue
		mat.set_shader_parameter("dissolve_amount", 0.0)
		mat.set_shader_parameter("edge_color", Color(0.6, 0.3, 1.0, 1.0))

	if _aberration_material:
		_aberration_material.set_shader_parameter("aberration_amount", 0.0)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _apply_dissolve_materials() -> void:
	_dissolve_sprites.clear()
	var sprites := _find_sprites(puppet)

	for sprite in sprites:
		var mat := ShaderMaterial.new()
		mat.shader = _dissolve_shader
		mat.set_shader_parameter("dissolve_amount", 0.0)
		mat.set_shader_parameter("edge_color", Color(0.6, 0.3, 1.0, 1.0))
		mat.set_shader_parameter("edge_width", 0.05)
		sprite.material = mat
		_dissolve_sprites.append(sprite)


func _apply_aberration_material() -> void:
	_aberration_material = ShaderMaterial.new()
	_aberration_material.shader = _aberration_shader
	_aberration_material.set_shader_parameter("aberration_amount", 0.0)
	_aberration_material.set_shader_parameter("aberration_direction", Vector2(1.0, 0.0))
	puppet.material = _aberration_material


## Recursively find all Sprite2D descendants.
func _find_sprites(node: Node) -> Array[Sprite2D]:
	var result: Array[Sprite2D] = []
	for child in node.get_children():
		if child is Sprite2D:
			result.append(child as Sprite2D)
		result.append_array(_find_sprites(child))
	return result


func _kill_tween(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()
