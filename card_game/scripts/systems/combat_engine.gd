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
signal boss_mechanic(mechanic_name: String, data: Dictionary)

var state: CombatState
var boss_encounter: BossEncounter = null

func initialize(peer_ids: Array[int], enemy_data_id: String) -> void:
	# Convenience wrapper for single-enemy initialisation (backwards compat).
	initialize_multi(peer_ids, [enemy_data_id])

func initialize_multi(peer_ids: Array[int], enemy_data_ids: Array) -> void:
	state = CombatState.new()

	# Create player states
	for peer_id in peer_ids:
		var ps = PlayerState.new()
		ps.peer_id = peer_id
		ps.display_name = "Player %d" % peer_id
		ps.draw_pile = DeckManager.create_starter_deck()
		DeckManager.shuffle(ps.draw_pile)
		state.players[peer_id] = ps

	# Create one EnemyState per enemy ID
	for enemy_data_id in enemy_data_ids:
		var enemy_data: EnemyData = load("res://data/enemies/%s.tres" % enemy_data_id)
		if not enemy_data:
			push_warning("CombatEngine: enemy data not found for '%s'" % enemy_data_id)
			continue
		var es = EnemyState.new()
		es.enemy_data_id = enemy_data_id
		es.max_hp = _scale_hp(enemy_data.max_hp, peer_ids.size())
		es.current_hp = es.max_hp
		EnemyAI.pick_intent(es, enemy_data)
		state.enemies.append(es)

	# Populate modifier stacks from persistent sources (equipment, etc.)
	if GameManager.is_run_active():
		for peer_id in state.players:
			var ps_init: PlayerState = state.players[peer_id]
			ModifierBridge.populate_combat_start(ps_init, GameManager.current_run)
			# Set character identity — use per-player map in co-op, fallback to run
			if GameManager.per_player_characters.has(peer_id):
				ps_init.character_id = GameManager.per_player_characters[peer_id]
			else:
				ps_init.character_id = GameManager.current_run.character_id
			# Sysadmin passive: start combat with 5 Block
			if ps_init.character_id == "sysadmin":
				ps_init.block = 5
			# Technomancer passive: Daemon Forge — +1 mana regen
			if ps_init.character_id == "technomancer":
				ps_init.mana_regen = 4
			# Apply max mana bonus from leveling
			ps_init.max_energy += GameManager.current_run.max_mana_bonus
			# Start combat with full mana pool
			ps_init.energy = ps_init.max_energy

	# Initialize boss encounter if applicable
	for es in state.enemies:
		var encounter = BossEncounter.create_for_boss(es.enemy_data_id)
		if encounter:
			encounter.initialize(state, es)
			encounter.mechanic_triggered.connect(func(name: String, data: Dictionary):
				boss_mechanic.emit(name, data)
			)
			boss_encounter = encounter
			break  # Only one boss encounter per combat

	start_player_turn()

func _scale_hp(base_hp: int, player_count: int) -> int:
	# Scale enemy HP with player count (STS2-style)
	if player_count <= 1:
		return base_hp
	return int(base_hp * (1.0 + 0.5 * (player_count - 1)))

func start_player_turn() -> void:
	state.turn_number += 1
	state.phase = Enums.CombatPhase.PLAYER_TURN
	state.turn_damage = PartyManager.init_turn_damage(state)

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

		# Tick modifier durations (handles pact boost expiry, sin penalties, etc.)
		ModifierBridge.tick_turn(ps)

		# Tick card cooldowns
		CooldownTracker.tick(ps)

		ManaSystem.regen(ps)
		ps.block = 0
		ps.has_ended_turn = false
		var draw_count = maxi(5 - ps.draw_penalty, 1)
		# Netrunner passive: +1 card draw per turn
		if ps.character_id == "netrunner":
			draw_count += 1
		DeckManager.draw(ps, draw_count)

	# Blood Tithe check
	if TitheSystem.is_tithe_turn(state.turn_number):
		var cost = TitheSystem.get_tithe_cost(state.turn_number, state.players.size())
		tithe_demanded.emit(cost)

	# Boss mechanics -- turn start
	if boss_encounter:
		var boss_results = boss_encounter.on_player_turn_start(state.turn_number)
		for r in boss_results:
			# Check if boss mechanic killed anyone
			for pid in state.players:
				var p: PlayerState = state.players[pid]
				if p.current_hp <= 0 and not p.is_dead and not p.is_on_deaths_door:
					if DeathsDoorSystem.check_deaths_door(p):
						player_entered_deaths_door.emit(pid)

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

	# Check cooldown
	if CooldownTracker.is_on_cooldown(ps, card_id):
		return false

	# White Hat passive: Holy-tagged cards cost 1 less energy
	var effective_cost = card_data.energy_cost
	if ps.character_id == "white_hat" and Enums.CardTag.HOLY in card_data.tags:
		effective_cost = maxi(0, effective_cost - 1)

	# Check energy
	if ps.energy < effective_cost:
		return false

	# Get target
	var target: EnemyState = null
	if card_data.target_type == Enums.TargetType.ENEMY:
		if target_index < 0 or target_index >= state.enemies.size():
			return false
		target = state.enemies[target_index]

	# Remove card from hand (before resolving, so hand_index is valid)
	ps.hand.remove_at(hand_index)
	if card_data.exhaust:
		ps.exhaust_pile.append(card_id)
	else:
		ps.discard_pile.append(card_id)

	# Compensate for White Hat discount: resolver always deducts card.energy_cost,
	# so pre-credit the difference so the net deduction equals effective_cost.
	var _wh_discount = card_data.energy_cost - effective_cost
	if _wh_discount > 0:
		ps.energy += _wh_discount

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
		# Process party effects once (not per-enemy)
		_process_party_effects(peer_id, ps, card_data, null)
		_post_card_played(peer_id, ps, card_data, total_result["damage_dealt"])
		card_was_played.emit(peer_id, card_id, target_index, total_result)
		_check_phase_transitions()
		_process_revive(card_data)
		state_changed.emit()
		_check_combat_end()
		return true

	# Resolve single target
	var result = CardResolver.resolve(card_data, ps, target)

	# Process party effects once (after resolve, before post-play hooks)
	_process_party_effects(peer_id, ps, card_data, target)

	_post_card_played(peer_id, ps, card_data, result["damage_dealt"])
	card_was_played.emit(peer_id, card_id, target_index, result)
	_check_phase_transitions()
	_process_revive(card_data)
	state_changed.emit()

	_check_combat_end()

	return true

