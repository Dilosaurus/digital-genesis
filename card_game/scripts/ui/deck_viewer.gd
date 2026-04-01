extends Control

signal closed

func _ready() -> void:
	visible = false
	$Panel/CloseButton.pressed.connect(_on_close_pressed)

func show_deck(deck: Array) -> void:
	for child in $Panel/ScrollContainer/CardList.get_children():
		child.queue_free()

	# Count cards
	var counts: Dictionary = {}
	for card_id in deck:
		counts[card_id] = counts.get(card_id, 0) + 1

	# Sort by name
	var sorted_ids = counts.keys()
	sorted_ids.sort()

	for card_id in sorted_ids:
		var card_data = GameManager.get_card_data(card_id)
		if not card_data:
			continue
		var label = Label.new()
		var count_str = " x%d" % counts[card_id] if counts[card_id] > 1 else ""
		label.text = "%s (%d)%s — %s" % [card_data.display_name, card_data.energy_cost, count_str, card_data.description]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.custom_minimum_size = Vector2(0, 25)

		match card_data.card_type:
			0: label.add_theme_color_override("font_color", Color(1, 0.5, 0.4))  # Attack
			1: label.add_theme_color_override("font_color", Color(0.4, 0.7, 1))  # Skill
			2: label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))  # Power
			_: label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

		$Panel/ScrollContainer/CardList.add_child(label)

	$Panel/CountLabel.text = "%d cards" % deck.size()
	visible = true

func _on_close_pressed() -> void:
	visible = false
	closed.emit()
