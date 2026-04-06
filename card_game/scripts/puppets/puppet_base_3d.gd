## Base class for 3D character puppets in combat.
## Provides the same animation interface as the 2D PuppetBase so combat_scene.gd
## can call play_attack(), play_hit(), etc. without knowing if it's 2D or 3D.
##
## Wraps Godot's AnimationPlayer to play GLB-embedded animations.
extends Node3D
class_name PuppetBase3D

signal animation_finished(anim_name: String)

## AnimationPlayer from the loaded GLB model
var _anim_player: AnimationPlayer = null

## The loaded 3D model scene instance
var _model_root: Node3D = null

## Map from game animation names to GLB animation names.
## Entries are tried in order: first match wins. This lets CombatMelee/Special
## packs override the weaker General-pack fallbacks.
var _anim_map: Dictionary = {
	# Idles
	"idle": "Skeletons_Idle",           # Special pack (skeleton-specific)
	"idle_alt": "Idle_B",               # General pack fallback
	"idle_melee": "Melee_Unarmed_Idle", # CombatMelee
	# Attacks — real combat anims from CombatMelee pack
	"attack": "Melee_1H_Attack_Slice_Horizontal",
	"attack_chop": "Melee_1H_Attack_Chop",
	"attack_stab": "Melee_1H_Attack_Stab",
	"attack_spin": "Melee_2H_Attack_Spin",
	"attack_kick": "Melee_Unarmed_Attack_Kick",
	"attack_punch": "Melee_Unarmed_Attack_Punch_A",
	"attack_alt": "Throw",              # General pack
	# Ranged / Magic — from CombatRanged pack
	"cast": "Ranged_Magic_Spellcasting",
	"cast_long": "Ranged_Magic_Spellcasting_Long",
	"cast_shoot": "Ranged_Magic_Shoot",
	"cast_summon": "Ranged_Magic_Summon",
	"cast_raise": "Ranged_Magic_Raise",
	# Defense
	"block": "Melee_Block",             # CombatMelee — proper block!
	"blocking": "Melee_Blocking",       # CombatMelee — sustained block
	"block_hit": "Melee_Block_Hit",     # CombatMelee — hit while blocking
	# Hit reactions
	"hit": "Hit_A",                     # General pack
	"hit_alt": "Hit_B",                 # General pack
	# Death / Resurrect — from Special pack
	"death": "Skeletons_Death",         # Special pack (dramatic skeleton death)
	"death_alt": "Death_A",             # General pack fallback
	"resurrect": "Skeletons_Death_Resurrect",  # Special pack
	# Spawn / Taunt
	"spawn": "Skeletons_Awaken_Floor",  # Special pack (rise from the ground!)
	"spawn_standing": "Skeletons_Awaken_Standing",
	"taunt": "Skeletons_Taunt",         # Special pack
	"taunt_long": "Skeletons_Taunt_Longer",
	# Utility
	"buff": "Use_Item",                 # General pack
	"tpose": "T-Pose",
}

## Whether the puppet is currently alive (stops idle on death)
var _is_alive: bool = true

## Flash material for hit effects
var _flash_material: StandardMaterial3D = null
var _original_materials: Array = []   # May contain null (no override set)
var _mesh_instances: Array = []       # Array of MeshInstance3D


func _ready() -> void:
	# Auto-play idle after a short delay to let model load
	if _anim_player and _is_alive:
		call_deferred("play_idle")


# ── Model Loading ──────────────────────────────────────────────────────────

## Load a GLB model and set up the animation player
func load_model(model_scene: PackedScene) -> void:
	if _model_root:
		_model_root.queue_free()

	_model_root = model_scene.instantiate()
	add_child(_model_root)

	# Find the AnimationPlayer in the model hierarchy, or create one
	_anim_player = _find_animation_player(_model_root)
	if not _anim_player:
		_anim_player = AnimationPlayer.new()
		_anim_player.name = "AnimationPlayer"
		_model_root.add_child(_anim_player)
	# Set root node so animation tracks resolve relative to the model
	_anim_player.root_node = _anim_player.get_path_to(_model_root)
	_anim_player.animation_finished.connect(_on_animation_finished)

	# Cache mesh instances for flash effects
	_mesh_instances.clear()
	_original_materials.clear()
	_find_mesh_instances(_model_root)

	# Create flash material
	_flash_material = StandardMaterial3D.new()
	_flash_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	_flash_material.emission_enabled = true
	_flash_material.emission = Color(1.0, 1.0, 1.0)
	_flash_material.emission_energy_multiplier = 2.0


