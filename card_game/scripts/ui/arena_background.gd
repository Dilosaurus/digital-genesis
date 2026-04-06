extends Control
## Full parallax battle arena background with particle effects and shader overlays.
## Loads ArenaConfig per act/floor, manages 8 ParallaxLayer nodes, atmospheric
## particle systems, and post-process shader passes.
## Drop as the first child of CombatScene (behind everything).

# ---- Arena mappings (enemy -> arena folder for custom art, unchanged) ----
const ARENA_MAP: Dictionary = {
	"metatron": "arena_metatron",
	"michael": "arena_michael",
	"azrael": "arena_azrael",
	"gabriel": "arena_gabriel",
	"raphael": "arena_raphael",
	"uriel": "arena_uriel",
}
const COMMON_ARENAS: Array[String] = [
	"arena_corrupted_halls",
	"arena_server_crypt",
	"arena_void_bridge",
	"arena_defiled_garden",
]

# ---- Node references (populated in _ready or after scene-tree addition) ----
var _parallax_bg: ParallaxBackground = null
var _parallax_layers: Array[ParallaxLayer] = []
var _layer_sprites: Array[Sprite2D] = []

var _primary_particles: GPUParticles2D = null
var _secondary_particles: GPUParticles2D = null
var _ambient_particles: GPUParticles2D = null

var _canvas_modulate: CanvasModulate = null
var _shader_overlay: ColorRect = null
var _vignette_overlay: ColorRect = null

# ---- State ----
var _config: ArenaConfig = null
var _current_act: int = 1
var _current_mood: String = ""
var _time: float = 0.0
var _ambient_tween: Tween = null
var _ambient_offset: Vector2 = Vector2.ZERO
var _drift_offsets: Array[Vector2] = []   # per-layer random drift targets
var _drift_seeds: Array[float] = []       # per-layer random phase seeds
var _boss_phase: bool = false

signal arena_loaded(arena_name: String)

# ---- Particle preset definitions ----
const _PARTICLE_PRESETS: Dictionary = {
	"rain": {
		"amount": 120,
		"lifetime": 1.2,
		"direction": Vector3(0.15, 1.0, 0.0),
		"initial_velocity_min": 280.0,
		"initial_velocity_max": 420.0,
		"gravity": Vector3(0, 600, 0),
		"scale_min": 0.3,
		"scale_max": 0.6,
		"color": Color(0.6, 0.7, 0.95, 0.35),
		"emission_box": Vector3(700, 0, 0),
	},
	"embers": {
		"amount": 35,
		"lifetime": 2.5,
		"direction": Vector3(0.1, -1.0, 0.0),
		"initial_velocity_min": 20.0,
		"initial_velocity_max": 60.0,
		"gravity": Vector3(0, -30, 0),
		"scale_min": 0.8,
		"scale_max": 2.0,
		"color": Color(1.0, 0.55, 0.15, 0.7),
		"emission_box": Vector3(600, 50, 0),
	},
	"data_fragments": {
		"amount": 50,
		"lifetime": 3.0,
		"direction": Vector3(0.0, 1.0, 0.0),
		"initial_velocity_min": 30.0,
		"initial_velocity_max": 80.0,
		"gravity": Vector3(0, 20, 0),
		"scale_min": 0.4,
		"scale_max": 1.0,
		"color": Color(0.3, 1.0, 0.6, 0.45),
		"emission_box": Vector3(600, 0, 0),
	},
	"divine_motes": {
		"amount": 40,
		"lifetime": 4.0,
		"direction": Vector3(0.0, -1.0, 0.0),
		"initial_velocity_min": 10.0,
		"initial_velocity_max": 35.0,
		"gravity": Vector3(0, -15, 0),
		"scale_min": 0.6,
		"scale_max": 1.5,
		"color": Color(1.0, 0.95, 0.7, 0.5),
		"emission_box": Vector3(600, 100, 0),
	},
	"sparks": {
		"amount": 25,
		"lifetime": 0.8,
		"direction": Vector3(0.0, -1.0, 0.0),
		"initial_velocity_min": 80.0,
		"initial_velocity_max": 200.0,
		"gravity": Vector3(0, 300, 0),
		"scale_min": 0.3,
		"scale_max": 0.8,
		"color": Color(1.0, 0.85, 0.3, 0.8),
		"emission_box": Vector3(400, 0, 0),
	},
	"dust": {
		"amount": 20,
		"lifetime": 5.0,
		"direction": Vector3(0.3, -0.1, 0.0),
		"initial_velocity_min": 5.0,
		"initial_velocity_max": 15.0,
		"gravity": Vector3(0, -2, 0),
		"scale_min": 0.5,
		"scale_max": 1.2,
		"color": Color(0.8, 0.75, 0.65, 0.2),
		"emission_box": Vector3(600, 300, 0),
	},
}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	anchors_preset = 15
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_find_or_create_nodes()

	# Default to act 1
	_config = ArenaConfig.get_config_for_act(1)
	_apply_config()


