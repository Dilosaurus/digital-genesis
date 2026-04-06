extends Node2D
## Michael VFX — visor glow and holy aura particles.
## Add as a child of MichaelPuppet. Creates all effects programmatically.

# --- Eye glow config ---
const EYE_COLOR := Color(0.9, 0.7, 0.2)
const EYE_OFFSETS: Array[Vector2] = [Vector2(0, 5)]
const EYE_ENERGY_MIN := 1.0
const EYE_ENERGY_MAX := 2.5
const EYE_ENERGY_IDLE := 1.5
const EYE_PULSE_DURATION := 2.0
const EYE_TEXTURE_SCALE := 0.3

# --- Aura config ---
const AURA_COLOR := Color(0.9, 0.8, 0.3, 0.5)
const AURA_AMOUNT := 15
const AURA_LIFETIME := 2.5
const AURA_VELOCITY := 20.0
const AURA_POSITION := Vector2(0, -100)

# --- Node references ---
var _eye_lights: Array[PointLight2D] = []
var _aura: GPUParticles2D = null

# --- Tween tracking ---
var _pulse_tween: Tween = null
var _intensify_tween: Tween = null


func _ready() -> void:
	_create_eye_lights()
	_create_aura()
	_start_pulse()


# ---------------------------------------------------------------------------
# Visor glow setup
# ---------------------------------------------------------------------------

func _create_eye_lights() -> void:
	var head: Node2D = get_parent().get_node("Torso/Head")
	var texture := _create_radial_gradient()

	for offset in EYE_OFFSETS:
		var light := PointLight2D.new()
		light.texture = texture
		light.texture_scale = EYE_TEXTURE_SCALE
		light.color = EYE_COLOR
		light.energy = EYE_ENERGY_IDLE
		light.position = offset
		head.add_child(light)
		_eye_lights.append(light)


func _create_radial_gradient() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))

	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	return tex


# ---------------------------------------------------------------------------
# Visor glow pulse loop
# ---------------------------------------------------------------------------

func _start_pulse() -> void:
	_kill_tween("_pulse_tween")
	_pulse_tween = create_tween().set_loops()
	for light in _eye_lights:
		_pulse_tween.tween_property(light, "energy", EYE_ENERGY_MAX, EYE_PULSE_DURATION) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	for light in _eye_lights:
		_pulse_tween.tween_property(light, "energy", EYE_ENERGY_MIN, EYE_PULSE_DURATION) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


# ---------------------------------------------------------------------------
# Visor glow public methods
# ---------------------------------------------------------------------------

func intensify_glow() -> void:
	_kill_tween("_pulse_tween")
	_kill_tween("_intensify_tween")
	_intensify_tween = create_tween()
	for light in _eye_lights:
		_intensify_tween.tween_property(light, "energy", 4.0, 0.1) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_intensify_tween.parallel().tween_property(light, "color", Color.WHITE, 0.1) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_intensify_tween.tween_interval(0.3)
	for light in _eye_lights:
		_intensify_tween.tween_property(light, "energy", EYE_ENERGY_IDLE, 0.2) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		_intensify_tween.parallel().tween_property(light, "color", EYE_COLOR, 0.2) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_intensify_tween.tween_callback(_start_pulse)


func dim_glow() -> void:
	_kill_tween("_pulse_tween")
	_kill_tween("_intensify_tween")
	var tw := create_tween()
	for light in _eye_lights:
		tw.parallel().tween_property(light, "energy", 0.0, 0.5) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)


func reset_glow() -> void:
	_kill_tween("_pulse_tween")
	_kill_tween("_intensify_tween")
	for light in _eye_lights:
		light.energy = EYE_ENERGY_IDLE
		light.color = EYE_COLOR
	_start_pulse()


# ---------------------------------------------------------------------------
# Holy aura setup
# ---------------------------------------------------------------------------

func _create_aura() -> void:
	_aura = GPUParticles2D.new()
	_aura.position = AURA_POSITION
	_aura.amount = AURA_AMOUNT
	_aura.lifetime = AURA_LIFETIME
	_aura.preprocess = 1.0
	_aura.emitting = true

	var mat := ParticleProcessMaterial.new()

	# Direction and velocity — slow upward drift (holy aura rising).
	mat.direction = Vector3(0, -1, 0)
	mat.initial_velocity_min = AURA_VELOCITY * 0.8
	mat.initial_velocity_max = AURA_VELOCITY
	mat.gravity = Vector3(0, -10, 0)
	mat.spread = 30.0

	# Emission shape — box covering the body.
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(80, 150, 0)

	# Scale randomisation.
	mat.scale_min = 2.0
	mat.scale_max = 5.0

	# Color: gold fading to transparent.
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, AURA_COLOR)
	color_ramp.set_color(1, Color(AURA_COLOR.r, AURA_COLOR.g, AURA_COLOR.b, 0.0))
	var color_tex := GradientTexture1D.new()
	color_tex.gradient = color_ramp
	mat.color_ramp = color_tex

	_aura.process_material = mat
	add_child(_aura)


# ---------------------------------------------------------------------------
# Holy aura public methods
# ---------------------------------------------------------------------------

func intensify_aura() -> void:
	if not _aura:
		return
	_aura.amount = AURA_AMOUNT * 2
	_aura.emitting = true
	var mat: ParticleProcessMaterial = _aura.process_material
	mat.initial_velocity_min = AURA_VELOCITY * 1.6
	mat.initial_velocity_max = AURA_VELOCITY * 2.0


func stop_aura() -> void:
	if not _aura:
		return
	_aura.emitting = false


func reset_aura() -> void:
	if not _aura:
		return
	_aura.amount = AURA_AMOUNT
	_aura.emitting = true
	var mat: ParticleProcessMaterial = _aura.process_material
	mat.initial_velocity_min = AURA_VELOCITY * 0.8
	mat.initial_velocity_max = AURA_VELOCITY


# ---------------------------------------------------------------------------
# Combined public API — called by MichaelPuppet
# ---------------------------------------------------------------------------

func intensify() -> void:
	intensify_glow()
	intensify_aura()


func dim() -> void:
	dim_glow()
	stop_aura()


func reset() -> void:
	reset_glow()
	reset_aura()


# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

func _kill_tween(tween_name: String) -> void:
	var tw: Tween = get(tween_name)
	if tw and tw.is_valid():
		tw.kill()
	set(tween_name, null)