## Load animations from a separate animation GLB and merge them.
## KayKit packs ship animations in separate GLBs with a shared rig.
## The animation tracks reference bones by path — we remap them to match
## the target model's skeleton hierarchy.
func load_animations(anim_scene: PackedScene) -> void:
	if not _anim_player:
		print("PuppetBase3D: No AnimationPlayer — cannot load animations")
		return

	# Instance the animation GLB temporarily to extract animations
	var anim_root := anim_scene.instantiate()
	add_child(anim_root)  # Must be in tree for paths to resolve
	var source_player := _find_animation_player(anim_root)

	if not source_player:
		print("PuppetBase3D: No AnimationPlayer found in animation GLB")
		anim_root.queue_free()
		return

	# Find the skeleton in both source (animation GLB) and target (character model)
	var target_skeleton := _find_skeleton(_model_root)
	var source_skeleton := _find_skeleton(anim_root)

	# Get or create target animation library
	var target_lib: AnimationLibrary
	if _anim_player.has_animation_library(""):
		target_lib = _anim_player.get_animation_library("")
	else:
		target_lib = AnimationLibrary.new()
		_anim_player.add_animation_library("", target_lib)

	# Copy animations from all libraries in the source
	var copied := 0
	for lib_name in source_player.get_animation_library_list():
		var src_lib = source_player.get_animation_library(lib_name)
		if not src_lib:
			continue
		for anim_name in src_lib.get_animation_list():
			if anim_name == "T-Pose" or anim_name == "RESET":
				continue  # Skip utility animations
			var anim = src_lib.get_animation(anim_name)
			if anim:
				# Remap track paths from source skeleton to target skeleton
				var remapped = _remap_animation(anim, source_skeleton, target_skeleton, anim_root)
				target_lib.add_animation(anim_name, remapped)
				copied += 1

	print("PuppetBase3D: Loaded %d animations" % copied)

	# Debug: print first animation's track paths to verify they resolve
	if copied > 0:
		var test_anim_name = target_lib.get_animation_list()[0]
		var test_anim = target_lib.get_animation(test_anim_name)
		print("PuppetBase3D: Sample tracks from '%s':" % test_anim_name)
		for i in range(mini(test_anim.get_track_count(), 5)):
			print("  Track %d: %s" % [i, test_anim.track_get_path(i)])

	anim_root.queue_free()


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result = _find_skeleton(child)
		if result:
			return result
	return null


func _remap_animation(source_anim: Animation, source_skel: Skeleton3D, target_skel: Skeleton3D, source_root: Node) -> Animation:
	## Remap animation track paths from the source model hierarchy to the target.
	## KayKit models share the same bone names, so we just need to adjust the
	## node path prefix to point to our model's skeleton instead of the source's.
	var anim = source_anim.duplicate()

	if not source_skel or not target_skel:
		return anim  # Can't remap without skeletons, return as-is

	# Get the path from AnimationPlayer to each skeleton
	var target_skel_path = _model_root.get_path_to(target_skel)

	for track_idx in range(anim.get_track_count()):
		var track_path = anim.track_get_path(track_idx)
		var path_str = str(track_path)

		# Replace the source skeleton path prefix with target skeleton path
		# Track paths look like "SourceSkeleton:bone_name" or "Armature/Skeleton3D:bone_name"
		# We need them to be relative to our AnimationPlayer's root
		if ":" in path_str:
			var parts = path_str.split(":")
			var bone_part = parts[1]  # e.g. "Hips" or the property
			# Reconstruct path relative to model root -> target skeleton
			var new_path = NodePath(str(target_skel_path) + ":" + bone_part)
			anim.track_set_path(track_idx, new_path)

	return anim


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result:
			return result
	return null


func _find_mesh_instances(node: Node) -> void:
	if node is MeshInstance3D:
		_mesh_instances.append(node as MeshInstance3D)
		# Store original material (may be null if no override is set)
		var mat = null
		if node.get_surface_override_material_count() > 0:
			mat = node.get_surface_override_material(0)
		_original_materials.append(mat)
	for child in node.get_children():
		_find_mesh_instances(child)


# ── Animation Interface ────────────────────────────────────────────────────
# Same interface as PuppetBase (2D) so combat_scene.gd doesn't need changes

