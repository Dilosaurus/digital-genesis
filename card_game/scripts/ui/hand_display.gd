extends Control

signal card_selected(hand_index: int, target_index: int)
# Emitted when the player clicks an attack card that needs a target selected.
# combat_scene listens to this and enables enemy targeting mode, then calls
# confirm_target() when the player picks an enemy.
signal targeting_started(hand_index: int)
signal targeting_cancelled()

const CardVisualScene = preload("res://scenes/cards/card_visual.tscn")

var current_energy: int = 3
var current_corruption_tier: int = 0
var card_nodes: Array = []

# Targeting state: set by combat_scene when a multi-enemy fight is active.
# When needs_target_selection is true and a single-target card is clicked,
# we emit targeting_started instead of card_selected directly.
var needs_target_selection: bool = false  # set true when enemy count > 1
var _pending_hand_index: int = -1          # card waiting for a target click

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
	var card_id = ""
	if hand_index >= 0 and hand_index < card_nodes.size() and card_nodes[hand_index]:
		card_id = card_nodes[hand_index].card_id
	var card_data: CardData = GameManager.get_card_data(card_id) if card_id != "" else null

	# Determine if this card needs the player to select an enemy target.
	# Only ENEMY-targeted cards in a multi-enemy fight need explicit selection.
	if needs_target_selection and card_data and card_data.target_type == Enums.TargetType.ENEMY:
		# If we're already pending a different card, cancel that first.
		if _pending_hand_index >= 0 and _pending_hand_index != hand_index:
			_cancel_pending()
		_pending_hand_index = hand_index
		targeting_started.emit(hand_index)
	else:
		# AoE cards, self-target cards, or single-enemy fights: emit immediately.
		# target_index -1 is used for non-ENEMY targets; 0 for single-enemy default.
		var target_index = 0
		if card_data and card_data.target_type != Enums.TargetType.ENEMY:
			target_index = -1
		card_selected.emit(hand_index, target_index)

# Called by combat_scene when the player has clicked a valid enemy target.
func confirm_target(target_index: int) -> void:
	if _pending_hand_index < 0:
		return
	var idx = _pending_hand_index
	_pending_hand_index = -1
	card_selected.emit(idx, target_index)

# Called by combat_scene to cancel target selection (e.g. right-click or mode exit).
func cancel_targeting() -> void:
	_cancel_pending()

func _cancel_pending() -> void:
	_pending_hand_index = -1
	targeting_cancelled.emit()

func _unhandled_input(event: InputEvent) -> void:
	# Right-click cancels pending target selection.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _pending_hand_index >= 0:
			_cancel_pending()
			get_viewport().set_input_as_handled()
