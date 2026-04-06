class_name ModifierStack
extends RefCounted

var _modifiers: Array[ModifierData] = []

# --- Adding / Removing ---

func add(mod: ModifierData) -> void:
	_modifiers.append(mod)

func remove(mod: ModifierData) -> void:
	_modifiers.erase(mod)

func remove_by_source(p_source_type: String, p_source_id: String = "") -> void:
	var filtered := _modifiers.filter(func(m: ModifierData) -> bool:
		if m.source_type != p_source_type:
			return true
		if p_source_id != "" and m.source_id != p_source_id:
			return true
		return false
	)
	_modifiers.clear()
	_modifiers.assign(filtered)

func remove_by_lifecycle(lifecycle: Enums.ModLifecycle) -> void:
	var filtered := _modifiers.filter(func(m: ModifierData) -> bool:
		return m.lifecycle != lifecycle
	)
	_modifiers.clear()
	_modifiers.assign(filtered)

func get_all() -> Array[ModifierData]:
	return _modifiers

func clear() -> void:
	_modifiers.clear()

# --- Resolution ---
# Resolves a stat to its final value.
# context dict (all optional):
#   card_tags: Array[int], card_type: int,
#   target_vulnerable: bool, player_hp_pct: float

func resolve(stat: Enums.Stat, base_value: float, context: Dictionary = {}) -> float:
	var active := _get_active_for_stat(stat, context)
	if active.is_empty():
		return base_value

	# Phase 1: OVERRIDE — highest value wins
	var has_override := false
	var override_value := 0.0
	for mod in active:
		if mod.operation == Enums.ModOp.OVERRIDE:
			if not has_override or mod.value > override_value:
				override_value = mod.value
				has_override = true
	if has_override:
		return override_value

	# Phase 2: FLAT_ADD
	var flat_total := base_value
	for mod in active:
		if mod.operation == Enums.ModOp.FLAT_ADD:
			flat_total += mod.value

	# Phase 3: PERCENT_ADD — all stack additively, then one multiply
	var pct_add_sum := 0.0
	for mod in active:
		if mod.operation == Enums.ModOp.PERCENT_ADD:
			pct_add_sum += mod.value
	var after_pct_add := flat_total * (1.0 + pct_add_sum)

	# Phase 4: PERCENT_MULT — each multiplies independently
	var result := after_pct_add
	for mod in active:
		if mod.operation == Enums.ModOp.PERCENT_MULT:
			result *= mod.value

	return result

func _get_active_for_stat(stat: Enums.Stat, context: Dictionary) -> Array[ModifierData]:
	var result: Array[ModifierData] = []
	for mod in _modifiers:
		if mod.stat != stat:
			continue
		if not _check_conditions(mod, context):
			continue
		result.append(mod)
	return result

func _check_conditions(mod: ModifierData, ctx: Dictionary) -> bool:
	if mod.required_card_tags.size() > 0:
		var card_tags: Array = ctx.get("card_tags", [])
		for required_tag in mod.required_card_tags:
			if required_tag not in card_tags:
				return false
	if mod.required_card_type >= 0:
		if ctx.get("card_type", -1) != mod.required_card_type:
			return false
	if mod.only_vs_vulnerable:
		if not ctx.get("target_vulnerable", false):
			return false
	if mod.only_when_hp_below_pct >= 0.0:
		var hp_pct: float = ctx.get("player_hp_pct", 1.0)
		if hp_pct > mod.only_when_hp_below_pct:
			return false
	return true

# --- Lifecycle ---

func tick_turn() -> void:
	var to_remove: Array[ModifierData] = []
	for mod in _modifiers:
		if mod.lifecycle == Enums.ModLifecycle.TURN and mod.duration > 0:
			mod.duration -= 1
			if mod.duration <= 0:
				to_remove.append(mod)
	for mod in to_remove:
		_modifiers.erase(mod)
