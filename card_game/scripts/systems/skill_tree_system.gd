class_name SkillTreeSystem
extends RefCounted

# ---------------------------------------------------------------------------
# Modifier spec keys (used in modifier_specs dictionaries on SkillNodeData)
# ---------------------------------------------------------------------------
# "stat"      : String — "damage", "block", "healing", "max_hp", "max_energy",
#                        "draw_per_turn", "energy_cost", "corruption_gain",
#                        "corruption_resist", "mana_regen"
# "op"        : String — "flat_add", "percent_add", "percent_mult", "override"
# "value"     : float
# "req_tags"  : Array[String] — card tag requirements (melee, ranged, fire, etc.)
# "vs_vuln"   : bool          — only applies against vulnerable enemies
# "hp_below"  : float         — only applies when player HP% is below this value
#                               (-1.0 means no restriction)
# ---------------------------------------------------------------------------

static var _tree_database: Dictionary = {}  # tree_id -> SkillTreeData

# ---------------------------------------------------------------------------
# Initialisation
# ---------------------------------------------------------------------------

static func load_skill_trees() -> void:
	_tree_database.clear()
	_create_default_trees()
	print("SkillTreeSystem: loaded %d tree(s)" % _tree_database.size())

# ---------------------------------------------------------------------------
# Lookup helpers
# ---------------------------------------------------------------------------

static func get_tree(id: String) -> SkillTreeData:
	return _tree_database.get(id)

static func get_all_trees() -> Array:
	return _tree_database.values()

static func get_node(tree_id: String, node_id: String) -> SkillNodeData:
	var tree: SkillTreeData = _tree_database.get(tree_id)
	if not tree:
		return null
	for n in tree.nodes:
		if n.id == node_id:
			return n
	return null

# ---------------------------------------------------------------------------
# Unlock logic
# ---------------------------------------------------------------------------

## Returns true when the player meets all prerequisites and has enough points.
static func can_unlock(node_id: String, unlocked_nodes: Array, skill_points: int) -> bool:
	# Find the node across all trees
	var node: SkillNodeData = _find_node_globally(node_id)
	if not node:
		return false
	if node_id in unlocked_nodes:
		return false  # already unlocked
	if skill_points < node.cost:
		return false
	for prereq in node.prerequisites:
		if prereq not in unlocked_nodes:
			return false
	return true

## Validates prerequisites, deducts skill points, and records the unlock.
## Returns true on success.
static func unlock_node(tree_id: String, node_id: String, run: RunState) -> bool:
	var node: SkillNodeData = get_node(tree_id, node_id)
	if not node:
		push_warning("SkillTreeSystem.unlock_node: node '%s' not found in tree '%s'" % [node_id, tree_id])
		return false
	if not can_unlock(node_id, run.unlocked_skills, run.skill_points):
		return false
	run.skill_points -= node.cost
	run.unlocked_skills.append(node_id)
	return true

# ---------------------------------------------------------------------------
# Modifier resolution — called by ModifierBridge at combat start
# ---------------------------------------------------------------------------

## Returns an array of ModifierData from all unlocked skill nodes.
## Called by ModifierBridge.populate_combat_start() to feed into the modifier stack.
static func get_all_modifiers(run: RunState) -> Array[ModifierData]:
	var result: Array[ModifierData] = []
	for tree in _tree_database.values():
		for node in tree.nodes:
			if node.id in run.unlocked_skills:
				for spec in node.modifier_specs:
					var mod := _spec_to_modifier(spec, node.id)
					if mod:
						result.append(mod)
	return result

