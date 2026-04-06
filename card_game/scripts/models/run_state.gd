class_name RunState
extends RefCounted

var character_id: String = "netrunner"
var deck: Array[String] = []
var current_hp: int = 80
var max_hp: int = 80
var gold: int = 0
var souls: int = 0
var crystals: int = 0
var corruption_essence: int = 0
var current_node: int = 0
var act: int = 1
var completed_nodes: Array[int] = []
var relics: Array[String] = []
var remove_count: int = 0  # Tracks how many cards removed at shop (raises price)

# XP / Leveling
var xp: int = 0
var level: int = 1
var max_mana_bonus: int = 0  # Accumulated mana bonus from leveling (applied during combat)

# Equipment & gems
var equipment: Dictionary = {}          # EquipSlot (int) -> equipment_id (String)
var gems: Array[String] = []            # Owned gem IDs
var gem_assignments: Dictionary = {}    # card_id (String) -> Array[String] of gem IDs

# Skill tree
var skill_points: int = 0
var unlocked_skills: Array[String] = []

# Corruption shrine
var shrine_corrupted_cards: Array[String] = []
var run_corruption: int = 0
var max_corruption: int = 100

# Run statistics
var enemies_defeated: int = 0
var floors_cleared: int = 0
var total_gold_earned: int = 0
var total_damage_dealt: int = 0

# Branching map data
var map_data: Array = []         # Array of rows; each row = Array of node dicts
var current_row: int = -1        # -1 = hasn't started yet
var current_node_col: int = -1   # column within current_row

static func new_run(p_character_id: String = "netrunner") -> RunState:
	var rs = RunState.new()
	rs.character_id = p_character_id
	var char_data: CharacterData = load("res://data/characters/%s.tres" % p_character_id)
	if char_data:
		rs.deck = char_data.starter_deck.duplicate()
		rs.max_hp = char_data.starting_hp
		rs.current_hp = char_data.starting_hp
	else:
		# Fallback to legacy starter deck
		for i in 4:
			rs.deck.append("strike")
		for i in 3:
			rs.deck.append("defend")
		rs.deck.append("bash")
		rs.deck.append("iron_wave")
		rs.deck.append("pommel_strike")
	# Cryptomancer passive: start at 15 corruption
	if p_character_id == "cryptomancer":
		rs.run_corruption = 15
	# Technomancer passive: start with 4 energy (handled via character data starting_energy)
	# No special run_state init needed — Daemon Forge is resolved in combat_engine
	rs.map_data = RunState.generate_map(1)
	return rs

