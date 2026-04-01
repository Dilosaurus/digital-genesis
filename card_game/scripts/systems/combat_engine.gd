class_name CombatEngine
extends RefCounted

signal state_changed()
signal card_was_played(peer_id: int, card_id: String, target_index: int, result: Dictionary)
signal enemy_acted(enemy_index: int, intent_type: int, value: int, target_peer_id: int, damage_dealt: int)
signal combat_ended(won: bool)
signal sin_punished(peer_id: int, sin_result: Dictionary)
signal player_entered_deaths_door(peer_id: int)
signal player_died(peer_id: int)
signal corruption_tier_changed(peer_id: int, new_tier: int)
signal soul_fragments_changed(total: int)
signal boss_absorbed_souls(amount: int)
signal tithe_demanded(cost: int)
signal pact_offered(peer_id: int, pact: Dictionary)

var state: CombatState

func initialize(peer_ids: Array[int], enemy_data_id: String) -> void:
	state = CombatState.new()

	# Create player states
	for peer_id in peer_ids:
		var ps = PlayerState.new()
		ps.peer_id = peer_id
		ps.display_name = "Player %d" % peer_id
		ps.draw_pile = DeckManager.create_starter_deck()
		DeckManager.shuffle(ps.draw_pile)
		state.players[peer_id] = ps

	# Create enemy
	var enemy_data: EnemyData = load("res://data/enemies/%s.tres" % enemy_data_id)
	var es = EnemyState.new()
	es.enemy_data_id = enemy_data_id
	es.max_hp = _scale_hp(enemy_data.max_hp, peer_ids.size())
	es.current_hp = es.max_hp
	EnemyAI.pick_intent(es, enemy_data)
	state.enemies.append(es)

	start_player_turn()

func _scale_hp(base_hp: int, player_count: int) -> int:
	# Scale enemy HP with player count (STS2-style)
	if player_count <= 1:
		return base_hp
	return int(base_hp * (1.0 + 0.5 * (player_count - 1)))

func start_player_turn() -> void:
	state.turn_number += 1
	state.phase = Enums.CombatPhase.PLAYER_TURN

	for peer_id in state.players:
		var ps: PlayerState = state.players[peer_id]
		if ps.is_dead:
			ps.has_ended_turn = true
			continue

		# Tick Death's Door
		if DeathsDoorSystem.tick(ps):
			player_died.emit(peer_id)
			ps.has_ended_turn = true
			continue

		# Corruption burn damage at high tiers
		var burn = CorruptionSystem.get_corruption_burn(ps)
		if burn > 0:
			ps.current_hp = maxi(ps.current_hp - burn, 0)
			if ps.current_hp <= 0:
				if DeathsDoorSystem.check_deaths_door(ps):
					player_entered_deaths_door.emit(peer_id)

		# Tick sin penalties
		SinSystem.tick_penalties(ps)

		# Tick pact effects
		PactSystem.tick_pact_effects(ps)

		ps.energy = ps.max_energy
		ps.block = 0
		ps.has_ended_turn = false
		var draw_count = maxi(5 - ps.draw_penalty, 1)
		DeckManager.draw(ps, draw_count)

	# Blood Tithe check
	if TitheSystem.is_tithe_turn(state.turn_number):
		var cost = TitheSystem.get_tithe_cost(state.turn_number, state.players.size())
		tithe_demanded.emit(cost)

	state_changed.emit()

