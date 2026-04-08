class_name CardVariant
extends Resource

# ============================================================================
# CardVariant — a hand-designed variation of a base card.
#
# Under the persistent-progression pivot (see balance_dashboard's
# decisions/0003-persistent-pivot.md), every card in the game has 1-4
# variants. The base CardData definition is the COMMON variant. Additional
# variants are designed cards (Strike+, Strike of the Wound, etc.) with
# their own stats and flavor.
#
# A variant references its base card by ID and overrides only the fields
# that differ. The base CardData is loaded as the foundation; variant
# fields layer on top via apply_to(card_data) at runtime.
#
# Variants live in res://data/variants/<base_id>/<variant_id>.tres
# Examples:
#   res://data/variants/strike/strike_plus.tres
#   res://data/variants/strike/strike_of_the_wound.tres
#   res://data/variants/strike/strike_of_silent_rites.tres
#
# Phase 10a ships this class only — actual .tres variant files come in 10c.
# ============================================================================

@export var id: String = ""                 # unique variant id, e.g. "strike_of_the_wound"
@export var base_card_id: String = ""       # base card id, e.g. "strike"
@export var display_name: String = ""       # "Strike of the Wound"
@export var flavor_text: String = ""        # in-voice prose, shown on the card
@export var rarity: Enums.Rarity = Enums.Rarity.COMMON

# --- Drop metadata (where this variant can come from) ---
@export var act_id: String = ""             # which act drops this variant ("outer_nexus", "neural_cathedral", "void_core_archives", or "" for any)
@export var min_hostility: int = 0          # minimum hostility required for this to drop
@export var drop_weight: int = 100          # relative drop weight within its tier (higher = more common)

# --- Stat overrides (only set fields that differ from the base card) ---
# Use sentinel value -999 for "no override" so 0 remains a valid override.
const NO_OVERRIDE := -999

@export var damage: int = NO_OVERRIDE
@export var block: int = NO_OVERRIDE
@export var heal: int = NO_OVERRIDE
@export var draw: int = NO_OVERRIDE
@export var hits: int = NO_OVERRIDE
@export var energy_cost: int = NO_OVERRIDE
@export var apply_vulnerable: int = NO_OVERRIDE
@export var apply_weak: int = NO_OVERRIDE
@export var corruption_gain: int = NO_OVERRIDE
@export var gain_strength: int = NO_OVERRIDE
@export var gain_dexterity: int = NO_OVERRIDE
@export var gem_sockets: int = NO_OVERRIDE

# --- Behavior overrides (rare — for variants with new mechanics) ---
@export var exhaust: bool = false
@export var exhaust_set: bool = false       # set true to indicate exhaust above is meaningful (else inherit)

# --- Corrupted variant fields ---
@export var is_corrupted: bool = false      # true = this is a corrupted-tier variant
@export var corruption_downside: String = ""  # human-readable downside text for the deck builder UI
@export var corruption_self_damage: int = 0  # damage to self per play (one common downside type)
@export var corruption_locked_in_deck: bool = false  # cannot be removed once equipped

# --- Optional artwork override ---
@export var artwork: Texture2D = null


# ----------------------------------------------------------------------------
# Apply this variant on top of a base CardData and return a fresh CardData
# instance with the merged values. The original base is not mutated.
# ----------------------------------------------------------------------------
func apply_to(base: CardData) -> CardData:
	if base == null:
		push_error("CardVariant.apply_to: base is null for variant %s" % id)
		return null

	var merged := CardData.new()

	# Copy every field from the base
	merged.id = base.id
	merged.display_name = display_name if display_name != "" else base.display_name
	merged.description = base.description
	merged.energy_cost = energy_cost if energy_cost != NO_OVERRIDE else base.energy_cost
	merged.card_type = base.card_type
	merged.target_type = base.target_type
	merged.artwork = artwork if artwork != null else base.artwork
	merged.damage = damage if damage != NO_OVERRIDE else base.damage
	merged.block = block if block != NO_OVERRIDE else base.block
	merged.heal = heal if heal != NO_OVERRIDE else base.heal
	merged.draw = draw if draw != NO_OVERRIDE else base.draw
	merged.hits = hits if hits != NO_OVERRIDE else base.hits
	merged.apply_vulnerable = apply_vulnerable if apply_vulnerable != NO_OVERRIDE else base.apply_vulnerable
	merged.apply_weak = apply_weak if apply_weak != NO_OVERRIDE else base.apply_weak
	merged.corruption_gain = corruption_gain if corruption_gain != NO_OVERRIDE else base.corruption_gain
	merged.exhaust = exhaust if exhaust_set else base.exhaust
	merged.gain_strength = gain_strength if gain_strength != NO_OVERRIDE else base.gain_strength
	merged.gain_dexterity = gain_dexterity if gain_dexterity != NO_OVERRIDE else base.gain_dexterity
	merged.upgraded = base.upgraded
	merged.upgrade_id = base.upgrade_id
	merged.rarity = rarity
	merged.character_class = base.character_class
	merged.tags = base.tags.duplicate()
	merged.cooldown_max = base.cooldown_max
	merged.gem_sockets = gem_sockets if gem_sockets != NO_OVERRIDE else base.gem_sockets

	# Co-op / party fields — pass through from base unchanged
	merged.party_heal = base.party_heal
	merged.party_draw = base.party_draw
	merged.party_damage = base.party_damage
	merged.share_block = base.share_block
	merged.transfer_mana = base.transfer_mana
	merged.mark_target = base.mark_target

	# Revival
	merged.revive_ally = base.revive_ally
	merged.revive_hp = base.revive_hp

	# Corruption removal
	merged.corruption_remove = base.corruption_remove
	merged.party_corruption_remove = base.party_corruption_remove

	# Scourge / PIRACY
	merged.steal_block = base.steal_block
	merged.steal_all_block = base.steal_all_block
	merged.aoe_steal_block = base.aoe_steal_block
	merged.create_contraband = base.create_contraband
	merged.destroy_contraband_for_damage = base.destroy_contraband_for_damage
	merged.destroy_contraband_for_block = base.destroy_contraband_for_block
	merged.destroy_contraband_corruption = base.destroy_contraband_corruption
	merged.damage_per_card_played = base.damage_per_card_played
	merged.damage_per_contraband_in_hand = base.damage_per_contraband_in_hand
	merged.conditional_damage_if_zero_block = base.conditional_damage_if_zero_block
	merged.aoe_damage = base.aoe_damage

	# Daemon fragments
	merged.create_daemon_fragment = base.create_daemon_fragment
	merged.destroy_daemons_for_damage = base.destroy_daemons_for_damage

	return merged


# ----------------------------------------------------------------------------
# A pretty label for UI display.
# ----------------------------------------------------------------------------
func get_label() -> String:
	if display_name != "":
		return display_name
	return id
