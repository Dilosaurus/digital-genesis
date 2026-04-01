extends Control

@onready var bar_fill: ColorRect = $BarFill
@onready var hp_label: Label = $HPLabel

var max_value: int = 80
var current_value: int = 80

func set_values(current: int, maximum: int) -> void:
	max_value = maximum
	current_value = current
	_update_display()

func _update_display() -> void:
	if not is_node_ready():
		return
	var ratio = float(current_value) / float(max_value) if max_value > 0 else 0.0
	var tween = create_tween()
	tween.tween_property(bar_fill, "scale:x", ratio, 0.3).set_ease(Tween.EASE_OUT)
	hp_label.text = "%d/%d" % [current_value, max_value]

	# Color based on HP ratio
	if ratio > 0.5:
		bar_fill.color = Color(0.2, 0.8, 0.3)
	elif ratio > 0.25:
		bar_fill.color = Color(0.9, 0.7, 0.1)
	else:
		bar_fill.color = Color(0.9, 0.2, 0.2)