func try_play_card(peer_id: int, hand_index: int, target_index: int) -> bool:
	if state.phase != Enums.CombatPhase.PLAYER_TURN:
		return false

	var ps: PlayerState = state.players.get(peer_id)
	if not ps or ps.has_ended_turn or ps.is_dead:
		return false

	if hand_index < 0 or hand_index >= ps.hand.size():
		return false

	var card_id = ps.hand[hand_index]
	var card_data = GameManager.get_card_data(card_id)
	if not card_data:
		return false

	# Check energy
	if ps.energy < card_data.energy_cost:
		return false

	# Get target
	var target: EnemyState = null
	if card_data.target_type == Enums.TargetType.ENEMY:
		if target_index < 0 or target_index >= state.enemies.size():
			return false
		target = state.enemies[target_index]

	# Remove card from hand (before resolving, so hand_index is valid)
	ps.hand.remove_at(hand_index)
	ps.discard_pile.append(card_id)

	# Handle ALL_ENEMIES target type (e.g. Cleave)
	if card_data.target_type == Enums.TargetType.ALL_ENEMIES:
		var total_result = {
			"card_id": card_id, "damage_dealt": 0, "block_gained": 0,
			"heal_amount": 0, "vulnerable_applied": 0, "weak_applied": 0,
		}
		for enemy in state.enemies:
			if enemy.current_hp > 0:
				var r = CardResolver.resolve(card_data, ps, enemy)
				total_result["damage_dealt"] += r["damage_dealt"]
				# Refund energy since resolver deducts it each time
				ps.energy += card_data.energy_cost
		ps.energy -= card_data.energy_cost  # Only deduct once total
		_post_card_played(peer_id, ps, card_data, total_result["damage_dealt"])
		card_was_played.emit(peer_id, card_id, target_index, total_result)
		state_changed.emit()
		_check_combat_end()
		return true

	# Resolve single target
	var result = CardResolver.resolve(card_data, ps, target)

	_post_card_played(peer_id, ps, card_data, result["damage_dealt"])
	card_was_played.emit(peer_id, card_id, target_index, result)
	state_changed.emit()

	_check_combat_end()

	return true

func _post_card_played(peer_id: int, ps: PlayerState, card_data: CardData, damage_dealt: int = 0) -> void:
	# Soul fragments from damage
	var frags = SoulSystem.calculate_fragments(damage_dealt)
	if frags > 0:
		SoulSystem.collect_fragments(state, frags)
		soul_fragments_changed.emit(state.soul_fragments)

	# Corrupted card self-damage and extra corruption
	if CardCorruption.should_corrupt(card_data.id, ps.corruption_tier):
		var overrides = CardCorruption.get_corrupted_overrides(card_data.id)
		var self_dmg = overrides.get("self_damage", 0)
		if self_dmg > 0:
			ps.current_hp = maxi(ps.current_hp - self_dmg, 0)
			if ps.current_hp <= 0:
				if DeathsDoorSystem.check_deaths_door(ps):
					player_entered_deaths_door.emit(peer_id)
		var extra_corr = overrides.get("extra_corruption", 0)
		if extra_corr > 0:
			CorruptionSystem.add_corruption(ps, extra_corr)

	# Corruption gain from card data
	var corr = CorruptionSystem.get_card_corruption(card_data)
	if corr > 0:
		var new_tier = CorruptionSystem.add_corruption(ps, corr)
		if new_tier >= 0:
			corruption_tier_changed.emit(peer_id, new_tier)

	# Sin tracking
	var triggered_sin = SinSystem.add_sin_for_card(ps, card_data)
	if triggered_sin >= 0:
		var sin_result = SinSystem.apply_punishment(ps, triggered_sin, state.enemies)
		sin_punished.emit(peer_id, sin_result)
		# Check if Wrath self-damage killed them
		if ps.current_hp <= 0:
			if DeathsDoorSystem.check_deaths_door(ps):
				player_entered_deaths_door.emit(peer_id)

	# Pact offer chance (corruption-gated, not after combat ends)
	if state.phase != Enums.CombatPhase.COMBAT_OVER and PactSystem.should_offer_pact(state.turn_number, ps.corruption):
		var pact = PactSystem.get_random_pact()
		pact_offered.emit(peer_id, pact)

func player_end_turn(peer_id: int) -> void:
	if state.phase != Enums.CombatPhase.PLAYER_TURN:
		return

	var ps: PlayerState = state.players.get(peer_id)
	if not ps or ps.has_ended_turn or ps.is_dead:
		return

	ps.has_ended_turn = true
	DeckManager.discard_hand(ps)
	state_changed.emit()

	# Check if all living players have ended their turn
	var all_done = true
	for pid in state.players:
		var p: PlayerState = state.players[pid]
		if not p.is_dead and not p.has_ended_turn:
			all_done = false
			break

	if all_done:
		execute_enemy_turn()

