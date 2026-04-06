class_name StatResolverTrace
extends RefCounted

# Mirrors StatResolver resolution logic step-by-step and returns a full breakdown
# dictionary at each phase. Useful for the Balance Dashboard "Pipeline" tab.
#
# All three entry points share the same private _trace() core; only the stat
# being resolved and the adjusted-base calculation differ.


## Trace damage resolution for one hit.
## Returns:
##   base              : int    — raw card damage value
##   strength_add      : int    — player.strength contribution
##   adjusted_base     : int    — base + strength_add (clamped to 0)
##   flat_adds         : Array  — [{source_type, source_id, value}]
##   pct_adds          : Array  — [{source_type, source_id, value}]
##   pct_mults         : Array  — [{source_type, source_id, value}]
##   overrides         : Array  — [{source_type, source_id, value}]
##   after_flat        : float  — adjusted_base + sum(flat_adds)
##   after_pct_add     : float  — after_flat * (1 + sum(pct_adds))
##   after_pct_mult    : float  — result of all PERCENT_MULT applications
##   vuln_applied      : bool
##   weak_applied      : bool
##   after_vuln_weak   : float
##   final             : int
static func trace_damage(
		base_damage: int,
		player: PlayerState,
		target,
		card_data: CardData) -> Dictionary:

	var adjusted_base := base_damage + player.strength
	var ctx := StatResolver._build_card_context(player, target, card_data)

	var trace := _trace(Enums.Stat.DAMAGE, adjusted_base, player, ctx)
	trace["base"]          = base_damage
	trace["strength_add"]  = player.strength
	trace["adjusted_base"] = adjusted_base

	# Post-stack status modifiers
	var vuln: bool = target != null and target.vulnerable > 0
	var weak: bool = player.weak > 0
	trace["vuln_applied"] = vuln
	trace["weak_applied"] = weak

	var after_stack: float = trace["after_pct_mult"]
	var post := after_stack
	if vuln:
		post *= 1.5
	if weak:
		post *= 0.75
	trace["after_vuln_weak"] = post
	trace["final"]           = int(post) if adjusted_base > 0 else 0

	return trace


## Trace block resolution.
## Returns the same fields as trace_damage minus vuln/weak columns.
static func trace_block(
		base_block: int,
		player: PlayerState,
		card_data: CardData) -> Dictionary:

	var adjusted_base := base_block + player.dexterity
	var ctx := StatResolver._build_card_context(player, null, card_data)

	var trace := _trace(Enums.Stat.BLOCK, adjusted_base, player, ctx)
	trace["base"]          = base_block
	trace["dexterity_add"] = player.dexterity
	trace["adjusted_base"] = adjusted_base
	trace["vuln_applied"]  = false
	trace["weak_applied"]  = false
	trace["after_vuln_weak"] = trace["after_pct_mult"]
	trace["final"]         = int(trace["after_pct_mult"]) if adjusted_base > 0 else 0

	return trace


## Trace healing resolution.
static func trace_healing(
		base_heal: int,
		player: PlayerState,
		card_data: CardData) -> Dictionary:

	var ctx := StatResolver._build_card_context(player, null, card_data)

	var trace := _trace(Enums.Stat.HEALING, base_heal, player, ctx)
	trace["base"]          = base_heal
	trace["adjusted_base"] = base_heal
	trace["vuln_applied"]  = false
	trace["weak_applied"]  = false
	trace["after_vuln_weak"] = trace["after_pct_mult"]
	trace["final"]         = int(trace["after_pct_mult"]) if base_heal > 0 else 0

	return trace


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

## Core trace logic — mirrors ModifierStack.resolve() but records each step.
static func _trace(
		stat: Enums.Stat,
		adjusted_base: int,
		player: PlayerState,
		ctx: Dictionary) -> Dictionary:

	var result := {
		"flat_adds":    [],
		"pct_adds":     [],
		"pct_mults":    [],
		"overrides":    [],
		"after_flat":        float(adjusted_base),
		"after_pct_add":     float(adjusted_base),
		"after_pct_mult":    float(adjusted_base),
	}

	if adjusted_base <= 0:
		return result

	# Gather active modifiers from the modifier stack
	var active: Array[ModifierData] = player.modifier_stack._get_active_for_stat(stat, ctx)

	if active.is_empty():
		return result

	# --- Phase 1: OVERRIDE ---
	var has_override := false
	var override_value := 0.0
	for mod in active:
		if mod.operation == Enums.ModOp.OVERRIDE:
			result["overrides"].append(_mod_entry(mod))
			if not has_override or mod.value > override_value:
				override_value = mod.value
				has_override = true

	if has_override:
		result["after_flat"]     = override_value
		result["after_pct_add"]  = override_value
		result["after_pct_mult"] = override_value
		return result

	# --- Phase 2: FLAT_ADD ---
	var flat_total: float = float(adjusted_base)
	for mod in active:
		if mod.operation == Enums.ModOp.FLAT_ADD:
			result["flat_adds"].append(_mod_entry(mod))
			flat_total += mod.value
	result["after_flat"] = flat_total

	# --- Phase 3: PERCENT_ADD ---
	var pct_add_sum := 0.0
	for mod in active:
		if mod.operation == Enums.ModOp.PERCENT_ADD:
			result["pct_adds"].append(_mod_entry(mod))
			pct_add_sum += mod.value
	var after_pct_add := flat_total * (1.0 + pct_add_sum)
	result["after_pct_add"] = after_pct_add

	# --- Phase 4: PERCENT_MULT ---
	var final_value := after_pct_add
	for mod in active:
		if mod.operation == Enums.ModOp.PERCENT_MULT:
			result["pct_mults"].append(_mod_entry(mod))
			final_value *= mod.value
	result["after_pct_mult"] = final_value

	return result


static func _mod_entry(mod: ModifierData) -> Dictionary:
	return {
		"source_type": mod.source_type,
		"source_id":   mod.source_id,
		"value":       mod.value,
		"operation":   mod.operation,
		"lifecycle":   mod.lifecycle,
	}
