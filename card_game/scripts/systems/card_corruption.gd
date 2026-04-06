class_name CardCorruption
extends RefCounted

# Maps base card ID -> corrupted display info
# At corruption tier 2+, cards transform visually and mechanically
const CORRUPTED_CARDS = {
	"strike": {
		"display_name": "Hellfire Strike",
		"description": "Deal 9 damage. Take 2 damage.",
		"damage": 9,
		"self_damage": 2,
	},
	"defend": {
		"display_name": "Bone Wall",
		"description": "Gain 8 Block. +3 corruption.",
		"block": 8,
		"extra_corruption": 3,
	},
	"bash": {
		"display_name": "Wrath Hammer",
		"description": "Deal 14 damage. Apply 3 Vulnerable. Take 4 damage.",
		"damage": 14,
		"apply_vulnerable": 3,
		"self_damage": 4,
	},
	"twin_strike": {
		"display_name": "Shadow Fork",
		"description": "Deal 7 damage three times. +2 corruption.",
		"damage": 7,
		"hits": 3,
		"extra_corruption": 2,
	},
	"iron_wave": {
		"display_name": "Blood Surge",
		"description": "Deal 8 damage. Gain 8 Block. Take 3 damage.",
		"damage": 8,
		"block": 8,
		"self_damage": 3,
	},
	"heavy_blade": {
		"display_name": "Doom Blade",
		"description": "Deal 22 damage. +5 corruption.",
		"damage": 22,
		"extra_corruption": 5,
	},
	"bandage": {
		"display_name": "Dark Mending",
		"description": "Heal 8 HP. +4 corruption.",
		"heal": 8,
		"extra_corruption": 4,
	},
	"uppercut": {
		"display_name": "Abyssal Strike",
		"description": "Deal 18 damage. Apply 2 Weak. Take 3 damage.",
		"damage": 18,
		"apply_weak": 2,
		"self_damage": 3,
	},
}

# Shrine corruption variants — deliberate permanent upgrades with drawbacks.
# Each entry: {"display_name", "description", "upgrades": {field: value, ...}, "drawbacks": {field: value, ...}}
# upgrades and drawbacks together represent the full card_data field overrides when shrine-corrupted.
const SHRINE_CORRUPTED_CARDS = {
	# ── Attack cards ─────────────────────────────────────────────────────────
	"strike": {
		"display_name": "Hellstrike",
		"description": "Deal 12 damage. Take 2 damage.",
		"upgrades": {"damage": 12},
		"drawbacks": {"self_damage": 2},
		"preview": "+4 damage. Take 2 self-damage.",
	},
	"bash": {
		"display_name": "Demonic Bash",
		"description": "Deal 16 damage. Apply 3 Vulnerable. Costs 3 energy.",
		"upgrades": {"damage": 16, "apply_vulnerable": 3},
		"drawbacks": {"energy_cost": 3},
		"preview": "+6 damage, +1 Vulnerable. Costs 1 more energy.",
	},
	"pommel_strike": {
		"display_name": "Skull Crusher",
		"description": "Deal 14 damage. Draw 2 cards. Generates 3 corruption.",
		"upgrades": {"damage": 14, "draw": 2},
		"drawbacks": {"corruption_gain": 3},
		"preview": "+5 damage, draws 2 cards. Generates 3 corruption on play.",
	},
	"iron_wave": {
		"display_name": "Blood Wave",
		"description": "Deal 10 damage. Gain 10 Block. Take 3 damage.",
		"upgrades": {"damage": 10, "block": 10},
		"drawbacks": {"self_damage": 3},
		"preview": "+4 damage, +4 block. Take 3 self-damage.",
	},
	"cleave": {
		"display_name": "Hellfire Cleave",
		"description": "Deal 14 damage to ALL enemies. Take 4 damage.",
		"upgrades": {"damage": 14},
		"drawbacks": {"self_damage": 4},
		"preview": "+6 damage to all enemies. Take 4 self-damage.",
	},
	"heavy_strike": {
		"display_name": "Annihilator",
		"description": "Deal 22 damage. Exhaust.",
		"upgrades": {"damage": 22},
		"drawbacks": {"exhaust": true},
		"preview": "+8 damage. Exhausts after play (single use).",
	},
	"body_slam": {
		"display_name": "Demonic Slam",
		"description": "Deal damage equal to Block x1.5. Apply 1 Weak. Lose 5 Block after.",
		"upgrades": {"apply_weak": 1},
		"drawbacks": {"block": -5},
		"preview": "Damage x1.5 of current Block, +1 Weak. Lose 5 Block after.",
	},
	# ── Skill cards ───────────────────────────────────────────────────────────
	"defend": {
		"display_name": "Dark Barrier",
		"description": "Gain 9 Block. +2 corruption.",
		"upgrades": {"block": 9},
		"drawbacks": {"corruption_gain": 2},
		"preview": "+4 block. Generates 2 corruption on play.",
	},
	"shrug_it_off": {
		"display_name": "Unholy Resilience",
		"description": "Gain 13 Block. Draw 2 cards. +3 corruption.",
		"upgrades": {"block": 13, "draw": 2},
		"drawbacks": {"corruption_gain": 3},
		"preview": "+5 block, draws 2 cards. Generates 3 corruption on play.",
	},
	"true_grit": {
		"display_name": "Soul Armor",
		"description": "Gain 12 Block. Exhaust a random card from hand.",
		"upgrades": {"block": 12},
		"drawbacks": {"exhaust_random": true},
		"preview": "+5 block. Exhausts a random card from hand on play.",
	},
	"battle_trance": {
		"display_name": "Blood Trance",
		"description": "Draw 5 cards. Costs 1 energy. Take 3 damage.",
		"upgrades": {"draw": 5},
		"drawbacks": {"energy_cost": 1, "self_damage": 3},
		"preview": "Draws 5 cards instead of 3. Costs 1 energy. Take 3 self-damage.",
	},
	# ── Power cards ───────────────────────────────────────────────────────────
	"inflame": {
		"display_name": "Hellfire Infusion",
		"description": "Gain 4 Strength. +8 corruption.",
		"upgrades": {"gain_strength": 4},
		"drawbacks": {"corruption_gain": 8},
		"preview": "+2 Strength. Generates 8 corruption on play.",
	},
	"metallicize": {
		"display_name": "Demonic Plates",
		"description": "At end of turn, gain 7 Block. Take 1 damage at end of turn.",
		"upgrades": {"block": 7},
		"drawbacks": {"self_damage": 1},
		"preview": "+3 block per turn. Take 1 self-damage each turn.",
	},
}