func execute_enemy_turn() -> void:
	state.phase = Enums.CombatPhase.ENEMY_TURN

	var peer_ids = state.players.keys()

	for i in state.enemies.size():
		var enemy = state.enemies[i]
		if enemy.current_hp <= 0:
			continue

		if enemy.intent_type == Enums.EnemyIntent.ATTACK:
			# Attack all living players (STS2 style)
			for peer_id in peer_ids:
				var ps: PlayerState = state.players[peer_id]
				if ps.is_dead:
					continue
				var dmg = enemy.intent_value + SoulSystem.get_boss_damage_bonus(state)
				if enemy.weak > 0:
					dmg = int(dmg * 0.75)
				if ps.vulnerable > 0:
					dmg = int(dmg * 1.5)
				var actual_dmg = dmg
				if ps.block > 0:
					var blocked = mini(dmg, ps.block)
					ps.block -= blocked
					actual_dmg = dmg - blocked
				ps.current_hp -= actual_dmg
				ps.current_hp = maxi(ps.current_hp, 0)
				enemy_acted.emit(i, enemy.intent_type, enemy.intent_value, peer_id, actual_dmg)
				# Death's Door check
				if ps.current_hp <= 0:
					if DeathsDoorSystem.check_deaths_door(ps):
						player_entered_deaths_door.emit(peer_id)

		elif enemy.intent_type == Enums.EnemyIntent.DEFEND:
			enemy.block += enemy.intent_value
			enemy_acted.emit(i, enemy.intent_type, enemy.intent_value, 0, 0)

		elif enemy.intent_type == Enums.EnemyIntent.HACK:
			# Hack targets a random living player — damage is deferred to client minigame
			var living_peers = []
			for peer_id in peer_ids:
				if state.players[peer_id].current_hp > 0:
					living_peers.append(peer_id)
			if living_peers.size() > 0:
				var target = living_peers[randi() % living_peers.size()]
				enemy_acted.emit(i, enemy.intent_type, enemy.intent_value, target, 0)

		# Tick enemy debuffs
		enemy.vulnerable = maxi(enemy.vulnerable - 1, 0)
		enemy.weak = maxi(enemy.weak - 1, 0)

	# Tick player debuffs
	for peer_id in state.players:
		var ps: PlayerState = state.players[peer_id]
		ps.vulnerable = maxi(ps.vulnerable - 1, 0)
		ps.weak = maxi(ps.weak - 1, 0)

	# Boss absorbs uncollected soul fragments
	var absorbed = SoulSystem.boss_absorb(state)
	if absorbed > 0:
		boss_absorbed_souls.emit(absorbed)
		soul_fragments_changed.emit(state.soul_fragments)

	# Pick next intents
	for enemy in state.enemies:
		if enemy.current_hp > 0:
			var enemy_data: EnemyData = load("res://data/enemies/%s.tres" % enemy.enemy_data_id)
			EnemyAI.pick_intent(enemy, enemy_data)

	state_changed.emit()

	if not _check_combat_end():
		start_player_turn()

func _check_combat_end() -> bool:
	# Check if all enemies dead
	var all_enemies_dead = true
	for enemy in state.enemies:
		if enemy.current_hp > 0:
			all_enemies_dead = false
			break

	if all_enemies_dead:
		state.phase = Enums.CombatPhase.COMBAT_OVER
		combat_ended.emit(true)
		return true

	# Check if all players dead (truly dead, not just on Death's Door)
	var all_players_dead = true
	for peer_id in state.players:
		if not DeathsDoorSystem.is_truly_dead(state.players[peer_id]):
			all_players_dead = false
			break

	if all_players_dead:
		state.phase = Enums.CombatPhase.COMBAT_OVER
		combat_ended.emit(false)
		return true

	return false
