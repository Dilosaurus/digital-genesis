extends Control

const EnemyDisplayScene = preload("res://scenes/combat/enemy_display.tscn")
const PlayerBoardScene = preload("res://scenes/combat/player_board.tscn")
const DamageNumberScript = preload("res://scripts/ui/damage_number.gd")
const RewardScreenScene = preload("res://scenes/ui/reward_screen.tscn")
const HackChallengeScene = preload("res://scenes/ui/hack_challenge.tscn")
const CorruptionMeterScene = preload("res://scenes/ui/corruption_meter.tscn")
const SinDisplayScene = preload("res://scenes/ui/sin_display.tscn")
const DeathsDoorOverlayScene = preload("res://scenes/ui/deaths_door_overlay.tscn")
const SoulDisplayScene = preload("res://scenes/ui/soul_display.tscn")
const TitheScreenScene = preload("res://scenes/ui/tithe_screen.tscn")
const PactScreenScene = preload("res://scenes/ui/pact_screen.tscn")

@onready var enemy_area: Control = $ShakeContainer/EnemyArea
@onready var hand_display = $HandDisplay
@onready var player_boards: HBoxContainer = $ShakeContainer/PlayerBoards
@onready var end_turn_btn: Button = $HUD/EndTurnButton
@onready var turn_label: Label = $HUD/TurnLabel
@onready var deck_count_label: Label = $HUD/DeckCount
@onready var discard_count_label: Label = $HUD/DiscardCount
@onready var result_panel: Panel = $HUD/ResultPanel
@onready var result_label: Label = $HUD/ResultPanel/ResultLabel
@onready var continue_btn: Button = $HUD/ResultPanel/ContinueButton
@onready var shake_container: Control = $ShakeContainer

var engine: CombatEngine
var local_peer_id: int = 1
var is_server: bool = true
var is_networked: bool = false

var player_board_nodes: Dictionary = {}
var enemy_display_nodes: Dictionary = {}
var cached_state: Dictionary = {}
var current_enemy_id: String = ""
var reward_screen = null
var hack_challenge = null
var corruption_meter = null
var sin_display = null
var deaths_door_overlay = null
var soul_display = null
var tithe_screen = null
var pact_screen = null

func _ready() -> void:
	result_panel.visible = false
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	hand_display.card_selected.connect(_on_card_selected)
	continue_btn.pressed.connect(_on_continue_pressed)

	# Check if we're in solo mode (launched via --solo or no real network peer)
	var is_solo = "--solo" in OS.get_cmdline_user_args() or not NetworkManager.is_host
	if not is_solo and multiplayer.has_multiplayer_peer() and NetworkManager.is_host:
		is_networked = true
		local_peer_id = multiplayer.get_unique_id()
		is_server = multiplayer.is_server()
		if is_server:
			await get_tree().create_timer(0.5).timeout
			_start_networked_combat()
		else:
			_setup_client_ui()
	elif not is_solo and multiplayer.has_multiplayer_peer() and not NetworkManager.is_host:
		is_networked = true
		local_peer_id = multiplayer.get_unique_id()
		is_server = false
		_setup_client_ui()
	else:
		_start_local_combat()

func _start_local_combat() -> void:
	is_server = true
	is_networked = false
	local_peer_id = 1
	engine = CombatEngine.new()
	_connect_engine_signals()
	var enemy = _pick_random_enemy()
	current_enemy_id = enemy
	# Solo mode: 1 human + 3 bots
	var peer_ids: Array[int] = [1, 2, 3, 4]
	print("Solo combat: %d players vs %s" % [peer_ids.size(), enemy])
	engine.initialize(peer_ids, enemy)
	_create_ui_elements_from_engine()
	_refresh_all_ui()

func _pick_random_enemy() -> String:
	var enemies = ["jaw_worm", "cultist", "louse_red", "michael"]
	return enemies[randi() % enemies.size()]