## Converts an internal spec dictionary into a proper ModifierData resource.
static func _spec_to_modifier(spec: Dictionary, source_id: String) -> ModifierData:
	var mod := ModifierData.new()
	mod.stat = _stat_from_string(spec.get("stat", "damage"))
	mod.operation = _op_from_string(spec.get("op", "flat_add"))
	mod.value = spec.get("value", 0.0)
	mod.lifecycle = Enums.ModLifecycle.PERMANENT
	mod.source_type = "skill_tree"
	mod.source_id = source_id
	# Conditional fields
	var req_tags: Array = spec.get("req_tags", [])
	if req_tags.size() > 0:
		for tag_name in req_tags:
			var tag_int := _tag_from_string(tag_name)
			if tag_int >= 0:
				mod.required_card_tags.append(tag_int)
	mod.only_vs_vulnerable = spec.get("vs_vuln", false)
	mod.only_when_hp_below_pct = spec.get("hp_below", -1.0)
	return mod

static func _stat_from_string(s: String) -> Enums.Stat:
	match s:
		"damage": return Enums.Stat.DAMAGE
		"block": return Enums.Stat.BLOCK
		"healing": return Enums.Stat.HEALING
		"max_hp": return Enums.Stat.MAX_HP
		"max_energy": return Enums.Stat.MAX_ENERGY
		"draw_per_turn": return Enums.Stat.DRAW_PER_TURN
		"energy_cost": return Enums.Stat.ENERGY_COST
		"corruption_gain": return Enums.Stat.CORRUPTION_GAIN
		"corruption_resist": return Enums.Stat.CORRUPTION_RESIST
		"mana_regen": return Enums.Stat.MANA_REGEN
		_: return Enums.Stat.DAMAGE

static func _op_from_string(s: String) -> Enums.ModOp:
	match s:
		"flat_add": return Enums.ModOp.FLAT_ADD
		"percent_add": return Enums.ModOp.PERCENT_ADD
		"percent_mult": return Enums.ModOp.PERCENT_MULT
		"override": return Enums.ModOp.OVERRIDE
		_: return Enums.ModOp.FLAT_ADD

static func _tag_from_string(s: String) -> int:
	match s:
		"melee": return Enums.CardTag.MELEE
		"ranged": return Enums.CardTag.RANGED
		"fire": return Enums.CardTag.FIRE
		"ice": return Enums.CardTag.ICE
		"holy": return Enums.CardTag.HOLY
		"shadow": return Enums.CardTag.SHADOW
		"tech": return Enums.CardTag.TECH
		"exploit": return Enums.CardTag.EXPLOIT
		"curse": return Enums.CardTag.CURSE
		_: return -1

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

static func _find_node_globally(node_id: String) -> SkillNodeData:
	for tree in _tree_database.values():
		for n in tree.nodes:
			if n.id == node_id:
				return n
	return null

# ---------------------------------------------------------------------------
# Modifier spec builder helpers (internal, for _create_default_trees)
# ---------------------------------------------------------------------------

static func _spec(stat: String, op: String, value: float,
		req_tags: Array = [], vs_vuln: bool = false, hp_below: float = -1.0) -> Dictionary:
	return {
		"stat": stat,
		"op": op,
		"value": value,
		"req_tags": req_tags,
		"vs_vuln": vs_vuln,
		"hp_below": hp_below,
	}

static func _node(id: String, name: String, desc: String, tier: int, cost: int,
		prereqs: Array, specs: Array, pos: Vector2) -> SkillNodeData:
	var n := SkillNodeData.new()
	n.id = id
	n.display_name = name
	n.description = desc
	n.tier = tier
	n.cost = cost
	n.prerequisites.assign(prereqs)
	n.modifier_specs = specs
	n.position = pos
	return n

# ---------------------------------------------------------------------------
# Character-specific skill trees (5 trees, 3 branches x 4 nodes each)
# Layout: 3 columns (one per branch), 4 rows (linear chain per branch)
# ---------------------------------------------------------------------------

static func _create_default_trees() -> void:
	_create_netrunner_tree()
	_create_sysadmin_tree()
	_create_cryptomancer_tree()
	_create_white_hat_tree()
	_create_technomancer_tree()

