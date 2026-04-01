extends Control

signal soul_ability_requested(ability_id: String)

@onready var count_label: Label = $CountLabel
@onready var absorbed_label: Label = $AbsorbedLabel

func update_souls(fragments: int, boss_absorbed: int) -> void:
	count_label.text = "Souls: %d" % fragments
	# Glow when enough for abilities
	if fragments >= 5:
		count_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	else:
		count_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))

	if boss_absorbed > 0:
		absorbed_label.text = "Boss: +%d" % boss_absorbed
		absorbed_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		absorbed_label.visible = true
	else:
		absorbed_label.visible = false
