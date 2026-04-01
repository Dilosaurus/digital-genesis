extends Node

var card_database: Dictionary = {}  # String -> CardData
var current_run: RunState = null
var current_enemy: String = ""

# Boss ID -> Array of card IDs players can absorb after defeating them
var boss_rewards: Dictionary = {
	"michael": ["flaming_sword", "divine_shield", "holy_wrath"],
	"hexaghost": ["heavy_blade", "cleave", "root_access"],
}

func _ready() -> void:
	_load_card_database()

func _load_card_database() -> void:
	var dir = DirAccess.open("res://data/cards/")
	if not dir:
		push_warning("No card data directory found")
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var card: CardData = load("res://data/cards/" + file_name)
			if card:
				card_database[card.id] = card
		file_name = dir.get_next()
	print("Loaded %d cards" % card_database.size())

func get_card_data(id: String) -> CardData:
	return card_database.get(id)

func get_starter_deck() -> Array[String]:
	var deck: Array[String] = []
	for i in 4:
		deck.append("strike")
	for i in 3:
		deck.append("defend")
	deck.append("bash")
	deck.append("iron_wave")
	deck.append("pommel_strike")
	return deck

func get_boss_rewards(enemy_id: String) -> Array[String]:
	return boss_rewards.get(enemy_id, [])

func start_new_run() -> void:
	current_run = RunState.new_run()
	current_enemy = ""

func is_run_active() -> bool:
	return current_run != null

func end_run() -> void:
	current_run = null