# ------------------------------------------------------------------
# Netrunner (Zephyr) — "Neural Network"
# Rogue/draw engine. Tags: TECH, EXPLOIT, RANGED. Passive: +1 draw/turn.
# Branch 1: Speed (Offensive)   — column 0
# Branch 2: Evasion (Defensive) — column 1
# Branch 3: Exploit (Utility)   — column 2
# ------------------------------------------------------------------
static func _create_netrunner_tree() -> void:
	var tree := SkillTreeData.new()
	tree.id = "netrunner"
	tree.display_name = "Neural Network"

	# --- Branch 1: Speed (Offensive) — column 0 ---
	tree.nodes.append(_node(
		"nr_rapid_fire", "Rapid Fire", "+2 Ranged Damage",
		0, 1, [],
		[_spec("damage", "flat_add", 2.0, ["ranged"])],
		Vector2(0, 0)
	))
	tree.nodes.append(_node(
		"nr_burst_mode", "Burst Mode", "+15% Tech Damage",
		1, 1, ["nr_rapid_fire"],
		[_spec("damage", "percent_add", 0.15, ["tech"])],
		Vector2(0, 1)
	))
	tree.nodes.append(_node(
		"nr_chain_hack", "Chain Hack", "+1 Card Draw per Turn",
		2, 2, ["nr_burst_mode"],
		[_spec("draw_per_turn", "flat_add", 1.0)],
		Vector2(0, 2)
	))
	tree.nodes.append(_node(
		"nr_overdrive", "Overdrive", "+25% Damage",
		3, 2, ["nr_chain_hack"],
		[_spec("damage", "percent_add", 0.25)],
		Vector2(0, 3)
	))

	# --- Branch 2: Evasion (Defensive) — column 1 ---
	tree.nodes.append(_node(
		"nr_firewall", "Firewall", "+3 Block",
		0, 1, [],
		[_spec("block", "flat_add", 3.0)],
		Vector2(1, 0)
	))
	tree.nodes.append(_node(
		"nr_proxy_shield", "Proxy Shield", "+15% Block",
		1, 1, ["nr_firewall"],
		[_spec("block", "percent_add", 0.15)],
		Vector2(1, 1)
	))
	tree.nodes.append(_node(
		"nr_ghost_protocol", "Ghost Protocol", "+5 Max HP",
		2, 1, ["nr_proxy_shield"],
		[_spec("max_hp", "flat_add", 5.0)],
		Vector2(1, 2)
	))
	tree.nodes.append(_node(
		"nr_quantum_dodge", "Quantum Dodge", "+2 Block below 50% HP",
		3, 2, ["nr_ghost_protocol"],
		[_spec("block", "flat_add", 2.0, [], false, 0.5)],
		Vector2(1, 3)
	))

	# --- Branch 3: Exploit (Utility) — column 2 ---
	tree.nodes.append(_node(
		"nr_packet_sniff", "Packet Sniff", "+1 Card Draw per Turn",
		0, 1, [],
		[_spec("draw_per_turn", "flat_add", 1.0)],
		Vector2(2, 0)
	))
	tree.nodes.append(_node(
		"nr_rootkit", "Rootkit", "-1 Energy Cost for Exploit cards",
		1, 2, ["nr_packet_sniff"],
		[_spec("energy_cost", "flat_add", -1.0, ["exploit"])],
		Vector2(2, 1)
	))
	tree.nodes.append(_node(
		"nr_zero_day", "Zero Day", "+3 Damage vs Vulnerable",
		2, 1, ["nr_rootkit"],
		[_spec("damage", "flat_add", 3.0, [], true)],
		Vector2(2, 2)
	))
	tree.nodes.append(_node(
		"nr_backdoor", "Backdoor", "+10% Corruption Resist",
		3, 1, ["nr_zero_day"],
		[_spec("corruption_resist", "percent_add", 0.1)],
		Vector2(2, 3)
	))

	_tree_database[tree.id] = tree

