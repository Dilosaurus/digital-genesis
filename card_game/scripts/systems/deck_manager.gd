class_name DeckManager
extends RefCounted

static func create_starter_deck() -> Array[String]:
	return GameManager.get_starter_deck()

static func shuffle(pile: Array[String]) -> void:
	pile.shuffle()

static func draw(player: PlayerState, count: int) -> Array[String]:
	var drawn: Array[String] = []
	for i in count:
		if player.draw_pile.is_empty():
			if player.discard_pile.is_empty():
				break  # Nothing left to draw
			# Reshuffle discard into draw
			player.draw_pile = player.discard_pile.duplicate()
			player.discard_pile.clear()
			shuffle(player.draw_pile)
		var card_id = player.draw_pile.pop_back()
		player.hand.append(card_id)
		drawn.append(card_id)
	return drawn

static func discard_hand(player: PlayerState) -> void:
	for card_id in player.hand:
		player.discard_pile.append(card_id)
	player.hand.clear()

static func discard_card_at(player: PlayerState, hand_index: int) -> String:
	if hand_index < 0 or hand_index >= player.hand.size():
		return ""
	var card_id = player.hand[hand_index]
	player.hand.remove_at(hand_index)
	player.discard_pile.append(card_id)
	return card_id
