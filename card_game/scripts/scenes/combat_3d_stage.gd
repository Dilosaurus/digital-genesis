## 3D combat stage that renders characters in a SubViewport.
## Embeds into the 2D combat scene via SubViewportContainer.
## Creates a 2.5D look with fixed camera, toon lighting, and cel shading.
extends SubViewportContainer
class_name Combat3DStage

## The 3D viewport
var _viewport: SubViewport
var _camera: Camera3D
var _env: WorldEnvironment

## Character spawn points
var _player_spawn: Node3D
var _enemy_spawn: Node3D

## Current player puppet
var _player_puppet: PuppetBase3D = null

## Toon shader (loaded once, applied to all characters)
var _toon_shader: Shader


func _ready() -> void:
	# Make container fill the combat area but be transparent where no 3D exists
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Critical: SubViewportContainer must not consume input
	set_process_input(false)
	set_process_unhandled_input(false)

	_build_viewport()
	_build_3d_scene()


func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)  # Render at decent resolution
	_viewport.transparent_bg = true         # Transparent so 2D shows through
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.gui_disable_input = true  # Don't let 3D viewport steal input
	_viewport.handle_input_locally = false
	add_child(_viewport)


func _build_3d_scene() -> void:
	# ── Camera (2.5D angle) ────────────────────────────────────────
	_camera = Camera3D.new()
	_camera.position = Vector3(0.0, 3.5, 12.0)
	_camera.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	_camera.fov = 32.0  # Wider view to show arena
	_camera.current = true
	_viewport.add_child(_camera)

	# ── Lighting ───────────────────────────────────────────────────
	# Main directional light (sun-like, from upper-front)
	var dir_light := DirectionalLight3D.new()
	dir_light.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	dir_light.light_energy = 1.2
	dir_light.light_color = Color(1.0, 0.97, 0.92)  # Warm white
	dir_light.shadow_enabled = true
	_viewport.add_child(dir_light)

	# Fill light (softer, from opposite side)
	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-30.0, 150.0, 0.0)
	fill_light.light_energy = 0.4
	fill_light.light_color = Color(0.7, 0.8, 1.0)  # Cool blue fill
	fill_light.shadow_enabled = false
	_viewport.add_child(fill_light)

	# ── Environment ────────────────────────────────────────────────
	_env = WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.02, 0.06)  # Dark purple-black void
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.05, 0.04, 0.08)
	environment.fog_density = 0.015
	environment.fog_aerial_perspective = 0.5
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.3, 0.3, 0.35)
	environment.ambient_light_energy = 0.5
	_env.environment = environment
	_viewport.add_child(_env)

	# ── Spawn Points ──────────────────────────────────────────────
	_player_spawn = Node3D.new()
	_player_spawn.name = "PlayerSpawn"
	_player_spawn.position = Vector3(-1.2, -0.5, 0.5)
	_viewport.add_child(_player_spawn)

	_enemy_spawn = Node3D.new()
	_enemy_spawn.name = "EnemySpawn"
	_enemy_spawn.position = Vector3(1.2, -0.5, 0.5)
	_viewport.add_child(_enemy_spawn)

	_build_arena()

	# Toon shader for cel-shaded character look
	if ResourceLoader.exists("res://shaders/toon_shader.gdshader"):
		_toon_shader = load("res://shaders/toon_shader.gdshader")


# ── Public API ─────────────────────────────────────────────────────────────

## Spawn the player character in the 3D scene
func spawn_player(character_id: String) -> PuppetBase3D:
	if _player_puppet:
		_player_puppet.queue_free()

	var puppet := PlayerPuppet3D.new()
	_player_spawn.add_child(puppet)

	# Face right (toward enemies)
	puppet.rotation_degrees.y = 25.0
	puppet.scale = Vector3(0.8, 0.8, 0.8)

	puppet.setup_character(character_id)

	# Apply toon shader to the model
	if _toon_shader:
		_apply_toon_shader(puppet)

	_player_puppet = puppet
	return puppet


## Spawn an enemy in the 3D scene
func spawn_enemy(enemy_id: String, slot_index: int = 0, total_enemies: int = 1) -> PuppetBase3D:
	var puppet := PlayerPuppet3D.new()
	_enemy_spawn.add_child(puppet)

	# Position enemies spread out
	var spread := 1.8
	var offset := (slot_index - (total_enemies - 1) / 2.0) * spread
	puppet.position = Vector3(offset, 0.0, 0.0)

	# Face left (toward player)
	puppet.rotation_degrees.y = -25.0
	puppet.scale = Vector3(0.8, 0.8, 0.8)

	# Map enemy IDs to skeleton models
	var model_id = ENEMY_MODEL_MAP.get(enemy_id, "skeleton_warrior")
	puppet.setup_character(model_id)

	return puppet


