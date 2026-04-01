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
