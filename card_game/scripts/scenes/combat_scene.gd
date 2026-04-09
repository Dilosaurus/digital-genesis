extends Control

const EnemyDisplayScene = preload("res://scenes/combat/enemy_display.tscn")
const PlayerBoardScene = preload("res://scenes/combat/player_board.tscn")
const DamageNumberScript = preload("res://scripts/ui/damage_number.gd")
const RewardScreenScene = preload("res://scenes/ui/reward_screen.tscn")
const RelicRewardScreenScene = preload("res://scenes/ui/relic_reward_screen.tscn")
const RelicDisplayScene = preload("res://scenes/ui/relic_display.tscn")
const HackChallengeScene = preload("res://scenes/ui/hack_challenge.tscn")
const DeathsDoorOverlayScene = preload("res://scenes/ui/deaths_door_overlay.tscn")
const TitheScreenScene = preload("res://scenes/ui/tithe_screen.tscn")
const PactScreenScene = preload("res://scenes/ui/pact_screen.tscn")
const CombatLogScene = preload("res://scenes/ui/combat_log.tscn")
const TurnBannerScene = preload("res://scenes/ui/turn_banner.tscn")
const RunSummaryScreenScene = preload("res://scenes/ui/run_summary_screen.tscn")
const EquipmentRewardScreenScene = preload("res://scenes/ui/equipment_reward_screen.tscn")
const GemRewardScreenScene = preload("res://scenes/ui/gem_reward_screen.tscn")
const Combat3DStageScene = preload("res://scenes/combat/combat_3d_stage.tscn")

@onready var enemy_area: Control = $ShakeContainer/EnemyArea
@onready var hand_display = $HandDisplay
@onready var player_boards: HBoxContainer = $ShakeContainer/PlayerBoards
@onready var end_turn_btn: Button = $HUD/EndTurnButton
@onready var turn_label: Label = $HUD/TurnLabel
@onready var deck_count_label: Label = $DeckPill/Label
@onready var discard_count_label: Label = $DiscardPill/Label
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
var current_enemy_id: String = ""       # first enemy — used for boss reward look-up
var reward_screen = null
var relic_reward_screen = null
var relic_display = null
var hack_challenge = null
@onready var corruption_meter = $CorruptionMeter
@onready var sin_display = $SinDisplay
var deaths_door_overlay = null
@onready var soul_display = $SoulDisplay
var tithe_screen = null
var pact_screen = null
var combat_log = null
var turn_banner = null
var run_summary_screen = null
@onready var hp_orb = $HPOrb
@onready var mana_orb = $ManaOrb
@onready var hp_number: Label = $HPNumber
@onready var mp_number: Label = $MPNumber
@onready var block_display: Label = $BlockDisplay
var player_status_float: Control = null
@onready var _local_dmg_anchor: Control = $LocalDmgAnchor  # Visible anchor for local player damage numbers (near HP orb)
var _ally_bar_nodes: Dictionary = {}  # peer_id -> Control (compact ally bars for remote players)

var _vote_overlay: VoteOverlay = null

var _end_turn_pulse_tween: Tween = null

# 3D character display
var _combat_3d_stage: Combat3DStage = null
var _player_puppet_3d: PuppetBase3D = null
var _enemy_puppets_3d: Dictionary = {}  # enemy_index -> Node3D (PuppetBase3D for KayKit enemies, plain Node3D anchor for painted 2D enemies)

# Targeting state for multi-enemy single-target card selection
var _targeting_active: bool = false
var _targeting_hand_index: int = -1
# Tracks enemy indices for which a death animation has already been triggered.
var _dead_enemies_animated: Array = []
var _last_phase: int = -1  # Track phase transitions to avoid banner spam
var _enemy_action_queue: Array = []  # Queue enemy actions for staggered playback
var _playing_enemy_turn: bool = false
var _deaths_door_aberration: ColorRect = null

func _process(_delta: float) -> void:
	_update_enemy_display_positions()

func _update_enemy_display_positions() -> void:
	# Project each enemy's 3D world position to 2D screen coords
	if not _combat_3d_stage:
		return
	var camera: Camera3D = _combat_3d_stage.get_camera()
	if not camera:
		return
	if Engine.get_process_frames() % 120 == 0:
		print("[EnemyTrack] _update called. _enemy_puppets_3d.size=%d enemy_display_nodes.size=%d _painted_arena=%s"
			% [_enemy_puppets_3d.size(), enemy_display_nodes.size(), str(_painted_arena)])
	for i in _enemy_puppets_3d:
		if not enemy_display_nodes.has(i):
			continue
		var puppet: Node3D = _enemy_puppets_3d[i]
		var ed: Control = enemy_display_nodes[i]
		if not is_instance_valid(puppet) or not is_instance_valid(ed):
			continue

		# Painted enemies have their character render in painted_arena.tscn
		# at an editor-placed fixed position. Put the HP / intent UI above
		# that sprite instead of projecting from the (hidden) 3D anchor.
		var enemy_id: String = ""
		if engine and engine.state and i < engine.state.enemies.size():
			enemy_id = engine.state.enemies[i].enemy_data_id
		if enemy_id in Combat3DStage.PAINTED_2D_ENEMIES:
			var slot: Control = _get_painted_enemy_slot(i)
			if slot != null:
				ed.visible = true
				# CRITICAL: ed is a child of EnemyArea (HBoxContainer), which
				# auto-lays-out its children every frame — any position we set
				# gets clobbered. top_level = true detaches ed from its parent
				# layout and makes its position global / screen-space. Idempotent
				# so it's safe to set every frame.
				if not ed.top_level:
					ed.top_level = true
					print("[EnemyTrack-%d] set top_level=true on ed (parent=%s)"
						% [i, ed.get_parent().name if ed.get_parent() else "null"])
				var slot_global_center_x: float = slot.global_position.x + slot.size.x / 2.0
				var slot_global_top_y: float = slot.global_position.y
				var target_pos := Vector2(
					slot_global_center_x - ed.size.x / 2.0,
					max(slot_global_top_y - 20.0, 10.0)
				)
				ed.global_position = target_pos
				if Engine.get_process_frames() % 60 == 0:
					print("[EnemyTrack-%d] slot.global_pos=%s slot.size=%s  →  ed.global_pos=%s ed.size=%s ed.top_level=%s"
						% [i, slot.global_position, slot.size, ed.global_position, ed.size, ed.top_level])
			continue

		# Get the world position above the enemy's head. KayKit puppets stand
		# at puppet.position.y = 0 (feet on ground) with head at +1.8m.
		var world_pos: Vector3 = puppet.global_position + Vector3(0, 1.8, 0)
		if camera.is_position_behind(world_pos):
			ed.visible = false
			continue
		ed.visible = true
		var screen_pos: Vector2 = camera.unproject_position(world_pos)
		# Center the display horizontally on the projected point
		ed.position = Vector2(screen_pos.x - ed.size.x / 2.0, screen_pos.y - ed.size.y)

func _ready() -> void:
	result_panel.visible = false
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	# Style the turn label — small, top-right, unobtrusive
	turn_label.add_theme_font_size_override("font_size", 13)
	turn_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 0.6))
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hand_display.card_selected.connect(_on_card_selected)
	hand_display.targeting_started.connect(_on_targeting_started)
	hand_display.targeting_cancelled.connect(_on_targeting_cancelled)
	continue_btn.pressed.connect(_on_continue_pressed)
	# Fade in the scene on entry
	TransitionManager.fade_in(0.4)

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

	if GameManager.is_run_active():
		# Use the full enemies list set by the map screen.
		var enemies_list: Array = GameManager.current_enemies.duplicate()
		if enemies_list.is_empty():
			# Fallback: use the legacy single-enemy field.
			if GameManager.current_enemy != "":
				enemies_list.append(GameManager.current_enemy)
			else:
				enemies_list.append("jaw_worm")
		current_enemy_id = enemies_list[0]  # first enemy for boss reward look-up
		var peer_ids: Array[int] = [1]
		print("Campaign combat: vs %s" % str(enemies_list))
		engine.initialize_multi(peer_ids, enemies_list)
		# Override with run deck/HP
		var ps = engine.state.players[1]
		ps.draw_pile = GameManager.current_run.deck.duplicate()
		ps.hand.clear()
		ps.discard_pile.clear()
		DeckManager.shuffle(ps.draw_pile)
		ps.current_hp = GameManager.current_run.current_hp
		ps.max_hp = GameManager.current_run.max_hp
		ps.energy = ps.max_energy
		DeckManager.draw(ps, 5)
		# Apply relic effects
		if GameManager.current_run.relics.size() > 0:
			RelicSystem.apply_start_of_combat(ps, GameManager.current_run.relics)
		_create_ui_elements_from_engine()
		_refresh_all_ui()
		_play_encounter_intro(GameManager.current_node_type)
		SFXManager.play_ambient_hum()
		MusicManager.play_combat_music(GameManager.current_enemies, GameManager.current_run.act if GameManager.current_run else 1)
		return

	# Solo / sandbox mode: 1 player vs a random enemy.
	var enemy = _pick_random_enemy()
	current_enemy_id = enemy
	var peer_ids: Array[int] = [1]
	print("Solo combat: %d players vs %s" % [peer_ids.size(), enemy])
	engine.initialize(peer_ids, enemy)
	_create_ui_elements_from_engine()
	_refresh_all_ui()
	SFXManager.play_ambient_hum()

func _play_encounter_intro(node_type: String) -> void:
	match node_type:
		"boss":
			SFXManager.play_boss_intro()
		"elite":
			SFXManager.play_elite_intro()

## Sandbox enemy picker. Set DEBUG_SANDBOX_ENEMY to a specific enemy id
## (e.g. "michael", "gabriel") to force every F6 of combat_scene.tscn to
## fight that enemy. Empty string = random from the pool.
const DEBUG_SANDBOX_ENEMY: String = "effigy"