func _post_card_played(peer_id: int, ps: PlayerState, card_data: CardData, damage_dealt: int = 0) -> void:
	# Soul fragments from damage
	var frags = SoulSystem.calculate_fragments(damage_dealt)
	if frags > 0:
		SoulSystem.collect_fragments(state, frags)
		soul_fragments_changed.emit(state.soul_fragments)

	# Track damage for boss mechanics
	PartyManager.record_damage(state.turn_damage, peer_id, damage_dealt)

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

	# Corruption gain (or removal if negative) from card data
	var corr = CorruptionSystem.get_card_corruption(card_data)
	if corr > 0:
		var new_tier = CorruptionSystem.add_corruption(ps, corr)
		if new_tier >= 0:
			corruption_tier_changed.emit(peer_id, new_tier)
	elif corr < 0:
		CorruptionSystem.remove_corruption(ps, -corr)

	# Sin tracking
	var triggered_sin = SinSystem.add_sin_for_card(ps, card_data)
	if triggered_sin >= 0:
		var sin_result = SinSystem.apply_punishment(ps, triggered_sin, state.enemies)
		sin_punished.emit(peer_id, sin_result)
		# Check if Wrath self-damage killed them
		if ps.current_hp <= 0:
			if DeathsDoorSystem.check_deaths_door(ps):
				player_entered_deaths_door.emit(peer_id)

	# Power Surge: gain max energy
	if card_data.id == "power_surge":
		ps.max_energy += 1
		ps.energy += 1

	# Pact offer chance (corruption-gated, not after combat ends)
	if state.phase != Enums.CombatPhase.COMBAT_OVER and PactSystem.should_offer_pact(state.turn_number, ps.corruption):
		var pact = PactSystem.get_random_pact()
		pact_offered.emit(peer_id, pact)

# ---------------------------------------------------------------------------
# Party / co-op card effects
# ---------------------------------------------------------------------------
func _process_party_effects(peer_id: int, ps: PlayerState, card: CardData, target: EnemyState) -> void:
	# Party heal — heal ALL living players
	if card.party_heal > 0:
		for pid in state.players:
			var p: PlayerState = state.players[pid]
			if not p.is_dead:
				var actual = mini(card.party_heal, p.max_hp - p.current_hp)
				p.current_hp += actual

	# Party draw bonus next turn (stored as negative draw_penalty)
	if card.party_draw > 0:
		for pid in state.players:
			var p: PlayerState = state.players[pid]
			if not p.is_dead:
				p.draw_penalty -= card.party_draw

	# Party damage — ALL players take this damage (self-harm mechanic)
	if card.party_damage > 0:
		for pid in state.players:
			var p: PlayerState = state.players[pid]
			if not p.is_dead:
				p.current_hp = maxi(p.current_hp - card.party_damage, 0)
				if p.current_hp <= 0:
					if DeathsDoorSystem.check_deaths_door(p):
						player_entered_deaths_door.emit(pid)

	# Share block — split caster's block evenly among all living players
	if card.share_block:
		var living: Array[int] = []
		for pid in state.players:
			if not state.players[pid].is_dead:
				living.append(pid)
		if living.size() > 1:
			var share_per = int(ps.block / living.size())
			ps.block = share_per
			for pid in living:
				if pid != peer_id:
					state.players[pid].block += share_per

	# Transfer mana — send mana to the living ally with the lowest energy
	if card.transfer_mana > 0:
		var best_target: PlayerState = null
		var lowest_energy: int = 999
		for pid in state.players:
			var p: PlayerState = state.players[pid]
			if pid != peer_id and not p.is_dead and p.energy < lowest_energy:
				lowest_energy = p.energy
				best_target = p
		if best_target:
			var actual = mini(card.transfer_mana, ps.energy)
			ps.energy -= actual
			best_target.energy = mini(best_target.energy + actual, best_target.max_energy)

	# Mark target — enemy takes +50% damage from all sources this turn
	if card.mark_target and target:
		target.marked = 1

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
				var dmg = enemy.intent_value + enemy.strength + SoulSystem.get_boss_damage_bonus(state)
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

		elif enemy.intent_type == Enums.EnemyIntent.BUFF:
			enemy.strength += enemy.intent_value
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
		enemy.marked = maxi(enemy.marked - 1, 0)

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

	# Boss mechanics -- enemy turn end
	if boss_encounter:
		boss_encounter.on_enemy_turn_end(state.turn_number)

	state_changed.emit()

	if not _check_combat_end():
		start_player_turn()