# ------------------------------------------------------------------
# Sysadmin (Bastion) — "Fortress Protocol"
# Tank/Defender. Tags: TECH, MELEE. Passive: Start with 5 Block.
# Branch 1: Shield Wall (Defensive)  — column 0
# Branch 2: Retaliation (Offensive)  — column 1
# Branch 3: Endurance (Utility)      — column 2
# ------------------------------------------------------------------
static func _create_sysadmin_tree() -> void:
	var tree := SkillTreeData.new()
	tree.id = "sysadmin"
	tree.display_name = "Fortress Protocol"

	# --- Branch 1: Shield Wall (Defensive) — column 0 ---
	tree.nodes.append(_node(
		"sa_iron_wall", "Iron Wall", "+5 Block",
		0, 1, [],
		[_spec("block", "flat_add", 5.0)],
		Vector2(0, 0)
	))
	tree.nodes.append(_node(
		"sa_bulwark", "Bulwark", "+20% Block",
		1, 1, ["sa_iron_wall"],
		[_spec("block", "percent_add", 0.2)],
		Vector2(0, 1)
	))
	tree.nodes.append(_node(
		"sa_aegis", "Aegis", "+3 Block to Melee cards",
		2, 2, ["sa_bulwark"],
		[_spec("block", "flat_add", 3.0, ["melee"])],
		Vector2(0, 2)
	))
	tree.nodes.append(_node(
		"sa_unbreakable", "Unbreakable", "+10 Max HP",
		3, 2, ["sa_aegis"],
		[_spec("max_hp", "flat_add", 10.0)],
		Vector2(0, 3)
	))

	# --- Branch 2: Retaliation (Offensive) — column 1 ---
	tree.nodes.append(_node(
		"sa_thorns", "Thorns", "+2 Damage",
		0, 1, [],
		[_spec("damage", "flat_add", 2.0)],
		Vector2(1, 0)
	))
	tree.nodes.append(_node(
		"sa_counter_strike", "Counter Strike", "+3 Melee Damage",
		1, 1, ["sa_thorns"],
		[_spec("damage", "flat_add", 3.0, ["melee"])],
		Vector2(1, 1)
	))
	tree.nodes.append(_node(
		"sa_power_surge", "Power Surge", "+15% Damage",
		2, 2, ["sa_counter_strike"],
		[_spec("damage", "percent_add", 0.15)],
		Vector2(1, 2)
	))
	tree.nodes.append(_node(
		"sa_crushing_blow", "Crushing Blow", "+5 Damage vs Vulnerable",
		3, 2, ["sa_power_surge"],
		[_spec("damage", "flat_add", 5.0, [], true)],
		Vector2(1, 3)
	))

	# --- Branch 3: Endurance (Utility) — column 2 ---
	tree.nodes.append(_node(
		"sa_backup_power", "Backup Power", "+1 Mana Regen",
		0, 1, [],
		[_spec("mana_regen", "flat_add", 1.0)],
		Vector2(2, 0)
	))
	tree.nodes.append(_node(
		"sa_redundancy", "Redundancy", "+5 Max HP",
		1, 1, ["sa_backup_power"],
		[_spec("max_hp", "flat_add", 5.0)],
		Vector2(2, 1)
	))
	tree.nodes.append(_node(
		"sa_deep_scan", "Deep Scan", "+10% Corruption Resist",
		2, 1, ["sa_redundancy"],
		[_spec("corruption_resist", "percent_add", 0.1)],
		Vector2(2, 2)
	))
	tree.nodes.append(_node(
		"sa_firewall_plus", "Firewall+", "+10% Healing",
		3, 2, ["sa_deep_scan"],
		[_spec("healing", "percent_add", 0.1)],
		Vector2(2, 3)
	))

	_tree_database[tree.id] = tree

