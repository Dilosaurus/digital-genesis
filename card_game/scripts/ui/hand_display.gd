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
var current_run: RunState = null
var card_nodes: Array = []

# Targeting state: set by combat_scene when a multi-enemy fight is active.
# When needs_target_selection is true and a single-target card is clicked,
# we emit targeting_started instead of card_selected directly.
var needs_target_selection: bool = false  # set true when enemy count > 1
var _pending_hand_index: int = -1          # card waiting for a target click

# ---------------------------------------------------------------------------
# Arc layout constants
# ---------------------------------------------------------------------------

# How many degrees the outermost card is rotated at a full hand
const ARC_MAX_DEG       := 8.0   # ±degrees at the extreme ends
# Vertical arc depth: how many px the edge cards dip below the center card
const ARC_DIP_PX        := 18.0
# Base spacing between card pivot centres (shrinks as hand grows)
const SPACING_WIDE      := 180.0  # 1-3 cards
const SPACING_NORMAL    := 155.0  # 4-6 cards
const SPACING_TIGHT     := 120.0  # 7+ cards
# Y offset applied to unplayable cards so they sink slightly
const UNPLAYABLE_SINK_PX := 14.0
# Draw animation: cards slide from this X offset relative to the hand centre
const DRAW_SLIDE_OFFSET_X := -380.0
# Stagger delay (seconds) between successive card entrance animations
const DRAW_STAGGER_S    := 0.07
# How much adjacent cards spread apart (in px) when one is hovered
const HOVER_SPREAD_PX   := 22.0

# ---------------------------------------------------------------------------

var current_cooldowns: Dictionary = {}

var _last_card_ids: Array = []

func update_hand(card_ids: Array, energy: int, corruption_tier: int = 0, run: RunState = null, cooldowns: Dictionary = {}) -> void:
	var energy_changed := energy != current_energy
	current_energy = energy
	current_corruption_tier = corruption_tier
	current_run = run
	current_cooldowns = cooldowns

	# Skip full rebuild if the cards haven't changed — just update energy/playability
	if card_ids == _last_card_ids and card_nodes.size() > 0:
		# Cards are the same, just refresh playability (energy may have changed)
		if energy_changed:
			for i in card_nodes.size():
				var card = card_nodes[i]
				if card and is_instance_valid(card):
					card.setup(card_ids[i], i, current_energy, current_corruption_tier, current_run, current_cooldowns)
			_apply_arc_layout(false)
		return

	_last_card_ids = card_ids.duplicate()

	# Full rebuild — cards actually changed
	for child in get_children():
		child.queue_free()
	card_nodes.clear()

	if card_ids.is_empty():
		return

	var card_count := card_ids.size()

	for i in card_count:
		var card_visual = CardVisualScene.instantiate()
		add_child(card_visual)
		card_visual.setup(card_ids[i], i, current_energy, current_corruption_tier, current_run, current_cooldowns)
		card_visual.card_clicked.connect(_on_card_clicked)
		card_visual.mouse_entered.connect(_on_card_hovered.bind(i))
		card_visual.mouse_exited.connect(_on_card_unhovered.bind(i))
		card_nodes.append(card_visual)

	# Place cards in arc, then animate them entering from the left
	_apply_arc_layout(true)

func _apply_arc_layout(animate_entrance: bool = false) -> void:
	# Filter out nulls (cards mid-play-animation)
	var live_nodes: Array = card_nodes.filter(func(n): return n != null)
	var card_count := live_nodes.size()
	if card_count == 0:
		return

	var spacing := _spacing_for_count(card_count)
	var total_width := spacing * (card_count - 1)
	var start_x := (size.x - total_width) / 2.0
	# Anchor the pivot row at the vertical centre of this container
	var base_y := size.y * 0.5 - 130.0  # 130 ≈ half card height (260/2)

	# Dynamic arc angle: grows slightly with hand size
	var arc_deg := clampf(ARC_MAX_DEG * (float(card_count - 1) / 6.0), 0.0, ARC_MAX_DEG)

	for idx in card_count:
		var card: Control = live_nodes[idx]
		# t ∈ [0,1] left-to-right; centre card(s) are near 0.5
		var t: float = float(idx) / float(maxi(card_count - 1, 1)) if card_count > 1 else 0.5

		# Rotation: linearly interpolated from -arc_deg to +arc_deg
		var rot_deg: float = lerp(-arc_deg, arc_deg, t)

		# Vertical dip: parabola — edge cards sit lower than center
		# f(t) = 4 * dip * t * (1 - t) gives 0 at edges, dip at centre;
		# we invert so centre is HIGHEST (subtract from base_y)
		var arc_lift := 4.0 * ARC_DIP_PX * t * (1.0 - t)

		# Unplayable cards sink a bit further
		var sink: float = UNPLAYABLE_SINK_PX if (not card.is_playable) else 0.0

		var dest_pos := Vector2(start_x + idx * spacing, base_y - arc_lift + sink)
		var dest_rot := deg_to_rad(rot_deg)

		# Store as the card's resting state so hover logic can reference it
		card._base_position = dest_pos
		card._base_rotation = dest_rot

		if animate_entrance:
			# Start the card off-screen to the left, invisible, no rotation
			var from_pos := Vector2(dest_pos.x + DRAW_SLIDE_OFFSET_X, dest_pos.y + 30.0)
			card.position = from_pos
			card.rotation = 0.0
			card.modulate.a = 0.0
			card.scale = Vector2(0.85, 0.85)

			var delay := idx * DRAW_STAGGER_S
			var tween := card.create_tween()
			tween.set_parallel()
			tween.tween_property(card, "modulate:a", 1.0, 0.18).set_delay(delay)
			tween.tween_property(card, "scale", Vector2.ONE, 0.22).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			tween.tween_property(card, "position", dest_pos, 0.28).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			tween.tween_property(card, "rotation", dest_rot, 0.28).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		else:
			# Smooth re-layout (after a card is played)
			var tween := card.create_tween()
			tween.set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tween.tween_property(card, "position", dest_pos, 0.18)
			tween.tween_property(card, "rotation", dest_rot, 0.18)