# ---------------------------------------------------------------------------
# Map generation
# ---------------------------------------------------------------------------
# Each node dict:
#   {
#     "type": String,           fight/elite/rest/event/shop/boss
#     "enemies": Array[String], enemy ids for combat/boss/elite
#     "col": int,               column index in its row
#     "connections": Array[int] column indices in the *next* row this node connects to
#   }
static func generate_map(act_number: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# --- enemy pools per act ---
	var fight_pool: Array[String]
	var elite_pool: Array[String]
	var boss_pool: Array[String]
	match act_number:
		1:
			fight_pool = ["jaw_worm", "louse_red", "cultist"]
			elite_pool = ["hexaghost"]
			boss_pool  = ["michael"]
		2:
			fight_pool = ["data_leech", "firewall_sentinel", "memory_worm"]
			elite_pool = ["gabriel", "fallen_archangel"]
			boss_pool  = ["raphael"]
		_:
			fight_pool = ["quantum_ghost", "seraph_drone", "core_guardian"]
			elite_pool = ["uriel", "azrael", "corrupted_throne"]
			boss_pool  = ["metatron"]

	# --- row type templates (7 rows: 0-6) ---
	# Row 0 : fight only
	# Row 1 : fight / event / shop
	# Row 2 : fight / elite / event
	# Row 3 : fight / event / shop / elite
	# Row 4 : rest (guaranteed)
	# Row 5 : fight / elite
	# Row 6 : boss (single node)
	var row_type_pools: Array = [
		["fight", "fight", "fight"],                            # row 0
		["fight", "fight", "event", "shop", "forge"],              # row 1
		["fight", "fight", "elite", "event", "altar", "shrine"], # row 2
		["fight", "event", "shop", "elite", "fight", "jeweler", "altar"],  # row 3
		["rest"],                                               # row 4
		["fight", "fight", "elite"],                            # row 5
		["boss"],                                               # row 6
	]

	# How many columns per row (row 4 and 6 are always 1)
	var col_counts: Array[int] = [
		rng.randi_range(2, 3),  # row 0
		rng.randi_range(2, 4),  # row 1
		rng.randi_range(2, 4),  # row 2
		rng.randi_range(2, 4),  # row 3
		1,                      # row 4  (rest)
		rng.randi_range(1, 3),  # row 5
		1,                      # row 6  (boss)
	]

	# --- build nodes ---
	var map: Array = []
	for row_idx in 7:
		var count = col_counts[row_idx]
		var row_arr: Array = []
		var type_pool: Array = row_type_pools[row_idx]
		for col in count:
			var ntype: String = type_pool[rng.randi() % type_pool.size()]
			var enemies: Array[String] = []
			match ntype:
				"fight":
					var num_enemies = rng.randi_range(1, 2)
					for _e in num_enemies:
						enemies.append(fight_pool[rng.randi() % fight_pool.size()])
				"elite":
					enemies.append(elite_pool[rng.randi() % elite_pool.size()])
				"boss":
					enemies.append(boss_pool[rng.randi() % boss_pool.size()])
			var node_dict: Dictionary = {
				"type": ntype,
				"enemies": enemies,
				"col": col,
				"connections": [],
			}
			row_arr.append(node_dict)
		map.append(row_arr)

	# --- build connections (each node connects to 1-2 nodes in the next row) ---
	for row_idx in 6:  # rows 0-5 connect forward
		var cur_row: Array = map[row_idx]
		var next_row: Array = map[row_idx + 1]
		var next_count: int = next_row.size()

		# Ensure every node in the next row is reachable from at least one node
		# First pass: assign at least one connection per current node
		for node in cur_row:
			# Map col proportionally to next row width for spatial coherence
			var frac: float = float(node["col"]) / float(maxi(cur_row.size() - 1, 1))
			var preferred_col: int = roundi(frac * (next_count - 1))
			preferred_col = clampi(preferred_col, 0, next_count - 1)
			if preferred_col not in node["connections"]:
				node["connections"].append(preferred_col)

		# Second pass: maybe add a second connection (branching)
		for node in cur_row:
			if rng.randf() < 0.45 and node["connections"].size() < 2:
				var c = rng.randi() % next_count
				if c not in node["connections"]:
					node["connections"].append(c)

		# Ensure every next-row node is reachable (flood from cur_row)
		var reached: Array[int] = []
		for node in cur_row:
			for c in node["connections"]:
				if c not in reached:
					reached.append(c)
		for next_node in next_row:
			if next_node["col"] not in reached:
				# Connect the closest current node to this orphan
				var closest_node = cur_row[0]
				var best_dist = abs(cur_row[0]["col"] - next_node["col"])
				for node in cur_row:
					var d = abs(node["col"] - next_node["col"])
					if d < best_dist:
						best_dist = d
						closest_node = node
				if next_node["col"] not in closest_node["connections"]:
					closest_node["connections"].append(next_node["col"])

		# Sort connections for consistency
		for node in cur_row:
			node["connections"].sort()

	return map

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func advance_act() -> void:
	act += 1
	map_data = RunState.generate_map(act)
	current_row = -1
	current_node_col = -1
	completed_nodes.clear()

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

## Apply penalty for a full party wipe (all players truly dead in combat).
## Loses 15% of gold (minimum 10 gold lost if gold > 0).
func apply_combat_loss_penalty() -> void:
	var gold_loss = maxi(int(gold * 0.15), mini(gold, 10))
	gold = maxi(gold - gold_loss, 0)
	# Note: progress loss (back to last rest point) would be handled by
	# reverting current_row to last rest row, but this needs careful
	# map traversal logic. For now, just the gold penalty.

# Returns the list of (row, col) pairs the player can visit next.
func get_accessible_nodes() -> Array:
	if current_row == -1:
		# Haven't started — first row is fully accessible
		var result: Array = []
		if map_data.size() > 0:
			for node in map_data[0]:
				result.append({"row": 0, "col": node["col"]})
		return result
	# Otherwise: follow connections from current node
	if current_row >= map_data.size() - 1:
		return []
	var cur_node = _get_node(current_row, current_node_col)
	if cur_node == null:
		return []
	var result: Array = []
	for col in cur_node["connections"]:
		result.append({"row": current_row + 1, "col": col})
	return result

func _get_node(row: int, col: int) -> Variant:
	if row < 0 or row >= map_data.size():
		return null
	for node in map_data[row]:
		if node["col"] == col:
			return node
	return null

func is_node_completed(row: int, col: int) -> bool:
	for entry in completed_nodes:
		# completed_nodes stores packed ints: row * 100 + col
		if entry == row * 100 + col:
			return true
	return false

func mark_node_complete(row: int, col: int) -> void:
	var key = row * 100 + col
	if key not in completed_nodes:
		completed_nodes.append(key)

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------
func save_to_file() -> void:
	# Serialize map_data (array of arrays of dicts, connections are int arrays)
	var serialized_map: Array = []
	for row in map_data:
		var srow: Array = []
		for node in row:
			var snode: Dictionary = {
				"type": node["type"],
				"enemies": node["enemies"],
				"col": node["col"],
				"connections": node["connections"],
			}
			srow.append(snode)
		serialized_map.append(srow)

	var data = {
		"character_id": character_id,
		"deck": deck,
		"current_hp": current_hp,
		"max_hp": max_hp,
		"gold": gold,
		"souls": souls,
		"crystals": crystals,
		"corruption_essence": corruption_essence,
		"current_node": current_node,
		"act": act,
		"completed_nodes": completed_nodes,
		"relics": relics,
		"map_data": serialized_map,
		"current_row": current_row,
		"current_node_col": current_node_col,
		"remove_count": remove_count,
		"equipment": equipment,
		"gems": gems,
		"gem_assignments": gem_assignments,
		"enemies_defeated": enemies_defeated,
		"floors_cleared": floors_cleared,
		"total_gold_earned": total_gold_earned,
		"total_damage_dealt": total_damage_dealt,
		"skill_points": skill_points,
		"unlocked_skills": unlocked_skills,
		"shrine_corrupted_cards": shrine_corrupted_cards,
		"run_corruption": run_corruption,
		"max_corruption": max_corruption,
		"xp": xp,
		"level": level,
		"max_mana_bonus": max_mana_bonus,
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
	rs.character_id = data.get("character_id", "netrunner")
	rs.deck.assign(data.get("deck", []))
	rs.current_hp = data.get("current_hp", 80)
	rs.max_hp = data.get("max_hp", 80)
	rs.gold = data.get("gold", 0)
	rs.souls = data.get("souls", 0)
	rs.crystals = data.get("crystals", 0)
	rs.corruption_essence = data.get("corruption_essence", 0)
	rs.current_node = data.get("current_node", 0)
	rs.act = data.get("act", 1)
	for n in data.get("completed_nodes", []):
		rs.completed_nodes.append(int(n))
	for r in data.get("relics", []):
		rs.relics.append(str(r))
	rs.current_row = data.get("current_row", -1)
	rs.current_node_col = data.get("current_node_col", -1)
	rs.remove_count = data.get("remove_count", 0)
	rs.equipment = data.get("equipment", {})
	for g in data.get("gems", []):
		rs.gems.append(str(g))
	rs.gem_assignments = data.get("gem_assignments", {})
	rs.enemies_defeated = data.get("enemies_defeated", 0)
	rs.floors_cleared = data.get("floors_cleared", 0)
	rs.total_gold_earned = data.get("total_gold_earned", 0)
	rs.total_damage_dealt = data.get("total_damage_dealt", 0)
	rs.skill_points = data.get("skill_points", 0)
	for s in data.get("unlocked_skills", []):
		rs.unlocked_skills.append(str(s))
	for sc in data.get("shrine_corrupted_cards", []):
		rs.shrine_corrupted_cards.append(str(sc))
	rs.run_corruption = data.get("run_corruption", 0)
	rs.max_corruption = data.get("max_corruption", 100)
	rs.xp = data.get("xp", 0)
	rs.level = data.get("level", 1)
	rs.max_mana_bonus = data.get("max_mana_bonus", 0)

	# Deserialize map_data
	var raw_map = data.get("map_data", [])
	if raw_map.size() > 0:
		for raw_row in raw_map:
			var row_arr: Array = []
			for raw_node in raw_row:
				var enemies_arr: Array[String] = []
				for e in raw_node.get("enemies", []):
					enemies_arr.append(str(e))
				var conns: Array[int] = []
				for c in raw_node.get("connections", []):
					conns.append(int(c))
				var node_dict: Dictionary = {
					"type": str(raw_node.get("type", "fight")),
					"enemies": enemies_arr,
					"col": int(raw_node.get("col", 0)),
					"connections": conns,
				}
				row_arr.append(node_dict)
			rs.map_data.append(row_arr)
	else:
		# No saved map — generate fresh
		rs.map_data = RunState.generate_map(rs.act)

	return rs

static func delete_save() -> void:
	if FileAccess.file_exists("user://save.json"):
		DirAccess.remove_absolute("user://save.json")
