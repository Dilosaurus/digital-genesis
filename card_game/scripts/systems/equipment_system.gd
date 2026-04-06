class_name EquipmentSystem
extends RefCounted

static var _database: Dictionary = {}

static func load_equipment() -> void:
	var dir = DirAccess.open("res://data/equipment/")
	if not dir:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var equip: EquipmentData = load("res://data/equipment/" + fname)
			if equip:
				_database[equip.id] = equip
		fname = dir.get_next()
	print("Loaded %d equipment" % _database.size())

static func get_equipment(id: String) -> EquipmentData:
	return _database.get(id)

static func get_all_ids() -> Array[String]:
	var result: Array[String] = []
	for k in _database:
		result.append(k)
	return result

# Equip an item. Returns the previously equipped item ID (or "" if slot was empty).
static func equip(run: RunState, equip_id: String) -> String:
	var equip_data = get_equipment(equip_id)
	if not equip_data:
		return ""
	var slot: int = equip_data.slot
	var old_id: String = run.equipment.get(slot, "")
	run.equipment[slot] = equip_id
	return old_id

# Unequip from a slot. Returns the removed item ID (or "" if empty).
static func unequip(run: RunState, slot: int) -> String:
	var old_id: String = run.equipment.get(slot, "")
	run.equipment.erase(slot)
	return old_id

# Get a random equipment reward. Weighted by rarity like relics.
static func get_random_equipment_reward(owned_slots: Dictionary, count: int = 3) -> Array[String]:
	var owned_ids: Array[String] = []
	for slot in owned_slots:
		owned_ids.append(owned_slots[slot])

	var by_rarity: Dictionary = {0: [], 1: [], 2: []}
	for eid in _database:
		if eid not in owned_ids:
			var e: EquipmentData = _database[eid]
			by_rarity[e.rarity].append(eid)

	var result: Array[String] = []
	var attempts = 0
	while result.size() < count and attempts < 100:
		attempts += 1
		var roll = randf()
		var pool: Array
		if roll < 0.6 and by_rarity[0].size() > 0:
			pool = by_rarity[0]
		elif roll < 0.9 and by_rarity[1].size() > 0:
			pool = by_rarity[1]
		elif by_rarity[2].size() > 0:
			pool = by_rarity[2]
		else:
			for rarity in [0, 1, 2]:
				if by_rarity[rarity].size() > 0:
					pool = by_rarity[rarity]
					break
		if pool == null or pool.size() == 0:
			break
		var pick: String = pool[randi() % pool.size()]
		if pick not in result:
			result.append(pick)
	return result

static func get_price(rarity: int) -> int:
	match rarity:
		0: return 120
		1: return 220
		2: return 380
		_: return 120
