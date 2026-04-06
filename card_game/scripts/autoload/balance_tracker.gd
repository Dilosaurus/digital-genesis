extends Node

# BalanceTracker — passive combat statistics accumulator
# Combat scene calls these functions directly; no signals are auto-connected.
# All data is plain Dictionaries for easy serialisation.

# Full history — one dict per completed combat
var combat_log: Array = []

# Accumulator for the combat currently in progress
var current_combat: Dictionary = {}

# --- Lifecycle ---

func start_combat(enemy_ids: Array) -> void:
	current_combat = {
		"enemy_ids":          enemy_ids.duplicate(),
		"total_damage_dealt": 0,
		"total_damage_taken": 0,
		"total_block_gained": 0,
		"total_healing":      0,
		"cards_played":       0,
		"turns_taken":        0,
		"enemies_killed":     0,
		"won":                false,
	}

func log_card_play(card_id: String, result: Dictionary) -> void:
	if current_combat.is_empty():
		return
	current_combat["cards_played"] += 1
	current_combat["total_damage_dealt"] += result.get("damage_dealt", 0)
	current_combat["total_block_gained"] += result.get("block_gained",  0)
	current_combat["total_healing"]      += result.get("heal_amount",   0)
	# Also capture per-card entry for later granular analysis
	if not current_combat.has("card_plays"):
		current_combat["card_plays"] = []
	current_combat["card_plays"].append({
		"card_id":      card_id,
		"damage":       result.get("damage_dealt", 0),
		"block":        result.get("block_gained",  0),
		"heal":         result.get("heal_amount",   0),
	})

func log_enemy_action(damage_dealt: int) -> void:
	if current_combat.is_empty():
		return
	current_combat["total_damage_taken"] += damage_dealt

func log_turn() -> void:
	if current_combat.is_empty():
		return
	current_combat["turns_taken"] += 1

func log_enemy_killed() -> void:
	if current_combat.is_empty():
		return
	current_combat["enemies_killed"] += 1

func end_combat(won: bool) -> void:
	if current_combat.is_empty():
		return
	current_combat["won"] = won
	combat_log.append(current_combat.duplicate(true))
	current_combat = {}

# --- Query API ---

func get_combat_log() -> Array:
	return combat_log

## Averages computed across all logged (completed) combats.
## Returns empty dict when no combats have been recorded.
func get_averages() -> Dictionary:
	var n := combat_log.size()
	if n == 0:
		return {}

	var totals := {
		"total_damage_dealt": 0,
		"total_damage_taken": 0,
		"total_block_gained": 0,
		"total_healing":      0,
		"cards_played":       0,
		"turns_taken":        0,
		"enemies_killed":     0,
	}

	var wins := 0
	for combat in combat_log:
		for key in totals:
			totals[key] += combat.get(key, 0)
		if combat.get("won", false):
			wins += 1

	var avgs: Dictionary = {}
	for key in totals:
		avgs["avg_" + key] = float(totals[key]) / float(n)
	avgs["win_rate"]       = float(wins) / float(n)
	avgs["combat_count"]   = n
	return avgs

## Returns an Array of Dictionaries aggregating stats per card_id across all combats.
## Each entry: { card_id, times_played, total_damage, total_block, total_heal }
func get_card_stats() -> Array:
	var card_map: Dictionary = {}
	for combat in combat_log:
		for play in combat.get("card_plays", []):
			var cid: String = play.get("card_id", "")
			if cid.is_empty():
				continue
			if not card_map.has(cid):
				card_map[cid] = {
					"card_id":      cid,
					"times_played": 0,
					"total_damage": 0,
					"total_block":  0,
					"total_heal":   0,
				}
			var entry: Dictionary = card_map[cid]
			entry["times_played"] += 1
			entry["total_damage"] += play.get("damage", 0)
			entry["total_block"]  += play.get("block",  0)
			entry["total_heal"]   += play.get("heal",   0)
	return card_map.values()

func clear() -> void:
	combat_log.clear()
	current_combat = {}