func _start_networked_combat() -> void:
	engine = CombatEngine.new()
	_connect_engine_signals()
	var peer_ids: Array[int] = NetworkManager.get_all_peer_ids()
	var enemy = _pick_random_enemy()
	current_enemy_id = enemy
	print("Starting networked combat with peers: %s vs %s" % [str(peer_ids), enemy])
	engine.initialize(peer_ids, enemy)
	_create_ui_elements_from_engine()
	_refresh_all_ui()
	var peer_id_array: Array = []
	for pid in peer_ids:
		peer_id_array.append(pid)
	_client_setup_combat.rpc(peer_id_array, enemy)
	_broadcast_state()

func _connect_engine_signals() -> void:
	engine.state_changed.connect(_on_state_changed)
	engine.card_was_played.connect(_on_card_played)
	engine.enemy_acted.connect(_on_enemy_acted)
	engine.combat_ended.connect(_on_combat_ended)
	engine.sin_punished.connect(_on_sin_punished)
	engine.player_entered_deaths_door.connect(_on_player_entered_deaths_door)
	engine.player_died.connect(_on_player_died)
	engine.corruption_tier_changed.connect(_on_corruption_tier_changed)
	engine.soul_fragments_changed.connect(_on_soul_fragments_changed)
	engine.boss_absorbed_souls.connect(_on_boss_absorbed_souls)
	engine.tithe_demanded.connect(_on_tithe_demanded)
	engine.pact_offered.connect(_on_pact_offered)

func _setup_client_ui() -> void:
	pass

# === Juice: Damage Numbers ===

func _spawn_damage_number(parent: Control, value: int, type: String) -> void:
	var label = Label.new()
	label.set_script(DamageNumberScript)
	parent.add_child(label)
	label.position = Vector2(parent.size.x / 2 - 20, parent.size.y / 2)
	label.show_number(value, type)

# === Juice: Screen Shake ===

func _do_screen_shake(intensity: float = 8.0, duration: float = 0.25) -> void:
	var target = shake_container if shake_container else self
	var orig = target.position
	var tween = create_tween()
	var steps = int(duration / 0.04)
	for i in steps:
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		intensity *= 0.8  # Decay
		tween.tween_property(target, "position", orig + offset, 0.04)
	tween.tween_property(target, "position", orig, 0.04)

# === RPCs: Server -> All Clients ===

@rpc("authority", "call_local", "reliable")
func _client_setup_combat(peer_ids: Array, _enemy_id: String) -> void:
	if is_server:
		return
	for i in 1:
		var ed = EnemyDisplayScene.instantiate()
		enemy_area.add_child(ed)
		enemy_display_nodes[i] = ed
	for peer_id in peer_ids:
		var pb = PlayerBoardScene.instantiate()
		player_boards.add_child(pb)
		player_board_nodes[int(peer_id)] = pb
	print("Client UI set up for %d players" % peer_ids.size())

@rpc("authority", "call_local", "reliable")
func _client_receive_state(state_dict: Dictionary) -> void:
	cached_state = state_dict
	_refresh_ui_from_dict(state_dict)

@rpc("authority", "reliable")
func _client_receive_hand(hand_cards: Array, energy: int, draw_count: int, discard_count: int) -> void:
	hand_display.update_hand(hand_cards, energy)
	deck_count_label.text = "Deck: %d" % draw_count
	discard_count_label.text = "Discard: %d" % discard_count

@rpc("authority", "call_local", "reliable")
func _client_card_played_fx(peer_id: int, card_id: String, target_index: int, damage: int, block: int, heal: int, vuln: int, weak: int) -> void:
	# Shake enemy on damage
	if damage > 0 and enemy_display_nodes.has(target_index):
		enemy_display_nodes[target_index].shake()
		_spawn_damage_number(enemy_display_nodes[target_index], damage, "damage")
		_do_screen_shake(clampf(float(damage) * 0.8, 3.0, 15.0))

	# Block number on player
	if block > 0 and player_board_nodes.has(peer_id):
		_spawn_damage_number(player_board_nodes[peer_id], block, "block")

	# Heal number on player
	if heal > 0 and player_board_nodes.has(peer_id):
		_spawn_damage_number(player_board_nodes[peer_id], heal, "heal")

	# Vulnerable text on enemy
	if vuln > 0 and enemy_display_nodes.has(target_index):
		_spawn_damage_number(enemy_display_nodes[target_index], vuln, "vulnerable")

	# Weak text on enemy
	if weak > 0 and enemy_display_nodes.has(target_index):
		_spawn_damage_number(enemy_display_nodes[target_index], weak, "weak")

