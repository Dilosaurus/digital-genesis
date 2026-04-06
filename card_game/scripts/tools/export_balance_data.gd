@tool
extends EditorScript

# ---------------------------------------------------------------------------
# export_balance_data.gd
# Run from Godot Editor > Script Editor > File > Run (Ctrl+Shift+X)
#
# Exports all game balance data to JSON files in:
#   E:\godot_games\balance_dashboard\data\
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Enum name arrays — order matches enums.gd exactly
# ---------------------------------------------------------------------------

const CARD_TYPE_NAMES   = ["ATTACK", "SKILL", "POWER", "STATUS", "CURSE"]
const TARGET_TYPE_NAMES = ["ENEMY", "SELF", "ALL_ENEMIES", "ALL_PLAYERS", "NONE"]
const ENEMY_INTENT_NAMES = ["ATTACK", "DEFEND", "BUFF", "DEBUFF", "UNKNOWN", "HACK"]

const STAT_NAMES = [
	"DAMAGE",
	"BLOCK",
	"HEALING",
	"MAX_HP",
	"MAX_ENERGY",
	"DRAW_PER_TURN",
	"ENERGY_COST",
	"CORRUPTION_GAIN",
	"CORRUPTION_RESIST",
]

const MOD_OP_NAMES = [
	"FLAT_ADD",
	"PERCENT_ADD",
	"PERCENT_MULT",
	"OVERRIDE",
]

const MOD_LIFECYCLE_NAMES = [
	"PERMANENT",
	"COMBAT",
	"TURN",
	"CARD_PLAY",
	"CONDITIONAL",
]

const CARD_TAG_NAMES = [
	"MELEE",
	"RANGED",
	"FIRE",
	"ICE",
	"HOLY",
	"SHADOW",
	"TECH",
	"EXPLOIT",
	"CURSE",
]

const EQUIP_SLOT_NAMES = ["HEAD", "CHEST", "WEAPON", "ACCESSORY"]
const RARITY_NAMES     = ["COMMON", "UNCOMMON", "RARE"]

# ---------------------------------------------------------------------------
# Output directory — navigate from project root up one level then into
# balance_dashboard/data/
# ---------------------------------------------------------------------------

func _get_output_dir() -> String:
	# ProjectSettings.globalize_path("res://") returns the card_game project dir,
	# e.g. "E:/godot_games/card_game". We go up one level to godot_games/, then
	# into balance_dashboard/data/.
	var project_dir: String = ProjectSettings.globalize_path("res://")
	# Trim trailing slash if present
	project_dir = project_dir.rstrip("/").rstrip("\\")
	var godot_games_dir: String = project_dir.get_base_dir()
	return godot_games_dir.path_join("balance_dashboard/data")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _enum_name(names: Array, index: int) -> String:
	if index >= 0 and index < names.size():
		return names[index]
	return "UNKNOWN_%d" % index

func _tags_to_strings(tag_ints: Array) -> Array:
	var result: Array = []
	for t in tag_ints:
		result.append(_enum_name(CARD_TAG_NAMES, t))
	return result

func _modifier_to_dict(mod: Resource) -> Dictionary:
	var d: Dictionary = {}
	d["id"]          = mod.id
	d["stat"]        = _enum_name(STAT_NAMES, mod.stat)
	d["operation"]   = _enum_name(MOD_OP_NAMES, mod.operation)
	d["value"]       = mod.value
	d["lifecycle"]   = _enum_name(MOD_LIFECYCLE_NAMES, mod.lifecycle)
	d["duration"]    = mod.duration

	# Conditions
	if mod.required_card_tags.size() > 0:
		d["required_card_tags"] = _tags_to_strings(mod.required_card_tags)
	else:
		d["required_card_tags"] = []

	d["required_card_type"]    = mod.required_card_type  # -1 = any
	d["only_vs_vulnerable"]    = mod.only_vs_vulnerable
	d["only_when_hp_below_pct"] = mod.only_when_hp_below_pct
	return d

