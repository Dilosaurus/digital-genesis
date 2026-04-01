extends Control

signal card_selected(hand_index: int, target_index: int)

const CardVisualScene = preload("res://scenes/cards/card_visual.tscn")

var current_energy: int = 3
var current_corruption_tier: int = 0
var card_nodes: Array = []

func update_hand(card_ids: Array, energy: int, corruption_tier: int = 0) -> void:
	current_energy = energy
	current_corruption_tier = corruption_tier
	# Clear existing cards
	for child in get_children():
		child.queue_free()
	card_nodes.clear()

	if card_ids.is_empty():
		return

	# Create card visuals in a fan layout
	var card_count = card_ids.size()
	var card_width = 150.0
	var spacing = minf(card_width + 10.0, (size.x - 60.0) / card_count)
	var total_width = spacing * (card_count - 1) + card_width
	var start_x = (size.x - total_width) / 2.0

	# Fan rotation
	var max_rotation = deg_to_rad(15.0) if card_count > 1 else 0.0

	for i in card_count:
		var card_visual = CardVisualScene.instantiate()
		add_child(card_visual)

		# Position with slight arc
		var t = float(i) / max(card_count - 1, 1) if card_count > 1 else 0.5
		var arc_y = -sin(t * PI) * 15.0  # Arc upward in the middle
		var rot = lerp(-max_rotation, max_rotation, t)

		card_visual.position = Vector2(start_x + i * spacing, 10 + arc_y)
		card_visual._base_position = card_visual.position
		card_visual.rotation = rot
		card_visual.setup(card_ids[i], i, current_energy, current_corruption_tier)
		card_visual.card_clicked.connect(_on_card_clicked)
		card_nodes.append(card_visual)

func get_card_node(hand_index: int):
	if hand_index >= 0 and hand_index < card_nodes.size():
		return card_nodes[hand_index]
	return null

func animate_card_play(hand_index: int, target_pos: Vector2) -> void:
	var card = get_card_node(hand_index)
	if card:
		# Convert target to local coords
		var local_target = target_pos - global_position
		card.play_animation(local_target)
		card_nodes[hand_index] = null  # Mark as gone

func _on_card_clicked(hand_index: int) -> void:
	# For now, always target enemy 0
	card_selected.emit(hand_index, 0)
