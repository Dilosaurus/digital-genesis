class_name MetaState
extends RefCounted

# ============================================================================
# MetaState — the persistent save layer that lives across runs.
#
# Under the persistent-progression pivot (see balance_dashboard's
# decisions/0003-persistent-pivot.md), the game now has TWO save layers:
#
#   1. RunState (existing) — transient, lives only during a single run.
#      Holds the active deck, current HP, current map, run-level corruption.
#      Destroyed when the run ends (success or death).
#
#   2. MetaState (this class) — persistent across runs forever. Holds the
#      stash of unlocked variants, the per-act hostility counters, the
#      character roster, persistent currencies, and unidentified packages
#      waiting for Balthaz to read.
#
# When a run ends:
#   - Successful extraction: the RunPouch is drained into
#     unidentified_packages, currencies are added to MetaState, and the
#     RunState is discarded.
#   - Death: the RunPouch is degraded to commons, drained, and added to
#     unidentified_packages. Currencies earned this run are kept (no
#     real punishment beyond the pouch degradation). RunState is discarded.
#
# MetaState saves to user://meta.json. The existing user://save.json
# continues to be used for in-progress RunState (so a player can quit
# mid-run and resume).
#
# Phase 10a ships this class without integrating it into the run loop.
# Integration happens in 10b/10c/10d as the town and identification UIs
# are built.
# ============================================================================

const META_SAVE_PATH := "user://meta.json"

# --- Stash: unlocked variants per base card ---
# unlocked_variants[base_card_id] = Array of variant_id strings the player has unlocked.
# The common variant of a base card is implicitly always unlocked, so this dict
# only needs to track non-common unlocks.
var unlocked_variants: Dictionary = {}

# --- Active deck composition per character ---
# equipped_variants[character_id][base_card_id] = variant_id currently equipped for that slot.
# Empty/missing means the common variant is used.
var equipped_variants: Dictionary = {}

# --- Hostility per act ---
# act_hostility[act_id] = current hostility level for that act.
# Range 0-12+. Persists across runs.
var act_hostility: Dictionary = {
	"outer_nexus": 0,
	"neural_cathedral": 0,
	"void_core_archives": 0,
	"broken_liturgy": 0,
	"compilers_dream": 0,
}

# --- Act unlock state ---
# act_unlocked[act_id] = bool. V1 acts (outer_nexus, neural_cathedral, void_core_archives)
# are unlocked from start. V2 acts unlock via specific clean clears.
var act_unlocked: Dictionary = {
	"outer_nexus": true,
	"neural_cathedral": true,
	"void_core_archives": true,
	"broken_liturgy": false,
	"compilers_dream": false,
}

# --- Persistent currencies (gold + essence) ---
var gold: int = 0
var essence: int = 0

# --- Unidentified packages waiting for Balthaz to read ---
# Each entry is the same Dictionary shape as RunPouch packages.
# The player visits Balthaz to identify them and unlock the variants.
var unidentified_packages: Array = []

# --- Character roster: which characters the player has access to ---
# character_roster[character_id] = Dictionary with persistent data:
#   {
#     "level": int,
#     "xp": int,
#     "skill_points": int,
#     "unlocked_skills": Array[String],
#   }
var character_roster: Dictionary = {}

# --- Stats / journal ---
var total_runs_completed: int = 0       # extractions + clean clears
var total_runs_failed: int = 0          # deaths
var total_act_clears: Dictionary = {}    # act_id -> count of clean clears for that act
var lifetime_packages_identified: int = 0


# ============================================================================
# Stash operations
# ============================================================================

# Mark a variant as unlocked. Returns true if it's a NEW unlock, false if dup.
func unlock_variant(base_card_id: String, variant_id: String) -> bool:
	if not unlocked_variants.has(base_card_id):
		unlocked_variants[base_card_id] = []
	if variant_id in unlocked_variants[base_card_id]:
		return false
	unlocked_variants[base_card_id].append(variant_id)
	return true


# Returns true if the player has unlocked a specific variant.
func has_variant(base_card_id: String, variant_id: String) -> bool:
	if variant_id == "" or variant_id == base_card_id:
		return true   # the common variant is always available
	if not unlocked_variants.has(base_card_id):
		return false
	return variant_id in unlocked_variants[base_card_id]


# Returns the count of distinct variants unlocked across all base cards.
func variant_count() -> int:
	var n := 0
	for base_id in unlocked_variants.keys():
		n += unlocked_variants[base_id].size()
	return n