## Sandbox player picker. Set DEBUG_SANDBOX_PLAYER to a specific character id
## (e.g. "netrunner" for Ghost, "white_hat" for Paladin) to force every F6 of
## combat_scene.tscn to use that painted character instead of the default
## KayKit chibi knight. Empty string = fall back to current_run.character_id
## or "knight".
const DEBUG_SANDBOX_PLAYER: String = "netrunner"

## Playable characters that render as painted 2D sprites (animated sprite
## sheets from the Veo 3.1 pipeline) instead of KayKit 3D puppets. When the
## current player's character_id is in this set, combat_scene.gd hides the
## entire Combat3DStage SubViewport and renders a painted backdrop + a
## SpriteSheetAnimator for the player in the 2D layer.
const PAINTED_2D_PLAYERS: Array[String] = ["netrunner"]

func _pick_random_enemy() -> String:
	if DEBUG_SANDBOX_ENEMY != "":
		return DEBUG_SANDBOX_ENEMY
	var enemies = ["seraph_drone", "jaw_worm", "cultist", "louse_red", "hexaghost", "quantum_ghost"]
	return enemies[randi() % enemies.size()]

func _start_networked_combat() -> void:
	engine = CombatEngine.new()
	_connect_engine_signals()
	var peer_ids: Array[int] = NetworkManager.get_all_peer_ids()

	# Use campaign enemies if in a run, otherwise random
	var enemies_list: Array = []
	if GameManager.is_run_active():
		enemies_list = GameManager.current_enemies.duplicate()
	if enemies_list.is_empty():
		enemies_list.append(_pick_random_enemy())
	current_enemy_id = enemies_list[0]

	print("Starting networked combat with peers: %s vs %s" % [str(peer_ids), str(enemies_list)])
	engine.initialize_multi(peer_ids, enemies_list)

	# Apply run state overrides for the host player
	if GameManager.is_run_active():
		var host_ps = engine.state.players.get(1)
		if host_ps:
			host_ps.draw_pile = GameManager.current_run.deck.duplicate()
			host_ps.hand.clear()
			host_ps.discard_pile.clear()
			DeckManager.shuffle(host_ps.draw_pile)
			host_ps.current_hp = GameManager.current_run.current_hp
			host_ps.max_hp = GameManager.current_run.max_hp
			host_ps.energy = host_ps.max_energy
			DeckManager.draw(host_ps, 5)
			if GameManager.current_run.relics.size() > 0:
				RelicSystem.apply_start_of_combat(host_ps, GameManager.current_run.relics)

	_create_ui_elements_from_engine()
	_refresh_all_ui()
	_play_encounter_intro(GameManager.current_node_type)
	SFXManager.play_ambient_hum()

	# Send setup to clients
	var peer_id_array: Array = []
	for pid in peer_ids:
		peer_id_array.append(pid)
	var enemy_ids_for_rpc: Array = []
	for eid in enemies_list:
		enemy_ids_for_rpc.append(eid)
	_client_setup_combat.rpc(peer_id_array, enemy_ids_for_rpc)
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
	engine.boss_mechanic.connect(_on_boss_mechanic)

	# Level-up notification broadcast
	EventBus.player_leveled_up.connect(func(level: int, rewards: Dictionary):
		if is_networked:
			_client_level_up_notification.rpc(level, rewards)
		else:
			_client_level_up_notification(level, rewards)
	)

func _setup_client_ui() -> void:
	# Client waits for _client_setup_combat RPC to create displays
	# Just ensure HUD is visible and ready
	result_panel.visible = false
	end_turn_btn.disabled = false
	print("Client UI ready, waiting for server setup...")

# === Juice: Damage Numbers ===

func _spawn_damage_number(parent: Control, value: int, type: String) -> void:
	var label = Label.new()
	label.set_script(DamageNumberScript)
	parent.add_child(label)
	label.position = Vector2(parent.size.x / 2 - 20, parent.size.y / 2)
	label.show_number(value, type)

## Returns a visible parent node for spawning damage numbers on a player.
## For the local player, uses the anchor near the HP orb (since the board is hidden).
## For remote players, uses the ally bar or falls back to the board node.
func _get_player_dmg_parent(peer_id: int) -> Control:
	if peer_id == local_peer_id and _local_dmg_anchor:
		return _local_dmg_anchor
	if player_board_nodes.has(peer_id):
		return player_board_nodes[peer_id]
	return null

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
func _client_setup_combat(peer_ids: Array, enemy_ids: Array) -> void:
	if is_server:
		return
	# Create enemy displays for each enemy
	for i in enemy_ids.size():
		var ed = EnemyDisplayScene.instantiate()
		enemy_area.add_child(ed)
		ed.enemy_index = i
		enemy_display_nodes[i] = ed
	var c_ally_bar_y: float = 200.0
	for peer_id in peer_ids:
		var pid = int(peer_id)
		if pid == local_peer_id:
			var pb = PlayerBoardScene.instantiate()
			pb.visible = false
			player_boards.add_child(pb)
			player_board_nodes[pid] = pb
		else:
			var ally_bar = _create_ally_bar(pid)
			ally_bar.position = Vector2(10, c_ally_bar_y)
			add_child(ally_bar)
			player_board_nodes[pid] = ally_bar
			_ally_bar_nodes[pid] = ally_bar
			c_ally_bar_y += 36.0
	print("Client UI set up: %d players vs %d enemies" % [peer_ids.size(), enemy_ids.size()])

@rpc("authority", "call_local", "reliable")
func _client_receive_state(state_dict: Dictionary) -> void:
	cached_state = state_dict
	_refresh_ui_from_dict(state_dict)

@rpc("authority", "reliable")
func _client_receive_hand(hand_cards: Array, energy: int, draw_count: int, discard_count: int, cooldowns: Dictionary = {}) -> void:
	hand_display.update_hand(hand_cards, energy, 0, null, cooldowns)
	if deck_count_label:
		deck_count_label.text = "Deck: %d" % draw_count
	if discard_count_label:
		discard_count_label.text = "Discard: %d" % discard_count

@rpc("authority", "call_local", "reliable")
func _client_card_played_fx(peer_id: int, card_id: String, target_index: int, damage: int, block: int, heal: int, vuln: int, weak: int) -> void:
	# Play type-specific card sound
	var cdata = GameManager.get_card_data(card_id)
	if cdata:
		match cdata.card_type:
			Enums.CardType.ATTACK: SFXManager.play_card_attack()
			Enums.CardType.SKILL:  SFXManager.play_card_skill()
			Enums.CardType.POWER:  SFXManager.play_card_power()
			_:                     SFXManager.play_card_curse()
	else:
		SFXManager.play_card()
	_puppet_play_card_anim(cdata)

	# Shake enemy on damage
	if damage > 0 and enemy_display_nodes.has(target_index):
		enemy_display_nodes[target_index].shake()
		_spawn_damage_number(enemy_display_nodes[target_index], damage, "damage")
		_do_screen_shake(clampf(float(damage) * 0.8, 3.0, 15.0))
		SFXManager.play_hit()
		# 3D enemy hit reaction — only for KayKit puppets; painted enemies
		# return a plain Node3D anchor from spawn_enemy() with no animation.
		if _enemy_puppets_3d.has(target_index) and _enemy_puppets_3d[target_index] is PuppetBase3D:
			_enemy_puppets_3d[target_index].play_hit()

	# Block number on player
	if block > 0:
		var _dmg_p = _get_player_dmg_parent(peer_id)
		if _dmg_p:
			_spawn_damage_number(_dmg_p, block, "block")
		SFXManager.play_block()

	# Heal number on player
	if heal > 0:
		var _dmg_p = _get_player_dmg_parent(peer_id)
		if _dmg_p:
			_spawn_damage_number(_dmg_p, heal, "heal")
		SFXManager.play_heal()

	# Vulnerable text on enemy
	if vuln > 0 and enemy_display_nodes.has(target_index):
		_spawn_damage_number(enemy_display_nodes[target_index], vuln, "vulnerable")

	# Weak text on enemy
	if weak > 0 and enemy_display_nodes.has(target_index):
		_spawn_damage_number(enemy_display_nodes[target_index], weak, "weak")

@rpc("authority", "call_local", "reliable")
func _client_enemy_acted_fx(enemy_index: int, intent_type: int, value: int, target_peer_id: int, damage_dealt: int) -> void:
	if intent_type == Enums.EnemyIntent.ATTACK and damage_dealt > 0:
		var _dmg_p = _get_player_dmg_parent(target_peer_id)
		if _dmg_p:
			_spawn_damage_number(_dmg_p, damage_dealt, "damage")
		SFXManager.play_hit()
		# 3D puppet hit reaction + screen shake
		if target_peer_id == local_peer_id:
			if _player_puppet_3d:
				_player_puppet_3d.play_hit()
			if _combat_3d_stage:
				_combat_3d_stage.do_camera_shake(0.08, 0.25)
			_do_screen_shake(clampf(float(damage_dealt) * 1.0, 5.0, 20.0), 0.3)
		# Enemy attack animation — only for KayKit puppets
		if _combat_3d_stage and _enemy_puppets_3d.has(enemy_index) and _enemy_puppets_3d[enemy_index] is PuppetBase3D:
			_enemy_puppets_3d[enemy_index].play_attack()

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
				var _dmg_p = _get_player_dmg_parent(target_peer_id)
				if _dmg_p:
					_spawn_damage_number(_dmg_p, hack_value, "damage")
				_do_screen_shake(12.0, 0.4)
				_refresh_all_ui()
		else:
			# Resisted — small block bonus as reward
			if engine and engine.state.players.has(target_peer_id):
				var ps: PlayerState = engine.state.players[target_peer_id]
				ps.block += 5
				var _dmg_p = _get_player_dmg_parent(target_peer_id)
				if _dmg_p:
					_spawn_damage_number(_dmg_p, 5, "block")
				_refresh_all_ui()
		hack_challenge.queue_free()
		hack_challenge = null
	)

