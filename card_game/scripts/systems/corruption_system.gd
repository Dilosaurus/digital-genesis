class_name CorruptionSystem
extends RefCounted

# Corruption thresholds for tier changes
const TIER_THRESHOLDS = [0, 25, 50, 75]

# Add corruption to a player, returns the new tier if it changed.
# Corruption resistance from modifiers (relics, equipment) reduces the gain.
static func add_corruption(ps: PlayerState, amount: int) -> int:
	var old_tier = ps.corruption_tier
	var resistance = int(ps.modifier_stack.resolve(Enums.Stat.CORRUPTION_RESIST, 0.0))
	var effective = maxi(amount - resistance, 0)
	ps.corruption += effective
	ps.corruption = clampi(ps.corruption, 0, ps.max_corruption)
	ps.corruption_tier = _calculate_tier(ps.corruption)
	return ps.corruption_tier if ps.corruption_tier != old_tier else -1

static func remove_corruption(ps: PlayerState, amount: int) -> void:
	ps.corruption -= amount
	ps.corruption = clampi(ps.corruption, 0, ps.max_corruption)
	ps.corruption_tier = _calculate_tier(ps.corruption)

static func _calculate_tier(corruption: int) -> int:
	if corruption >= 75:
		return 3  # Demonic
	elif corruption >= 50:
		return 2  # Corrupted
	elif corruption >= 25:
		return 1  # Tainted
	return 0  # Pure

# Get damage multiplier based on corruption tier
static func get_damage_multiplier(ps: PlayerState) -> float:
	match ps.corruption_tier:
		1: return 1.1   # Tainted: +10% damage
		2: return 1.25  # Corrupted: +25% damage
		3: return 1.5   # Demonic: +50% damage
		_: return 1.0   # Pure: normal

# Get self-damage per turn at high corruption
static func get_corruption_burn(ps: PlayerState) -> int:
	match ps.corruption_tier:
		2: return 2   # Corrupted: 2 HP/turn
		3: return 5   # Demonic: 5 HP/turn
		_: return 0

# Card corruption gain - base amount from card data plus bonus for expensive cards.
# Negative values (e.g. White Hat purge cards) remove corruption.
static func get_card_corruption(card_data) -> int:
	var base: int = card_data.corruption_gain
	if base < 0:
		return base  # Corruption removal — pass through as-is
	if base == 0:
		# Powerful cards (2+ energy, 10+ damage) always generate some corruption
		if card_data.energy_cost >= 2:
			base = 1
		elif card_data.damage >= 10:
			base = 1
	return base
