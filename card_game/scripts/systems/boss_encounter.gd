class_name BossEncounter
extends RefCounted

## Base class for boss-specific raid mechanics.
## Subclass this for each boss to define unique turn-based effects.
##
## Lifecycle hooks are called by CombatEngine at the appropriate points.
## Each hook returns an Array of result Dicts that the UI layer can process.

signal mechanic_triggered(mechanic_name: String, data: Dictionary)
signal mechanic_resolved(mechanic_name: String, result: Dictionary)

var state: CombatState
var boss_enemy: EnemyState  # The boss enemy state reference
var boss_id: String = ""

func initialize(p_state: CombatState, p_boss: EnemyState) -> void:
	state = p_state
	boss_enemy = p_boss
	boss_id = p_boss.enemy_data_id

## Called at the START of each player turn, AFTER standard start_player_turn
## processing (mana regen, draw, debuff ticks, etc.).
## Override in subclasses to trigger turn-based mechanics.
func on_player_turn_start(turn_number: int) -> Array:
	return []

## Called at the END of each enemy turn, AFTER enemy actions and intent picks.
## Override for end-of-turn boss effects.
func on_enemy_turn_end(turn_number: int) -> Array:
	return []

## Called when a card is played, AFTER resolution.
## Override for reaction mechanics (e.g. counter-attacks, mark transfers).
func on_card_played(peer_id: int, card_id: String, damage_dealt: int) -> Array:
	return []

## Called when the boss enters a new phase (HP threshold crossed).
func on_phase_transition(phase_index: int) -> Array:
	return []

## Factory: create the right encounter subclass for a boss ID.
## Returns null for enemies that have no unique raid mechanics.
static func create_for_boss(boss_id: String) -> BossEncounter:
	match boss_id:
		"gabriel":
			return GabrielEncounter.new()
		"michael":
			return MichaelEncounter.new()
		"azrael":
			return AzraelEncounter.new()
		"metatron":
			return MetatronEncounter.new()
	return null