func _find_or_create_nodes() -> void:
	# ParallaxBackground
	_parallax_bg = _find_child_of_type("ParallaxBackground") as ParallaxBackground
	if not _parallax_bg:
		_parallax_bg = ParallaxBackground.new()
		_parallax_bg.name = "ParallaxBG"
		add_child(_parallax_bg)

	# Discover or create 8 ParallaxLayer nodes (L0..L7)
	_parallax_layers.clear()
	_layer_sprites.clear()
	for i in range(8):
		var layer_name := "L%d" % i
		var layer: ParallaxLayer = _parallax_bg.get_node_or_null(layer_name) as ParallaxLayer
		if not layer:
			layer = ParallaxLayer.new()
			layer.name = layer_name
			_parallax_bg.add_child(layer)
		_parallax_layers.append(layer)

		var sprite: Sprite2D = layer.get_node_or_null("Sprite") as Sprite2D
		if not sprite:
			sprite = Sprite2D.new()
			sprite.name = "Sprite"
			sprite.centered = false
			layer.add_child(sprite)
		_layer_sprites.append(sprite)

	# Particles
	_primary_particles = _find_child_of_type("GPUParticles2D", "PrimaryParticles") as GPUParticles2D
	if not _primary_particles:
		_primary_particles = GPUParticles2D.new()
		_primary_particles.name = "PrimaryParticles"
		_primary_particles.emitting = false
		add_child(_primary_particles)

	_secondary_particles = _find_child_of_type("GPUParticles2D", "SecondaryParticles") as GPUParticles2D
	if not _secondary_particles:
		_secondary_particles = GPUParticles2D.new()
		_secondary_particles.name = "SecondaryParticles"
		_secondary_particles.emitting = false
		add_child(_secondary_particles)

	_ambient_particles = _find_child_of_type("GPUParticles2D", "AmbientParticles") as GPUParticles2D
	if not _ambient_particles:
		_ambient_particles = GPUParticles2D.new()
		_ambient_particles.name = "AmbientParticles"
		_ambient_particles.emitting = false
		add_child(_ambient_particles)

	# Canvas modulate for ambient color
	_canvas_modulate = _find_child_of_type("CanvasModulate") as CanvasModulate
	if not _canvas_modulate:
		_canvas_modulate = CanvasModulate.new()
		_canvas_modulate.name = "AmbientTint"
		add_child(_canvas_modulate)

	# Shader overlay (fullscreen ColorRect with ShaderMaterial)
	_shader_overlay = get_node_or_null("ShaderOverlay") as ColorRect
	if not _shader_overlay:
		_shader_overlay = ColorRect.new()
		_shader_overlay.name = "ShaderOverlay"
		_shader_overlay.anchors_preset = 15
		_shader_overlay.anchor_right = 1.0
		_shader_overlay.anchor_bottom = 1.0
		_shader_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shader_overlay.color = Color(1, 1, 1, 0)  # transparent until shader is set
		add_child(_shader_overlay)

	# Vignette overlay
	_vignette_overlay = get_node_or_null("VignetteOverlay") as ColorRect
	if not _vignette_overlay:
		_vignette_overlay = ColorRect.new()
		_vignette_overlay.name = "VignetteOverlay"
		_vignette_overlay.anchors_preset = 15
		_vignette_overlay.anchor_right = 1.0
		_vignette_overlay.anchor_bottom = 1.0
		_vignette_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vignette_overlay.color = Color(0, 0, 0, 0)
		add_child(_vignette_overlay)


