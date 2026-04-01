extends Control

@onready var bar_fill: ColorRect = $BarFill
@onready var bar_damage_preview: ColorRect = $BarDamagePreview
@onready var hp_label: Label = $HPLabel

var max_value: int = 80
var current_value: int = 80
var _display_value: float = 80.0
var _tween: Tween = null

func _ready() -> void:
	# Initialize preview to hidden
	if bar_damage_preview:
		bar_damage_preview.visible = false

func set_values(current: int, maximum: int) -> void:
	max_value = maximum
	current_value = current
	_update_display_animated()

## Show projected damage on the bar (called when hovering over attack cards)
func show_damage_preview(damage: int) -> void:
	if not bar_damage_preview:
		return
	var ratio = float(current_value) / float(max_value) if max_value > 0 else 0.0
	var after_dmg = maxi(current_value - damage, 0)
	var ratio_after = float(after_dmg) / float(max_value) if max_value > 0 else 0.0
	bar_damage_preview.scale.x = ratio
	bar_damage_preview.visible = true
	bar_fill.scale.x = ratio_after

## Hide the damage preview
func hide_damage_preview() -> void:
	if not bar_damage_preview:
		return
	bar_damage_preview.visible = false
	var ratio = float(current_value) / float(max_value) if max_value > 0 else 0.0
	bar_fill.scale.x = ratio

func _update_display_animated() -> void:
	if not is_node_ready():
		return
	hp_label.text = "%d / %d" % [current_value, max_value]

	var target_ratio = float(current_value) / float(max_value) if max_value > 0 else 0.0

	# Kill existing tween if running
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(bar_fill, "scale:x", target_ratio, 0.35)

	# Update color to reflect health level
	_tween.parallel().tween_method(_update_bar_color, bar_fill.scale.x, target_ratio, 0.35)

func _update_bar_color(ratio: float) -> void:
	if ratio > 0.6:
		bar_fill.color = Color(0.15, 0.82, 0.3)
	elif ratio > 0.35:
		# Lerp green->yellow
		var t = (ratio - 0.35) / 0.25
		bar_fill.color = lerp(Color(0.9, 0.75, 0.1), Color(0.15, 0.82, 0.3), t)
	elif ratio > 0.15:
		# Lerp yellow->orange
		var t = (ratio - 0.15) / 0.2
		bar_fill.color = lerp(Color(0.9, 0.3, 0.1), Color(0.9, 0.75, 0.1), t)
	else:
		bar_fill.color = Color(0.9, 0.15, 0.15)
