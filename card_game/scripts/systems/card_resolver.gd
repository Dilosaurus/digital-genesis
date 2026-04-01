class_name CardResolver
extends RefCounted

static func resolve(card: CardData, player: PlayerState, target: EnemyState) -> Dictionary:
	var result = {
		"card_id": card.id,
		"damage_dealt": 0,
		"block_gained": 0,
		"heal_amount": 0,
		"vulnerable_applied": 0,
		"weak_applied": 0,
	}

	# Deduct energy
	player.energy -= card.energy_cost

	# Check for corrupted card overrides
	var c_overrides = {}
	if CardCorruption.should_corrupt(card.id, player.corruption_tier):
		c_overrides = CardCorruption.get_corrupted_overrides(card.id)

	# Special: Body Slam — damage equals current block
	var effective_damage = c_overrides.get("damage", card.damage)
	if card.id == "body_slam":
		effective_damage = player.block
	var effective_hits = c_overrides.get("hits", card.hits)
	var effective_block = c_overrides.get("block", card.block)
	var effective_heal = c_overrides.get("heal", card.heal)
	var effective_vuln = c_overrides.get("apply_vulnerable", card.apply_vulnerable)
	var effective_weak = c_overrides.get("apply_weak", card.apply_weak)

	# Apply damage
	if effective_damage > 0 and target:
		var total_damage = 0
		for hit_i in effective_hits:
			var dmg = effective_damage
			# Corruption damage bonus
			dmg = int(dmg * CorruptionSystem.get_damage_multiplier(player))
			# Pact damage boost
			dmg = int(dmg * PactSystem.get_pact_damage_multiplier(player))
			# Vulnerable: target takes 50% more damage
			if target.vulnerable > 0:
				dmg = int(dmg * 1.5)
			# Weak: player deals 25% less damage
			if player.weak > 0:
				dmg = int(dmg * 0.75)
			# Apply through block
			if target.block > 0:
				var blocked = mini(dmg, target.block)
				target.block -= blocked
				dmg -= blocked
			target.current_hp -= dmg
			total_damage += dmg
		target.current_hp = maxi(target.current_hp, 0)
		result["damage_dealt"] = total_damage

	# Apply block
	if effective_block > 0:
		player.block += effective_block
		result["block_gained"] = effective_block

	# Apply heal (affected by Pride sin penalty)
	if effective_heal > 0:
		var heal_amount = int(effective_heal * SinSystem.get_heal_multiplier(player))
		var actual_heal = mini(heal_amount, player.max_hp - player.current_hp)
		player.current_hp += actual_heal
		result["heal_amount"] = actual_heal

	# Apply debuffs
	if effective_vuln > 0 and target:
		target.vulnerable += effective_vuln
		result["vulnerable_applied"] = effective_vuln

	if effective_weak > 0 and target:
		target.weak += effective_weak
		result["weak_applied"] = effective_weak

	# Draw cards
	if card.draw > 0:
		DeckManager.draw(player, card.draw)

	return result
