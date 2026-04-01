extends Control

@onready var panel: Panel = $Panel
@onready var label: Label = $Panel/Label

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_banner(text: String, color: Color = Color(0.9, 0.8, 0.2)) -> void:
	label.text = text
	label.add_theme_color_override("font_color", color)
	visible = true
	panel.position.x = 1920.0
	var center_x = (1920.0 - 400.0) / 2.0
	var tween = create_tween()
	tween.tween_property(panel, "position:x", center_x, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(0.7)
	tween.tween_property(panel, "position:x", -400.0, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func(): visible = false)