@rpc("authority", "call_local", "reliable")
func _client_enemy_acted_fx(enemy_index: int, intent_type: int, value: int, target_peer_id: int, damage_dealt: int) -> void:
	if intent_type == Enums.EnemyIntent.ATTACK and damage_dealt > 0:
		if player_board_nodes.has(target_peer_id):
			_spawn_damage_number(player_board_nodes[target_peer_id], damage_dealt, "damage")
		# Shake screen when local player takes damage
		if target_peer_id == local_peer_id:
			_do_screen_shake(clampf(float(damage_dealt) * 1.0, 5.0, 20.0), 0.3)

	# Hack challenge — only triggers for the targeted local player
	if intent_type == Enums.EnemyIntent.HACK and target_peer_id == local_peer_id:
		_trigger_hack_challenge(value, target_peer_id)

func _trigger_hack_challenge(hack_value: int, target_peer_id: int) -> void:
	hack_challenge = HackChallengeScene.instantiate()
	add_child(hack_challenge)
	var difficulty = clampf(float(hack_value) / 20.0, 0.5, 2.0)
	hack_challenge.start_challenge(difficulty)
	hack_challenge.challenge_completed.connect(func(success: bool):
		if not success:
			# Hack succeeded — apply damage to local player
			if engine and engine.state.players.has(target_peer_id):
				var ps: PlayerState = engine.state.players[target_peer_id]
				var dmg = hack_value
				if ps.block > 0:
					var blocked = mini(dmg, ps.block)
					ps.block -= blocked
					dmg -= blocked
				ps.current_hp = maxi(ps.current_hp - dmg, 0)
				if player_board_nodes.has(target_peer_id):
					_spawn_damage_number(player_board_nodes[target_peer_id], hack_value, "damage")
				_do_screen_shake(12.0, 0.4)
				_refresh_all_ui()
		else:
			# Resisted — small block bonus as reward
			if engine and engine.state.players.has(target_peer_id):
				var ps: PlayerState = engine.state.players[target_peer_id]
				ps.block += 5
				if player_board_nodes.has(target_peer_id):
					_spawn_damage_number(player_board_nodes[target_peer_id], 5, "block")
				_refresh_all_ui()
		hack_challenge.queue_free()
		hack_challenge = null
	)

@rpc("authority", "call_local", "reliable")
func _client_combat_over(won: bool) -> void:
	result_panel.visible = true
	if won:
		result_label.text = "VICTORY!"
		result_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
		# Show boss reward screen if rewards exist
		var rewards = GameManager.get_boss_rewards(current_enemy_id)
		if rewards.size() > 0:
			await get_tree().create_timer(1.5).timeout
			result_panel.visible = false
			_show_reward_screen(rewards)
	else:
		result_label.text = "DEFEAT"
		result_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	end_turn_btn.disabled = true

func _show_reward_screen(rewards: Array[String]) -> void:
	reward_screen = RewardScreenScene.instantiate()
	add_child(reward_screen)
	var enemy_data: EnemyData = load("res://data/enemies/%s.tres" % current_enemy_id)
	var boss_name = enemy_data.display_name if enemy_data else current_enemy_id
	reward_screen.show_rewards(boss_name, rewards)
	reward_screen.card_chosen.connect(_on_reward_chosen)

func _on_reward_chosen(card_id: String) -> void:
	if card_id != "":
		print("Absorbed ability: %s" % card_id)
		# In a full roguelike, this would add to player's persistent deck
		# For now, just display confirmation
		result_panel.visible = true
		var card_data = GameManager.get_card_data(card_id)
		if card_data:
			result_label.text = "ABSORBED: %s" % card_data.display_name
			result_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	else:
		result_panel.visible = true
		result_label.text = "VICTORY!"
		result_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))

