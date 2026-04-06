extends Node2D
## Azrael VFX — soul fire eyes and bone dust particles.
## Add as a child of AzraelPuppet. Creates all effects programmatically.

# --- Eye glow config ---
const EYE_COLOR := Color(0.2, 0.8, 0.6)
const EYE_OFFSETS: Array[Vector2] = [Vector2(-12, -5), Vector2(12, -5)]
const EYE_ENERGY_MIN := 1.0
const EYE_ENERGY_MAX := 2.5
const EYE_ENERGY_IDLE := 1.5
const EYE_PULSE_DURATION := 2.0
const EYE_TEXTURE_SCALE := 0.3

# --- Bone dust config ---
const DUST_COLOR := Color(0.8, 0.7, 0.6, 0.4)
const DUST_AMOUNT := 15
const DUST_LIFETIME := 2.5
const DUST_VELOCITY := 15.0
const DUST_POSITION := Vector2(0, -100)

# --- Node references ---
var _eye_lights: Array[PointLight2D] = []
var _dust: GPUParticles2D = null

# --- Tween tracking ---
var _pulse_tween: Tween = null
var _intensify_tween: Tween = null


func _ready() -> void:
	_create_eye_lights()
	_create_dust()
	_start_pulse()


# ---------------------------------------------------------------------------
# Eye glow setup
# ---------------------------------------------------------------------------

func _create_eye_lights() -> void:
	var head: Node2D = get_parent().get_node("Torso/SkullHood")
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
# Eye glow pulse loop
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
# Eye glow public methods
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
# Bone dust setup
# ---------------------------------------------------------------------------

func _create_dust() -> void:
	_dust = GPUParticles2D.new()
	_dust.position = DUST_POSITION
	_dust.amount = DUST_AMOUNT
	_dust.lifetime = DUST_LIFETIME
	_dust.preprocess = 1.0
	_dust.emitting = true

	var mat := ParticleProcessMaterial.new()

	# Direction and velocity — slow downward drift (bone dust falling).
	mat.direction = Vector3(0, 1, 0)
	mat.initial_velocity_min = DUST_VELOCITY * 0.8
	mat.initial_velocity_max = DUST_VELOCITY
	mat.gravity = Vector3(0, 20, 0)
	mat.spread = 30.0

	# Emission shape — box covering the body.
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(80, 150, 0)

	# Scale randomisation — small particles.
	mat.scale_min = 1.0
	mat.scale_max = 3.0

	# Color: bone-white fading to transparent.
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, DUST_COLOR)
	color_ramp.set_color(1, Color(DUST_COLOR.r, DUST_COLOR.g, DUST_COLOR.b, 0.0))
	var color_tex := GradientTexture1D.new()
	color_tex.gradient = color_ramp
	mat.color_ramp = color_tex

	_dust.process_material = mat
	add_child(_dust)


# ---------------------------------------------------------------------------
# Bone dust public methods
# ---------------------------------------------------------------------------

func intensify_dust() -> void:
	if not _dust:
		return
	_dust.amount = DUST_AMOUNT * 2
	_dust.emitting = true
	var mat: ParticleProcessMaterial = _dust.process_material
	mat.initial_velocity_min = DUST_VELOCITY * 1.6
	mat.initial_velocity_max = DUST_VELOCITY * 2.0


func stop_dust() -> void:
	if not _dust:
		return
	_dust.emitting = false


func reset_dust() -> void:
	if not _dust:
		return
	_dust.amount = DUST_AMOUNT
	_dust.emitting = true
	var mat: ParticleProcessMaterial = _dust.process_material
	mat.initial_velocity_min = DUST_VELOCITY * 0.8
	mat.initial_velocity_max = DUST_VELOCITY


# ---------------------------------------------------------------------------
# Combined public API — called by AzraelPuppet
# ---------------------------------------------------------------------------

func intensify() -> void:
	intensify_glow()
	intensify_dust()


func dim() -> void:
	dim_glow()
	stop_dust()


func reset() -> void:
	reset_glow()
	reset_dust()


# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

func _kill_tween(tween_name: String) -> void:
	var tw: Tween = get(tween_name)
	if tw and tw.is_valid():
		tw.kill()
	set(tween_name, null)