# ---------------------------------------------------------------------------
# Spacing helper
# ---------------------------------------------------------------------------

func _spacing_for_count(n: int) -> float:
	if n <= 3:
		return SPACING_WIDE
	elif n <= 6:
		return SPACING_NORMAL
	else:
		return SPACING_TIGHT

# ---------------------------------------------------------------------------
# Hover spread: nudge non-hovered cards outward to make visual room
# ---------------------------------------------------------------------------

func _on_card_hovered(hovered_idx: int) -> void:
	# hovered_idx is the original card_nodes index; iterate card_nodes directly
	# so left/right comparisons stay anchored to the original hand order.
	for idx in card_nodes.size():
		var card: Control = card_nodes[idx]
		if card == null or idx == hovered_idx:
			continue
		var spread: float = HOVER_SPREAD_PX if idx > hovered_idx else -HOVER_SPREAD_PX
		var tw: Tween = card.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(card, "position:x", card._base_position.x + spread, 0.15)

func _on_card_unhovered(_hovered_idx: int) -> void:
	# Restore all live cards to their base X positions
	for card: Control in card_nodes:
		if card == null:
			continue
		var tw: Tween = card.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(card, "position:x", card._base_position.x, 0.15)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func get_card_node(hand_index: int):
	if hand_index >= 0 and hand_index < card_nodes.size():
		return card_nodes[hand_index]
	return null

func animate_card_play(hand_index: int, target_pos: Vector2) -> void:
	_last_card_ids.clear()  # Force rebuild on next update_hand (card count changed)
	var card = get_card_node(hand_index)
	if card:
		var local_target := target_pos - global_position
		card.play_animation(local_target)
		card_nodes[hand_index] = null  # Mark as gone
		# Allow the fly animation to start before redistributing
		await get_tree().create_timer(0.08).timeout
		_apply_arc_layout(false)

## Animate all remaining cards sliding to the discard pile (bottom-right) and fading out.
func animate_discard_all() -> void:
	_last_card_ids.clear()  # Force rebuild on next update_hand
	var discard_pos := Vector2(size.x + 100, size.y + 50)  # Off-screen bottom-right
	for idx in card_nodes.size():
		var card = card_nodes[idx]
		if card == null:
			continue
		var delay := idx * 0.04
		var tween: Tween = card.create_tween().set_parallel()
		tween.tween_property(card, "position", discard_pos, 0.3).set_delay(delay).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		tween.tween_property(card, "scale", Vector2(0.4, 0.4), 0.3).set_delay(delay)
		tween.tween_property(card, "modulate:a", 0.0, 0.15).set_delay(delay + 0.2)
		tween.tween_property(card, "rotation", deg_to_rad(15.0), 0.3).set_delay(delay)
		tween.chain().tween_callback(card.queue_free)
	card_nodes.clear()

## Animate a specific card dissolving (for exhaust effects)
func animate_card_exhaust(hand_index: int) -> void:
	var card = get_card_node(hand_index)
	if card:
		card.play_exhaust_dissolve()
		card_nodes[hand_index] = null
		await get_tree().create_timer(0.1).timeout
		_apply_arc_layout(false)

# ---------------------------------------------------------------------------
# Input handlers
# ---------------------------------------------------------------------------

func _on_card_clicked(hand_index: int) -> void:
	var card_id := ""
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
		var target_index := 0
		if card_data and card_data.target_type != Enums.TargetType.ENEMY:
			target_index = -1
		card_selected.emit(hand_index, target_index)

# Called by combat_scene when the player has clicked a valid enemy target.
func confirm_target(target_index: int) -> void:
	if _pending_hand_index < 0:
		return
	var idx := _pending_hand_index
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