# ------------------------------------------------------------------
# Cryptomancer (Cipher) — "Dark Codex"
# Corruption glass cannon. Tags: SHADOW, EXPLOIT. Passive: +25% dmg at corr>=50.
# Branch 1: Corruption Power (Offensive)  — column 0
# Branch 2: Corruption Mastery (Utility)  — column 1
# Branch 3: Glass Cannon (Offensive 2)    — column 2
# ------------------------------------------------------------------
static func _create_cryptomancer_tree() -> void:
	var tree := SkillTreeData.new()
	tree.id = "cryptomancer"
	tree.display_name = "Dark Codex"

	# --- Branch 1: Corruption Power (Offensive) — column 0 ---
	tree.nodes.append(_node(
		"cm_dark_pulse", "Dark Pulse", "+3 Shadow Damage",
		0, 1, [],
		[_spec("damage", "flat_add", 3.0, ["shadow"])],
		Vector2(0, 0)
	))
	tree.nodes.append(_node(
		"cm_void_strike", "Void Strike", "+20% Damage",
		1, 1, ["cm_dark_pulse"],
		[_spec("damage", "percent_add", 0.2)],
		Vector2(0, 1)
	))
	tree.nodes.append(_node(
		"cm_chaos_bolt", "Chaos Bolt", "+5 Damage (corruption synergy)",
		2, 2, ["cm_void_strike"],
		[_spec("damage", "flat_add", 5.0)],
		Vector2(0, 2)
	))
	tree.nodes.append(_node(
		"cm_annihilate", "Annihilate", "x1.15 All Damage",
		3, 2, ["cm_chaos_bolt"],
		[_spec("damage", "percent_mult", 1.15)],
		Vector2(0, 3)
	))

	# --- Branch 2: Corruption Mastery (Utility) — column 1 ---
	tree.nodes.append(_node(
		"cm_dark_embrace", "Dark Embrace", "+20% Corruption Resist",
		0, 1, [],
		[_spec("corruption_resist", "percent_add", 0.2)],
		Vector2(1, 0)
	))
	tree.nodes.append(_node(
		"cm_soul_siphon", "Soul Siphon", "+10% Healing",
		1, 1, ["cm_dark_embrace"],
		[_spec("healing", "percent_add", 0.1)],
		Vector2(1, 1)
	))
	tree.nodes.append(_node(
		"cm_void_shield", "Void Shield", "+3 Block for Shadow cards",
		2, 1, ["cm_soul_siphon"],
		[_spec("block", "flat_add", 3.0, ["shadow"])],
		Vector2(1, 2)
	))
	tree.nodes.append(_node(
		"cm_entropy", "Entropy", "+1 Card Draw per Turn",
		3, 2, ["cm_void_shield"],
		[_spec("draw_per_turn", "flat_add", 1.0)],
		Vector2(1, 3)
	))

	# --- Branch 3: Glass Cannon (Offensive 2) — column 2 ---
	tree.nodes.append(_node(
		"cm_empower", "Empower", "+2 Damage",
		0, 1, [],
		[_spec("damage", "flat_add", 2.0)],
		Vector2(2, 0)
	))
	tree.nodes.append(_node(
		"cm_reckless", "Reckless", "+25% Damage below 50% HP",
		1, 1, ["cm_empower"],
		[_spec("damage", "percent_add", 0.25, [], false, 0.5)],
		Vector2(2, 1)
	))
	tree.nodes.append(_node(
		"cm_blood_magic", "Blood Magic", "+1 Mana Regen",
		2, 2, ["cm_reckless"],
		[_spec("mana_regen", "flat_add", 1.0)],
		Vector2(2, 2)
	))
	tree.nodes.append(_node(
		"cm_final_form", "Final Form", "+30% Damage below 25% HP",
		3, 2, ["cm_blood_magic"],
		[_spec("damage", "percent_add", 0.3, [], false, 0.25)],
		Vector2(2, 3)
	))

	_tree_database[tree.id] = tree