@rpc("authority", "call_local", "reliable")
func _client_level_up_notification(level: int, rewards: Dictionary) -> void:
	# Show level-up in combat log and as floating text
	if combat_log:
		combat_log.add_status("LEVEL UP! Now level %d (+%d HP, +%d SP)" % [
			level, rewards.get("max_hp_bonus", 0), rewards.get("skill_points", 0)])
	print("Level up! Level %d" % level)

@rpc("authority", "call_local", "reliable")
func _client_combat_over(won: bool) -> void:
	SFXManager.stop_ambient_hum()
	MusicManager.play("victory" if won else "defeat", 0.5)
	end_turn_btn.disabled = true
	result_panel.visible = true
	if won:
		if GameManager.is_run_active():
			var run := GameManager.current_run
			var gold_gained: int = 25 + randi() % 26  # 25-50 gold per win
			CurrencyManager.add(run, CurrencyManager.Type.GOLD, gold_gained)
			run.total_gold_earned += gold_gained
			run.enemies_defeated += engine.state.enemies.size()

			# Soul & crystal rewards for elite / boss kills
			var _node_type := GameManager.current_node_type
			if _node_type == "elite":
				CurrencyManager.add(run, CurrencyManager.Type.SOULS, 1 + randi() % 2)  # 1-2 Souls
			elif _node_type == "boss":
				CurrencyManager.add(run, CurrencyManager.Type.SOULS, 3 + randi() % 3)  # 3-5 Souls
				CurrencyManager.add(run, CurrencyManager.Type.CRYSTALS, 1)              # 1 Crystal

		# Brief flash of "VICTORY!" before reward flow
		result_panel.visible = true
		result_label.text = "VICTORY!"
		result_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
		SFXManager.play_victory()
		SFXManager.play_gold_gain()

		await get_tree().create_timer(1.2).timeout
		result_panel.visible = false

		# Always show card reward screen after any combat victory
		var card_rewards = GameManager.get_random_card_rewards(3)
		if card_rewards.size() > 0:
			var chosen_card = await _show_card_reward_screen(card_rewards)
			if chosen_card != "":
				print("Added card to deck: %s" % chosen_card)
				if GameManager.is_run_active():
					GameManager.current_run.add_card(chosen_card)

		# Elite and boss fights award a relic
		var node_type = GameManager.current_node_type
		var is_elite = node_type == "elite"
		var is_boss = node_type == "boss"
		if GameManager.is_run_active() and (is_elite or is_boss):
			await _show_relic_reward()
			await _show_equipment_reward()

		# All victories can yield a gem reward (rarer for normal fights)
		if GameManager.is_run_active():
			var gem_chance = 1.0 if is_boss else (0.6 if is_elite else 0.25)
			if randf() <= gem_chance:
				await _show_gem_reward()

		# Boss fights also award card absorption
		if is_boss:
			var boss_rewards_list = GameManager.get_boss_rewards(current_enemy_id)
			if boss_rewards_list.size() > 0:
				var absorbed = await _show_boss_reward_screen(boss_rewards_list)
				if absorbed != "":
					print("Absorbed boss ability: %s" % absorbed)
					if GameManager.is_run_active():
						GameManager.current_run.add_card(absorbed)

		# All rewards done — check for final boss victory
		if GameManager.is_run_active():
			var ps = engine.state.players.get(local_peer_id)
			if ps:
				GameManager.current_run.current_hp = ps.current_hp
			var run := GameManager.current_run
			run.floors_cleared += 1
			var is_final_boss: bool = (run.current_row == run.map_data.size() - 1)
			if is_final_boss:
				# Victory run complete — show summary then return to menu
				await _show_run_summary(true)
				DungeonManager.exit_room(true)
				GameManager.end_run()
				DungeonManager.reset()
				TransitionManager.transition_to_scene("res://scenes/main/main_menu.tscn")
			else:
				# Intermediate victory — show summary then continue to map
				await _show_run_summary(true)
				DungeonManager.exit_room(true)
				DungeonManager.advance_act()
				GameManager.save_run()
				TransitionManager.transition_to_scene("res://scenes/map/map_screen.tscn")
		else:
			# Non-campaign victory (solo/networked): show continue button
			result_panel.visible = true
			result_label.text = "VICTORY!"
			result_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
			continue_btn.visible = true
	else:
		# Defeat
		if GameManager.is_run_active():
			await _show_run_summary(false)
			DungeonManager.fail_run()
			GameManager.end_run()
			DungeonManager.reset()
			TransitionManager.transition_to_scene("res://scenes/main/main_menu.tscn")
		else:
			# Non-campaign defeat
			result_label.text = "DEFEAT"
			result_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
			result_panel.visible = true
			if is_networked:
				NetworkManager.disconnect_game()

func _show_relic_reward() -> void:
	if not GameManager.is_run_active():
		return
	var owned = GameManager.current_run.relics
	var relic_ids = RelicSystem.get_random_relic_reward(owned, 3)
	if relic_ids.size() == 0:
		return
	relic_reward_screen = RelicRewardScreenScene.instantiate()
	add_child(relic_reward_screen)
	relic_reward_screen.show_relics(relic_ids)
	var chosen_id = await relic_reward_screen.relic_chosen
	relic_reward_screen.queue_free()
	relic_reward_screen = null
	if chosen_id != "" and GameManager.is_run_active():
		GameManager.current_run.add_relic(chosen_id)
		SFXManager.play_relic_acquire()
		if not relic_display:
			relic_display = RelicDisplayScene.instantiate()
			$HUD.add_child(relic_display)
			relic_display.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			relic_display.position = Vector2(-620.0, 35.0)
		relic_display.update_relics(GameManager.current_run.relics)

func _show_equipment_reward() -> void:
	if not GameManager.is_run_active():
		return
	var run := GameManager.current_run
	var equip_ids = EquipmentSystem.get_random_equipment_reward(run.equipment, 3)
	if equip_ids.size() == 0:
		return
	var screen = EquipmentRewardScreenScene.instantiate()
	add_child(screen)
	screen.show_equipment(equip_ids)
	var chosen_id = await screen.equipment_chosen
	screen.queue_free()
	if chosen_id != "" and GameManager.is_run_active():
		EquipmentSystem.equip(run, chosen_id)

func _show_gem_reward() -> void:
	if not GameManager.is_run_active():
		return
	var gem_ids = GemSystem.get_random_gem_reward(3)
	if gem_ids.size() == 0:
		return
	var screen = GemRewardScreenScene.instantiate()
	add_child(screen)
	screen.show_gems(gem_ids)
	var chosen_id = await screen.gem_chosen
	screen.queue_free()
	if chosen_id != "" and GameManager.is_run_active():
		GameManager.current_run.gems.append(chosen_id)

# Shows the post-combat card reward screen; returns the chosen card_id or "" for skip.
func _show_card_reward_screen(card_ids: Array[String]) -> String:
	reward_screen = RewardScreenScene.instantiate()
	add_child(reward_screen)
	reward_screen.show_card_rewards(card_ids)
	var chosen: String = await reward_screen.card_chosen
	if reward_screen:
		reward_screen.queue_free()
		reward_screen = null
	return chosen

# Shows the boss ability absorption screen; returns the chosen card_id or "" for skip.
func _show_boss_reward_screen(rewards: Array[String]) -> String:
	var screen = RewardScreenScene.instantiate()
	add_child(screen)
	var enemy_data: EnemyData = load("res://data/enemies/%s.tres" % current_enemy_id)
	var boss_name = enemy_data.display_name if enemy_data else current_enemy_id
	screen.show_rewards(boss_name, rewards)
	var chosen: String = await screen.card_chosen
	screen.queue_free()
	return chosen

# Legacy wrapper kept so any external callers still compile (unused in normal flow).
func _show_reward_screen(rewards: Array[String]) -> void:
	var screen = RewardScreenScene.instantiate()
	add_child(screen)
	var enemy_data: EnemyData = load("res://data/enemies/%s.tres" % current_enemy_id)
	var boss_name = enemy_data.display_name if enemy_data else current_enemy_id
	screen.show_rewards(boss_name, rewards)
	screen.card_chosen.connect(_on_reward_chosen)

func _on_reward_chosen(card_id: String) -> void:
	if card_id != "":
		print("Absorbed ability: %s" % card_id)
		if GameManager.is_run_active():
			GameManager.current_run.add_card(card_id)
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
	if GameManager.is_run_active():
		var ps = engine.state.players.get(local_peer_id)
		if ps:
			GameManager.current_run.current_hp = ps.current_hp
		var run := GameManager.current_run
		# Mark the combat node as complete via DungeonManager
		DungeonManager.exit_room(true)
		run.floors_cleared += 1
		# Show run summary before transitioning
		await _show_run_summary(true)
		# Check if we just beat the boss (last row of the map)
		var is_boss_row: bool = (run.current_row == run.map_data.size() - 1)
		if is_boss_row:
			if run.act >= 3:
				# Final boss defeated — show victory screen
				_show_victory_screen()
			else:
				# Advance to next act
				var completed_act: int = run.act
				DungeonManager.advance_act()
				GameManager.save_run()
				_show_act_complete_screen(completed_act)
		else:
			GameManager.save_run()
			TransitionManager.transition_to_scene("res://scenes/map/map_screen.tscn")
		return
	if is_networked:
		NetworkManager.disconnect_game()
	TransitionManager.transition_to_scene("res://scenes/main/main_menu.tscn")

