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
		"strength_gained": 0,
		"dexterity_gained": 0,
	}

	# Deduct energy
	player.energy -= card.energy_cost

	# Activate gem modifiers for this card (CARD_PLAY lifecycle)
	GemSystem.activate_gems_for_card(player, card.id)

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

	# Damage — fully resolved through StatResolver (strength, corruption,
	# pact, equipment, gems, vulnerable, weak all handled in pipeline)
	if effective_damage > 0 and target:
		if target.shielded:
			# Boss shield absorbs all damage — no HP change
			result["damage_dealt"] = 0
		else:
			var total_damage = 0
			for hit_i in effective_hits:
				var dmg = StatResolver.resolve_damage(effective_damage, player, target, card)
				# Marked enemy takes +50% damage from all sources
				if target.marked > 0:
					dmg = int(dmg * 1.5)
				# Apply through block
				if target.block > 0:
					var blocked = mini(dmg, target.block)
					target.block -= blocked
					dmg -= blocked
				target.current_hp -= dmg
				total_damage += dmg
			target.current_hp = maxi(target.current_hp, 0)
			result["damage_dealt"] = total_damage
			# Track total damage dealt in run stats
			if GameManager.is_run_active():
				GameManager.current_run.total_damage_dealt += total_damage

	# Block — fully resolved through StatResolver (dexterity, equipment, gems)
	if effective_block > 0:
		var final_block = StatResolver.resolve_block(effective_block, player, card)
		player.block += final_block
		result["block_gained"] = final_block

	# Heal — fully resolved through StatResolver (sin penalty, equipment, gems)
	if effective_heal > 0:
		var heal_amount = StatResolver.resolve_healing(effective_heal, player, card)
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

	if card.gain_strength > 0:
		player.strength += card.gain_strength
		result["strength_gained"] = card.gain_strength
	if card.gain_dexterity > 0:
		player.dexterity += card.gain_dexterity
		result["dexterity_gained"] = card.gain_dexterity

	# Deactivate gem modifiers
	GemSystem.deactivate_gems(player)

	# Set cooldown if card has one
	CooldownTracker.set_cooldown(player, card.id)

	# Party effect flags (processed by CombatEngine after resolve)
	result["party_heal"] = card.party_heal
	result["party_draw"] = card.party_draw
	result["party_damage"] = card.party_damage
	result["share_block"] = card.share_block
	result["transfer_mana"] = card.transfer_mana
	result["mark_target"] = card.mark_target

	# Revival flags (processed by CombatEngine._process_revive)
	result["revive_ally"] = card.revive_ally
	result["revive_hp"] = card.revive_hp

	return result
