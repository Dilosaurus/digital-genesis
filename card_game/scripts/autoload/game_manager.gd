extends Node

var card_database: Dictionary = {}  # String -> CardData
var current_run: RunState = null
var current_enemy: String = ""          # kept for backwards compat; always first enemy
var current_enemies: Array[String] = [] # all enemies in the current combat node
var current_node_type: String = "fight"  # "fight", "elite", or "boss"

# Boss ID -> Array of card IDs players can absorb after defeating them
var boss_rewards: Dictionary = {
	"michael": ["flaming_sword", "divine_shield", "holy_wrath"],
	"hexaghost": ["heavy_blade", "overclock_core", "power_surge"],
	"jaw_worm": ["recursive_loop", "phantom_firewall"],
	"cultist": ["adaptive_shield", "full_reboot"],
	"louse_red": ["overclock_core", "recursive_loop"],
	"gabriel": ["adaptive_shield", "full_reboot", "phantom_firewall"],
	"raphael": ["overclock_core", "phantom_firewall", "full_reboot"],
	"uriel": ["power_surge", "recursive_loop"],
	"azrael": ["overclock_core", "power_surge", "recursive_loop"],
	"metatron": ["flaming_sword", "divine_shield", "holy_wrath", "power_surge"],
}

func _ready() -> void:
	_load_card_database()
	RelicSystem.load_relics()

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
	var rewards: Array[String] = []
	var raw = boss_rewards.get(enemy_id, [])
	for r in raw:
		rewards.append(r)
	return rewards

func get_random_card_rewards(count: int = 3) -> Array[String]:
	# Collect eligible cards: non-curse, non-upgraded
	var eligible: Array[String] = []
	var player_deck: Array[String] = []
	if is_run_active():
		player_deck = current_run.deck

	for card_id in card_database:
		var card: CardData = card_database[card_id]
		# Exclude curses (CURSE = 4) and pre-upgraded variants
		if card.card_type == Enums.CardType.CURSE:
			continue
		if card.upgraded:
			continue
		eligible.append(card_id)

	# Shuffle eligible list (Fisher-Yates)
	for i in range(eligible.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var tmp = eligible[i]
		eligible[i] = eligible[j]
		eligible[j] = tmp

	# Pick cards — prefer ones not already in the deck
	var result: Array[String] = []
	var fallback: Array[String] = []
	for card_id in eligible:
		if result.size() >= count:
			break
		if player_deck.has(card_id):
			fallback.append(card_id)
		else:
			result.append(card_id)

	# Fill remaining slots from fallback (duplicates) if needed
	var fi = 0
	while result.size() < count and fi < fallback.size():
		result.append(fallback[fi])
		fi += 1

	return result

func start_new_run() -> void:
	current_run = RunState.new_run()
	current_enemy = ""
	current_enemies = []
	current_run.save_to_file()

func is_run_active() -> bool:
	return current_run != null

func end_run() -> void:
	RunState.delete_save()
	current_run = null

func save_run() -> void:
	if current_run:
		current_run.save_to_file()

func load_saved_run() -> bool:
	var loaded = RunState.load_from_file()
	if loaded:
		current_run = loaded
		return true
	return false
