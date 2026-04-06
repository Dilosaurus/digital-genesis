class_name GemData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var rarity: int = 0  # 0=common, 1=uncommon, 2=rare
@export var icon: Texture2D = null

# Modifiers applied when the socketed card is played (CARD_PLAY lifecycle)
@export var on_play_modifiers: Array[ModifierData] = []

# --- Trigger / Convert extensions ---
# These cover gem effects that the flat ModifierData stat-pipeline can't express.
# Combat code is expected to read these fields when resolving the socketed card.

# Event-based triggers. Combat hooks check these strings on matching events.
# Supported trigger_event values:
#   ""                  - no trigger (default)
#   "on_play"           - fires once when the card resolves (after damage/block applied)
#   "on_kill"           - fires when the card kills at least one enemy
#   "on_unblocked_hit"  - fires when the card deals damage that is not fully blocked
#
# Supported trigger_effect values:
#   "gain_energy"       - owner gains trigger_value energy
#   "apply_weak"        - target gains trigger_value Weak stacks
#   "apply_vulnerable"  - target gains trigger_value Vulnerable stacks
#   "deal_aoe_damage"   - deal trigger_value damage to ALL enemies
#   "create_contraband" - create trigger_value Contraband tokens in hand/draw
#   "draw_cards"        - draw trigger_value cards
@export var trigger_event: String = ""
@export var trigger_effect: String = ""
@export var trigger_value: int = 0

# --- Convert flags ---
# When true, the card's outgoing damage is suppressed and converted into self-healing
# of equal magnitude (after stat pipeline). Used by Moonstone of Conversion.
@export var convert_damage_to_heal: bool = false

# When > 0.0, the card's damage event is repeated once at this fractional value
# (e.g. 0.5 = "second hit at 50% damage"). Used by Star Sapphire of Reprise.
@export var extra_hit_percent: float = 0.0

# When > 0, additionally creates this many Contraband tokens whenever the card is played.
# Stacks with trigger_effect "create_contraband"; this is the cheaper "always-on" rider.
# Used by Black Pearl of Plunder.
@export var add_create_contraband: int = 0
