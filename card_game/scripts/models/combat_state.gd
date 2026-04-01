class_name CombatState
extends RefCounted

var phase: Enums.CombatPhase = Enums.CombatPhase.WAITING_FOR_PLAYERS
var turn_number: int = 0
var players: Dictionary = {}  # peer_id -> PlayerState
var enemies: Array[EnemyState] = []
var soul_fragments: int = 0
var boss_absorbed_souls: int = 0

func to_public_dict() -> Dictionary:
	var players_dict = {}
	for peer_id in players:
		players_dict[peer_id] = players[peer_id].to_public_dict()

	var enemies_array = []
	for enemy in enemies:
		enemies_array.append(enemy.to_dict())

	return {
		"phase": phase,
		"turn_number": turn_number,
		"players": players_dict,
		"enemies": enemies_array,
		"soul_fragments": soul_fragments,
		"boss_absorbed_souls": boss_absorbed_souls,
	}
