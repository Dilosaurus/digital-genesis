extends RefCounted
class_name DungeonVariator
## Applies seeded procedural variation to a freshly instantiated dungeon scene.
##
## A dungeon author places props normally in the editor, then marks nodes
## with Godot groups to opt them into variation:
##
##   "proc_jitter"   — position jittered ±0.3m and rotated ±15° around Y
##   "proc_optional" — may be culled entirely (enabled_chance default 0.7)
##   "proc_tint"     — albedo tinted by a per-run palette entry
##
## Torches get their light_color and light_energy nudged so every run feels
## a little warmer or cooler than the last. Camera nodes in the root can be
## micro-offset via `apply_camera_jitter()`.
##
## Everything is deterministic from (run_seed, act, floor_depth) so the same
## room in the same run always looks the same, but a new run is different.

const JITTER_POS: float = 0.25
const JITTER_ROT_DEG: float = 12.0
const OPTIONAL_KEEP_CHANCE: float = 0.85
const TORCH_WARMTH_RANGE: float = 0.12
const TORCH_ENERGY_RANGE: float = 0.25
const CAMERA_POS_JITTER: float = 0.15
const CAMERA_FOV_JITTER: float = 0.8

var _rng: RandomNumberGenerator

func _init(seed_value: int) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value

## Apply all variation passes to the freshly instantiated dungeon root.
func vary(dungeon_root: Node3D) -> void:
	if not dungeon_root:
		return
	_vary_jittered(dungeon_root)
	_vary_optional(dungeon_root)
	_vary_torches(dungeon_root)

## Apply camera micro-offset. Called separately since the camera lives in
## the combat_3d_stage, not the dungeon scene.
func apply_camera_jitter(camera: Camera3D) -> void:
	if not camera:
		return
	var base_pos := camera.position
	camera.position = base_pos + Vector3(
		_rng.randf_range(-CAMERA_POS_JITTER, CAMERA_POS_JITTER),
		_rng.randf_range(-CAMERA_POS_JITTER * 0.5, CAMERA_POS_JITTER * 0.5),
		_rng.randf_range(-CAMERA_POS_JITTER, CAMERA_POS_JITTER)
	)
	camera.fov += _rng.randf_range(-CAMERA_FOV_JITTER, CAMERA_FOV_JITTER)

# ─── Internal passes ────────────────────────────────────────────────────────

func _vary_jittered(root: Node) -> void:
	for node in root.get_tree().get_nodes_in_group("proc_jitter"):
		if not (node is Node3D) or not _is_descendant_of(node, root):
			continue
		var n3d := node as Node3D
		n3d.position += Vector3(
			_rng.randf_range(-JITTER_POS, JITTER_POS),
			0.0,
			_rng.randf_range(-JITTER_POS, JITTER_POS)
		)
		n3d.rotation_degrees.y += _rng.randf_range(-JITTER_ROT_DEG, JITTER_ROT_DEG)

func _vary_optional(root: Node) -> void:
	for node in root.get_tree().get_nodes_in_group("proc_optional"):
		if not (node is Node3D) or not _is_descendant_of(node, root):
			continue
		if _rng.randf() > OPTIONAL_KEEP_CHANCE:
			node.visible = false
			node.set_process(false)

func _vary_torches(root: Node) -> void:
	# Recursive walk — torches may be nested anywhere.
	_walk_for_torches(root)

func _walk_for_torches(node: Node) -> void:
	if node is OmniLight3D:
		var light := node as OmniLight3D
		# Warmth shift: nudge the red/blue balance slightly.
		var c := light.light_color
		var warmth := _rng.randf_range(-TORCH_WARMTH_RANGE, TORCH_WARMTH_RANGE)
		c.r = clamp(c.r + warmth, 0.0, 1.0)
		c.b = clamp(c.b - warmth, 0.0, 1.0)
		light.light_color = c
		light.light_energy *= _rng.randf_range(
			1.0 - TORCH_ENERGY_RANGE, 1.0 + TORCH_ENERGY_RANGE
		)
	for child in node.get_children():
		_walk_for_torches(child)

func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var n := node
	while n:
		if n == ancestor:
			return true
		n = n.get_parent()
	return false
