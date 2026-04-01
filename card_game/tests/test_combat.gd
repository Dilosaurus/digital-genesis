extends Node

# Automated combat test — run headlessly to verify engine works
# Usage: godot --headless --path . -s tests/test_combat.gd

var engine: CombatEngine
var won := false
var lost := false

func _ready() -> void:
	print("=== COMBAT ENGINE TEST ===\n")

	# Load card database
	GameManager._load_card_database()
	print("Cards loaded: %s" % str(GameManager.card_database.keys()))

	# Initialize combat with 2 fake players
	engine = CombatEngine.new()
	engine.state_changed.connect(_on_state_changed)
	engine.card_was_played.connect(_on_card_played)
	engine.enemy_acted.connect(_on_enemy_acted)
	engine.combat_ended.connect(_on_combat_ended)

	engine.initialize([1, 2], "jaw_worm")

	print("Enemy HP: %d/%d (scaled for 2 players)" % [
		engine.state.enemies[0].current_hp,
		engine.state.enemies[0].max_hp
	])
	print("")

	# Simulate turns
	var max_turns = 20
	while not won and not lost and engine.state.turn_number <= max_turns:
		_simulate_player_turn(1)
		_simulate_player_turn(2)
		engine.player_end_turn(1)
		engine.player_end_turn(2)
		# enemy_turn is triggered automatically when both end

	if not won and not lost:
		print("\nTest ended after %d turns without resolution" % max_turns)

	print("\n=== TEST COMPLETE ===")
	get_tree().quit()

func _simulate_player_turn(peer_id: int) -> void:
	var ps: PlayerState = engine.state.players[peer_id]
	print("--- Player %d turn (HP: %d, Energy: %d, Hand: %s) ---" % [
		peer_id, ps.current_hp, ps.energy, str(ps.hand)
	])

	# Simple AI: play cards from left to right if we can afford them
	while ps.hand.size() > 0 and ps.energy > 0:
		var card_id = ps.hand[0]
		var card_data = GameManager.get_card_data(card_id)
		if not card_data or card_data.energy_cost > ps.energy:
			break
		var target_idx = 0 if card_data.target_type == Enums.TargetType.ENEMY else -1
		var success = engine.try_play_card(peer_id, 0, target_idx)
		if not success:
			break
		if won or lost:
			return

func _on_state_changed() -> void:
	pass

func _on_card_played(peer_id: int, card_id: String, target_index: int, result: Dictionary) -> void:
	var parts = []
	if result["damage_dealt"] > 0:
		parts.append("dealt %d damage" % result["damage_dealt"])
	if result["block_gained"] > 0:
		parts.append("gained %d block" % result["block_gained"])
	if result["heal_amount"] > 0:
		parts.append("healed %d" % result["heal_amount"])
	if result["vulnerable_applied"] > 0:
		parts.append("applied %d vulnerable" % result["vulnerable_applied"])
	print("  P%d played %s -> %s" % [peer_id, card_id, ", ".join(parts)])

func _on_enemy_acted(enemy_index: int, intent_type: int, value: int, target_peer_id: int, damage_dealt: int) -> void:
	if intent_type == Enums.EnemyIntent.ATTACK:
		print("  Enemy attacks P%d for %d damage (%d after block)" % [target_peer_id, value, damage_dealt])
	elif intent_type == Enums.EnemyIntent.DEFEND:
		print("  Enemy defends for %d block" % value)

func _on_combat_ended(player_won: bool) -> void:
	if player_won:
		won = true
		print("\n*** VICTORY! Enemy defeated! ***")
	else:
		lost = true
		print("\n*** DEFEAT! All players died! ***")
	for peer_id in engine.state.players:
		var ps = engine.state.players[peer_id]
		print("  Player %d: %d/%d HP" % [peer_id, ps.current_hp, ps.max_hp])
	for enemy in engine.state.enemies:
		print("  Enemy: %d/%d HP" % [enemy.current_hp, enemy.max_hp])