func _on_continue_pressed() -> void:
	if is_networked:
		NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")

# === RPCs: Client -> Server ===

@rpc("any_peer", "call_remote", "reliable")
func _server_play_card(hand_index: int, target_index: int) -> void:
	if not is_server:
		return
	var sender = multiplayer.get_remote_sender_id()
	engine.try_play_card(sender, hand_index, target_index)

@rpc("any_peer", "call_remote", "reliable")
func _server_end_turn() -> void:
	if not is_server:
		return
	var sender = multiplayer.get_remote_sender_id()
	engine.player_end_turn(sender)

# === UI Element Creation ===

func _create_ui_elements_from_engine() -> void:
	for i in engine.state.enemies.size():
		var ed = EnemyDisplayScene.instantiate()
		enemy_area.add_child(ed)
		enemy_display_nodes[i] = ed
	for peer_id in engine.state.players:
		var pb = PlayerBoardScene.instantiate()
		player_boards.add_child(pb)
		player_board_nodes[peer_id] = pb

	# M1 UI: Corruption meter + Sin display (top-left HUD)
	corruption_meter = CorruptionMeterScene.instantiate()
	add_child(corruption_meter)
	corruption_meter.position = Vector2(10, 40)

	sin_display = SinDisplayScene.instantiate()
	add_child(sin_display)
	sin_display.position = Vector2(10, 90)

	# Death's Door overlay (hidden by default)
	deaths_door_overlay = DeathsDoorOverlayScene.instantiate()
	add_child(deaths_door_overlay)

	# M2 UI: Soul display
	soul_display = SoulDisplayScene.instantiate()
	add_child(soul_display)
	soul_display.position = Vector2(10, 160)

	# M2 UI: Tithe screen (modal on HUD layer so it renders above everything)
	tithe_screen = TitheScreenScene.instantiate()
	$HUD.add_child(tithe_screen)

	# M2 UI: Pact screen (modal on HUD layer so it renders above everything)
	pact_screen = PactScreenScene.instantiate()
	$HUD.add_child(pact_screen)

# === State Broadcast ===

func _broadcast_state() -> void:
	if not is_server:
		return
	var public_state = engine.state.to_public_dict()
	_client_receive_state.rpc(public_state)
	for peer_id in engine.state.players:
		var ps: PlayerState = engine.state.players[peer_id]
		var hand = ps.hand.duplicate()
		if is_networked and peer_id != 1:
			_client_receive_hand.rpc_id(peer_id, hand, ps.energy, ps.draw_pile.size(), ps.discard_pile.size())
		elif peer_id == local_peer_id:
			hand_display.update_hand(hand, ps.energy, ps.corruption_tier)
			deck_count_label.text = "Deck: %d" % ps.draw_pile.size()
			discard_count_label.text = "Discard: %d" % ps.discard_pile.size()

# === UI Refresh ===

func _refresh_all_ui() -> void:
	if not engine:
		return
	var state_dict = engine.state.to_public_dict()
	_refresh_ui_from_dict(state_dict)
	var local_ps: PlayerState = engine.state.players.get(local_peer_id)
	if local_ps:
		hand_display.update_hand(local_ps.hand, local_ps.energy, local_ps.corruption_tier)
		deck_count_label.text = "Deck: %d" % local_ps.draw_pile.size()
		discard_count_label.text = "Discard: %d" % local_ps.discard_pile.size()
		if local_ps.exhaust_pile.size() > 0:
			discard_count_label.text += " | Exhaust: %d" % local_ps.exhaust_pile.size()

		# Update M1 UI
		if corruption_meter:
			corruption_meter.update_corruption(local_ps.corruption, local_ps.max_corruption, local_ps.corruption_tier)
		if sin_display:
			sin_display.update_sins(local_ps.sin_wrath, local_ps.sin_sloth, local_ps.sin_pride)
		if deaths_door_overlay:
			if local_ps.is_dead:
				deaths_door_overlay.show_dead()
			elif local_ps.is_on_deaths_door:
				deaths_door_overlay.show_deaths_door(local_ps.deaths_door_turns)
			else:
				deaths_door_overlay.hide_overlay()

		# Update M2 UI
		if soul_display:
			soul_display.update_souls(engine.state.soul_fragments, engine.state.boss_absorbed_souls)

