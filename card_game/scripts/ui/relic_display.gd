extends Control

@onready var relic_container: HBoxContainer = $RelicContainer

func update_relics(relic_ids: Array) -> void:
	for child in relic_container.get_children():
		child.queue_free()

	for rid in relic_ids:
		var relic = RelicSystem.get_relic(rid)
		if not relic:
			continue
		var label = Label.new()
		label.text = "[%s]" % relic.display_name
		label.tooltip_text = relic.description
		match relic.rarity:
			0: label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			1: label.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
			2: label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
		relic_container.add_child(label)