## Enemy ID → 3D model mapping
const ENEMY_MODEL_MAP: Dictionary = {
	# Act 1 — corrupted tech enemies (skeletons + machines)
	"jaw_worm":           "skeleton_minion",
	"louse_red":          "skeleton_rogue",
	"cultist":            "skeleton_mage",
	"firewall_sentinel":  "clanker",           # robotic sentinel
	"data_leech":         "skeleton_rogue",
	"memory_worm":        "skeleton_minion",
	# Act 2 — cathedral enemies (undead + corrupted holy)
	"quantum_ghost":      "vampire",            # spectral presence
	"core_guardian":      "frost_golem",        # massive guardian
	# Act 3 — void core enemies (angels + constructs)
	"seraph_drone":       "clanker",            # aggressive combat drone
	# Elite enemies — unique threatening models
	"hexaghost":          "werewolf",           # terrifying beast
	"corrupted_throne":   "black_knight",       # corrupted authority
	"fallen_archangel":   "tiefling",           # fallen divine
	# Bosses — each visually distinct and imposing
	"gabriel":            "paladin",            # holy warrior angel
	"michael":            "black_knight",       # armored judge
	"raphael":            "witch",              # healer turned dark
	"uriel":              "barbarian",          # brute force angel
	"azrael":             "vampire",            # death incarnate
	"metatron":           "frost_golem",        # cosmic final boss
}


## Get the player puppet for animation calls
func get_player_puppet() -> PuppetBase3D:
	return _player_puppet


func get_camera() -> Camera3D:
	return _camera


## Camera shake effect
func do_camera_shake(intensity: float = 0.1, duration: float = 0.2) -> void:
	if not _camera:
		return
	var original_pos := _camera.position
	var tween := create_tween()
	var steps := 6
	for i in range(steps):
		var offset := Vector3(
			randf_range(-intensity, intensity),
			randf_range(-intensity * 0.5, intensity * 0.5),
			0.0
		)
		tween.tween_property(_camera, "position", original_pos + offset, duration / steps)
	tween.tween_property(_camera, "position", original_pos, duration / steps)


## Set lighting colors based on the current act
func set_act_lighting(act: int) -> void:
	if not _camera:
		return
	# Find the directional lights (first two DirectionalLight3D children)
	var dir_lights: Array = []
	for child in _viewport.get_children():
		if child is DirectionalLight3D:
			dir_lights.append(child)

	var key_color: Color
	var fill_color: Color
	var ambient_color: Color
	var bg_color: Color
	var fog_color: Color

	match act:
		1:  # Corrupted Server Farm — cool green tech
			key_color = Color(0.7, 1.0, 0.8)
			fill_color = Color(0.3, 0.6, 0.5)
			ambient_color = Color(0.15, 0.25, 0.2)
			bg_color = Color(0.02, 0.04, 0.03)
			fog_color = Color(0.03, 0.06, 0.04)
		2:  # Neural Cathedral — warm gold
			key_color = Color(1.0, 0.85, 0.6)
			fill_color = Color(0.6, 0.4, 0.2)
			ambient_color = Color(0.3, 0.22, 0.12)
			bg_color = Color(0.06, 0.04, 0.02)
			fog_color = Color(0.08, 0.05, 0.02)
		3, _:  # Void Core — dark purple neon
			key_color = Color(0.7, 0.4, 1.0)
			fill_color = Color(0.4, 0.2, 0.6)
			ambient_color = Color(0.15, 0.08, 0.25)
			bg_color = Color(0.03, 0.01, 0.06)
			fog_color = Color(0.04, 0.02, 0.08)

	if dir_lights.size() >= 1:
		dir_lights[0].light_color = key_color
	if dir_lights.size() >= 2:
		dir_lights[1].light_color = fill_color

	if _env and _env.environment:
		_env.environment.ambient_light_color = ambient_color
		_env.environment.background_color = bg_color
		_env.environment.fog_light_color = fog_color


# ── Internal ───────────────────────────────────────────────────────────────

