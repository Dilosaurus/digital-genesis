class_name RunState
extends RefCounted

var deck: Array[String] = []
var current_hp: int = 80
var max_hp: int = 80
var gold: int = 0
var current_node: int = 0
var act: int = 1
var completed_nodes: Array[int] = []
var relics: Array[String] = []

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

func add_relic(relic_id: String) -> void:
	if relic_id not in relics:
		relics.append(relic_id)
		var relic = RelicSystem.get_relic(relic_id)
		if relic and relic.bonus_max_hp > 0:
			max_hp += relic.bonus_max_hp
			current_hp += relic.bonus_max_hp

func heal(amount: int) -> void:
	current_hp = mini(current_hp + amount, max_hp)

func save_to_file() -> void:
	var data = {
		"deck": deck,
		"current_hp": current_hp,
		"max_hp": max_hp,
		"gold": gold,
		"current_node": current_node,
		"act": act,
		"completed_nodes": completed_nodes,
		"relics": relics,
	}
	var file = FileAccess.open("user://save.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

static func load_from_file() -> RunState:
	if not FileAccess.file_exists("user://save.json"):
		return null
	var file = FileAccess.open("user://save.json", FileAccess.READ)
	if not file:
		return null
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		return null
	var data = json.data
	var rs = RunState.new()
	rs.deck.assign(data.get("deck", []))
	rs.current_hp = data.get("current_hp", 80)
	rs.max_hp = data.get("max_hp", 80)
	rs.gold = data.get("gold", 0)
	rs.current_node = data.get("current_node", 0)
	rs.act = data.get("act", 1)
	for n in data.get("completed_nodes", []):
		rs.completed_nodes.append(int(n))
	for r in data.get("relics", []):
		rs.relics.append(str(r))
	return rs

static func delete_save() -> void:
	if FileAccess.file_exists("user://save.json"):
		DirAccess.remove_absolute("user://save.json")