func _show_act_complete_screen(completed_act: int) -> void:
	# Hide the result panel so only our interstitial is visible
	result_panel.visible = false

	var act_names := ["ACT I", "ACT II", "ACT III"]
	var act_label_text: String = act_names[clampi(completed_act - 1, 0, 2)]

	var overlay := Panel.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.modulate = Color(0, 0, 0, 0)
	add_child(overlay)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(480, 260)
	vbox.position -= vbox.custom_minimum_size / 2.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(vbox)

	var title := Label.new()
	title.text = "%s COMPLETE" % act_label_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 28)
	vbox.add_child(spacer)

	var sub := Label.new()
	sub.text = "Prepare yourself for Act %d..." % (completed_act + 1)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(sub)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 36)
	vbox.add_child(spacer2)

	var cont_btn := Button.new()
	cont_btn.text = "Continue"
	cont_btn.custom_minimum_size = Vector2(200, 48)
	cont_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cont_btn)
	cont_btn.pressed.connect(func():
		TransitionManager.transition_to_scene("res://scenes/map/map_screen.tscn")
	)

	# Fade the overlay in
	var tween := create_tween()
	tween.tween_property(overlay, "modulate", Color(0.05, 0.05, 0.1, 0.96), 0.5)

func _show_victory_screen() -> void:
	# Hide the result panel so only our victory screen is visible
	result_panel.visible = false

	var overlay := Panel.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.modulate = Color(0, 0, 0, 0)
	add_child(overlay)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(520, 300)
	vbox.position -= vbox.custom_minimum_size / 2.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(vbox)

	var title := Label.new()
	title.text = "YOU WIN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)

	var sub := Label.new()
	sub.text = "deus.exe COMPLETE"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0))
	vbox.add_child(sub)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer2)

	var cont_btn := Button.new()
	cont_btn.text = "Return to Main Menu"
	cont_btn.custom_minimum_size = Vector2(240, 48)
	cont_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cont_btn)
	cont_btn.pressed.connect(func():
		GameManager.end_run()
		TransitionManager.transition_to_scene("res://scenes/main/main_menu.tscn")
	)

	# Fade the overlay in
	var tween := create_tween()
	tween.tween_property(overlay, "modulate", Color(0.0, 0.02, 0.05, 0.97), 0.7)

## Show the run summary overlay and wait for the player to dismiss it.
func _show_run_summary(is_victory: bool) -> void:
	if not GameManager.is_run_active():
		return
	var run := GameManager.current_run
	var ps = engine.state.players.get(local_peer_id)
	var hp: int = ps.current_hp if ps else 0

	run_summary_screen = RunSummaryScreenScene.instantiate()
	add_child(run_summary_screen)
	run_summary_screen.show_summary(is_victory, run, hp)
	await run_summary_screen.summary_closed
	if run_summary_screen:
		run_summary_screen.queue_free()
		run_summary_screen = null

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
	var enemy_count = engine.state.enemies.size()
	for i in enemy_count:
		var ed = EnemyDisplayScene.instantiate()
		enemy_area.add_child(ed)
		ed.enemy_index = i
		ed.enemy_clicked.connect(_on_enemy_display_clicked)
		enemy_display_nodes[i] = ed

	# Widen the enemy area to fit multiple enemies side by side.
	# Each enemy display is 200px wide + 30px gap between; add 20px padding each side.
	const ENEMY_W: int = 200
	const ENEMY_GAP: int = 30
	const AREA_PADDING: int = 20
	var area_width = enemy_count * ENEMY_W + (enemy_count - 1) * ENEMY_GAP + AREA_PADDING * 2
	area_width = maxi(area_width, 300)  # Minimum 300px for single enemy

	# Reparent enemy displays from the area container to the scene root
	# so we can position each one individually above its 3D model.
	for i in enemy_display_nodes:
		var ed = enemy_display_nodes[i]
		ed.get_parent().remove_child(ed)
		add_child(ed)
	enemy_area.visible = false

	# Target selection disabled while using 3D models (TODO: add 3D click targeting)
	hand_display.needs_target_selection = false

	# Local player: hidden board (giant orbs replace it).
	# Remote players: compact ally bars in top-left corner.
	var ally_bar_y: float = 200.0  # Below corruption/sin/soul displays
	for peer_id in engine.state.players:
		if peer_id == local_peer_id:
			# Local player — create board but hide it (orbs replace it)
			var pb = PlayerBoardScene.instantiate()
			pb.visible = false
			player_boards.add_child(pb)
			player_board_nodes[peer_id] = pb
		else:
			# Remote player — compact ally bar in top-left
			var ally_bar = _create_ally_bar(peer_id)
			ally_bar.position = Vector2(10, ally_bar_y)
			add_child(ally_bar)
			player_board_nodes[peer_id] = ally_bar
			_ally_bar_nodes[peer_id] = ally_bar
			ally_bar_y += 36.0

	# 3D character puppet (left side of combat)
	_spawn_player_puppet_3d()

	# Player status is shown via the orbs — no floating panel needed
	# Note: corruption_meter, sin_display, soul_display, hp_orb, mana_orb,
	# hp_number, mp_number, block_display, DeckPill, DiscardPill, LocalDmgAnchor
	# all live in combat_scene.tscn as static nodes (visible in the editor).

	deaths_door_overlay = DeathsDoorOverlayScene.instantiate()
	add_child(deaths_door_overlay)

	tithe_screen = TitheScreenScene.instantiate()
	$HUD.add_child(tithe_screen)

	pact_screen = PactScreenScene.instantiate()
	$HUD.add_child(pact_screen)

	# Combat log — hidden by default, toggle with L key
	combat_log = CombatLogScene.instantiate()
	add_child(combat_log)
	combat_log.position = Vector2(240, 500)
	combat_log.scale = Vector2(0.75, 0.75)
	combat_log.visible = false

	# Turn banner (fullscreen overlay)
	turn_banner = TurnBannerScene.instantiate()
	add_child(turn_banner)

	# Relic display (top-right of HUD, below deck count)
	if GameManager.is_run_active() and GameManager.current_run.relics.size() > 0:
		relic_display = RelicDisplayScene.instantiate()
		$HUD.add_child(relic_display)
		relic_display.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		relic_display.position = Vector2(-620.0, 35.0)
		relic_display.update_relics(GameManager.current_run.relics)

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
			_client_receive_hand.rpc_id(peer_id, hand, ps.energy, ps.draw_pile.size(), ps.discard_pile.size(), ps.cooldowns.duplicate())
		elif peer_id == local_peer_id:
			hand_display.update_hand(hand, ps.energy, ps.corruption_tier, null, ps.cooldowns)
			if deck_count_label:
				deck_count_label.text = "Deck: %d" % ps.draw_pile.size()
			if discard_count_label:
				discard_count_label.text = "Discard: %d" % ps.discard_pile.size()

# === UI Refresh ===

func _refresh_all_ui() -> void:
	if not engine:
		return
	var state_dict = engine.state.to_public_dict()
	_refresh_ui_from_dict(state_dict)
	var local_ps: PlayerState = engine.state.players.get(local_peer_id)
	if local_ps:
		hand_display.update_hand(local_ps.hand, local_ps.energy, local_ps.corruption_tier, null, local_ps.cooldowns)
		if deck_count_label:
			deck_count_label.text = "Deck: %d" % local_ps.draw_pile.size()
		if discard_count_label:
			discard_count_label.text = "Discard: %d" % local_ps.discard_pile.size()
			if local_ps.exhaust_pile.size() > 0:
				discard_count_label.text += " | Exhaust: %d" % local_ps.exhaust_pile.size()

		# Update M1 UI
		if corruption_meter:
			corruption_meter.update_corruption(local_ps.corruption, local_ps.max_corruption, local_ps.corruption_tier)
		if sin_display:
			var has_sin := local_ps.sin_wrath > 0 or local_ps.sin_sloth > 0 or local_ps.sin_pride > 0
			sin_display.visible = has_sin
			if has_sin:
				sin_display.update_sins(local_ps.sin_wrath, local_ps.sin_sloth, local_ps.sin_pride)
		if deaths_door_overlay:
			if local_ps.is_dead:
				deaths_door_overlay.show_dead()
			elif local_ps.is_on_deaths_door:
				deaths_door_overlay.show_deaths_door(local_ps.deaths_door_turns)
			else:
				deaths_door_overlay.hide_overlay()

		# Chromatic aberration on death's door
		if local_ps.is_dead or not local_ps.is_on_deaths_door:
			_set_deaths_door_visual(false)

		# Update M2 UI
		if soul_display:
			var has_souls := engine.state.soul_fragments > 0 or engine.state.boss_absorbed_souls > 0
			soul_display.visible = has_souls
			if has_souls:
				soul_display.update_souls(engine.state.soul_fragments, engine.state.boss_absorbed_souls)

		# Update resource orbs
		if hp_orb:
			hp_orb.max_value = local_ps.max_hp
			hp_orb.set_value(local_ps.current_hp)
		if mana_orb:
			mana_orb.max_value = local_ps.max_energy
			mana_orb.set_value(local_ps.energy)

		# Update large number labels on orbs
		if hp_number:
			hp_number.text = "%d / %d" % [local_ps.current_hp, local_ps.max_hp]
		if mp_number:
			mp_number.text = "%d / %d" % [local_ps.energy, local_ps.max_energy]

		# Update block display near HP orb
		if block_display:
			if local_ps.block > 0:
				block_display.text = "BLOCK %d" % local_ps.block
				block_display.visible = true
			else:
				block_display.visible = false

		# Update floating status above player 3D model
		if player_status_float:
			var float_hp = player_status_float.get_node_or_null("FloatHP")
			if float_hp:
				float_hp.set_values(local_ps.current_hp, local_ps.max_hp)
			var float_mp = player_status_float.get_node_or_null("FloatMP")
			if float_mp:
				float_mp.text = "MP: %d/%d" % [local_ps.energy, local_ps.max_energy]
			var float_block = player_status_float.get_node_or_null("FloatBlock")
			if float_block:
				if local_ps.block > 0:
					float_block.text = "Block: %d" % local_ps.block
				else:
					float_block.text = ""

		# Update ally bars for remote players
		for pid in _ally_bar_nodes:
			var remote_ps: PlayerState = engine.state.players.get(pid)
			if remote_ps and _ally_bar_nodes[pid]:
				_update_ally_bar(_ally_bar_nodes[pid], {
					"display_name": "Player %d" % pid,
					"current_hp": remote_ps.current_hp,
					"max_hp": remote_ps.max_hp,
					"energy": remote_ps.energy,
					"max_energy": remote_ps.max_energy,
				})

	# Re-hide 2D enemy art every refresh (update_enemy re-creates sprites)
	if _combat_3d_stage:
		for i in _enemy_puppets_3d:
			_hide_enemy_2d_art(i)

