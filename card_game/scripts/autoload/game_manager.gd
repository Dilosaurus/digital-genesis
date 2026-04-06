extends Node

var card_database: Dictionary = {}  # String -> CardData
var current_run: RunState = null
var selected_character_id: String = "netrunner"
var current_enemy: String = ""          # kept for backwards compat; always first enemy
var current_enemies: Array[String] = [] # all enemies in the current combat node
var current_node_type: String = "fight"  # "fight", "elite", or "boss"

# Co-op: maps peer_id -> character_id for networked games
var per_player_characters: Dictionary = {}  # int -> String

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
	"data_leech": ["memory_leak", "backdoor"],
	"firewall_sentinel": ["data_shield", "digital_fortress"],
	"memory_worm": ["cache_flush", "null_pointer"],
	"quantum_ghost": ["phantom_firewall", "recursive_loop"],
	"seraph_drone": ["holy_wrath", "flaming_sword"],
	"core_guardian": ["digital_fortress", "adaptive_shield", "overclock_core"],
	"fallen_archangel": ["power_surge", "phantom_firewall", "malware_inject"],
	"corrupted_throne": ["divine_shield", "holy_wrath", "overclock_core", "recursive_loop"],
}

func _ready() -> void:
	_load_card_database()
	RelicSystem.load_relics()
	EquipmentSystem.load_equipment()
	GemSystem.load_gems()
	SkillTreeSystem.load_skill_trees()

	# Load saved video/audio settings
	var SettingsScreen = load("res://scripts/scenes/settings_screen.gd")
	SettingsScreen.load_and_apply_settings()

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
	if current_run:
		var char_data: CharacterData = load("res://data/characters/%s.tres" % current_run.character_id)
		if char_data:
			return char_data.starter_deck.duplicate()
	# Fallback to legacy starter deck
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

# Character -> preferred card tags for affinity-based reward weighting
const CHARACTER_AFFINITY: Dictionary = {
	"netrunner": [Enums.CardTag.TECH, Enums.CardTag.EXPLOIT, Enums.CardTag.RANGED],
	"sysadmin": [Enums.CardTag.TECH, Enums.CardTag.MELEE],
	"cryptomancer": [Enums.CardTag.SHADOW, Enums.CardTag.EXPLOIT],
	"white_hat": [Enums.CardTag.HOLY, Enums.CardTag.MELEE],
	"technomancer": [Enums.CardTag.TECH, Enums.CardTag.SHADOW, Enums.CardTag.EXPLOIT],
}

func get_random_card_rewards(count: int = 3) -> Array[String]:
	# Collect eligible cards: non-curse, non-upgraded
	var eligible_affinity: Array[String] = []
	var eligible_other: Array[String] = []
	var player_deck: Array[String] = []
	var char_id: String = ""
	if is_run_active():
		player_deck = current_run.deck
		char_id = current_run.character_id

	var preferred_tags: Array = CHARACTER_AFFINITY.get(char_id, [])

	for card_id in card_database:
		var card: CardData = card_database[card_id]
		# Exclude curses and pre-upgraded variants
		if card.card_type == Enums.CardType.CURSE:
			continue
		if card.upgraded:
			continue
		# Check if card matches any preferred tag
		var matches_affinity := false
		for tag in preferred_tags:
			if tag in card.tags:
				matches_affinity = true
				break
		if matches_affinity:
			eligible_affinity.append(card_id)
		else:
			eligible_other.append(card_id)

	# Shuffle both pools (Fisher-Yates)
	_shuffle_array(eligible_affinity)
	_shuffle_array(eligible_other)

	# 60% affinity, 40% random — determine how many slots go to each pool
	var affinity_count: int = ceili(count * 0.6)
	var other_count: int = count - affinity_count

	# Pick cards — prefer ones not already in the deck
	var result: Array[String] = []

	# Fill affinity slots first
	result.append_array(_pick_from_pool(eligible_affinity, affinity_count, player_deck))
	# Fill remaining with other pool
	result.append_array(_pick_from_pool(eligible_other, other_count, player_deck))

	# If we didn't get enough (small pools), fill from whichever pool has leftovers
	if result.size() < count:
		var combined: Array[String] = []
		combined.append_array(eligible_affinity)
		combined.append_array(eligible_other)
		_shuffle_array(combined)
		for card_id in combined:
			if result.size() >= count:
				break
			if card_id not in result:
				result.append(card_id)

	return result

func _pick_from_pool(pool: Array[String], count: int, player_deck: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var fallback: Array[String] = []
	for card_id in pool:
		if result.size() >= count:
			break
		if player_deck.has(card_id):
			fallback.append(card_id)
		else:
			result.append(card_id)
	var fi := 0
	while result.size() < count and fi < fallback.size():
		result.append(fallback[fi])
		fi += 1
	return result

func _shuffle_array(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func start_new_run() -> void:
	current_run = RunState.new_run(selected_character_id)
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