func _find_child_of_type(type_name: String, node_name: String = "") -> Node:
	for child in get_children():
		if child.get_class() == type_name:
			if node_name == "" or child.name == node_name:
				return child
	# Also search inside ParallaxBG
	if _parallax_bg:
		for child in _parallax_bg.get_children():
			if child.get_class() == type_name:
				if node_name == "" or child.name == node_name:
					return child
	return null

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func load_arena(enemy_id: String) -> void:
	## Legacy compatibility: load arena art for a given enemy, then apply
	## the current act config on top.
	var arena_name: String = ARENA_MAP.get(enemy_id, "") as String
	if arena_name == "":
		arena_name = COMMON_ARENAS[randi() % COMMON_ARENAS.size()]

	# Determine act from GameManager if available
	var act := 1
	if Engine.has_singleton("GameManager") or has_node("/root/GameManager"):
		var gm = Engine.get_singleton("GameManager") if Engine.has_singleton("GameManager") else get_node("/root/GameManager")
		if gm and gm.get("current_run") and gm.current_run.get("act"):
			act = gm.current_run.act

	setup_arena(act, _floor_type_from_enemy(enemy_id))
	_load_enemy_arena_art(enemy_id, arena_name)
	arena_loaded.emit(arena_name)


func setup_arena(act: int, floor_type: String = "normal") -> void:
	## Full setup: pick config by act, apply layers/particles/shaders.
	_current_act = act
	_config = ArenaConfig.get_config_for_act(act)
	_apply_config()

	# Set mood based on floor type
	if floor_type == "boss":
		set_mood("boss")
	elif floor_type == "elite":
		set_mood("elite")
	else:
		set_mood("")

	_start_ambient_drift()