func _refresh_ui_from_dict(state_dict: Dictionary) -> void:
	if not turn_label:
		return
	turn_label.text = "Turn %d" % state_dict["turn_number"]
	for i in state_dict["enemies"].size():
		if enemy_display_nodes.has(i):
			var ed = enemy_display_nodes[i]
			var edata: Dictionary = state_dict["enemies"][i]
			if edata.get("current_hp", 1) <= 0:
				# Dead enemy: trigger death animation exactly once, then hide.
				if i not in _dead_enemies_animated:
					_dead_enemies_animated.append(i)
					ed.play_death_animation()
					_hide_enemy_display_after_death(ed)
			else:
				ed.update_enemy(edata)
	for peer_id in state_dict["players"]:
		var pid = int(peer_id)
		if player_board_nodes.has(pid):
			var pb = player_board_nodes[pid]
			if pb is Control and pb.has_method("update_player"):
				pb.update_player(state_dict["players"][peer_id], pid == local_peer_id)
			elif pb is Control:
				_update_ally_bar(pb, state_dict["players"][peer_id])
	var local_data = state_dict["players"].get(local_peer_id, state_dict["players"].get(str(local_peer_id), {}))
	# Update resource orbs from dict state (client path)
	if local_data:
		if hp_orb:
			hp_orb.max_value = int(local_data.get("max_hp", 1))
			hp_orb.set_value(int(local_data.get("current_hp", 0)))
		if mana_orb:
			mana_orb.max_value = int(local_data.get("max_energy", 1))
			mana_orb.set_value(int(local_data.get("energy", 0)))
		# Update large number labels on orbs (client path)
		if hp_number:
			hp_number.text = "%d / %d" % [int(local_data.get("current_hp", 0)), int(local_data.get("max_hp", 1))]
		if mp_number:
			mp_number.text = "%d / %d" % [int(local_data.get("energy", 0)), int(local_data.get("max_energy", 1))]
		# Update block display from dict state (client path)
		if block_display:
			var blk = int(local_data.get("block", 0))
			if blk > 0:
				block_display.text = "BLOCK %d" % blk
				block_display.visible = true
			else:
				block_display.visible = false
		# Update floating status above player 3D model (client path)
		if player_status_float:
			var float_hp = player_status_float.get_node_or_null("FloatHP")
			if float_hp:
				float_hp.set_values(int(local_data.get("current_hp", 0)), int(local_data.get("max_hp", 1)))
			var float_mp = player_status_float.get_node_or_null("FloatMP")
			if float_mp:
				float_mp.text = "MP: %d/%d" % [int(local_data.get("energy", 0)), int(local_data.get("max_energy", 1))]
			var float_block = player_status_float.get_node_or_null("FloatBlock")
			if float_block:
				var blk2 = int(local_data.get("block", 0))
				if blk2 > 0:
					float_block.text = "Block: %d" % blk2
				else:
					float_block.text = ""
	if local_data and not local_data.get("has_ended_turn", true) and state_dict.get("phase", -1) == Enums.CombatPhase.PLAYER_TURN:
		end_turn_btn.disabled = false
		_start_end_turn_pulse()
	else:
		end_turn_btn.disabled = true
		_stop_end_turn_pulse()


func _start_end_turn_pulse() -> void:
	if _end_turn_pulse_tween and _end_turn_pulse_tween.is_valid():
		return  # Already pulsing
	_end_turn_pulse_tween = create_tween().set_loops()
	_end_turn_pulse_tween.tween_property(end_turn_btn, "modulate", Color(1.3, 1.3, 1.1, 1.0), 0.7).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_end_turn_pulse_tween.tween_property(end_turn_btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.7).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _stop_end_turn_pulse() -> void:
	if _end_turn_pulse_tween and _end_turn_pulse_tween.is_valid():
		_end_turn_pulse_tween.kill()
		_end_turn_pulse_tween = null
	end_turn_btn.modulate = Color(0.6, 0.6, 0.6, 0.8)

# Waits for the death animation (~0.85s) then hides the enemy display node.
func _hide_enemy_display_after_death(ed: Control) -> void:
	await get_tree().create_timer(0.85).timeout
	if is_instance_valid(ed):
		ed.visible = false

# === Input Handlers ===

func _on_card_selected(hand_index: int, target_index: int) -> void:
	# Clear any lingering targeting highlights before playing the card.
	_clear_targeting_highlights()
	_targeting_active = false
	_targeting_hand_index = -1

	# Animate card flying to target (optimistic — fires before engine resolves)
	var target_pos: Vector2 = Vector2(960, 400)  # Center screen for self-target
	if target_index >= 0 and enemy_display_nodes.has(target_index):
		target_pos = enemy_display_nodes[target_index].global_position + Vector2(100, 80)
	hand_display.animate_card_play(hand_index, target_pos)

	if is_networked:
		if is_server:
			engine.try_play_card(local_peer_id, hand_index, target_index)
		else:
			_server_play_card.rpc_id(1, hand_index, target_index)
	else:
		engine.try_play_card(local_peer_id, hand_index, target_index)

# --- Multi-enemy targeting flow ---

func _on_targeting_started(hand_index: int) -> void:
	_targeting_active = true
	_targeting_hand_index = hand_index
	# Highlight all living enemies as valid targets.
	for i in enemy_display_nodes:
		var ed = enemy_display_nodes[i]
		if ed and engine and i < engine.state.enemies.size():
			var es = engine.state.enemies[i]
			ed.set_targetable(es.current_hp > 0)

func _on_targeting_cancelled() -> void:
	_targeting_active = false
	_targeting_hand_index = -1
	_clear_targeting_highlights()

func _on_enemy_display_clicked(enemy_index: int) -> void:
	if not _targeting_active:
		return
	# Validate that this enemy is still alive.
	if engine and enemy_index < engine.state.enemies.size():
		var es = engine.state.enemies[enemy_index]
		if es.current_hp <= 0:
			return  # dead enemy — ignore click
	_targeting_active = false
	_targeting_hand_index = -1
	_clear_targeting_highlights()
	hand_display.confirm_target(enemy_index)

func _clear_targeting_highlights() -> void:
	for i in enemy_display_nodes:
		var ed = enemy_display_nodes[i]
		if ed:
			ed.set_targetable(false)

func _on_end_turn_pressed() -> void:
	if is_networked:
		if is_server:
			engine.player_end_turn(local_peer_id)
		else:
			_server_end_turn.rpc_id(1)
	else:
		engine.player_end_turn(local_peer_id)

# === Engine Signal Handlers (server only) ===

func _on_state_changed() -> void:
	if is_server:
		var current_phase: int = engine.state.phase
		var phase_changed: bool = current_phase != _last_phase
		_last_phase = current_phase

		if current_phase == Enums.CombatPhase.PLAYER_TURN and phase_changed:
			# Defer YOUR TURN banner AND hand refresh until enemy animations finish
			if _playing_enemy_turn:
				pass  # _play_enemy_actions() will show banner + refresh when done
			else:
				if turn_banner:
					turn_banner.show_banner("YOUR TURN", Color(0.2, 0.9, 0.3))
				SFXManager.play_card_draw()
				_refresh_all_ui()
		elif current_phase == Enums.CombatPhase.ENEMY_TURN and phase_changed:
			if turn_banner:
				turn_banner.show_enemy_turn()
			hand_display.animate_discard_all()
			_refresh_all_ui()
		else:
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

	if combat_log:
		if result["damage_dealt"] > 0:
			var target_name = _get_enemy_log_name(target_index)
			combat_log.add_damage("P%d" % peer_id, target_name, result["damage_dealt"])
		if result["block_gained"] > 0:
			combat_log.add_block("P%d" % peer_id, result["block_gained"])
		if result["heal_amount"] > 0:
			combat_log.add_heal("P%d" % peer_id, result["heal_amount"])

func _get_enemy_log_name(enemy_index: int) -> String:
	if engine and enemy_index >= 0 and enemy_index < engine.state.enemies.size():
		var es = engine.state.enemies[enemy_index]
		var edata: EnemyData = load("res://data/enemies/%s.tres" % es.enemy_data_id)
		if edata:
			return edata.display_name
	return "Enemy"

func _on_enemy_acted(enemy_index: int, intent_type: int, value: int, target_peer_id: int, damage_dealt: int) -> void:
	# Queue enemy actions for staggered playback instead of instant
	_enemy_action_queue.append({
		"enemy_index": enemy_index, "intent_type": intent_type,
		"value": value, "target_peer_id": target_peer_id, "damage_dealt": damage_dealt,
	})
	# Start playback if not already running
	if not _playing_enemy_turn:
		_play_enemy_actions()


