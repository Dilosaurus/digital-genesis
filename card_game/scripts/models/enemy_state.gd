class_name EnemyState
extends RefCounted

var enemy_data_id: String = ""
var max_hp: int = 40
var current_hp: int = 40
var block: int = 0
var intent_type: Enums.EnemyIntent = Enums.EnemyIntent.UNKNOWN
var intent_value: int = 0
var intent_index: int = 0
var vulnerable: int = 0
var weak: int = 0
var strength: int = 0

func to_dict() -> Dictionary:
	return {
		"enemy_data_id": enemy_data_id,
		"max_hp": max_hp,
		"current_hp": current_hp,
		"block": block,
		"intent_type": intent_type,
		"intent_value": intent_value,
		"vulnerable": vulnerable,
		"weak": weak,
		"strength": strength,
	}
