class_name ActData
extends Resource

# ============================================================================
# ActData — defines a single Act (top-level region accessible via a portal).
#
# Under the persistent-progression pivot (see balance_dashboard's
# decisions/0003-persistent-pivot.md), the game has 5 Acts (3 in V1):
#   Act I   — The Outer Nexus
#   Act II  — The Neural Cathedral
#   Act III — The Void Core Archives
#   Act IV  — The Broken Liturgy        (post-launch)
#   Act V   — The Compiler's Dream      (post-launch)
#
# Each Act has its own enemy pool, boss roster, lore tone, and legendary
# variant pool. Acts are replayable; players choose which to enter from
# the town. Internally, each Act is structured as 3 Rites (sub-sections),
# and each Rite has its own boss. The Rite III boss is the Act Boss.
#
# This class formalizes what was previously hardcoded in
# RunState.generate_map's match statement on act_number.
#
# Act .tres files live in res://data/acts/<act_id>.tres
#
# Phase 10a ships this class only — actual .tres act definitions and the
# integration with RunState's map generation come in 10b.
# ============================================================================

@export var id: String = ""                # "outer_nexus", "neural_cathedral", "void_core_archives", "broken_liturgy", "compilers_dream"
@export var display_name: String = ""      # "The Outer Nexus"
@export var subtitle: String = ""          # "corrupted server farms"
@export var roman_numeral: String = "I"    # for UI display
@export var description: String = ""       # in-voice prose

# --- Lock state ---
@export var unlocked_by_default: bool = true  # V1 acts are unlocked from start; V2 acts may require progression

# --- Enemy pools (one pool per rite) ---
# Each rite of the act draws from these pools. Rite I uses index 0, Rite II uses 1, Rite III uses 2.
# Falls back to the last available pool if a rite index exceeds the array length.
@export var fight_pools: Array[Array] = []   # Array of Array[String] — enemy ids
@export var elite_pools: Array[Array] = []   # same shape
@export var rite_bosses: Array[String] = []  # boss id per rite. rite_bosses[0] = Rite I boss, etc.

# --- The Act Boss is rite_bosses[2], the boss of Rite III (the named angel for this act) ---

# --- Rite layout per rite (number of rooms / row count) ---
@export var rite_row_counts: Array[int] = [7, 7, 7]   # how many rows per rite. Default 7 each.

# --- Loot pool ---
@export var legendary_variant_ids: Array[String] = []  # which legendary variants drop in this act
@export var rare_variant_ids: Array[String] = []       # which rare variants drop in this act
@export var corrupted_variant_ids: Array[String] = []  # corrupted variants this act can drop (high hostility only)

# --- Theming ---
@export var accent_color_hex: String = "#D9B05F"   # the act's signature color, used in UI
@export var ambient_track: String = ""             # path to ambient music for this act (optional)


# ----------------------------------------------------------------------------
# Get the fight pool for a specific rite (1, 2, or 3).
# ----------------------------------------------------------------------------
func get_fight_pool(rite_index: int) -> Array:
	var idx := clampi(rite_index - 1, 0, fight_pools.size() - 1)
	if fight_pools.size() == 0:
		return []
	return fight_pools[idx]


# ----------------------------------------------------------------------------
# Get the elite pool for a specific rite.
# ----------------------------------------------------------------------------
func get_elite_pool(rite_index: int) -> Array:
	var idx := clampi(rite_index - 1, 0, elite_pools.size() - 1)
	if elite_pools.size() == 0:
		return []
	return elite_pools[idx]


# ----------------------------------------------------------------------------
# Get the boss id for a specific rite. Rite III's boss is the Act Boss.
# ----------------------------------------------------------------------------
func get_rite_boss(rite_index: int) -> String:
	var idx := clampi(rite_index - 1, 0, rite_bosses.size() - 1)
	if rite_bosses.size() == 0:
		return ""
	return rite_bosses[idx]


# ----------------------------------------------------------------------------
# True if this act has a Rite III boss defined (i.e. it's a complete act).
# ----------------------------------------------------------------------------
func is_complete() -> bool:
	return rite_bosses.size() >= 3 and rite_bosses[2] != ""