func _play_enemy_actions() -> void:
	_playing_enemy_turn = true
	# Brief pause before enemies start acting (let "ENEMY TURN" banner show)
	await get_tree().create_timer(0.8).timeout

	while _enemy_action_queue.size() > 0:
		var action: Dictionary = _enemy_action_queue.pop_front()
		var ei: int = action["enemy_index"]
		var it: int = action["intent_type"]
		var val: int = action["value"]
		var tpid: int = action["target_peer_id"]
		var dd: int = action["damage_dealt"]

		# Play the enemy's attack/defend/buff animation on the 3D model —
		# only for KayKit puppets; painted enemies have no animation rig.
		if _enemy_puppets_3d.has(ei) and _enemy_puppets_3d[ei] is PuppetBase3D:
			match it:
				Enums.EnemyIntent.ATTACK: _enemy_puppets_3d[ei].play_attack()
				Enums.EnemyIntent.DEFEND: _enemy_puppets_3d[ei].play_block()
				Enums.EnemyIntent.BUFF:   _enemy_puppets_3d[ei].play_buff()
				_:                        _enemy_puppets_3d[ei].play_cast()

		# Brief wind-up pause so the animation plays before impact
		await get_tree().create_timer(0.4).timeout

		# Now show the FX (damage numbers, screen shake, etc.)
		if is_networked:
			_client_enemy_acted_fx.rpc(ei, it, val, tpid, dd)
		else:
			_client_enemy_acted_fx(ei, it, val, tpid, dd)

		# Log it
		if combat_log:
			var ename = _get_enemy_log_name(ei)
			if it == Enums.EnemyIntent.ATTACK and dd > 0:
				combat_log.add_damage(ename, "P%d" % tpid, dd)
			elif it == Enums.EnemyIntent.DEFEND:
				combat_log.add_block(ename, val)
			elif it == Enums.EnemyIntent.BUFF:
				combat_log.add_status("%s buffed: +%d STR" % [ename, val])

		_refresh_all_ui()

		# Pause between enemy actions so each one is visible
		await get_tree().create_timer(0.6).timeout

	_playing_enemy_turn = false
	# NOW show YOUR TURN banner (after all enemy animations finished)
	if engine and engine.state.phase == Enums.CombatPhase.PLAYER_TURN:
		if turn_banner:
			turn_banner.show_banner("YOUR TURN", Color(0.2, 0.9, 0.3))
		SFXManager.play_card_draw()
		_refresh_all_ui()

func _on_combat_ended(won: bool) -> void:
	if is_networked:
		_client_combat_over.rpc(won)
	else:
		_client_combat_over(won)

# === M1 Signal Handlers ===

func _on_sin_punished(peer_id: int, sin_result: Dictionary) -> void:
	# Show sin punishment as a big damage number / status text
	var _dmg_p = _get_player_dmg_parent(peer_id)
	if _dmg_p:
		var dmg = sin_result.get("damage", 0)
		if dmg > 0:
			_spawn_damage_number(_dmg_p, dmg, "damage")
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
		_set_deaths_door_visual(true)

func _on_player_died(peer_id: int) -> void:
	print("Player %d has died!" % peer_id)
	SFXManager.play_death()
	if peer_id == local_peer_id and deaths_door_overlay:
		deaths_door_overlay.show_dead()

func _on_corruption_tier_changed(peer_id: int, new_tier: int) -> void:
	var tier_names = ["PURE", "TAINTED", "CORRUPTED", "DEMONIC"]
	print("Player %d corruption tier: %s" % [peer_id, tier_names[new_tier]])
	if peer_id == local_peer_id:
		SFXManager.play_corruption()
		_do_screen_shake(6.0, 0.2)
		_flash_glitch_effect()

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
				var _dmg_p = _get_player_dmg_parent(pid)
				if paid[pid] > 0 and _dmg_p:
					_spawn_damage_number(_dmg_p, paid[pid], "damage")
			print("Tithe paid: %s" % str(paid))
		else:
			var lost = TitheSystem.apply_tithe_refusal(engine.state)
			for pid in lost:
				var _dmg_p = _get_player_dmg_parent(pid)
				if lost[pid] != "" and _dmg_p:
					_spawn_damage_number(_dmg_p, 1, "weak")
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
				if pact.get("hp_cost", 0) > 0:
					var _dmg_p = _get_player_dmg_parent(peer_id)
					if _dmg_p:
						_spawn_damage_number(_dmg_p, pact["hp_cost"], "damage")
		else:
			print("Pact declined: %s" % pact["title"])
		_refresh_all_ui()

# === Boss Mechanic Handlers ===

func _on_boss_mechanic(mechanic_name: String, data: Dictionary) -> void:
	# Log to combat log
	if combat_log:
		var desc = data.get("description", mechanic_name.replace("_", " ").to_upper())
		combat_log.add_status(desc)

	# Check if this mechanic requires a vote
	if data.get("requires_vote", false):
		_handle_boss_vote(mechanic_name, data)
		return

	# Non-vote mechanics: show visual feedback
	match mechanic_name:
		"divine_trumpet":
			if turn_banner:
				turn_banner.show_banner("DIVINE TRUMPET!", Color(1.0, 0.85, 0.2))
			var target_pid = data.get("target_peer_id", local_peer_id)
			var dmg = data.get("damage", 0)
			if dmg > 0:
				var _dmg_p = _get_player_dmg_parent(target_pid)
				if _dmg_p:
					_spawn_damage_number(_dmg_p, dmg, "damage")
				if target_pid == local_peer_id:
					_do_screen_shake(12.0, 0.4)
					SFXManager.play_hit()

		"blessing_of_worthy":
			if turn_banner:
				turn_banner.show_banner("BLESSING!", Color(0.2, 0.9, 0.3))
			var target_pid = data.get("target_peer_id", local_peer_id)
			var heal = data.get("heal", 0)
			if heal > 0:
				var _dmg_p = _get_player_dmg_parent(target_pid)
				if _dmg_p:
					_spawn_damage_number(_dmg_p, heal, "heal")
				SFXManager.play_heal()

		"holy_fire_burn":
			if turn_banner:
				turn_banner.show_banner("HOLY FIRE!", Color(1.0, 0.5, 0.1))
			var player_dmg = data.get("player_damage", {})
			for pid in player_dmg:
				var dmg = player_dmg[pid]
				if dmg > 0:
					var _dmg_p = _get_player_dmg_parent(int(pid))
					if _dmg_p:
						_spawn_damage_number(_dmg_p, dmg, "damage")
			_do_screen_shake(10.0, 0.35)
			SFXManager.play_hit()

		"twin_swords":
			if turn_banner:
				turn_banner.show_banner("TWIN SWORDS!", Color(0.9, 0.3, 0.3))
			_do_screen_shake(8.0, 0.3)
			SFXManager.play_hit()

		"shield_raised":
			if turn_banner:
				turn_banner.show_banner("SHIELD RAISED!", Color(0.4, 0.75, 1.0))
			_flash_aberration()

		"death_mark_applied":
			if turn_banner:
				turn_banner.show_banner("DEATH MARK!", Color(0.6, 0.1, 0.6))
			var target_pid = data.get("target_peer_id", -1)
			if target_pid == local_peer_id:
				_do_screen_shake(15.0, 0.5)

		"death_mark_tick":
			pass  # Already logged to combat_log above

		"death_mark_triggered":
			if turn_banner:
				turn_banner.show_banner("DEATH MARK TRIGGERED!", Color(0.8, 0.0, 0.0))
			_do_screen_shake(20.0, 0.6)
			SFXManager.play_death()

		"soul_harvest":
			if turn_banner:
				turn_banner.show_banner("SOUL HARVEST!", Color(0.5, 0.0, 0.5))
			var hp_loss = data.get("hp_loss_per_player", 0)
			if hp_loss > 0:
				for pid in engine.state.players:
					var _dmg_p = _get_player_dmg_parent(pid)
					if _dmg_p:
						_spawn_damage_number(_dmg_p, hp_loss, "damage")
			_do_screen_shake(12.0, 0.4)

		"death_mark_transferred":
			if turn_banner:
				turn_banner.show_banner("MARK TRANSFERRED!", Color(0.6, 0.4, 0.8))

		"final_convergence_start":
			if turn_banner:
				turn_banner.show_banner("FINAL CONVERGENCE!", Color(1.0, 0.0, 0.0))
			_do_screen_shake(20.0, 0.7)
			_flash_aberration(0.5, 8.0)

		"final_convergence_end":
			if turn_banner:
				turn_banner.show_banner("CONVERGENCE ENDS!", Color(0.2, 0.9, 0.5))

		"reality_split":
			if turn_banner:
				turn_banner.show_banner("REALITY SPLIT!", Color(0.8, 0.2, 0.8))
			_do_screen_shake(15.0, 0.5)

	_refresh_all_ui()


func _handle_boss_vote(mechanic_name: String, data: Dictionary) -> void:
	var options: Array[String] = []
	for opt in data.get("options", []):
		options.append(str(opt))

	var voter_ids: Array[int] = []
	for vid in data.get("voter_peer_ids", [local_peer_id]):
		voter_ids.append(int(vid))

	var prompt_text = data.get("description", "The boss demands a choice!")
	var ctx = VoteSystem.create_vote(mechanic_name, prompt_text, options, voter_ids)

	# Create and show vote overlay
	_vote_overlay = VoteOverlay.new()
	add_child(_vote_overlay)
	_vote_overlay.show_vote(ctx)

	# In solo mode, just wait for local vote. In co-op, collect from all players.
	_vote_overlay.vote_cast.connect(func(option_index: int):
		VoteSystem.cast_vote(ctx, local_peer_id, option_index)
		# In solo mode, resolve immediately
		if not is_networked or VoteSystem.all_voted(ctx):
			_resolve_boss_vote(mechanic_name, ctx)
	)

	_vote_overlay.vote_timed_out.connect(func():
		_resolve_boss_vote(mechanic_name, ctx)
	)


