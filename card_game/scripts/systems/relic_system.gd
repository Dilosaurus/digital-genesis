class_name RelicSystem
extends RefCounted

static var _relic_database: Dictionary = {}

static func load_relics() -> void:
	var dir = DirAccess.open("res://data/relics/")
	if not dir:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var relic: RelicData = load("res://data/relics/" + fname)
			if relic:
				_relic_database[relic.id] = relic
		fname = dir.get_next()
	print("Loaded %d relics" % _relic_database.size())

static func get_relic(id: String) -> RelicData:
	return _relic_database.get(id)

# Combat stat bonuses (strength, dexterity, block, energy) are now handled by
# ModifierBridge.populate_combat_start() which creates proper modifier stack entries.
# This function is kept for backwards compatibility but is no longer called.
static func apply_start_of_combat(_player: PlayerState, _relic_ids: Array) -> void:
	pass

static func get_heal_on_win(relic_ids: Array) -> int:
	var total = 0
	for rid in relic_ids:
		var r = get_relic(rid)
		if r:
			total += r.heal_on_combat_end
	return total

static func get_random_relic_reward(owned: Array, count: int = 3) -> Array[String]:
	# Separate by rarity: 0=common, 1=uncommon, 2=rare
	var by_rarity: Dictionary = {0: [], 1: [], 2: []}
	for rid in _relic_database:
		if rid not in owned:
			var r: RelicData = _relic_database[rid]
			by_rarity[r.rarity].append(rid)

	# Build weighted pool: common=60%, uncommon=30%, rare=10%
	# We'll pick by weighted random, without replacement per call
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
			# Fallback: any non-empty pool
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