func transition_to(act: int) -> void:
	## Smoothly transition from current arena to a new act.
	var target_config: ArenaConfig = ArenaConfig.get_config_for_act(act)
	var tween: Tween = create_tween().set_parallel(true)

	# Fade ambient color
	tween.tween_property(_canvas_modulate, "color", target_config.ambient_color, 1.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# Fade vignette
	var target_vignette_alpha: float = target_config.vignette_intensity
	tween.tween_property(_vignette_overlay, "color",
		Color(0, 0, 0, target_vignette_alpha), 1.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# After fade, swap config fully
	tween.chain().tween_callback(func():
		_current_act = act
		_config = target_config
		_apply_config()
	)


func set_mood(mood: String) -> void:
	## Apply a mood variant (e.g. "boss", "elite") from the current config.
	_current_mood = mood
	if not _config:
		return

	if mood == "" or not _config.mood_variants.has(mood):
		# Reset to base config
		_canvas_modulate.color = _config.ambient_color
		_apply_particles(_config.particle_presets)
		_apply_shader_overlays(_config.shader_overlays)
		return

	var variant: Dictionary = _config.mood_variants[mood]
	if variant.has("ambient_color"):
		var tween: Tween = create_tween()
		tween.tween_property(_canvas_modulate, "color", variant["ambient_color"], 0.8) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	if variant.has("particle_overrides"):
		_apply_particles(variant["particle_overrides"])

	if variant.has("shader_overrides"):
		_apply_shader_overlays(variant["shader_overrides"])


func enter_boss_phase() -> void:
	## Dramatic boss phase transition: darken sky, add effects, intensify.
	_boss_phase = true
	var tween: Tween = create_tween().set_parallel(true)

	# Darken ambient
	var dark_color: Color = _canvas_modulate.color * 0.6
	dark_color.a = 1.0
	tween.tween_property(_canvas_modulate, "color", dark_color, 1.0) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	# Intensify vignette
	tween.tween_property(_vignette_overlay, "color",
		Color(0, 0, 0, 0.65), 1.0) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	# Add glitch shader
	_apply_shader_overlays(["res://shaders/glitch_distortion.gdshader"])

	# Boost particles
	if _primary_particles and _primary_particles.emitting:
		_primary_particles.amount = int(_primary_particles.amount * 1.5)
	if _secondary_particles and _secondary_particles.emitting:
		_secondary_particles.amount = int(_secondary_particles.amount * 1.5)


func exit_boss_phase() -> void:
	_boss_phase = false
	if _config:
		_apply_config()
		if _current_mood != "":
			set_mood(_current_mood)

# ---------------------------------------------------------------------------
# Process — drives layer motion
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta

	if not _config or _parallax_layers.is_empty():
		return

	# Get screen-shake offset if available
	var shake: Vector2 = Vector2.ZERO
	if has_node("/root/ScreenShake"):
		var ss = get_node("/root/ScreenShake")
		if ss.has_method("get_current_offset"):
			shake = ss.get_current_offset()

	# Apply parallax scroll offset (screen-shake + ambient drift)
	_parallax_bg.scroll_offset = shake + _ambient_offset

	# Drive per-layer motion types
	for i in range(mini(_config.layers.size(), _parallax_layers.size())):
		var layer_def: Dictionary = _config.layers[i]
		var layer: ParallaxLayer = _parallax_layers[i]
		var motion_type: String = layer_def.get("motion_type", "static")
		var speed: float = layer_def.get("motion_speed", 0.0)

		match motion_type:
			"scroll":
				# Continuous horizontal looping scroll
				layer.motion_offset.x -= speed * delta
			"drift":
				# Slow random drift using sine with per-layer seed
				if i < _drift_seeds.size():
					var seed_val: float = _drift_seeds[i]
					layer.motion_offset.x = sin(_time * 0.3 + seed_val) * speed * 2.0
					layer.motion_offset.y = cos(_time * 0.25 + seed_val * 1.7) * speed * 0.8
			"float":
				# Vertical sin-wave bob
				if i < _drift_seeds.size():
					var seed_val: float = _drift_seeds[i]
					layer.motion_offset.y = sin(_time * speed * 0.5 + seed_val) * 8.0
			"static":
				pass  # No motion

# ---------------------------------------------------------------------------
# Internal — config application
# ---------------------------------------------------------------------------

func _apply_config() -> void:
	if not _config:
		return

	# Set parallax scales and initialize per-layer data
	_drift_seeds.clear()
	_drift_offsets.clear()
	for i in range(mini(_config.layers.size(), _parallax_layers.size())):
		var layer_def: Dictionary = _config.layers[i]
		var layer: ParallaxLayer = _parallax_layers[i]
		var p_scale = Vector2(layer_def.get("parallax_scale", Vector2(0.5, 0.5)))
		layer.motion_scale = p_scale
		layer.motion_offset = Vector2.ZERO

		# Random seed per layer for drift/float variation
		_drift_seeds.append(randf() * TAU)
		_drift_offsets.append(Vector2.ZERO)

	# Ambient color
	if _canvas_modulate:
		_canvas_modulate.color = _config.ambient_color

	# Vignette
	if _vignette_overlay:
		_vignette_overlay.color = Color(0, 0, 0, _config.vignette_intensity)

	# Particles
	_apply_particles(_config.particle_presets)

	# Shader overlays
	_apply_shader_overlays(_config.shader_overlays)


func _apply_particles(preset_names: Array) -> void:
	var particle_nodes: Array = [_primary_particles, _secondary_particles, _ambient_particles]

	# Stop all first
	for p in particle_nodes:
		if p:
			p.emitting = false

	# Assign presets to available particle nodes
	for i in range(mini(preset_names.size(), particle_nodes.size())):
		var preset_name: String = preset_names[i]
		if not _PARTICLE_PRESETS.has(preset_name):
			continue

		var preset: Dictionary = _PARTICLE_PRESETS[preset_name]
		var node: GPUParticles2D = particle_nodes[i]
		if not node:
			continue

		_configure_particle_node(node, preset)
		node.emitting = true


func _configure_particle_node(node: GPUParticles2D, preset: Dictionary) -> void:
	node.amount = int(preset.get("amount", 30))
	node.lifetime = float(preset.get("lifetime", 2.0))
	node.position = get_viewport_rect().size * 0.5  # center of screen

	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(preset.get("direction", Vector3(0, 1, 0)))
	mat.initial_velocity_min = float(preset.get("initial_velocity_min", 10.0))
	mat.initial_velocity_max = float(preset.get("initial_velocity_max", 50.0))
	mat.gravity = Vector3(preset.get("gravity", Vector3(0, 0, 0)))
	mat.scale_min = float(preset.get("scale_min", 0.5))
	mat.scale_max = float(preset.get("scale_max", 1.0))
	mat.color = Color(preset.get("color", Color.WHITE))
	mat.spread = 25.0

	# Emission shape: box
	var emission_box = Vector3(preset.get("emission_box", Vector3(400, 0, 0)))
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = emission_box

	node.process_material = mat


func _apply_shader_overlays(shader_paths: Array) -> void:
	if not _shader_overlay:
		return

	if shader_paths.is_empty():
		_shader_overlay.material = null
		_shader_overlay.color = Color(1, 1, 1, 0)
		return

	# Load the first shader as the main overlay
	var shader_path: String = shader_paths[0]
	if ResourceLoader.exists(shader_path):
		var shader: Shader = load(shader_path)
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = shader
		_shader_overlay.material = mat
		_shader_overlay.color = Color(1, 1, 1, 1)
	else:
		_shader_overlay.material = null
		_shader_overlay.color = Color(1, 1, 1, 0)

# ---------------------------------------------------------------------------
# Internal — legacy arena art loading (textures from asset folders)
# ---------------------------------------------------------------------------

func _load_enemy_arena_art(enemy_id: String, arena_name: String) -> void:
	## Try to load actual texture files from the arena folder and assign them
	## to the parallax layer sprites.
	var layers_path := "res://assets/backgrounds/arenas/%s/layers/" % arena_name
	var has_layers := ResourceLoader.exists(layers_path + "bg_far.png")

	if has_layers:
		# Map old 3-layer names to the new 8-layer system
		var layer_mapping: Array = [
			{"file": "bg_far",  "target_index": 0},
			{"file": "bg_mid",  "target_index": 3},
			{"file": "bg_near", "target_index": 6},
		]
		for mapping in layer_mapping:
			var tex_path: String = layers_path + str(mapping["file"]) + ".png"
			if ResourceLoader.exists(tex_path) and int(mapping["target_index"]) < _layer_sprites.size():
				var tex: Texture2D = load(tex_path)
				_layer_sprites[int(mapping["target_index"])].texture = tex
	else:
		# Try single full-screen image
		var single_path := "res://assets/backgrounds/arenas/%s/output_3440x1440.png" % arena_name
		if not ResourceLoader.exists(single_path):
			single_path = "res://assets/backgrounds/arenas/%s/output.png" % arena_name
		if ResourceLoader.exists(single_path):
			var tex: Texture2D = load(single_path)
			if _layer_sprites.size() > 0:
				_layer_sprites[0].texture = tex

	print("ArenaBackground: Loaded '%s' for enemy '%s'" % [arena_name, enemy_id])


func _floor_type_from_enemy(enemy_id: String) -> String:
	## Infer floor type from enemy ID for mood selection.
	var bosses: Array = ["metatron", "hexaghost"]
	var elites: Array = ["michael", "gabriel", "raphael", "uriel", "azrael"]
	if enemy_id in bosses:
		return "boss"
	elif enemy_id in elites:
		return "elite"
	return "normal"

# ---------------------------------------------------------------------------
# Ambient drift (subtle continuous parallax motion)
# ---------------------------------------------------------------------------

func _start_ambient_drift() -> void:
	if _ambient_tween and _ambient_tween.is_valid():
		_ambient_tween.kill()
	_ambient_drift_loop()


func _ambient_drift_loop() -> void:
	if not is_inside_tree():
		return

	var target: Vector2 = Vector2(
		randf_range(-20.0, 20.0),
		randf_range(-10.0, 10.0)
	)
	var duration: float = randf_range(4.0, 8.0)

	_ambient_tween = create_tween()
	_ambient_tween.tween_property(self, "_ambient_offset", target, duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_ambient_tween.tween_callback(_ambient_drift_loop)
