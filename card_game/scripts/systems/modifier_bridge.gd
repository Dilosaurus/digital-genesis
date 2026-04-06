class_name ModifierBridge
extends RefCounted

# Populates a player's modifier stack at combat start from all persistent sources.
static func populate_combat_start(player: PlayerState, run: RunState) -> void:
	# Clear stale combat/turn modifiers from any previous fight
	player.modifier_stack.remove_by_lifecycle(Enums.ModLifecycle.COMBAT)
	player.modifier_stack.remove_by_lifecycle(Enums.ModLifecycle.TURN)
	player.modifier_stack.remove_by_lifecycle(Enums.ModLifecycle.CARD_PLAY)

	# Equipment modifiers (re-applied each combat for clean state)
	player.modifier_stack.remove_by_source("equipment")
	for slot in run.equipment:
		var equip_id: String = run.equipment[slot]
		if equip_id == "":
			continue
		var equip_data = EquipmentSystem.get_equipment(equip_id)
		if not equip_data:
			continue
		for mod in equip_data.modifiers:
			player.modifier_stack.add(mod.stamped("equipment", equip_id))

	# Relic modifiers — strength/dexterity become COMBAT modifiers instead of
	# mutating PlayerState fields directly. Block and energy are one-time effects.
	player.modifier_stack.remove_by_source("relic")
	for rid in run.relics:
		var r = RelicSystem.get_relic(rid)
		if not r:
			continue
		if r.start_combat_strength > 0:
			player.modifier_stack.add(_create_mod(
				Enums.Stat.DAMAGE, Enums.ModOp.FLAT_ADD,
				r.start_combat_strength, Enums.ModLifecycle.COMBAT,
				"relic", rid))
		if r.start_combat_dexterity > 0:
			player.modifier_stack.add(_create_mod(
				Enums.Stat.BLOCK, Enums.ModOp.FLAT_ADD,
				r.start_combat_dexterity, Enums.ModLifecycle.COMBAT,
				"relic", rid))
		if r.bonus_draw > 0:
			player.modifier_stack.add(_create_mod(
				Enums.Stat.DRAW_PER_TURN, Enums.ModOp.FLAT_ADD,
				r.bonus_draw, Enums.ModLifecycle.COMBAT,
				"relic", rid))
		if r.corruption_resistance > 0:
			player.modifier_stack.add(_create_mod(
				Enums.Stat.CORRUPTION_RESIST, Enums.ModOp.FLAT_ADD,
				r.corruption_resistance, Enums.ModLifecycle.COMBAT,
				"relic", rid))
		# Block and energy are immediate effects, not modifiers
		if r.start_combat_block > 0:
			player.block += r.start_combat_block
		if r.bonus_max_energy > 0:
			player.max_energy += r.bonus_max_energy
			player.energy += r.bonus_max_energy

	# Corruption tier → damage multiplier
	var corruption_mult := _get_corruption_mult(player.corruption_tier)
	if corruption_mult > 0.0:
		player.modifier_stack.add(_create_mod(
			Enums.Stat.DAMAGE, Enums.ModOp.PERCENT_MULT,
			corruption_mult, Enums.ModLifecycle.COMBAT,
			"corruption", "tier_%d" % player.corruption_tier))

	# Skill tree modifiers (PERMANENT lifecycle — all conditions handled by stack)
	player.modifier_stack.remove_by_source("skill_tree")
	var skill_mods = SkillTreeSystem.get_all_modifiers(run)
	for mod in skill_mods:
		player.modifier_stack.add(mod)

# Called at start of each player turn to tick down duration-based modifiers.
static func tick_turn(player: PlayerState) -> void:
	player.modifier_stack.tick_turn()

# --- Helpers ---

static func _create_mod(stat: Enums.Stat, op: Enums.ModOp, value: float,
		lifecycle: Enums.ModLifecycle, source_type: String, source_id: String) -> ModifierData:
	var mod = ModifierData.new()
	mod.stat = stat
	mod.operation = op
	mod.value = value
	mod.lifecycle = lifecycle
	mod.source_type = source_type
	mod.source_id = source_id
	return mod

static func _get_corruption_mult(tier: int) -> float:
	match tier:
		1: return 1.1
		2: return 1.25
		3: return 1.5
		_: return 0.0  # No modifier for tier 0 (pure)
