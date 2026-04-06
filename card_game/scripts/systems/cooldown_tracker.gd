class_name CooldownTracker
extends RefCounted

## Tracks per-card cooldowns on PlayerState.
## Cards with cooldown_max > 0 enter cooldown after being played.
## Cooldowns tick down by 1 at the start of each player turn.

## Tick all cooldowns down by 1, removing any that hit 0.
static func tick(player: PlayerState) -> void:
	var to_remove: Array[String] = []
	for card_id in player.cooldowns:
		player.cooldowns[card_id] -= 1
		if player.cooldowns[card_id] <= 0:
			to_remove.append(card_id)
	for card_id in to_remove:
		player.cooldowns.erase(card_id)

## Set a card on cooldown after being played.
static func set_cooldown(player: PlayerState, card_id: String) -> void:
	var card_data: CardData = GameManager.get_card_data(card_id)
	if card_data and card_data.cooldown_max > 0:
		player.cooldowns[card_id] = card_data.cooldown_max

## Check if a card is on cooldown.
static func is_on_cooldown(player: PlayerState, card_id: String) -> bool:
	return player.cooldowns.has(card_id) and player.cooldowns[card_id] > 0

## Get remaining cooldown turns for a card.
static func get_remaining(player: PlayerState, card_id: String) -> int:
	return player.cooldowns.get(card_id, 0)
