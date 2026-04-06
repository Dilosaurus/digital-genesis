class_name PuppetBase
extends Node2D
## Base class for all character/enemy puppets.
## Provides tween-based bone animation infrastructure.
## Subclasses define their own @onready vars and animation methods.

signal animation_finished(anim_name: String)

var _idle_tween: Tween = null
var _current_anim: String = ""
var _active_tweens: Array[Tween] = []
var _rest_positions: Dictionary = {}  # Node -> Vector2
var _rest_rotations: Dictionary = {}  # Node -> float
var _all_bones: Array[Node2D] = []

# Override in subclass to return all bone nodes
func _get_bones() -> Array[Node2D]:
	return []


func _ready() -> void:
	_all_bones = _get_bones()
	_capture_rest_state()
	_on_puppet_ready()
	play_idle()


func _on_puppet_ready() -> void:
	pass  # Override for effects setup etc.


func _capture_rest_state() -> void:
	for node in _all_bones:
		if node:
			_rest_positions[node] = node.position
			_rest_rotations[node] = node.rotation_degrees


func _rest_pos(node: Node2D) -> Vector2:
	var pos: Vector2 = _rest_positions.get(node, node.position)
	return pos


func _rest_rot(node: Node2D) -> float:
	var rot: float = _rest_rotations.get(node, 0.0)
	return rot


# ── Tween Management ──────────────────────────────────────────────────────

func _kill_current() -> void:
	_current_anim = ""
	for tw in _active_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_active_tweens.clear()
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
		_idle_tween = null


func _track(tw: Tween) -> Tween:
	_active_tweens.append(tw)
	return tw


func _reset_pose(duration: float = 0.3) -> Tween:
	var t := create_tween().set_parallel()
	for node in _all_bones:
		if not node:
			continue
		t.tween_property(node, "position", _rest_pos(node), duration) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		t.tween_property(node, "rotation_degrees", _rest_rot(node), duration) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		t.tween_property(node, "scale", Vector2.ONE, duration) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_track(t)
	return t


func _emit_finished(anim_name: String) -> void:
	animation_finished.emit(anim_name)


# ── Flash / Hit Effect ────────────────────────────────────────────────────

func _flash_white(duration: float = 0.15) -> void:
	modulate = Color(3.0, 3.0, 3.0, 1.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, duration)
	_track(tw)


func _shake(intensity: float = 8.0, duration: float = 0.2) -> void:
	var orig: Vector2 = position
	var tw: Tween = create_tween()
	var steps: int = int(duration / 0.03)
	for i in steps:
		var offset: Vector2 = Vector2(randf_range(-intensity, intensity), randf_range(-intensity * 0.5, intensity * 0.5))
		tw.tween_property(self, "position", orig + offset, 0.03)
	tw.tween_property(self, "position", orig, 0.03)
	_track(tw)


# ── Standard Animation Interface ─────────────────────────────────────────
# All puppets must implement these. Base versions provide simple fallbacks.

func play_idle() -> void:
	_kill_current()
	_current_anim = "idle"
	_reset_pose(0.3)
	await get_tree().create_timer(0.35).timeout
	if _current_anim != "idle" or not is_inside_tree():
		return
	_idle_loop()


func _idle_loop() -> void:
	pass  # Override with character-specific idle


func play_attack() -> void:
	_kill_current()
	_current_anim = "attack"
	# Default: lunge forward and back
	var tw := create_tween()
	tw.tween_property(self, "position:x", position.x + 40.0, 0.15) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "position:x", position.x, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_emit_finished.bind("attack"))
	_track(tw)


func play_hit() -> void:
	_kill_current()
	_current_anim = "hit"
	_flash_white()
	_shake()
	await get_tree().create_timer(0.3).timeout
	if _current_anim == "hit":
		play_idle()


func play_block() -> void:
	_kill_current()
	_current_anim = "block"
	_flash_white(0.1)
	_shake(4.0, 0.15)
	await get_tree().create_timer(0.25).timeout
	if _current_anim == "block":
		play_idle()


func play_cast() -> void:
	play_attack()  # Default fallback


func play_buff() -> void:
	_kill_current()
	_current_anim = "buff"
	# Glow up
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1.5, 1.3, 1.0, 1.0), 0.3)
	tw.tween_property(self, "modulate", Color.WHITE, 0.3)
	tw.tween_callback(_emit_finished.bind("buff"))
	_track(tw)


func play_telegraph() -> void:
	_kill_current()
	_current_anim = "telegraph"
	# Subtle tension/readying
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.02, 0.98), 0.3) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_track(tw)


func play_death() -> void:
	_kill_current()
	_current_anim = "death"
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.tween_property(self, "position:y", position.y + 30.0, 0.8)
	tw.tween_property(self, "rotation_degrees", -5.0, 0.8)
	_track(tw)
	tw.chain().tween_callback(_emit_finished.bind("death"))
