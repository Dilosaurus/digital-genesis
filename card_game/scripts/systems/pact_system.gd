class_name PactSystem
extends RefCounted

# Chance a pact is offered each turn (increases with corruption)
static func should_offer_pact(turn_number: int, corruption: int) -> bool:
	if turn_number <= 1:
		return false
	# Base 20% chance, +1% per corruption point
	var chance = 0.2 + corruption * 0.01
	return randf() < chance

# Get a random pact offer
static func get_random_pact() -> Dictionary:
	var pacts = [
		{
			"id": "dark_power",
			"title": "Dark Power",
			"description": "Gain +1 max energy this combat.\nCost: 15 HP, +10 corruption.",
			"benefit": "energy",
			"hp_cost": 15,
			"corruption_cost": 10,
			"energy_gain": 1,
		},
		{
			"id": "blood_offering",
			"title": "Blood Offering",
			"description": "Draw 3 extra cards next turn.\nCost: 10 HP, teammates take 5 damage.",
			"benefit": "draw",
			"hp_cost": 10,
			"corruption_cost": 5,
			"draw_gain": 3,
			"team_damage": 5,
		},
		{
			"id": "hellfire_pact",
			"title": "Hellfire Pact",
			"description": "Your attacks deal +50% damage for 2 turns.\nCost: 20 HP, +15 corruption.",
			"benefit": "damage",
			"hp_cost": 20,
			"corruption_cost": 15,
			"damage_boost_turns": 2,
		},
		{
			"id": "soul_bargain",
			"title": "Soul Bargain",
			"description": "Fully heal yourself.\nCost: +25 corruption, lose 2 random cards.",
			"benefit": "heal",
			"hp_cost": 0,
			"corruption_cost": 25,
			"cards_lost": 2,
		},
		{
			"id": "demons_gift",
			"title": "Demon's Gift",
			"description": "Gain 20 Block.\nCost: 8 HP, +5 corruption.",
			"benefit": "block",
			"hp_cost": 8,
			"corruption_cost": 5,
			"block_gain": 20,
		},
	]
	return pacts[randi() % pacts.size()]

# Accept a pact — apply benefit and cost
static func accept_pact(pact: Dictionary, ps: PlayerState, all_players: Dictionary) -> Dictionary:
	var result = {"accepted": true, "pact_id": pact["id"], "effects": []}

	# Apply HP cost
	if pact.get("hp_cost", 0) > 0:
		ps.current_hp = maxi(ps.current_hp - pact["hp_cost"], 1)
		result["effects"].append("Lost %d HP" % pact["hp_cost"])

	# Apply corruption cost
	if pact.get("corruption_cost", 0) > 0:
		ps.corruption = mini(ps.corruption + pact["corruption_cost"], ps.max_corruption)
		result["effects"].append("+%d corruption" % pact["corruption_cost"])

	# Apply benefits
	match pact.get("benefit", ""):
		"energy":
			ps.max_energy += pact.get("energy_gain", 1)
			ps.energy += pact.get("energy_gain", 1)
			result["effects"].append("+%d max energy" % pact.get("energy_gain", 1))
		"draw":
			ps.draw_penalty -= pact.get("draw_gain", 3)  # Negative penalty = bonus draws
			result["effects"].append("Draw %d extra next turn" % pact.get("draw_gain", 3))
		"damage":
			ps.pact_damage_boost = pact.get("damage_boost_turns", 2)
			result["effects"].append("+50%% damage for %d turns" % pact.get("damage_boost_turns", 2))
		"heal":
			ps.current_hp = ps.max_hp
			# Lose random cards
			var lost = pact.get("cards_lost", 2)
			for _i in lost:
				if ps.draw_pile.size() > 0:
					ps.draw_pile.remove_at(randi() % ps.draw_pile.size())
			result["effects"].append("Fully healed, lost %d cards" % lost)
		"block":
			ps.block += pact.get("block_gain", 20)
			result["effects"].append("+%d Block" % pact.get("block_gain", 20))

	# Team damage (for blood_offering)
	if pact.get("team_damage", 0) > 0:
		for pid in all_players:
			if pid != ps.peer_id:
				var teammate = all_players[pid]
				if teammate.current_hp > 0 and not teammate.is_dead:
					teammate.current_hp = maxi(teammate.current_hp - pact["team_damage"], 1)
		result["effects"].append("Teammates took %d damage" % pact["team_damage"])

	return result

# Tick down pact effects at start of turn
static func tick_pact_effects(ps: PlayerState) -> void:
	if ps.pact_damage_boost > 0:
		ps.pact_damage_boost -= 1

# Get pact damage multiplier
static func get_pact_damage_multiplier(ps: PlayerState) -> float:
	if ps.pact_damage_boost > 0:
		return 1.5
	return 1.0
