extends CanvasLayer

# TransitionManager: Fade-to-black transitions between scenes.
# Usage:
#   TransitionManager.transition_to_scene("res://scenes/...")
#   await TransitionManager.fade_out(0.4)
#   await TransitionManager.fade_in(0.4)

var _overlay: ColorRect
var _is_transitioning: bool = false

func _ready() -> void:
	layer = 100  # Always on top
	_overlay = ColorRect.new()
	_overlay.name = "FadeOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

## Fade screen to black. Returns when complete.
func fade_out(duration: float = 0.4) -> void:
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_overlay, "color:a", 1.0, duration)
	await tween.finished

## Fade screen from black to clear. Returns when complete.
func fade_in(duration: float = 0.4) -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_overlay, "color:a", 0.0, duration)
	await tween.finished
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Full transition: fade out, change scene, fade in.
func transition_to_scene(scene_path: String, out_duration: float = 0.35, in_duration: float = 0.35) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	await fade_out(out_duration)
	get_tree().change_scene_to_file(scene_path)
	# Wait one frame for the new scene to be ready
	await get_tree().process_frame
	await fade_in(in_duration)
	_is_transitioning = false

## Flash white briefly (hit effect on enemy, etc.)
func flash_white(target: CanvasItem, duration: float = 0.12) -> void:
	var orig = target.modulate
	var tween = create_tween()
	tween.tween_property(target, "modulate", Color(2.0, 2.0, 2.0, 1.0), duration * 0.3)
	tween.tween_property(target, "modulate", orig, duration * 0.7)
