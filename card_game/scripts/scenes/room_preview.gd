class_name RoomPreview
extends SubViewportContainer
## Shows a 3D room preview when entering a dungeon map node.
## Instantiate dynamically, call show_room(), await preview_complete, then cleanup().
##
## Usage:
##   var preview := RoomPreview.new()
##   some_canvas_parent.add_child(preview)
##   preview.show_room("fight")
##   await preview.preview_complete
##   preview.cleanup()

signal preview_complete()

var _viewport: SubViewport
var _camera: Camera3D
var _room: Node3D
var _is_showing := false

func _ready() -> void:
	# SubViewport for 3D rendering
	_viewport = SubViewport.new()
	_viewport.name = "RoomViewport"
	_viewport.size = Vector2i(1920, 1080)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)

	# Stretch to fill the container
	stretch = true
	size = Vector2(1920, 1080)
	anchors_preset = Control.PRESET_FULL_RECT

	# Start invisible
	modulate = Color(1, 1, 1, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Build and display a room for the given node type.
## duration: how long (seconds) to hold the room on screen before signalling.
func show_room(node_type: String, duration: float = 1.5) -> void:
	if _is_showing:
		push_warning("RoomPreview: show_room called while already showing")
		return
	_is_showing = true

	# Build the room
	_room = RoomBuilder.build_room(node_type)
	_viewport.add_child(_room)

	# Camera positioned to overlook the room
	_camera = Camera3D.new()
	_camera.name = "RoomCamera"
	_camera.fov = 50
	_camera.position = Vector3(0, 5, 8)
	_camera.look_at(Vector3(0, 0, -1), Vector3.UP)
	_viewport.add_child(_camera)

	# Animate: fade in -> hold -> signal
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_interval(duration)
	tween.tween_callback(_on_preview_hold_finished)


## Fade out and emit preview_complete. Called automatically after hold duration.
func _on_preview_hold_finished() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		preview_complete.emit()
	)


## Free the room, camera, and this node. Call after preview_complete fires.
func cleanup() -> void:
	if _room and is_instance_valid(_room):
		_room.queue_free()
		_room = null
	if _camera and is_instance_valid(_camera):
		_camera.queue_free()
		_camera = null
	_is_showing = false
	queue_free()
