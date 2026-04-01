class_name RunState
extends RefCounted

var deck: Array[String] = []
var current_hp: int = 80
var max_hp: int = 80
var gold: int = 0
var current_node: int = 0
var act: int = 1
var completed_nodes: Array[int] = []

static func new_run() -> RunState:
	var rs = RunState.new()
	for i in 4:
		rs.deck.append("strike")
	for i in 3:
		rs.deck.append("defend")
	rs.deck.append("bash")
	rs.deck.append("iron_wave")
	rs.deck.append("pommel_strike")
	return rs

func add_card(card_id: String) -> void:
	deck.append(card_id)

func heal(amount: int) -> void:
	current_hp = mini(current_hp + amount, max_hp)