func _write_json(output_dir: String, filename: String, data: Array) -> void:
	var path: String = output_dir.path_join(filename)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("export_balance_data: Failed to open '%s' for writing (error %d)" % [
			path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

# ---------------------------------------------------------------------------
# 1. cards.json
# ---------------------------------------------------------------------------

func _export_cards(output_dir: String) -> int:
	var cards: Array = []
	var files: PackedStringArray = DirAccess.get_files_at("res://data/cards")
	for fname in files:
		if not fname.ends_with(".tres"):
			continue
		var res = load("res://data/cards/" + fname)
		if res == null:
			push_warning("export_balance_data: Could not load res://data/cards/" + fname)
			continue

		var d: Dictionary = {}
		d["id"]               = res.id
		d["name"]             = res.display_name
		d["description"]      = res.description
		d["energy_cost"]      = res.energy_cost
		d["type"]             = _enum_name(CARD_TYPE_NAMES, res.card_type)
		d["target_type"]      = _enum_name(TARGET_TYPE_NAMES, res.target_type)
		d["damage"]           = res.damage
		d["block"]            = res.block
		d["heal"]             = res.heal
		d["draw"]             = res.draw
		d["hits"]             = res.hits
		d["apply_vulnerable"] = res.apply_vulnerable
		d["apply_weak"]       = res.apply_weak
		d["corruption_gain"]  = res.corruption_gain
		d["exhaust"]          = res.exhaust
		d["gain_strength"]    = res.gain_strength
		d["gain_dexterity"]   = res.gain_dexterity
		d["upgraded"]         = res.upgraded
		d["upgrade_id"]       = res.upgrade_id
		d["tags"]             = _tags_to_strings(res.tags)
		d["gem_sockets"]      = res.gem_sockets

		# Corruption data (passive and shrine)
		var has_passive_corruption: bool = CardCorruption.CORRUPTED_CARDS.has(res.id)
		var has_shrine_corruption: bool  = CardCorruption.SHRINE_CORRUPTED_CARDS.has(res.id)
		d["has_passive_corruption"] = has_passive_corruption
		d["has_shrine_corruption"]  = has_shrine_corruption

		if has_passive_corruption:
			d["passive_corruption"] = CardCorruption.CORRUPTED_CARDS[res.id].duplicate()
		else:
			d["passive_corruption"] = {}

		if has_shrine_corruption:
			d["shrine_corruption"] = CardCorruption.SHRINE_CORRUPTED_CARDS[res.id].duplicate()
		else:
			d["shrine_corruption"] = {}

		cards.append(d)

	cards.sort_custom(func(a, b): return a["id"] < b["id"])
	_write_json(output_dir, "cards.json", cards)
	return cards.size()

# ---------------------------------------------------------------------------
# 2. relics.json
# ---------------------------------------------------------------------------

func _export_relics(output_dir: String) -> int:
	var relics: Array = []
	var files: PackedStringArray = DirAccess.get_files_at("res://data/relics")
	for fname in files:
		if not fname.ends_with(".tres"):
			continue
		var res = load("res://data/relics/" + fname)
		if res == null:
			push_warning("export_balance_data: Could not load res://data/relics/" + fname)
			continue

		var d: Dictionary = {}
		d["id"]                    = res.id
		d["name"]                  = res.display_name
		d["description"]           = res.description
		d["rarity"]                = _enum_name(RARITY_NAMES, res.rarity)
		d["start_combat_strength"] = res.start_combat_strength
		d["start_combat_dexterity"] = res.start_combat_dexterity
		d["start_combat_block"]    = res.start_combat_block
		d["bonus_draw"]            = res.bonus_draw
		d["bonus_max_energy"]      = res.bonus_max_energy
		d["bonus_max_hp"]          = res.bonus_max_hp
		d["heal_on_combat_end"]    = res.heal_on_combat_end
		d["corruption_resistance"] = res.corruption_resistance
		relics.append(d)

	relics.sort_custom(func(a, b): return a["id"] < b["id"])
	_write_json(output_dir, "relics.json", relics)
	return relics.size()

# ---------------------------------------------------------------------------
# 3. equipment.json
# ---------------------------------------------------------------------------

func _export_equipment(output_dir: String) -> int:
	var equipment: Array = []
	var files: PackedStringArray = DirAccess.get_files_at("res://data/equipment")
	for fname in files:
		if not fname.ends_with(".tres"):
			continue
		var res = load("res://data/equipment/" + fname)
		if res == null:
			push_warning("export_balance_data: Could not load res://data/equipment/" + fname)
			continue

		var d: Dictionary = {}
		d["id"]          = res.id
		d["name"]        = res.display_name
		d["description"] = res.description
		d["slot"]        = _enum_name(EQUIP_SLOT_NAMES, res.slot)
		d["rarity"]      = _enum_name(RARITY_NAMES, res.rarity)

		var mods: Array = []
		for mod in res.modifiers:
			mods.append(_modifier_to_dict(mod))
		d["modifiers"] = mods

		equipment.append(d)

	equipment.sort_custom(func(a, b): return a["id"] < b["id"])
	_write_json(output_dir, "equipment.json", equipment)
	return equipment.size()

# ---------------------------------------------------------------------------
# 4. gems.json
# ---------------------------------------------------------------------------

func _export_gems(output_dir: String) -> int:
	var gems: Array = []
	var files: PackedStringArray = DirAccess.get_files_at("res://data/gems")
	for fname in files:
		if not fname.ends_with(".tres"):
			continue
		var res = load("res://data/gems/" + fname)
		if res == null:
			push_warning("export_balance_data: Could not load res://data/gems/" + fname)
			continue

		var d: Dictionary = {}
		d["id"]          = res.id
		d["name"]        = res.display_name
		d["description"] = res.description
		d["rarity"]      = _enum_name(RARITY_NAMES, res.rarity)

		var mods: Array = []
		for mod in res.on_play_modifiers:
			mods.append(_modifier_to_dict(mod))
		d["on_play_modifiers"] = mods

		gems.append(d)

	gems.sort_custom(func(a, b): return a["id"] < b["id"])
	_write_json(output_dir, "gems.json", gems)
	return gems.size()

# ---------------------------------------------------------------------------
# 5. skill_tree.json
# ---------------------------------------------------------------------------
# The warrior tree is defined programmatically in SkillTreeSystem. We
# reconstruct it here by mirroring the exact same node/spec data, using the
# same helper logic, so we stay in sync with the source of truth without
# having to call load_skill_trees() (which would require a RunState).

func _build_skill_tree_json() -> Array:
	# Each entry: {id, name, tier, cost, description, prerequisites, modifiers,
	#              position: {x, y}}
	var nodes: Array = []

	# Helper to build one expanded modifier dict from a spec dictionary.
	# Mirrors SkillTreeSystem._spec() / _node() logic exactly.
	var make_mod = func(spec: Dictionary) -> Dictionary:
		var stat_map := {
			"damage": "DAMAGE", "block": "BLOCK", "healing": "HEALING",
			"max_hp": "MAX_HP", "max_energy": "MAX_ENERGY",
			"draw_per_turn": "DRAW_PER_TURN", "energy_cost": "ENERGY_COST",
			"corruption_gain": "CORRUPTION_GAIN", "corruption_resist": "CORRUPTION_RESIST",
		}
		var op_map := {
			"flat_add": "FLAT_ADD", "percent_add": "PERCENT_ADD",
			"percent_mult": "PERCENT_MULT", "override": "OVERRIDE",
		}
		var tag_map := {
			"melee": "MELEE", "ranged": "RANGED", "fire": "FIRE",
			"ice": "ICE", "holy": "HOLY", "shadow": "SHADOW",
			"tech": "TECH", "exploit": "EXPLOIT", "curse": "CURSE",
		}
		var m: Dictionary = {}
		m["stat"]      = stat_map.get(spec.get("stat", "damage"), spec.get("stat", "damage").to_upper())
		m["operation"] = op_map.get(spec.get("op", "flat_add"), spec.get("op", "flat_add").to_upper())
		m["value"]     = spec.get("value", 0.0)
		m["lifecycle"] = "PERMANENT"
		var req_tags: Array = []
		for t in spec.get("req_tags", []):
			req_tags.append(tag_map.get(t, t.to_upper()))
		m["required_card_tags"]     = req_tags
		m["only_vs_vulnerable"]     = spec.get("vs_vuln", false)
		m["only_when_hp_below_pct"] = spec.get("hp_below", -1.0)
		return m

	var add_node = func(id: String, name: String, desc: String, tier: int, cost: int,
			prereqs: Array, specs: Array, pos_x: float, pos_y: float) -> void:
		var mods: Array = []
		for spec in specs:
			mods.append(make_mod.call(spec))
		nodes.append({
			"id": id, "name": name, "description": desc,
			"tier": tier, "cost": cost,
			"prerequisites": prereqs,
			"modifiers": mods,
			"position": {"x": pos_x, "y": pos_y},
		})

	# ------------------------------------------------------------------
	# Tier 0 — Starting nodes (no prerequisites, cost 1)
	# ------------------------------------------------------------------
	add_node.call("iron_fist", "Iron Fist", "+2 Damage",
		0, 1, [],
		[{"stat": "damage", "op": "flat_add", "value": 2.0, "req_tags": [], "vs_vuln": false, "hp_below": -1.0}],
		0.0, 0.0)

	add_node.call("thick_skin", "Thick Skin", "+3 Block",
		0, 1, [],
		[{"stat": "block", "op": "flat_add", "value": 3.0, "req_tags": [], "vs_vuln": false, "hp_below": -1.0}],
		1.0, 0.0)

	add_node.call("vitality", "Vitality", "+5 Max HP",
		0, 1, [],
		[{"stat": "max_hp", "op": "flat_add", "value": 5.0, "req_tags": [], "vs_vuln": false, "hp_below": -1.0}],
		2.0, 0.0)

	# ------------------------------------------------------------------
	# Tier 1 — Requires 1 tier-0 node, cost 1
	# ------------------------------------------------------------------
	add_node.call("weapon_mastery", "Weapon Mastery", "+10% Melee Damage",
		1, 1, ["iron_fist"],
		[{"stat": "damage", "op": "percent_add", "value": 0.1, "req_tags": ["melee"], "vs_vuln": false, "hp_below": -1.0}],
		0.0, 1.0)

	add_node.call("tech_affinity", "Tech Affinity", "+10% Tech Damage",
		1, 1, ["iron_fist"],
		[{"stat": "damage", "op": "percent_add", "value": 0.1, "req_tags": ["tech"], "vs_vuln": false, "hp_below": -1.0}],
		1.0, 1.0)

	add_node.call("resilience", "Resilience", "+1 Energy per Turn",
		1, 1, ["thick_skin"],
		[{"stat": "max_energy", "op": "flat_add", "value": 1.0, "req_tags": [], "vs_vuln": false, "hp_below": -1.0}],
		2.0, 1.0)

	add_node.call("inner_fire", "Inner Fire", "+15% Fire Damage",
		1, 1, ["vitality"],
		[{"stat": "damage", "op": "percent_add", "value": 0.15, "req_tags": ["fire"], "vs_vuln": false, "hp_below": -1.0}],
		3.0, 1.0)

	# ------------------------------------------------------------------
	# Tier 2 — Requires 2 tier-1 nodes, cost 2
	# ------------------------------------------------------------------
	add_node.call("berserker", "Berserker", "+25% Damage below 50% HP",
		2, 2, ["weapon_mastery", "tech_affinity"],
		[{"stat": "damage", "op": "percent_add", "value": 0.25, "req_tags": [], "vs_vuln": false, "hp_below": 0.5}],
		0.0, 2.0)

	add_node.call("fortress", "Fortress", "+20% Block",
		2, 2, ["resilience", "thick_skin"],
		[{"stat": "block", "op": "percent_add", "value": 0.2, "req_tags": [], "vs_vuln": false, "hp_below": -1.0}],
		1.0, 2.0)

	add_node.call("shadow_arts", "Shadow Arts", "+4 Damage vs Vulnerable",
		2, 2, ["weapon_mastery", "resilience"],
		[{"stat": "damage", "op": "flat_add", "value": 4.0, "req_tags": [], "vs_vuln": true, "hp_below": -1.0}],
		2.0, 2.0)

	add_node.call("divine_healing", "Divine Healing", "+30% Healing",
		2, 2, ["vitality", "inner_fire"],
		[{"stat": "healing", "op": "percent_add", "value": 0.3, "req_tags": [], "vs_vuln": false, "hp_below": -1.0}],
		3.0, 2.0)

	# ------------------------------------------------------------------
	# Tier 3 — Capstone nodes, requires 2 tier-2 nodes, cost 3
	# ------------------------------------------------------------------
	add_node.call("warlord", "Warlord", "x1.2 All Damage",
		3, 3, ["berserker", "shadow_arts"],
		[{"stat": "damage", "op": "percent_mult", "value": 1.2, "req_tags": [], "vs_vuln": false, "hp_below": -1.0}],
		1.0, 3.0)

	add_node.call("immortal", "Immortal", "+15 Max HP, +10% Block",
		3, 3, ["fortress", "divine_healing"],
		[
			{"stat": "max_hp",  "op": "flat_add",    "value": 15.0, "req_tags": [], "vs_vuln": false, "hp_below": -1.0},
			{"stat": "block",   "op": "percent_add", "value": 0.1,  "req_tags": [], "vs_vuln": false, "hp_below": -1.0},
		],
		2.0, 3.0)

	return nodes

func _export_skill_tree(output_dir: String) -> int:
	var trees: Array = []
	var warrior_nodes := _build_skill_tree_json()
	trees.append({
		"id": "warrior",
		"display_name": "Warrior",
		"nodes": warrior_nodes,
	})
	_write_json(output_dir, "skill_tree.json", trees)
	return warrior_nodes.size()

# ---------------------------------------------------------------------------
# 6. enemies.json
# ---------------------------------------------------------------------------

func _export_enemies(output_dir: String) -> int:
	var enemies: Array = []
	var files: PackedStringArray = DirAccess.get_files_at("res://data/enemies")
	for fname in files:
		if not fname.ends_with(".tres"):
			continue
		var res = load("res://data/enemies/" + fname)
		if res == null:
			push_warning("export_balance_data: Could not load res://data/enemies/" + fname)
			continue

		var d: Dictionary = {}
		d["id"]      = res.id
		d["name"]    = res.display_name
		d["max_hp"]  = res.max_hp

		# intent_pool is an Array of Dictionaries with "type" (int) and "value" (int)
		var intents: Array = []
		for intent in res.intent_pool:
			var i: Dictionary = {}
			i["type"]  = _enum_name(ENEMY_INTENT_NAMES, intent.get("type", 0))
			i["value"] = intent.get("value", 0)
			# Copy any extra keys the intent dict may have (e.g. block on DEFEND)
			for key in intent.keys():
				if key != "type" and key != "value":
					i[key] = intent[key]
			intents.append(i)
		d["intent_pool"] = intents

		enemies.append(d)

	enemies.sort_custom(func(a, b): return a["id"] < b["id"])
	_write_json(output_dir, "enemies.json", enemies)
	return enemies.size()

# ---------------------------------------------------------------------------
# 7. corruption.json
# ---------------------------------------------------------------------------

func _export_corruption(output_dir: String) -> int:
	var passive_entries: Array = []
	for card_id in CardCorruption.CORRUPTED_CARDS.keys():
		var entry: Dictionary = CardCorruption.CORRUPTED_CARDS[card_id].duplicate()
		entry["card_id"] = card_id
		entry["corruption_type"] = "PASSIVE"
		passive_entries.append(entry)

	var shrine_entries: Array = []
	for card_id in CardCorruption.SHRINE_CORRUPTED_CARDS.keys():
		var raw: Dictionary = CardCorruption.SHRINE_CORRUPTED_CARDS[card_id]
		var entry: Dictionary = {}
		entry["card_id"]         = card_id
		entry["corruption_type"] = "SHRINE"
		entry["display_name"]    = raw.get("display_name", "")
		entry["description"]     = raw.get("description", "")
		entry["preview"]         = raw.get("preview", "")
		entry["upgrades"]        = raw.get("upgrades", {}).duplicate()
		entry["drawbacks"]       = raw.get("drawbacks", {}).duplicate()
		shrine_entries.append(entry)

	# Sort for stable output
	passive_entries.sort_custom(func(a, b): return a["card_id"] < b["card_id"])
	shrine_entries.sort_custom(func(a, b): return a["card_id"] < b["card_id"])

	var all_corruption: Array = passive_entries + shrine_entries
	_write_json(output_dir, "corruption.json", all_corruption)
	return all_corruption.size()

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

func _run() -> void:
	var output_dir: String = _get_output_dir()
	print("export_balance_data: Output directory -> ", output_dir)

	# Ensure the directory exists
	if not DirAccess.dir_exists_absolute(output_dir):
		var err := DirAccess.make_dir_recursive_absolute(output_dir)
		if err != OK:
			push_error("export_balance_data: Failed to create output directory '%s' (error %d)" % [
				output_dir, err])
			return
		print("export_balance_data: Created output directory.")

	var card_count      := _export_cards(output_dir)
	var relic_count     := _export_relics(output_dir)
	var equipment_count := _export_equipment(output_dir)
	var gem_count       := _export_gems(output_dir)
	var skill_count     := _export_skill_tree(output_dir)
	var enemy_count     := _export_enemies(output_dir)
	var corruption_count := _export_corruption(output_dir)

	print("export_balance_data: Export complete.")
	print("  Exported %d cards      -> cards.json"       % card_count)
	print("  Exported %d relics     -> relics.json"      % relic_count)
	print("  Exported %d equipment  -> equipment.json"   % equipment_count)
	print("  Exported %d gems       -> gems.json"        % gem_count)
	print("  Exported %d skill nodes (warrior tree) -> skill_tree.json" % skill_count)
	print("  Exported %d enemies    -> enemies.json"     % enemy_count)
	print("  Exported %d corruption entries -> corruption.json" % corruption_count)
	print("  Output path: ", output_dir)
