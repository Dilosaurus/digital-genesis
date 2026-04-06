class_name GemSystem
extends RefCounted

static var _database: Dictionary = {}

static func load_gems() -> void:
	var dir = DirAccess.open("res://data/gems/")
	if not dir:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var gem: GemData = load("res://data/gems/" + fname)
			if gem:
				_database[gem.id] = gem
		fname = dir.get_next()
	print("Loaded %d gems" % _database.size())

static func get_gem(id: String) -> GemData:
	return _database.get(id)

static func get_all_ids() -> Array[String]:
	var result: Array[String] = []
	for k in _database:
		result.append(k)
	return result

# Socket a gem into a card. Returns true if successful.
static func socket_gem(run: RunState, card_id: String, gem_id: String) -> bool:
	var card_data = GameManager.get_card_data(card_id)
	if not card_data or card_data.gem_sockets <= 0:
		return false
	if gem_id not in run.gems:
		return false

	var current: Array = run.gem_assignments.get(card_id, [])
	if current.size() >= card_data.gem_sockets:
		return false

	# Remove gem from inventory, add to card
	run.gems.erase(gem_id)
	current.append(gem_id)
	run.gem_assignments[card_id] = current
	return true

# Unsocket a gem from a card. Returns it to inventory.
static func unsocket_gem(run: RunState, card_id: String, gem_index: int) -> String:
	var current: Array = run.gem_assignments.get(card_id, [])
	if gem_index < 0 or gem_index >= current.size():
		return ""
	var gem_id: String = current[gem_index]
	current.remove_at(gem_index)
	if current.is_empty():
		run.gem_assignments.erase(card_id)
	else:
		run.gem_assignments[card_id] = current
	run.gems.append(gem_id)
	return gem_id

# Activate gem modifiers for a card being played (adds CARD_PLAY lifecycle mods to stack).
static func activate_gems_for_card(player: PlayerState, card_id: String) -> void:
	if not GameManager.is_run_active():
		return
	var gem_ids: Array = GameManager.current_run.gem_assignments.get(card_id, [])
	for gid in gem_ids:
		var gem = get_gem(gid)
		if not gem:
			continue
		for mod in gem.on_play_modifiers:
			player.modifier_stack.add(mod.stamped("gem", gid))

# Deactivate all CARD_PLAY lifecycle modifiers (called after card resolves).
static func deactivate_gems(player: PlayerState) -> void:
	player.modifier_stack.remove_by_lifecycle(Enums.ModLifecycle.CARD_PLAY)

# Get a random gem reward. Weighted by rarity.
static func get_random_gem_reward(count: int = 3) -> Array[String]:
	var by_rarity: Dictionary = {0: [], 1: [], 2: []}
	for gid in _database:
		var g: GemData = _database[gid]
		by_rarity[g.rarity].append(gid)

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
		0: return 80
		1: return 160
		2: return 300
		_: return 80