func _build_arena() -> void:
	var Y := -0.5  # Ground plane

	# ── Floor: 5x4 grid of tiles (wide arena) ──
	var floor_main = _try_load("res://assets/models/dungeon/floor_tile_large.gltf")
	var floor_grate = _try_load("res://assets/models/dungeon/floor_tile_big_grate.gltf")
	var floor_deco = _try_load("res://assets/models/dungeon/floor_tile_small_decorated.gltf")
	if floor_main:
		for x in range(-2, 3):
			for z in range(-2, 3):
				# Use grate tiles for the center strip, decorated for edges, plain otherwise
				var scene = floor_main
				if floor_grate and z == 0 and abs(x) <= 1:
					scene = floor_grate
				elif floor_deco and (x == -2 or x == 2) and z == -1:
					scene = floor_deco
				var tile = scene.instantiate()
				tile.position = Vector3(x * 2.0, Y, z * 2.0)
				_viewport.add_child(tile)

	# ── Back wall: full width with arched center ──
	var wall_scene = _try_load("res://assets/models/dungeon/wall.gltf")
	var wall_arched = _try_load("res://assets/models/dungeon/wall_arched.gltf")
	if wall_scene:
		for i in range(-3, 4):
			var scene = wall_scene
			if wall_arched and i == 0:
				scene = wall_arched  # Grand arch in the center
			var w = scene.instantiate()
			w.position = Vector3(i * 2.0, Y, -5.0)
			_viewport.add_child(w)

	# ── Side walls (left and right, angled inward) ──
	if wall_scene:
		for z_idx in range(-2, 2):
			# Left wall
			var lw = wall_scene.instantiate()
			lw.position = Vector3(-6.0, Y, z_idx * 2.0)
			lw.rotation_degrees.y = 90.0
			_viewport.add_child(lw)
			# Right wall
			var rw = wall_scene.instantiate()
			rw.position = Vector3(6.0, Y, z_idx * 2.0)
			rw.rotation_degrees.y = 90.0
			_viewport.add_child(rw)

	# ── Corner walls ──
	var wall_corner = _try_load("res://assets/models/dungeon/wall_corner.gltf")
	if wall_corner:
		for corner in [
			{"pos": Vector3(-6.0, Y, -5.0), "rot": 0.0},
			{"pos": Vector3(6.0, Y, -5.0), "rot": -90.0},
		]:
			var c = wall_corner.instantiate()
			c.position = corner["pos"]
			c.rotation_degrees.y = corner["rot"]
			_viewport.add_child(c)

	# ── Pillars: frame the arena entrance and flanking the arch ──
	var pillar_scene = _try_load("res://assets/models/dungeon/pillar.gltf")
	var column_scene = _try_load("res://assets/models/dungeon/column.gltf")
	if pillar_scene:
		# Back row pillars flanking the arch
		for px in [-2.0, 2.0]:
			var p = pillar_scene.instantiate()
			p.position = Vector3(px, Y, -5.0)
			_viewport.add_child(p)
		# Front row columns (arena entrance feel)
		if column_scene:
			for px in [-4.5, 4.5]:
				var col = column_scene.instantiate()
				col.position = Vector3(px, Y, 2.0)
				_viewport.add_child(col)

	# ── Torches: wall-mounted with warm point lights ──
	var torch_scene = _try_load("res://assets/models/dungeon/torch_mounted.gltf")
	var torch_positions = [
		Vector3(-4.0, 1.0, -4.5), Vector3(4.0, 1.0, -4.5),  # Back wall
		Vector3(-5.8, 1.0, -1.0), Vector3(5.8, 1.0, -1.0),   # Side walls
	]
	for tpos in torch_positions:
		if torch_scene:
			var t = torch_scene.instantiate()
			t.position = tpos
			_viewport.add_child(t)
		# Warm flickering omni light at each torch
		var light = OmniLight3D.new()
		light.position = tpos + Vector3(0, 0.5, 0.3)
		light.light_color = Color(1.0, 0.7, 0.3)
		light.light_energy = 0.8
		light.omni_range = 6.0
		light.omni_attenuation = 1.2
		light.shadow_enabled = false
		_viewport.add_child(light)

	# ── Props: barrels, banners, chests for atmosphere ──
	var barrel_scene = _try_load("res://assets/models/dungeon/barrel_large.gltf")
	if barrel_scene:
		for bpos in [Vector3(-5.0, Y, -3.5), Vector3(5.2, Y, -3.8)]:
			var b = barrel_scene.instantiate()
			b.position = bpos
			b.rotation_degrees.y = randf() * 30.0
			_viewport.add_child(b)

	var banner_scene = _try_load("res://assets/models/dungeon/banner_red.gltf")
	if banner_scene:
		for bx in [-3.0, 3.0]:
			var ban = banner_scene.instantiate()
			ban.position = Vector3(bx, Y, -4.8)
			_viewport.add_child(ban)

	var chest_scene = _try_load("res://assets/models/dungeon/chest.gltf")
	if chest_scene:
		var ch = chest_scene.instantiate()
		ch.position = Vector3(-5.3, Y, 0.5)
		ch.rotation_degrees.y = 25.0
		_viewport.add_child(ch)


func _try_load(path: String) -> PackedScene:
	if ResourceLoader.exists(path):
		return load(path) as PackedScene
	return null


func _apply_toon_shader(puppet: Node3D) -> void:
	## Apply toon shader to all mesh instances in the puppet
	for node in _get_all_mesh_instances(puppet):
		var mesh := node as MeshInstance3D
		if not mesh:
			continue
		for s in range(mesh.get_surface_override_material_count()):
			var base_mat = mesh.get_active_material(s)
			if base_mat is StandardMaterial3D:
				var shader_mat := ShaderMaterial.new()
				shader_mat.shader = _toon_shader
				# Transfer the albedo texture from the original material
				if base_mat.albedo_texture:
					shader_mat.set_shader_parameter("base_texture", base_mat.albedo_texture)
				shader_mat.set_shader_parameter("albedo_tint", base_mat.albedo_color)
				mesh.set_surface_override_material(s, shader_mat)


func _get_all_mesh_instances(node: Node) -> Array:
	var result: Array = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_get_all_mesh_instances(child))
	return result
