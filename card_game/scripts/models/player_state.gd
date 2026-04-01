class_name PlayerState
extends RefCounted

var peer_id: int = 0
var display_name: String = "Player"
var max_hp: int = 80
var current_hp: int = 80
var block: int = 0
var energy: int = 3
var max_energy: int = 3
var draw_pile: Array[String] = []
var hand: Array[String] = []
var discard_pile: Array[String] = []
var exhaust_pile: Array[String] = []
var has_ended_turn: bool = false
var vulnerable: int = 0
var weak: int = 0
var corruption: int = 0
var max_corruption: int = 100
var corruption_tier: int = 0
var sin_wrath: int = 0
var sin_sloth: int = 0
var sin_pride: int = 0
var draw_penalty: int = 0
var pride_penalty: int = 0
var is_on_deaths_door: bool = false
var deaths_door_turns: int = 0
var is_dead: bool = false
var pact_damage_boost: int = 0
var strength: int = 0
var dexterity: int = 0

func to_public_dict() -> Dictionary:
	return {
		"peer_id": peer_id,
		"display_name": display_name,
		"max_hp": max_hp,
		"current_hp": current_hp,
		"block": block,
		"energy": energy,
		"max_energy": max_energy,
		"hand_count": hand.size(),
		"draw_pile_count": draw_pile.size(),
		"discard_pile_count": discard_pile.size(),
		"has_ended_turn": has_ended_turn,
		"vulnerable": vulnerable,
		"weak": weak,
		"corruption": corruption,
		"corruption_tier": corruption_tier,
		"sin_wrath": sin_wrath,
		"sin_sloth": sin_sloth,
		"sin_pride": sin_pride,
		"strength": strength,
		"dexterity": dexterity,
		"is_on_deaths_door": is_on_deaths_door,
		"deaths_door_turns": deaths_door_turns,
		"is_dead": is_dead,
	}

func to_owner_dict() -> Dictionary:
	var d = to_public_dict()
	d["hand"] = hand.duplicate()
	return d