func _refresh_ui_from_dict(state_dict: Dictionary) -> void:
	turn_label.text = "Turn %d" % state_dict["turn_number"]
	for i in state_dict["enemies"].size():
		if enemy_display_nodes.has(i):
			enemy_display_nodes[i].update_enemy(state_dict["enemies"][i])
	for peer_id in state_dict["players"]:
		var pid = int(peer_id)
		if player_board_nodes.has(pid):
			player_board_nodes[pid].update_player(
				state_dict["players"][peer_id],
				pid == local_peer_id
			)
	var local_data = state_dict["players"].get(local_peer_id, state_dict["players"].get(str(local_peer_id), {}))
	if local_data and not local_data.get("has_ended_turn", true) and state_dict.get("phase", -1) == Enums.CombatPhase.PLAYER_TURN:
		end_turn_btn.disabled = false
	else:
		end_turn_btn.disabled = true

# === Input Handlers ===

func _on_card_selected(hand_index: int, target_index: int) -> void:
	if is_networked:
		if is_server:
			engine.try_play_card(local_peer_id, hand_index, target_index)
		else:
			_server_play_card.rpc_id(1, hand_index, target_index)
	else:
		engine.try_play_card(local_peer_id, hand_index, target_index)
		_bot_play_turn()

func _on_end_turn_pressed() -> void:
	if is_networked:
		if is_server:
			engine.player_end_turn(local_peer_id)
		else:
			_server_end_turn.rpc_id(1)
	else:
		engine.player_end_turn(local_peer_id)
		# End turn for all bots
		for pid in engine.state.players:
			if pid != local_peer_id:
				engine.player_end_turn(pid)

# === Engine Signal Handlers (server only) ===

func _on_state_changed() -> void:
	if is_server:
		_refresh_all_ui()
		if is_networked:
			_broadcast_state()

func _on_card_played(peer_id: int, card_id: String, target_index: int, result: Dictionary) -> void:
	if is_networked:
		_client_card_played_fx.rpc(peer_id, card_id, target_index,
			result["damage_dealt"], result["block_gained"],
			result["heal_amount"], result["vulnerable_applied"],
			result["weak_applied"])
	else:
		_client_card_played_fx(peer_id, card_id, target_index,
			result["damage_dealt"], result["block_gained"],
			result["heal_amount"], result["vulnerable_applied"],
			result["weak_applied"])

func _on_enemy_acted(enemy_index: int, intent_type: int, value: int, target_peer_id: int, damage_dealt: int) -> void:
	if is_networked:
		_client_enemy_acted_fx.rpc(enemy_index, intent_type, value, target_peer_id, damage_dealt)
	else:
		_client_enemy_acted_fx(enemy_index, intent_type, value, target_peer_id, damage_dealt)

func _on_combat_ended(won: bool) -> void:
	if is_networked:
		_client_combat_over.rpc(won)
	else:
		_client_combat_over(won)

# === M1 Signal Handlers ===

func _on_sin_punished(peer_id: int, sin_result: Dictionary) -> void:
	# Show sin punishment as a big damage number / status text
	if player_board_nodes.has(peer_id):
		var dmg = sin_result.get("damage", 0)
		if dmg > 0:
			_spawn_damage_number(player_board_nodes[peer_id], dmg, "damage")
			if peer_id == local_peer_id:
				_do_screen_shake(10.0, 0.3)
	# Print punishment text
	print(sin_result.get("description", "Sin punished"))

func _on_player_entered_deaths_door(peer_id: int) -> void:
	print("Player %d entered Death's Door!" % peer_id)
	if peer_id == local_peer_id and deaths_door_overlay:
		var ps: PlayerState = engine.state.players.get(peer_id)
		if ps:
			deaths_door_overlay.show_deaths_door(ps.deaths_door_turns)
		_do_screen_shake(15.0, 0.5)

