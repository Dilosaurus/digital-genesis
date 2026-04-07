## 3D combat stage that renders characters + dungeon in a SubViewport.
## Embeds into the 2D combat scene via SubViewportContainer.
##
## As of the dungeon-variant refactor, the stage is a real scene
## (scenes/combat/combat_3d_stage.tscn) — the viewport, camera, lights,
## environment, and spawn points are all editable in the Godot editor.
## The dungeon geometry is no longer built in code; instead, combat_scene
## calls load_dungeon(variant, seed) to composite a DungeonVariant into
## the DungeonRoot node.
extends SubViewportContainer
class_name Combat3DStage

const DungeonVariantClass = preload("res://scripts/combat/dungeon_variant.gd")
const DungeonVariatorClass = preload("res://scripts/combat/dungeon_variator.gd")

## Scene-owned nodes (bound from combat_3d_stage.tscn).
@onready var _viewport: SubViewport = $SubViewport
@onready var _camera: Camera3D = $SubViewport/Camera3D
@onready var _key_light: DirectionalLight3D = $SubViewport/KeyLight
@onready var _fill_light: DirectionalLight3D = $SubViewport/FillLight
@onready var _env: WorldEnvironment = $SubViewport/WorldEnvironment
@onready var _player_spawn: Node3D = $SubViewport/PlayerSpawn
@onready var _enemy_spawn: Node3D = $SubViewport/EnemySpawn
@onready var _dungeon_root: Node3D = $SubViewport/DungeonRoot

## Current player puppet
var _player_puppet: PuppetBase3D = null

## Toon shader (loaded once, applied to all characters)
var _toon_shader: Shader

## Currently loaded dungeon instance (child of _dungeon_root)
var _current_dungeon: Node3D = null

## Base camera position — stored so camera shake / jitter can restore it.
var _camera_base_pos: Vector3


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Critical: SubViewportContainer must not consume input.
	set_process_input(false)
	set_process_unhandled_input(false)

	_camera_base_pos = _camera.position

	# Toon shader for cel-shaded character look
	if ResourceLoader.exists("res://shaders/toon_shader.gdshader"):
		_toon_shader = load("res://shaders/toon_shader.gdshader")


# ── Public API ─────────────────────────────────────────────────────────────

## Load a DungeonVariant into the stage. Clears any previously loaded dungeon,
## instances the variant's base scene + optional decay overlay, runs seeded
## procedural variation, moves spawn points if the dungeon provides markers,
## and applies the appropriate lighting preset.
func load_dungeon(variant: Resource, run_seed: int = 0) -> void:
	if not variant:
		push_warning("Combat3DStage.load_dungeon: null variant")
		return

	# Clear previous dungeon (and any edit-time placeholder children).
	if _current_dungeon and is_instance_valid(_current_dungeon):
		_current_dungeon.queue_free()
		_current_dungeon = null
	for child in _dungeon_root.get_children():
		child.queue_free()

	# Instance the base dungeon.
	var base_scene: PackedScene = variant.get("base_dungeon")
	if not base_scene:
		push_warning("Combat3DStage.load_dungeon: variant has no base_dungeon")
		return

	_current_dungeon = base_scene.instantiate() as Node3D
	if not _current_dungeon:
		push_warning("Combat3DStage.load_dungeon: base_dungeon root is not a Node3D")
		return
	_dungeon_root.add_child(_current_dungeon)

	# Composite decay overlay (skipped for boss arenas).
	var decay: PackedScene = variant.get("decay_overlay")
	var is_boss: bool = bool(variant.get("is_boss_arena"))
	if decay and not is_boss:
		var decay_inst := decay.instantiate() as Node3D
		if decay_inst:
			_current_dungeon.add_child(decay_inst)

	# Apply seeded procedural variation.
	# Camera jitter is intentionally NOT applied — the camera transform
	# authored in combat_3d_stage.tscn is the source of truth.
	if run_seed != 0:
		var variator := DungeonVariatorClass.new(run_seed)
		variator.vary(_current_dungeon)

	# Move spawn points if the dungeon provides marker nodes.
	# Read LOCAL position relative to the dungeon root — global_position
	# isn't reliably propagated this same frame after add_child, and we
	# parented the dungeon at origin anyway.
	var player_marker := _current_dungeon.find_child("PlayerSpawnPoint", true, false) as Node3D
	if player_marker:
		_player_spawn.position = player_marker.position
	var enemy_marker := _current_dungeon.find_child("EnemySpawnPoint", true, false) as Node3D
	if enemy_marker:
		_enemy_spawn.position = enemy_marker.position

	# Strip editor-only spawn-position preview models. Done AFTER reading
	# positions so the marker nodes are still alive above.
	for preview in get_tree().get_nodes_in_group("spawn_preview"):
		if preview is Node and _is_descendant(preview, _current_dungeon):
			preview.queue_free()

	# Apply lighting preset.
	var preset: String = "boss" if is_boss else str(variant.get("lighting_preset"))
	_apply_lighting_preset(preset)


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
	var original_pos := _camera_base_pos
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


## Set lighting colors based on the current act. Thin wrapper around
## _apply_lighting_preset for backwards compat with callers that pass an int.
func set_act_lighting(act: int) -> void:
	var preset := "act%d" % act
	_apply_lighting_preset(preset)


func _apply_lighting_preset(preset: String) -> void:
	if not _camera:
		return

	var key_color: Color
	var fill_color: Color
	var ambient_color: Color
	var bg_color: Color
	var fog_color: Color

	match preset:
		"act1":  # Corrupted Server Farm — cool green tech
			key_color = Color(0.7, 1.0, 0.8)
			fill_color = Color(0.3, 0.6, 0.5)
			ambient_color = Color(0.15, 0.25, 0.2)
			bg_color = Color(0.02, 0.04, 0.03)
			fog_color = Color(0.03, 0.06, 0.04)
		"act2":  # Neural Cathedral — warm gold
			key_color = Color(1.0, 0.85, 0.6)
			fill_color = Color(0.6, 0.4, 0.2)
			ambient_color = Color(0.3, 0.22, 0.12)
			bg_color = Color(0.06, 0.04, 0.02)
			fog_color = Color(0.08, 0.05, 0.02)
		"act3":  # Void Core — dark purple neon
			key_color = Color(0.7, 0.4, 1.0)
			fill_color = Color(0.4, 0.2, 0.6)
			ambient_color = Color(0.15, 0.08, 0.25)
			bg_color = Color(0.03, 0.01, 0.06)
			fog_color = Color(0.04, 0.02, 0.08)
		"boss":  # Boss — dramatic high-contrast white/blue
			key_color = Color(1.0, 0.95, 1.0)
			fill_color = Color(0.35, 0.55, 0.9)
			ambient_color = Color(0.12, 0.15, 0.25)
			bg_color = Color(0.01, 0.01, 0.04)
			fog_color = Color(0.02, 0.03, 0.08)
		_:
			return

	if _key_light:
		_key_light.light_color = key_color
	if _fill_light:
		_fill_light.light_color = fill_color

	if _env and _env.environment:
		_env.environment.ambient_light_color = ambient_color
		_env.environment.background_color = bg_color
		_env.environment.fog_light_color = fog_color


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


func _is_descendant(node: Node, ancestor: Node) -> bool:
	var n: Node = node
	while n:
		if n == ancestor:
			return true
		n = n.get_parent()
	return false


func _get_all_mesh_instances(node: Node) -> Array:
	var result: Array = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_get_all_mesh_instances(child))
	return result