# ------------------------------------------------------------------
# White Hat (Sentinel) — "Divine Protocol"
# Paladin/Support. Tags: HOLY, MELEE. Passive: Holy cards cost -1 energy.
# Branch 1: Holy Strike (Offensive)   — column 0
# Branch 2: Protection (Defensive)    — column 1
# Branch 3: Purification (Utility)    — column 2
# ------------------------------------------------------------------
static func _create_white_hat_tree() -> void:
	var tree := SkillTreeData.new()
	tree.id = "white_hat"
	tree.display_name = "Divine Protocol"

	# --- Branch 1: Holy Strike (Offensive) — column 0 ---
	tree.nodes.append(_node(
		"wh_smite", "Smite", "+3 Holy Damage",
		0, 1, [],
		[_spec("damage", "flat_add", 3.0, ["holy"])],
		Vector2(0, 0)
	))
	tree.nodes.append(_node(
		"wh_divine_wrath", "Divine Wrath", "+15% Melee Damage",
		1, 1, ["wh_smite"],
		[_spec("damage", "percent_add", 0.15, ["melee"])],
		Vector2(0, 1)
	))
	tree.nodes.append(_node(
		"wh_righteous_fury", "Righteous Fury", "+4 Damage vs Vulnerable",
		2, 2, ["wh_divine_wrath"],
		[_spec("damage", "flat_add", 4.0, [], true)],
		Vector2(0, 2)
	))
	tree.nodes.append(_node(
		"wh_judgment", "Judgment", "+20% Damage",
		3, 2, ["wh_righteous_fury"],
		[_spec("damage", "percent_add", 0.2)],
		Vector2(0, 3)
	))

	# --- Branch 2: Protection (Defensive) — column 1 ---
	tree.nodes.append(_node(
		"wh_blessing", "Blessing", "+3 Block",
		0, 1, [],
		[_spec("block", "flat_add", 3.0)],
		Vector2(1, 0)
	))
	tree.nodes.append(_node(
		"wh_sanctuary", "Sanctuary", "+15% Block",
		1, 1, ["wh_blessing"],
		[_spec("block", "percent_add", 0.15)],
		Vector2(1, 1)
	))
	tree.nodes.append(_node(
		"wh_divine_shield", "Divine Shield", "+8 Max HP",
		2, 2, ["wh_sanctuary"],
		[_spec("max_hp", "flat_add", 8.0)],
		Vector2(1, 2)
	))
	tree.nodes.append(_node(
		"wh_absolution", "Absolution", "+20% Healing",
		3, 2, ["wh_divine_shield"],
		[_spec("healing", "percent_add", 0.2)],
		Vector2(1, 3)
	))

	# --- Branch 3: Purification (Utility) — column 2 ---
	tree.nodes.append(_node(
		"wh_cleanse", "Cleanse", "+25% Corruption Resist",
		0, 1, [],
		[_spec("corruption_resist", "percent_add", 0.25)],
		Vector2(2, 0)
	))
	tree.nodes.append(_node(
		"wh_purify", "Purify", "+10% Healing",
		1, 1, ["wh_cleanse"],
		[_spec("healing", "percent_add", 0.1)],
		Vector2(2, 1)
	))
	tree.nodes.append(_node(
		"wh_holy_light", "Holy Light", "+1 Card Draw per Turn",
		2, 1, ["wh_purify"],
		[_spec("draw_per_turn", "flat_add", 1.0)],
		Vector2(2, 2)
	))
	tree.nodes.append(_node(
		"wh_redemption", "Redemption", "-1 Energy Cost for Holy cards",
		3, 2, ["wh_holy_light"],
		[_spec("energy_cost", "flat_add", -1.0, ["holy"])],
		Vector2(2, 3)
	))

	_tree_database[tree.id] = tree