# ---------------------------------------------------------------------------
# Passive corruption (tier-based)
# ---------------------------------------------------------------------------

# Check if a card should be corrupted based on player's corruption tier
static func should_corrupt(card_id: String, corruption_tier: int) -> bool:
	return corruption_tier >= 2 and CORRUPTED_CARDS.has(card_id)

# Get the corrupted version's overrides for a card
static func get_corrupted_overrides(card_id: String) -> Dictionary:
	return CORRUPTED_CARDS.get(card_id, {})

# Get display name for a card considering corruption
static func get_display_name(card_id: String, corruption_tier: int) -> String:
	if should_corrupt(card_id, corruption_tier):
		return CORRUPTED_CARDS[card_id].get("display_name", card_id)
	return ""  # Empty = use default

# Get description for a card considering corruption
static func get_description(card_id: String, corruption_tier: int) -> String:
	if should_corrupt(card_id, corruption_tier):
		return CORRUPTED_CARDS[card_id].get("description", "")
	return ""

# ---------------------------------------------------------------------------
# Shrine corruption (deliberate, permanent)
# ---------------------------------------------------------------------------

# Returns true if a card can be shrine-corrupted at all
static func can_shrine_corrupt(card_id: String) -> bool:
	return SHRINE_CORRUPTED_CARDS.has(card_id)

# Returns the shrine corruption data dict, or {} if none exists
static func get_shrine_corruption(card_id: String) -> Dictionary:
	return SHRINE_CORRUPTED_CARDS.get(card_id, {})

# Check if a specific card instance (by deck index) has been shrine-corrupted
static func is_shrine_corrupted(card_id: String, run: RunState) -> bool:
	return card_id in run.shrine_corrupted_cards

# Apply shrine corruption to a card — marks it in RunState and returns the
# shrine corruption dict so the caller can display feedback.
# Returns {} if the card has no shrine variant or is already corrupted.
static func apply_shrine_corruption(card_id: String, run: RunState) -> Dictionary:
	if not can_shrine_corrupt(card_id):
		return {}
	if is_shrine_corrupted(card_id, run):
		return {}
	run.shrine_corrupted_cards.append(card_id)
	return SHRINE_CORRUPTED_CARDS[card_id]

# Get the effective card_data overrides for a card, combining shrine and
# tier-based corruption (shrine takes priority for overlapping fields).
# Returns {} if neither applies.
static func get_effective_overrides(card_id: String, corruption_tier: int, run: RunState) -> Dictionary:
	var result: Dictionary = {}

	# Tier-based corruption
	if should_corrupt(card_id, corruption_tier):
		result.merge(CORRUPTED_CARDS[card_id])

	# Shrine corruption — merges on top (overrides tier-based if fields overlap)
	if is_shrine_corrupted(card_id, run):
		var sc = SHRINE_CORRUPTED_CARDS.get(card_id, {})
		if not sc.is_empty():
			result["display_name"] = sc.get("display_name", result.get("display_name", card_id))
			result["description"] = sc.get("description", result.get("description", ""))
			# Merge upgrade and drawback field overrides
			for field in sc.get("upgrades", {}).keys():
				result[field] = sc["upgrades"][field]
			for field in sc.get("drawbacks", {}).keys():
				result[field] = sc["drawbacks"][field]

	return result
