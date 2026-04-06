extends Node2D
## Tommy VFX — chest gem glow and power sparks.
## Add as a child of TommyPuppet. Creates all effects programmatically.

# --- Gem glow config ---
const GEM_COLOR := Color(0.2, 1.0, 0.3)
const GEM_OFFSET := Vector2(0, -10)
const GEM_ENERGY_MIN := 0.8
const GEM_ENERGY_MAX := 2.0
const GEM_ENERGY_IDLE := 1.2
const GEM_PULSE_DURATION := 1.8
const GEM_TEXTURE_SCALE := 0.4

# --- Spark config ---
const SPARK_COLOR := Color(0.3, 1.0, 0.4, 0.6)
const SPARK_AMOUNT := 10
const SPARK_LIFETIME := 1.5
const SPARK_VELOCITY := 20.0
const SPARK_POSITION := Vector2(0, -120)

# --- Node references ---
var _gem_light: PointLight2D = null
var _sparks: GPUParticles2D = null

# --- Tween tracking ---
var _pulse_tween: Tween = null
var _intensify_tween: Tween = null


func _ready() -> void:
	_create_gem_light()
	_create_sparks()
	_start_pulse()


# ---------------------------------------------------------------------------
# Gem glow setup
# ---------------------------------------------------------------------------

func _create_gem_light() -> void:
	var chest: Node2D = get_parent().get_node("Torso")
	var texture := _create_radial_gradient()

	_gem_light = PointLight2D.new()
	_gem_light.texture = texture
	_gem_light.texture_scale = GEM_TEXTURE_SCALE
	_gem_light.color = GEM_COLOR
	_gem_light.energy = GEM_ENERGY_IDLE
	_gem_light.position = GEM_OFFSET
	chest.add_child(_gem_light)


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
# Gem glow pulse loop
# ---------------------------------------------------------------------------

func _start_pulse() -> void:
	_kill_tween("_pulse_tween")
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_gem_light, "energy", GEM_ENERGY_MAX, GEM_PULSE_DURATION) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_gem_light, "energy", GEM_ENERGY_MIN, GEM_PULSE_DURATION) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


# ---------------------------------------------------------------------------
# Gem glow public methods
# ---------------------------------------------------------------------------

func intensify_glow() -> void:
	_kill_tween("_pulse_tween")
	_kill_tween("_intensify_tween")
	_intensify_tween = create_tween()
	_intensify_tween.tween_property(_gem_light, "energy", 4.0, 0.1) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_intensify_tween.parallel().tween_property(_gem_light, "color", Color.WHITE, 0.1) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_intensify_tween.tween_interval(0.3)
	_intensify_tween.tween_property(_gem_light, "energy", GEM_ENERGY_IDLE, 0.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_intensify_tween.parallel().tween_property(_gem_light, "color", GEM_COLOR, 0.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_intensify_tween.tween_callback(_start_pulse)


func dim_glow() -> void:
	_kill_tween("_pulse_tween")
	_kill_tween("_intensify_tween")
	var tw := create_tween()
	tw.tween_property(_gem_light, "energy", 0.0, 0.5) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)


func reset_glow() -> void:
	_kill_tween("_pulse_tween")
	_kill_tween("_intensify_tween")
	_gem_light.energy = GEM_ENERGY_IDLE
	_gem_light.color = GEM_COLOR
	_start_pulse()


# ---------------------------------------------------------------------------
# Spark setup
# ---------------------------------------------------------------------------

func _create_sparks() -> void:
	_sparks = GPUParticles2D.new()
	_sparks.position = SPARK_POSITION
	_sparks.amount = SPARK_AMOUNT
	_sparks.lifetime = SPARK_LIFETIME
	_sparks.preprocess = 1.0
	_sparks.emitting = true

	var mat := ParticleProcessMaterial.new()

	# Direction — upward drift (power radiating from armor).
	mat.direction = Vector3(0, -1, 0)
	mat.initial_velocity_min = SPARK_VELOCITY * 0.6
	mat.initial_velocity_max = SPARK_VELOCITY
	mat.gravity = Vector3(0, -10, 0)
	mat.spread = 40.0

	# Emission shape — narrow box around chest.
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(50, 80, 0)

	# Scale.
	mat.scale_min = 1.0
	mat.scale_max = 2.5

	# Color: green fading to transparent.
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, SPARK_COLOR)
	color_ramp.set_color(1, Color(SPARK_COLOR.r, SPARK_COLOR.g, SPARK_COLOR.b, 0.0))
	var color_tex := GradientTexture1D.new()
	color_tex.gradient = color_ramp
	mat.color_ramp = color_tex

	_sparks.process_material = mat
	add_child(_sparks)


# ---------------------------------------------------------------------------
# Spark public methods
# ---------------------------------------------------------------------------

func intensify_sparks() -> void:
	if not _sparks:
		return
	_sparks.amount = SPARK_AMOUNT * 3
	_sparks.emitting = true
	var mat: ParticleProcessMaterial = _sparks.process_material
	mat.initial_velocity_min = SPARK_VELOCITY * 1.5
	mat.initial_velocity_max = SPARK_VELOCITY * 2.5


func stop_sparks() -> void:
	if not _sparks:
		return
	_sparks.emitting = false


func reset_sparks() -> void:
	if not _sparks:
		return
	_sparks.amount = SPARK_AMOUNT
	_sparks.emitting = true
	var mat: ParticleProcessMaterial = _sparks.process_material
	mat.initial_velocity_min = SPARK_VELOCITY * 0.6
	mat.initial_velocity_max = SPARK_VELOCITY


# ---------------------------------------------------------------------------
# Combined public API — called by TommyPuppet
# ---------------------------------------------------------------------------

func intensify() -> void:
	intensify_glow()
	intensify_sparks()


func dim() -> void:
	dim_glow()
	stop_sparks()


func reset() -> void:
	reset_glow()
	reset_sparks()


# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

func _kill_tween(tween_name: String) -> void:
	var tw: Tween = get(tween_name)
	if tw and tw.is_valid():
		tw.kill()
	set(tween_name, null)