# ============================================================================
# Equipped variants per character
# ============================================================================

# Set the equipped variant for a character's deck slot.
# Empty variant_id means "use the common variant of base_card_id."
func set_equipped_variant(character_id: String, base_card_id: String, variant_id: String) -> void:
	if not equipped_variants.has(character_id):
		equipped_variants[character_id] = {}
	if variant_id == "" or variant_id == base_card_id:
		equipped_variants[character_id].erase(base_card_id)
	else:
		equipped_variants[character_id][base_card_id] = variant_id


# Get the equipped variant for a character's deck slot, or "" if common.
func get_equipped_variant(character_id: String, base_card_id: String) -> String:
	if not equipped_variants.has(character_id):
		return ""
	return equipped_variants[character_id].get(base_card_id, "")


# ============================================================================
# Hostility per act
# ============================================================================

# Increase an act's hostility. Called on entry (+1), death (+1 more), etc.
func bump_hostility(act_id: String, amount: int = 1) -> void:
	if not act_hostility.has(act_id):
		act_hostility[act_id] = 0
	act_hostility[act_id] = act_hostility[act_id] + amount


# Reset an act's hostility to 0. Called on a clean clear at hostility ≥5.
func reset_hostility(act_id: String) -> void:
	if act_hostility.has(act_id):
		act_hostility[act_id] = 0


# Decay hostility for all acts EXCEPT the one just completed. Called once
# per completed run — the angels' attention shifts when you play elsewhere.
# Each non-active act loses 1 hostility (down to 0).
func decay_hostility_other_acts(except_act_id: String) -> void:
	for act_id in act_hostility.keys():
		if act_id == except_act_id:
			continue
		act_hostility[act_id] = maxi(act_hostility[act_id] - 1, 0)


func get_hostility(act_id: String) -> int:
	return act_hostility.get(act_id, 0)


# ============================================================================
# Pouch drain — called when a run ends to add packages to MetaState.
# ============================================================================

func receive_pouch(packages: Array) -> void:
	for pkg in packages:
		unidentified_packages.append(pkg)


# ============================================================================
# Save / load
# ============================================================================

func save_to_file() -> void:
	var data := {
		"unlocked_variants": unlocked_variants,
		"equipped_variants": equipped_variants,
		"act_hostility": act_hostility,
		"act_unlocked": act_unlocked,
		"gold": gold,
		"essence": essence,
		"unidentified_packages": unidentified_packages,
		"character_roster": character_roster,
		"total_runs_completed": total_runs_completed,
		"total_runs_failed": total_runs_failed,
		"total_act_clears": total_act_clears,
		"lifetime_packages_identified": lifetime_packages_identified,
	}
	var file := FileAccess.open(META_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


static func load_from_file() -> MetaState:
	var ms := MetaState.new()
	if not FileAccess.file_exists(META_SAVE_PATH):
		return ms   # fresh save with defaults
	var file := FileAccess.open(META_SAVE_PATH, FileAccess.READ)
	if not file:
		return ms
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("MetaState.load_from_file: JSON parse error, using defaults")
		return ms
	var data: Dictionary = json.data

	ms.unlocked_variants = data.get("unlocked_variants", {})
	ms.equipped_variants = data.get("equipped_variants", {})

	# act_hostility is a dictionary; merge over the defaults so new acts
	# added in code updates get a starting value of 0.
	var saved_hostility: Dictionary = data.get("act_hostility", {})
	for k in saved_hostility.keys():
		ms.act_hostility[k] = saved_hostility[k]

	var saved_unlocked: Dictionary = data.get("act_unlocked", {})
	for k in saved_unlocked.keys():
		ms.act_unlocked[k] = saved_unlocked[k]

	ms.gold = data.get("gold", 0)
	ms.essence = data.get("essence", 0)
	ms.unidentified_packages = data.get("unidentified_packages", [])
	ms.character_roster = data.get("character_roster", {})
	ms.total_runs_completed = data.get("total_runs_completed", 0)
	ms.total_runs_failed = data.get("total_runs_failed", 0)
	ms.total_act_clears = data.get("total_act_clears", {})
	ms.lifetime_packages_identified = data.get("lifetime_packages_identified", 0)

	return ms


static func delete_save() -> void:
	if FileAccess.file_exists(META_SAVE_PATH):
		DirAccess.remove_absolute(META_SAVE_PATH)
