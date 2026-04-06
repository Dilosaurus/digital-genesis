class_name StatResolver
extends RefCounted

static func resolve_damage(base_damage: int, player: PlayerState,
		target, card_data: CardData) -> int:
	# Mid-combat strength (from gain_strength card effects) adds to base
	var adjusted_base := base_damage + player.strength
	if adjusted_base <= 0:
		return 0
	var ctx := _build_card_context(player, target, card_data)
	var result := player.modifier_stack.resolve(Enums.Stat.DAMAGE, float(adjusted_base), ctx)
	# Cryptomancer passive: +25% damage when corruption >= 50
	if player.character_id == "cryptomancer" and player.corruption >= 50:
		result *= 1.25
	# Post-stack status effects (not in modifier stack — they're per-entity counters)
	if target and target.vulnerable > 0:
		result *= 1.5
	if player.weak > 0:
		result *= 0.75
	return int(result)

static func resolve_block(base_block: int, player: PlayerState,
		card_data: CardData) -> int:
	# Mid-combat dexterity (from gain_dexterity card effects) adds to base
	var adjusted_base := base_block + player.dexterity
	if adjusted_base <= 0:
		return 0
	var ctx := _build_card_context(player, null, card_data)
	var result := player.modifier_stack.resolve(Enums.Stat.BLOCK, float(adjusted_base), ctx)
	return int(result)

static func resolve_healing(base_heal: int, player: PlayerState,
		card_data: CardData) -> int:
	if base_heal <= 0:
		return 0
	var ctx := _build_card_context(player, null, card_data)
	# Sin pride penalty is now a PERCENT_MULT 0.5 in the modifier stack
	var result := player.modifier_stack.resolve(Enums.Stat.HEALING, float(base_heal), ctx)
	return int(result)

static func resolve_stat(stat: Enums.Stat, base: float, player: PlayerState) -> float:
	return player.modifier_stack.resolve(stat, base)

static func _build_card_context(player: PlayerState, target,
		card_data: CardData) -> Dictionary:
	var ctx := {}
	if card_data:
		ctx["card_type"] = card_data.card_type
		ctx["card_tags"] = card_data.tags
	else:
		ctx["card_type"] = -1
		ctx["card_tags"] = []
	ctx["target_vulnerable"] = target.vulnerable > 0 if target else false
	ctx["player_hp_pct"] = float(player.current_hp) / float(player.max_hp) if player.max_hp > 0 else 1.0
	return ctx
