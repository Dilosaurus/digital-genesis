class_name SinSystem
extends RefCounted

const SIN_THRESHOLD = 7

# Add sin based on card type played. Returns the sin type that triggered punishment, or -1
static func add_sin_for_card(ps: PlayerState, card_data) -> int:
	if card_data.card_type == Enums.CardType.ATTACK:
		ps.sin_wrath += 1
		if ps.sin_wrath >= SIN_THRESHOLD:
			ps.sin_wrath = 0
			return Enums.SinType.WRATH
	elif card_data.card_type == Enums.CardType.SKILL:
		# Check if it's a defense card (has block) or heal card
		if card_data.heal > 0:
			ps.sin_pride += 1
			if ps.sin_pride >= SIN_THRESHOLD:
				ps.sin_pride = 0
				return Enums.SinType.PRIDE
		elif card_data.block > 0:
			ps.sin_sloth += 1
			if ps.sin_sloth >= SIN_THRESHOLD:
				ps.sin_sloth = 0
				return Enums.SinType.SLOTH
	return -1

# Apply punishment for a triggered sin. Returns a description of what happened.
static func apply_punishment(ps: PlayerState, sin_type: int, enemies: Array) -> Dictionary:
	var result = {"type": sin_type, "description": "", "damage": 0, "cards_lost": 0, "heal_reduction": 0}
	match sin_type:
		Enums.SinType.WRATH:
			# Wrath: take damage equal to 50% of damage dealt this turn (approximated as flat 8)
			var self_dmg = 8
			ps.current_hp = maxi(ps.current_hp - self_dmg, 0)
			result["damage"] = self_dmg
			result["description"] = "WRATH — Divine retribution! Take %d damage." % self_dmg
		Enums.SinType.SLOTH:
			# Sloth: draw 2 fewer cards next turn (tracked via flag)
			ps.draw_penalty = 2
			result["cards_lost"] = 2
			result["description"] = "SLOTH — Heavenly lethargy! Draw 2 fewer cards next turn."
		Enums.SinType.PRIDE:
			# Pride: all healing halved for 2 turns (via modifier stack)
			var mod = ModifierData.new()
			mod.stat = Enums.Stat.HEALING
			mod.operation = Enums.ModOp.PERCENT_MULT
			mod.value = 0.5
			mod.lifecycle = Enums.ModLifecycle.TURN
			mod.duration = 2
			mod.source_type = "sin"
			mod.source_id = "pride"
			ps.modifier_stack.add(mod)
			result["heal_reduction"] = 50
			result["description"] = "PRIDE — Angels mock your hubris! Healing halved for 2 turns."
	return result

# Tick down sin penalties at start of turn
# Note: pride_penalty healing reduction is now handled via modifier stack (TURN lifecycle).
static func tick_penalties(ps: PlayerState) -> void:
	if ps.draw_penalty > 0:
		ps.draw_penalty = 0  # One-turn effect, reset after applied