func _resolve_boss_vote(mechanic_name: String, ctx: VoteSystem.VoteContext) -> void:
	var result_index = VoteSystem.resolve(ctx)

	if combat_log:
		combat_log.add_status("Vote result: %s" % ctx.options[result_index])

	# Call the appropriate resolve method on the boss encounter
	if engine.boss_encounter:
		match mechanic_name:
			"judgment":
				var result = engine.boss_encounter.resolve_judgment(result_index == 0)
				if turn_banner:
					if result_index == 0:
						turn_banner.show_banner("SHIELD BROKEN!", Color(1.0, 0.5, 0.0))
					else:
						turn_banner.show_banner("SHIELD ENDURES!", Color(0.4, 0.4, 0.8))
			"holy_fire":
				var result = engine.boss_encounter.resolve_holy_fire(result_index == 0)
				if turn_banner:
					if result_index == 0:
						turn_banner.show_banner("FIRE EXTINGUISHED!", Color(0.2, 0.9, 0.5))
					else:
						turn_banner.show_banner("FLAMES ENDURE!", Color(1.0, 0.3, 0.0))
			"the_cube":
				var result = engine.boss_encounter.resolve_cube(result_index)
				if turn_banner:
					var face_names = ["PAIN", "FRAILTY", "CORRUPTION", "VOID"]
					if result_index >= 0 and result_index < face_names.size():
						turn_banner.show_banner("FACE OF %s!" % face_names[result_index], Color(0.8, 0.2, 0.8))
		_do_screen_shake(10.0, 0.3)

	# Clean up vote overlay
	if _vote_overlay:
		_vote_overlay.close()
		_vote_overlay = null

	_refresh_all_ui()

# === Compact Ally Bars (for remote players in co-op) ===

func _create_ally_bar(peer_id: int) -> Control:
	var bar = Control.new()
	bar.custom_minimum_size = Vector2(180, 32)
	bar.name = "AllyBar_%d" % peer_id

	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.12, 0.75)
	bg.size = Vector2(180, 32)
	bar.add_child(bg)

	var name_lbl = Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = "Player %d" % peer_id
	name_lbl.position = Vector2(4, 1)
	name_lbl.size = Vector2(80, 14)
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	bar.add_child(name_lbl)

	var hp_bar_node = preload("res://scenes/ui/hp_bar.tscn").instantiate()
	hp_bar_node.name = "HPBar"
	hp_bar_node.position = Vector2(4, 16)
	hp_bar_node.size = Vector2(120, 12)
	hp_bar_node.custom_minimum_size = Vector2(120, 12)
	bar.add_child(hp_bar_node)

	var energy_lbl = Label.new()
	energy_lbl.name = "EnergyLabel"
	energy_lbl.text = "10"
	energy_lbl.position = Vector2(130, 8)
	energy_lbl.size = Vector2(46, 20)
	energy_lbl.add_theme_font_size_override("font_size", 11)
	energy_lbl.add_theme_color_override("font_color", Color(0.4, 0.65, 1.0))
	energy_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(energy_lbl)

	return bar

func _update_ally_bar(bar: Control, state_dict: Dictionary) -> void:
	var name_lbl = bar.get_node_or_null("NameLabel")
	if name_lbl:
		name_lbl.text = state_dict.get("display_name", "Ally")
	var hp_bar_node = bar.get_node_or_null("HPBar")
	if hp_bar_node:
		hp_bar_node.set_values(state_dict.get("current_hp", 0), state_dict.get("max_hp", 1))
	var energy_lbl = bar.get_node_or_null("EnergyLabel")
	if energy_lbl:
		energy_lbl.text = "%d/%d" % [state_dict.get("energy", 0), state_dict.get("max_energy", 10)]

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
		var target: int = -1
		if card_data.target_type == Enums.TargetType.ENEMY:
			# Target the first living enemy.
			target = _get_first_living_enemy_index()
			if target < 0:
				break  # No living enemies — combat should be ending
		if not engine.try_play_card(bot_id, 0, target):
			break

func _get_first_living_enemy_index() -> int:
	if engine:
		for i in engine.state.enemies.size():
			if engine.state.enemies[i].current_hp > 0:
				return i
	return -1

# === Character Rendering (3D Puppet or Painted 2D Sprite) ===

## Resolve which character the player is this combat.
## Priority: active run → DEBUG_SANDBOX_PLAYER override (F6 sandbox) → "knight".
func _resolve_player_character_id() -> String:
	if GameManager.is_run_active() and GameManager.current_run:
		return GameManager.current_run.character_id
	if DEBUG_SANDBOX_PLAYER != "":
		return DEBUG_SANDBOX_PLAYER
	return "knight"


func _spawn_player_puppet_3d() -> void:
	var character_id := _resolve_player_character_id()
	var painted_mode := character_id in PAINTED_2D_PLAYERS

	_combat_3d_stage = Combat3DStageScene.instantiate() as Combat3DStage
	_combat_3d_stage.name = "Combat3DStage"
	_combat_3d_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_combat_3d_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shake_container.add_child(_combat_3d_stage)
	shake_container.move_child(_combat_3d_stage, 0)

	# Painted 2D mode: hide the entire 3D stage (stone dungeon + KayKit puppets)
	# and render a painted backdrop + painted player in the 2D layer instead.
	# The 3D stage is kept in the tree (not freed) so the invisible Node3D
	# enemy anchors still exist inside _enemy_spawn and the existing
	# _update_enemy_display_positions() can still project their screen coords
	# via the Camera3D. The camera's unproject_position() is pure math and
	# works even when the SubViewport isn't rendering.
	if painted_mode:
		_combat_3d_stage.visible = false
		_spawn_painted_backdrop_and_player(character_id)
	else:
		# Load a dungeon variant for this combat. Phase 1: pick by whether the
		# first enemy is a boss, else use the Act 1 server crypt variants.
		var variant := _pick_dungeon_variant()
		if variant:
			var seed_val: int = 1
			if GameManager.is_run_active() and GameManager.current_run:
				# Hash (act, floors_cleared) so each room in a run varies
				# deterministically without needing a dedicated run seed field.
				var r = GameManager.current_run
				seed_val = (int(r.act) * 10007) ^ (int(r.floors_cleared) * 31)
				if seed_val == 0:
					seed_val = 1
			_combat_3d_stage.load_dungeon(variant, seed_val)

	# Spawn player puppet via the 3D stage. In painted mode this is still
	# called so _player_puppet_3d is populated for any legacy code paths, but
	# the puppet is inside the hidden Combat3DStage so it doesn't render. The
	# painted SpriteSheetAnimator added in _spawn_painted_backdrop_and_player
	# is what the player actually sees.
	_player_puppet_3d = _combat_3d_stage.spawn_player(character_id)
	if painted_mode and _player_puppet_3d:
		# Extra safety: hide the KayKit puppet even within the hidden stage,
		# in case anything tries to bring the stage back visible later.
		_player_puppet_3d.visible = false

	# Spawn enemies as 3D anchors (invisible) / 2D painted sprites and hide
	# the legacy 2D fullbody artwork in EnemyDisplay for painted enemies.
	if engine:
		var enemy_count: int = engine.state.enemies.size()
		print("[EnemySpawnLoop] enemy_count=%d painted_arena=%s PAINTED_2D_ENEMIES=%s"
			% [enemy_count, str(_painted_arena), str(Combat3DStage.PAINTED_2D_ENEMIES)])
		for i in enemy_count:
			var enemy_id: String = engine.state.enemies[i].enemy_data_id
			print("[EnemySpawnLoop] i=%d enemy_id=%s in_painted_list=%s"
				% [i, enemy_id, enemy_id in Combat3DStage.PAINTED_2D_ENEMIES])
			var enemy_puppet: Node3D = _combat_3d_stage.spawn_enemy(enemy_id, i, enemy_count)
			_enemy_puppets_3d[i] = enemy_puppet
			# Painted enemies: set up the corresponding slot in painted_arena.tscn
			# so its TextureRect shows this enemy's fullbody sprite at the
			# editor-placed position. See _configure_painted_enemy_slot.
			if enemy_id in Combat3DStage.PAINTED_2D_ENEMIES:
				_configure_painted_enemy_slot(enemy_id, i)
			# Hide 2D enemy artwork after a frame so it catches dynamically loaded sprites
			if enemy_display_nodes.has(i):
				_hide_enemy_2d_art.call_deferred(i)

		# Hide any unused painted enemy slots (if painted_arena.tscn has more
		# slots than the current encounter needs).
		if _painted_arena != null:
			var slot_idx: int = enemy_count
			while true:
				var slot = _painted_arena.get_node_or_null("PaintedEnemySprite_%d" % slot_idx)
				if slot == null:
					break
				slot.visible = false
				slot_idx += 1


## Packed painted arena scene — edit scenes/combat/painted_arena.tscn in the
## Godot editor to drag the backdrop / player / enemy sprites around visually.
## Runtime code below just instantiates the scene and swaps textures as needed.
const PaintedArenaScene = preload("res://scenes/combat/painted_arena.tscn")
const SpriteSheetAnimatorScript = preload("res://scripts/ui/sprite_sheet_animator.gd")

## The instantiated PaintedArena root, cached so later code can find its
## PaintedPlayer / PaintedEnemySprite_* children for texture swapping and
## for EnemyDisplay UI positioning.
var _painted_arena: Control = null