func play_idle() -> void:
	if not _is_alive or not _anim_player:
		return
	# Try skeleton-specific idle first, then general idles
	for anim_name in ["Skeletons_Idle", "Idle_B", "Idle_A", "Melee_Unarmed_Idle"]:
		if _anim_player.has_animation(anim_name):
			var anim = _anim_player.get_animation(anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
			_anim_player.play(anim_name, 0.3)  # 0.3s crossfade
			return


func play_attack() -> void:
	_play_anim("attack", false)


func play_hit() -> void:
	_play_anim("hit", false)
	_flash_white(0.15)


func play_block() -> void:
	_play_anim("block", false)


func play_cast() -> void:
	_play_anim("cast", false)


func play_buff() -> void:
	_play_anim("buff", false)


func play_telegraph() -> void:
	# Subtle anticipation — just a slight scale bounce
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.05, 0.95, 1.05), 0.15)
	tween.tween_property(self, "scale", Vector3.ONE, 0.15)


func play_death() -> void:
	_is_alive = false
	_play_anim("death", false)
	# Fade out after death animation
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(_fade_out)


func play_spawn() -> void:
	_play_anim("spawn", false)


# ── Internal Animation Helpers ─────────────────────────────────────────────

func _play_anim(game_name: String, looping: bool) -> void:
	if not _anim_player:
		return

	var glb_name: String = _anim_map.get(game_name, "")
	if glb_name == "" or not _anim_player.has_animation(glb_name):
		# Fallback: try the game name directly
		if _anim_player.has_animation(game_name):
			glb_name = game_name
		else:
			push_warning("PuppetBase3D: No animation '%s' (mapped to '%s')" % [game_name, glb_name])
			return

	# Set loop mode on the animation resource
	var anim = _anim_player.get_animation(glb_name)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE

	_anim_player.play(glb_name, 0.25)  # 0.25s crossfade blend


func _on_animation_finished(anim_name: StringName) -> void:
	animation_finished.emit(anim_name)
	# Return to idle after non-looping animations (if alive) — with a brief pause
	if _is_alive:
		# Don't re-trigger idle if we're already playing an idle variant
		var idle_anims := ["Skeletons_Idle", "Idle_B", "Idle_A", "Melee_Unarmed_Idle"]
		if str(anim_name) not in idle_anims:
			# Small delay so the action anim holds its final pose briefly
			var tree = get_tree()
			if tree:
				await tree.create_timer(0.15).timeout
				if _is_alive:
					play_idle()


# ── Visual Effects ─────────────────────────────────────────────────────────

func _flash_white(duration: float) -> void:
	# Override all mesh materials with flash
	for node in _mesh_instances:
		var mesh = node as MeshInstance3D
		if not mesh:
			continue
		for s in range(mesh.get_surface_override_material_count()):
			mesh.set_surface_override_material(s, _flash_material)

	# Restore after duration
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(_restore_materials)


func _restore_materials() -> void:
	for node in _mesh_instances:
		var mesh = node as MeshInstance3D
		if not mesh:
			continue
		for s in range(mesh.get_surface_override_material_count()):
			mesh.set_surface_override_material(s, null)


func _fade_out() -> void:
	# Fade all meshes to transparent
	for node in _mesh_instances:
		var mesh = node as MeshInstance3D
		if not mesh:
			continue
		for s in range(mesh.get_surface_override_material_count()):
			var mat = mesh.get_active_material(s)
			if mat is StandardMaterial3D:
				var dup = mat.duplicate() as StandardMaterial3D
				dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mesh.set_surface_override_material(s, dup)

	var tween := create_tween()
	tween.tween_property(self, "modulate_alpha", 0.0, 0.5)


## Helper for fading - modulates all mesh albedo alpha
var modulate_alpha: float = 1.0:
	set(value):
		modulate_alpha = value
		for node in _mesh_instances:
			var mesh = node as MeshInstance3D
			if not mesh:
				continue
			for s in range(mesh.get_surface_override_material_count()):
				var mat = mesh.get_surface_override_material(s)
				if mat is StandardMaterial3D:
					mat.albedo_color.a = value


# ── Shake Effect ───────────────────────────────────────────────────────────

func shake(intensity: float = 0.1, duration: float = 0.2) -> void:
	var original_pos := position
	var tween := create_tween()
	var steps := 6
	for i in range(steps):
		var offset := Vector3(
			randf_range(-intensity, intensity),
			randf_range(-intensity * 0.5, intensity * 0.5),
			0.0
		)
		tween.tween_property(self, "position", original_pos + offset, duration / steps)
	tween.tween_property(self, "position", original_pos, duration / steps)