func _on_player_died(peer_id: int) -> void:
	print("Player %d has died!" % peer_id)
	if peer_id == local_peer_id and deaths_door_overlay:
		deaths_door_overlay.show_dead()

func _on_corruption_tier_changed(peer_id: int, new_tier: int) -> void:
	var tier_names = ["PURE", "TAINTED", "CORRUPTED", "DEMONIC"]
	print("Player %d corruption tier: %s" % [peer_id, tier_names[new_tier]])
	if peer_id == local_peer_id:
		_do_screen_shake(6.0, 0.2)

# === M2 Signal Handlers ===

func _on_soul_fragments_changed(total: int) -> void:
	if soul_display:
		soul_display.update_souls(total, engine.state.boss_absorbed_souls)

func _on_boss_absorbed_souls(amount: int) -> void:
	if soul_display:
		soul_display.update_souls(engine.state.soul_fragments, engine.state.boss_absorbed_souls)
	# Visual warning
	for i in enemy_display_nodes:
		if enemy_display_nodes[i]:
			_spawn_damage_number(enemy_display_nodes[i], amount, "damage")
	print("Boss absorbed %d soul fragments!" % amount)

func _on_tithe_demanded(cost: int) -> void:
	if tithe_screen:
		var living_count = 0
		for pid in engine.state.players:
			var ps: PlayerState = engine.state.players[pid]
			if not ps.is_dead and ps.current_hp > 0:
				living_count += 1
		tithe_screen.show_tithe(cost, maxi(living_count, 1))
		_do_screen_shake(8.0, 0.3)
		# Wait for player choice
		var accepted = await tithe_screen.tithe_choice_made
		if accepted:
			var paid = TitheSystem.apply_tithe_evenly(engine.state, cost)
			for pid in paid:
				if paid[pid] > 0 and player_board_nodes.has(pid):
					_spawn_damage_number(player_board_nodes[pid], paid[pid], "damage")
			print("Tithe paid: %s" % str(paid))
		else:
			var lost = TitheSystem.apply_tithe_refusal(engine.state)
			for pid in lost:
				if lost[pid] != "" and player_board_nodes.has(pid):
					_spawn_damage_number(player_board_nodes[pid], 1, "weak")
			print("Tithe refused — cards lost: %s" % str(lost))
		_refresh_all_ui()

func _on_pact_offered(peer_id: int, pact: Dictionary) -> void:
	if peer_id != local_peer_id:
		return
	if pact_screen:
		pact_screen.show_pact(pact)
		_do_screen_shake(5.0, 0.2)
		var accepted = await pact_screen.pact_resolved
		if accepted:
			var ps: PlayerState = engine.state.players.get(peer_id)
			if ps:
				var result = PactSystem.accept_pact(pact, ps, engine.state.players)
				print("Pact accepted: %s — %s" % [pact["title"], str(result["effects"])])
				# Show damage number for HP cost
				if pact.get("hp_cost", 0) > 0 and player_board_nodes.has(peer_id):
					_spawn_damage_number(player_board_nodes[peer_id], pact["hp_cost"], "damage")
		else:
			print("Pact declined: %s" % pact["title"])
		_refresh_all_ui()

# === Bot AI (solo mode only) ===

func _bot_play_turn() -> void:
	for pid in engine.state.players:
		if pid == local_peer_id:
			continue
		_bot_play_for(pid)

func _bot_play_for(bot_id: int) -> void:
	var bot_ps: PlayerState = engine.state.players.get(bot_id)
	if not bot_ps or bot_ps.has_ended_turn or bot_ps.is_dead:
		return
	while bot_ps.hand.size() > 0 and bot_ps.energy > 0:
		var card_data = GameManager.get_card_data(bot_ps.hand[0])
		if not card_data or card_data.energy_cost > bot_ps.energy:
			break
		var target = 0 if card_data.target_type == Enums.TargetType.ENEMY else -1
		if not engine.try_play_card(bot_id, 0, target):
			break