## Instantiate painted_arena.tscn as a child of shake_container. The scene
## file has default textures (Ghost idle for PaintedPlayer, Effigy v4 for
## PaintedEnemySprite_0) and fixed positions that can be tweaked in the
## editor. Here we just override textures / sheets based on the actual
## character_id + enemy list for this combat.
func _spawn_painted_backdrop_and_player(character_id: String) -> void:
	_painted_arena = PaintedArenaScene.instantiate() as Control
	shake_container.add_child(_painted_arena)
	shake_container.move_child(_painted_arena, 0)  # behind everything else

	# Verify the backdrop texture actually loaded. Godot's import system has
	# been flaky about some PNGs in this project (it marks the .import file
	# valid=false and never generates the .ctex, leaving scene-file ExtResource
	# references resolving to null). When that happens, bypass the import
	# pipeline entirely: read the raw PNG bytes with FileAccess, decode them
	# in memory with Image.load_png_from_buffer, and build an ImageTexture.
	# Slightly less efficient (no GPU compression) but guaranteed to work.
	var backdrop := _painted_arena.get_node_or_null("PaintedBackdrop") as TextureRect
	if backdrop:
		if backdrop.texture == null:
			print("[PaintedBackdrop] texture is NULL — bypassing import via FileAccess")
			# Try multiple candidate paths in order — first the art_pipeline
			# anchor (the original), then the assets copy.
			var candidates := [
				"res://art_pipeline/anchors/background_anchor.png",
				"res://assets/backdrops/server_crypt.png",
			]
			var loaded := false
			for p in candidates:
				if not FileAccess.file_exists(p):
					print("[PaintedBackdrop] candidate missing: %s" % p)
					continue
				var bytes := FileAccess.get_file_as_bytes(p)
				print("[PaintedBackdrop] read %d bytes from %s" % [bytes.size(), p])
				if bytes.size() == 0:
					continue
				var img := Image.new()
				var err := img.load_png_from_buffer(bytes)
				if err != OK:
					print("[PaintedBackdrop] load_png_from_buffer FAILED err=%d for %s" % [err, p])
					continue
				var tex := ImageTexture.create_from_image(img)
				backdrop.texture = tex
				print("[PaintedBackdrop] loaded via FileAccess: %s  size=%s" % [p, img.get_size()])
				loaded = true
				break
			if not loaded:
				push_warning("PaintedBackdrop: ALL candidate paths failed to load")
		print("[PaintedBackdrop] final texture=%s size=%s visible=%s"
			% [str(backdrop.texture), backdrop.size, backdrop.visible])
	else:
		push_warning("PaintedArena: PaintedBackdrop node missing")

	# --- Override the player sprite sheet based on the actual character_id ---
	# The scene file defaults to Ghost's idle. For other painted characters,
	# swap to their sheet here.
	var painted_player := _painted_arena.get_node_or_null("PaintedPlayer")
	if painted_player:
		var sheet_path := "res://assets/characters/%s/sheets/idle.png" % character_id
		var meta_path := "res://assets/characters/%s/sheets/idle.json" % character_id
		if ResourceLoader.exists(sheet_path) and painted_player.has_method("load_pose"):
			painted_player.load_pose(sheet_path, meta_path)
		print("[PaintedPlayer] character=%s position=%s size=%s"
			% [character_id, painted_player.position, painted_player.size])
	else:
		push_warning("PaintedArena: PaintedPlayer node not found in instantiated scene")

	print("[PaintedArena] instantiated at position=%s size=%s"
		% [_painted_arena.position, _painted_arena.size])


## Configure the PaintedEnemySprite_<slot_index> node in the instantiated
## painted arena: set its texture from the enemy's fullbody.png and make it
## visible. Slots beyond total_slots are hidden. Called from the main enemy
## spawn loop in _spawn_player_puppet_3d for each painted enemy.
func _configure_painted_enemy_slot(enemy_id: String, slot_index: int) -> void:
	if _painted_arena == null:
		return
	var slot_name := "PaintedEnemySprite_%d" % slot_index
	var slot: TextureRect = _painted_arena.get_node_or_null(slot_name) as TextureRect
	if slot == null:
		push_warning("PaintedArena: %s not found — add more slots to painted_arena.tscn if needed" % slot_name)
		return

	var fullbody_path := "res://assets/characters/%s/fullbody.png" % enemy_id
	if ResourceLoader.exists(fullbody_path):
		slot.texture = load(fullbody_path)
	slot.visible = true
	print("[PaintedArena] %s configured for %s" % [slot_name, enemy_id])


## Return the PaintedEnemySprite_<slot_index> Control from the instantiated
## painted arena, or null if it doesn't exist. Used by
## _update_enemy_display_positions to place the HP / intent UI above the
## painted enemy sprite instead of projecting from the (hidden) 3D anchor.
func _get_painted_enemy_slot(slot_index: int) -> Control:
	if _painted_arena == null:
		return null
	return _painted_arena.get_node_or_null("PaintedEnemySprite_%d" % slot_index) as Control


## Pick a DungeonVariant for the current combat.
## Phase 1: if the first enemy is "michael" return the Michael boss arena; if
## any enemy is flagged boss return the boss variant; otherwise pick between
## the Act 1 crypt pristine/worn variants based on floor depth.
func _pick_dungeon_variant() -> Resource:
	if not engine or engine.state.enemies.is_empty():
		return load("res://resources/dungeons/variants/act1_server_crypt_pristine.tres")

	var first_enemy_id: String = engine.state.enemies[0].enemy_data_id
	if first_enemy_id == "michael":
		return load("res://resources/dungeons/variants/boss_michael_judgment_hall.tres")

	# Floor depth decides pristine vs worn on Act 1.
	var floor_depth: int = 0
	if GameManager.is_run_active() and GameManager.current_run:
		floor_depth = int(GameManager.current_run.floors_cleared)

	if floor_depth >= 5:
		return load("res://resources/dungeons/variants/act1_server_crypt_worn.tres")
	return load("res://resources/dungeons/variants/act1_server_crypt_pristine.tres")


## Debug: hot-swap the loaded dungeon variant without restarting combat.
## (F-keys collide with the Godot debugger; use Ctrl+number instead.)
##   Ctrl+1 → server crypt pristine
##   Ctrl+2 → server crypt worn
##   Ctrl+3 → Michael's judgment hall (boss)
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if not event.ctrl_pressed:
		return
	if not _combat_3d_stage:
		return
	var path := ""
	match event.keycode:
		KEY_1:
			path = "res://resources/dungeons/variants/act1_server_crypt_pristine.tres"
		KEY_2:
			path = "res://resources/dungeons/variants/act1_server_crypt_worn.tres"
		KEY_3:
			path = "res://resources/dungeons/variants/boss_michael_judgment_hall.tres"
		_:
			return
	var variant: Resource = load(path)
	if not variant:
		push_warning("Dungeon debug swap: could not load %s" % path)
		return
	_combat_3d_stage.load_dungeon(variant, randi() % 100000 + 1)
	print("[DEBUG] Swapped dungeon → %s" % path.get_file())


func _hide_enemy_2d_art(enemy_index: int) -> void:
	if not enemy_display_nodes.has(enemy_index):
		return

	# In painted 2D combat mode, the character render IS the EnemySprite
	# TextureRect inside EnemyDisplay (loaded by enemy_display.gd from
	# assets/characters/<id>/fullbody.png). Don't hide it — the whole point
	# of painted mode is that the 2D sprite IS what the player sees.
	if engine and engine.state and enemy_index < engine.state.enemies.size():
		var enemy_id: String = engine.state.enemies[enemy_index].enemy_data_id
		if enemy_id in Combat3DStage.PAINTED_2D_ENEMIES:
			return

	var ed = enemy_display_nodes[enemy_index]
	# Hide all visual children but keep UI elements (HP bar, intent, name, etc.)
	# This is the legacy chibi-mode path — only used when a KayKit 3D puppet
	# is actually rendering behind the EnemyDisplay.
	for child in ed.get_children():
		if child is ColorRect or child is TextureRect or child.name == "EnemySprite" or child.name == "ShadowRect":
			child.visible = false
		# Hide 2D puppet if loaded
		if child.name.contains("puppet") or child.name.contains("Puppet"):
			child.visible = false

func _puppet_play_card_anim(card_data) -> void:
	if not _player_puppet_3d:
		return
	if not card_data:
		_player_puppet_3d.play_attack()
		return
	match card_data.card_type:
		Enums.CardType.ATTACK: _player_puppet_3d.play_attack()
		Enums.CardType.SKILL:  _player_puppet_3d.play_cast()
		Enums.CardType.POWER:  _player_puppet_3d.play_buff()
		_:                     _player_puppet_3d.play_cast()

# === Shader VFX Helpers ===

func _flash_glitch_effect(duration: float = 0.4) -> void:
	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(1, 1, 1, 1)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/glitch_distortion.gdshader")
	mat.set_shader_parameter("tear_intensity", 0.04)
	mat.set_shader_parameter("tear_frequency", 8.0)
	mat.set_shader_parameter("chromatic_shift", 0.008)
	mat.set_shader_parameter("glitch_chance", 0.8)
	overlay.material = mat
	add_child(overlay)
	# Auto-remove after duration
	var tw = create_tween()
	tw.tween_interval(duration)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.15)
	tw.tween_callback(overlay.queue_free)

func _set_deaths_door_visual(active: bool) -> void:
	if active and not _deaths_door_aberration:
		_deaths_door_aberration = ColorRect.new()
		_deaths_door_aberration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_deaths_door_aberration.color = Color(1, 1, 1, 1)
		_deaths_door_aberration.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat = ShaderMaterial.new()
		mat.shader = load("res://shaders/chromatic_aberration.gdshader")
		mat.set_shader_parameter("aberration_amount", 3.0)
		add_child(_deaths_door_aberration)
	elif not active and _deaths_door_aberration:
		_deaths_door_aberration.queue_free()
		_deaths_door_aberration = null

func _flash_aberration(duration: float = 0.3, intensity: float = 5.0) -> void:
	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(1, 1, 1, 1)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/chromatic_aberration.gdshader")
	mat.set_shader_parameter("aberration_amount", intensity)
	overlay.material = mat
	add_child(overlay)
	var tw = create_tween()
	tw.tween_method(func(val: float):
		if is_instance_valid(overlay) and overlay.material:
			overlay.material.set_shader_parameter("aberration_amount", val)
	, intensity, 0.0, duration)
	tw.tween_callback(overlay.queue_free)