# ------------------------------------------------------------------
# Technomancer (FLUX) — "Daemon Forge"
# Summoner/Utility. Tags: TECH, SHADOW, EXPLOIT. Passive: +1 mana regen.
# Branch 1: Construct (Offensive)   — column 0
# Branch 2: Efficiency (Utility)    — column 1
# Branch 3: Resilience (Defensive)  — column 2
# ------------------------------------------------------------------
static func _create_technomancer_tree() -> void:
	var tree := SkillTreeData.new()
	tree.id = "technomancer"
	tree.display_name = "Daemon Forge"

	# --- Branch 1: Construct (Offensive) — column 0 ---
	tree.nodes.append(_node(
		"tm_overclock", "Overclock", "+2 Tech Damage",
		0, 1, [],
		[_spec("damage", "flat_add", 2.0, ["tech"])],
		Vector2(0, 0)
	))
	tree.nodes.append(_node(
		"tm_compile", "Compile", "+15% Damage",
		1, 1, ["tm_overclock"],
		[_spec("damage", "percent_add", 0.15)],
		Vector2(0, 1)
	))
	tree.nodes.append(_node(
		"tm_execute", "Execute", "+3 Exploit Damage",
		2, 1, ["tm_compile"],
		[_spec("damage", "flat_add", 3.0, ["exploit"])],
		Vector2(0, 2)
	))
	tree.nodes.append(_node(
		"tm_kernel_panic", "Kernel Panic", "+25% Damage, x1.1 Multiplier",
		3, 2, ["tm_execute"],
		[
			_spec("damage", "percent_add", 0.25),
			_spec("damage", "percent_mult", 1.1),
		],
		Vector2(0, 3)
	))

	# --- Branch 2: Efficiency (Utility) — column 1 ---
	tree.nodes.append(_node(
		"tm_cache", "Cache", "+1 Mana Regen",
		0, 1, [],
		[_spec("mana_regen", "flat_add", 1.0)],
		Vector2(1, 0)
	))
	tree.nodes.append(_node(
		"tm_optimize", "Optimize", "-1 Energy Cost for Tech cards",
		1, 2, ["tm_cache"],
		[_spec("energy_cost", "flat_add", -1.0, ["tech"])],
		Vector2(1, 1)
	))
	tree.nodes.append(_node(
		"tm_pipeline", "Pipeline", "+1 Card Draw per Turn",
		2, 1, ["tm_optimize"],
		[_spec("draw_per_turn", "flat_add", 1.0)],
		Vector2(1, 2)
	))
	tree.nodes.append(_node(
		"tm_quantum_core", "Quantum Core", "+5 Max Energy",
		3, 2, ["tm_pipeline"],
		[_spec("max_energy", "flat_add", 5.0)],
		Vector2(1, 3)
	))

	# --- Branch 3: Resilience (Defensive) — column 2 ---
	tree.nodes.append(_node(
		"tm_firewall", "Firewall", "+3 Block",
		0, 1, [],
		[_spec("block", "flat_add", 3.0)],
		Vector2(2, 0)
	))
	tree.nodes.append(_node(
		"tm_patch", "Patch", "+10% Block",
		1, 1, ["tm_firewall"],
		[_spec("block", "percent_add", 0.1)],
		Vector2(2, 1)
	))
	tree.nodes.append(_node(
		"tm_debug", "Debug", "+5 Max HP",
		2, 1, ["tm_patch"],
		[_spec("max_hp", "flat_add", 5.0)],
		Vector2(2, 2)
	))
	tree.nodes.append(_node(
		"tm_safe_mode", "Safe Mode", "+15% Corruption Resist, +5 Max HP",
		3, 2, ["tm_debug"],
		[
			_spec("corruption_resist", "percent_add", 0.15),
			_spec("max_hp", "flat_add", 5.0),
		],
		Vector2(2, 3)
	))

	_tree_database[tree.id] = tree
