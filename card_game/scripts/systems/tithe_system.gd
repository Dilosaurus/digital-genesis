class_name TitheSystem
extends RefCounted

const TITHE_INTERVAL = 3  # Every 3 turns
const BASE_TITHE = 10  # Base HP cost, scales with turn number

# Check if tithe is due this turn
static func is_tithe_turn(turn_number: int) -> bool:
	return turn_number > 1 and turn_number % TITHE_INTERVAL == 0

# Calculate the tithe cost for this turn
static func get_tithe_cost(turn_number: int, player_count: int) -> int:
	var scaling = int(turn_number / TITHE_INTERVAL)  # Gets harder each time
	return BASE_TITHE + (scaling - 1) * 5

# Apply tithe — each living player pays an equal share of HP
# Returns a dictionary of {peer_id: hp_paid}
static func apply_tithe_evenly(state, tithe_cost: int) -> Dictionary:
	var result = {}
	var living = []
	for peer_id in state.players:
		var ps = state.players[peer_id]
		if ps.current_hp > 0 and not ps.is_dead:
			living.append(peer_id)

	if living.is_empty():
		return result

	var per_player = maxi(int(tithe_cost / living.size()), 1)

	for peer_id in living:
		var ps = state.players[peer_id]
		var actual_cost = mini(per_player, ps.current_hp - 1)  # Can't kill via tithe
		actual_cost = maxi(actual_cost, 0)
		ps.current_hp -= actual_cost
		result[peer_id] = actual_cost

	return result

# Alternative: refuse the tithe — each player loses a random card from draw pile permanently
static func apply_tithe_refusal(state) -> Dictionary:
	var result = {}
	for peer_id in state.players:
		var ps = state.players[peer_id]
		if ps.is_dead:
			continue
		if ps.draw_pile.size() > 0:
			var idx = randi() % ps.draw_pile.size()
			var lost_card = ps.draw_pile[idx]
			ps.draw_pile.remove_at(idx)
			result[peer_id] = lost_card
		elif ps.discard_pile.size() > 0:
			var idx = randi() % ps.discard_pile.size()
			var lost_card = ps.discard_pile[idx]
			ps.discard_pile.remove_at(idx)
			result[peer_id] = lost_card
		else:
			result[peer_id] = ""
	return result
