## Afterimage / ghost trail effect for attack lunge animations.
##
## Add as a sibling or scene-level child (NOT a child of the moving puppet,
## since ghosts must stay at the positions where they were spawned).
##
## Usage:
##   afterimage_node.spawn_afterimage(puppet, 3, 0.05)
extends Node2D

const GHOST_COLOR := Color(0.4, 0.2, 0.7, 0.6)
const FADE_DURATION_MIN := 0.3
const FADE_DURATION_MAX := 0.5


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Spawns a trail of fading ghost copies behind a moving source node.
## [param source]: The Node2D whose Sprite2D children will be cloned.
## [param count]: Number of ghost copies to create.
## [param interval]: Seconds between each successive ghost spawn.
func spawn_afterimage(source: Node2D, count: int = 3, interval: float = 0.05) -> void:
	for i in count:
		if not is_instance_valid(source):
			break
		# Each successive ghost starts slightly more transparent.
		var alpha_scale: float = 1.0 - (float(i) / count) * 0.5
		_create_ghost(source, alpha_scale)
		if i < count - 1:
			await get_tree().create_timer(interval).timeout


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

## Creates a single ghost frame by duplicating every Sprite2D descendant of
## [param source] into a temporary container node.
func _create_ghost(source: Node2D, alpha_scale: float) -> void:
	var container := Node2D.new()
	add_child(container)
	container.global_position = Vector2.ZERO

	var sprites := _collect_sprites(source)
	if sprites.is_empty():
		container.queue_free()
		return

	for original: Sprite2D in sprites:
		var ghost_sprite := Sprite2D.new()
		ghost_sprite.texture = original.texture
		ghost_sprite.offset = original.offset
		ghost_sprite.flip_h = original.flip_h
		ghost_sprite.flip_v = original.flip_v
		ghost_sprite.hframes = original.hframes
		ghost_sprite.vframes = original.vframes
		ghost_sprite.frame = original.frame
		ghost_sprite.region_enabled = original.region_enabled
		if original.region_enabled:
			ghost_sprite.region_rect = original.region_rect

		# Copy the global transform so the ghost appears exactly where the
		# original sprite is right now.
		ghost_sprite.global_transform = original.global_transform

		# Start with the purple ghost tint, scaled by trail position.
		var start_color := GHOST_COLOR
		start_color.a *= alpha_scale
		ghost_sprite.modulate = start_color

		container.add_child(ghost_sprite)

	# Fade the entire container to transparent, then free it.
	var duration := randf_range(FADE_DURATION_MIN, FADE_DURATION_MAX)
	var tween := create_tween()
	tween.tween_property(container, "modulate:a", 0.0, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(container.queue_free)


## Recursively collects all Sprite2D descendants of [param node].
func _collect_sprites(node: Node) -> Array[Sprite2D]:
	var result: Array[Sprite2D] = []
	for child in node.get_children():
		if child is Sprite2D:
			result.append(child as Sprite2D)
		result.append_array(_collect_sprites(child))
	return result