# ---------------------------------------------------------------------------
# Revival processing (Phase 3 Stream D)
# ---------------------------------------------------------------------------
func _process_revive(card_data: CardData) -> void:
	if not card_data.revive_ally:
		return
	var downed = DeathsDoorSystem.get_first_downed(state)
	if not downed:
		return
	var hp = card_data.revive_hp if card_data.revive_hp > 0 else 15
	if downed.is_dead:
		DeathsDoorSystem.revive_from_death(downed, hp)
	else:
		DeathsDoorSystem.stabilize(downed, hp)
	state_changed.emit()

func _check_combat_end() -> bool:
	# Check if all enemies dead
	var all_enemies_dead = true
	for enemy in state.enemies:
		if enemy.current_hp > 0:
			all_enemies_dead = false
			break

	if all_enemies_dead:
		# Unlock lore entries for all defeated enemies
		for enemy in state.enemies:
			LoreManager.unlock_entry("enemies", enemy.enemy_data_id)
		# Grant XP for each killed enemy + room completion bonus
		_grant_combat_xp()
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

# ---------------------------------------------------------------------------
# XP / Leveling
# ---------------------------------------------------------------------------
func _grant_combat_xp() -> void:
	if not GameManager.is_run_active():
		return
	var run: RunState = GameManager.current_run

	# Grant XP for each enemy killed
	for enemy in state.enemies:
		var xp_amount = LevelSystem.get_enemy_xp(enemy.enemy_data_id)
		var level_ups = LevelSystem.grant_xp(run, xp_amount)
		EventBus.xp_gained.emit(xp_amount, run.xp)
		for rewards in level_ups:
			EventBus.player_leveled_up.emit(rewards["level"], rewards)

	# Room completion bonus
	var room_xp = LevelSystem.get_room_completion_xp()
	var room_level_ups = LevelSystem.grant_xp(run, room_xp)
	EventBus.xp_gained.emit(room_xp, run.xp)
	for rewards in room_level_ups:
		EventBus.player_leveled_up.emit(rewards["level"], rewards)

# ---------------------------------------------------------------------------
# Boss phase transitions
# ---------------------------------------------------------------------------
func _check_phase_transitions() -> void:
	for enemy in state.enemies:
		if enemy.current_hp <= 0:
			continue
		var enemy_data: EnemyData = load("res://data/enemies/%s.tres" % enemy.enemy_data_id)
		if not enemy_data or enemy_data.phases.is_empty():
			continue

		var hp_pct: float = float(enemy.current_hp) / float(enemy.max_hp)

		# Find the highest-index phase whose threshold we've crossed
		for i in enemy_data.phases.size():
			var phase: Dictionary = enemy_data.phases[i]
			var threshold: float = phase.get("hp_threshold", 0.0)
			if hp_pct <= threshold and i > enemy.current_phase_index:
				# Transition to this phase
				enemy.current_phase_index = i
				enemy.phase_intent_index = 0
				_apply_phase_enter_effect(enemy, phase)
				# Re-pick intent from the new phase pool
				EnemyAI.pick_intent(enemy, enemy_data)
				print("Boss %s entered phase %d (HP %.0f%%)" % [
					enemy.enemy_data_id, i + 1, hp_pct * 100.0])

func _apply_phase_enter_effect(enemy: EnemyState, phase: Dictionary) -> void:
	var effect: String = phase.get("on_enter", "")
	var value: int = phase.get("on_enter_value", 0)
	match effect:
		"strength_buff":
			enemy.strength += value
		"heal":
			enemy.current_hp = mini(enemy.current_hp + value, enemy.max_hp)
		"block_buff":
			enemy.block += value
		"shuffle_discard":
			# Shuffle all player discard piles back into draw piles
			for peer_id in state.players:
				var ps: PlayerState = state.players[peer_id]
				if ps.is_dead:
					continue
				ps.draw_pile.append_array(ps.discard_pile)
				ps.discard_pile.clear()
				DeckManager.shuffle(ps.draw_pile)
			# Also grant strength if value is set
			if value > 0:
				enemy.strength += value
		"dialogue":
			# Cosmetic only — handled by UI listening to state changes
			pass
