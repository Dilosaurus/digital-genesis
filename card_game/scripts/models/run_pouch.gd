class_name RunPouch
extends RefCounted

# ============================================================================
# RunPouch — transient inventory of unidentified packages collected during
# a single dungeon run.
#
# Under the persistent-progression pivot (see balance_dashboard's
# mechanics/the-portals.md), loot during a run drops as "unidentified
# packages" — the player sees a rarity hint but not the contents. The
# pouch persists through Rites within a run but degrades on death.
#
# When the run ends:
#   - Successful extraction (Rite Boss kill + extract OR Act Boss kill):
#       pouch contents move to the player's MetaState as unidentified
#       packages, ready for Balthaz's identification ceremony in the town.
#   - Death anywhere in any Rite:
#       every package in the pouch is degraded to common before being
#       moved to the MetaState. The variant tier is lost forever.
#
# This class is purely in-memory and lives on the active RunState. It is
# not directly saved/loaded; the act of extraction OR death drains it
# into the MetaState's unidentified_packages list.
# ============================================================================

# Each package is a Dictionary with the shape:
#   {
#     "rarity_hint": String,    # "common" / "uncommon" / "rare" / "legendary" / "corrupted"
#     "card_type_hint": String, # "ATTACK" / "SKILL" / "POWER" — what shape of card
#     "base_card_id": String,   # the eventual base card; revealed later
#     "variant_id": String,     # the variant id this package will resolve to
#     "discovery_room": int,    # which room in the rite this dropped at
#     "discovery_rite": int,    # which rite (1/2/3) this dropped in
#   }
var packages: Array = []


# ----------------------------------------------------------------------------
# Add an unidentified package to the pouch.
# ----------------------------------------------------------------------------
func add_package(rarity_hint: String, card_type_hint: String, base_card_id: String, variant_id: String, discovery_room: int = 0, discovery_rite: int = 1) -> void:
	packages.append({
		"rarity_hint": rarity_hint,
		"card_type_hint": card_type_hint,
		"base_card_id": base_card_id,
		"variant_id": variant_id,
		"discovery_room": discovery_room,
		"discovery_rite": discovery_rite,
	})


# ----------------------------------------------------------------------------
# Number of packages currently held.
# ----------------------------------------------------------------------------
func count() -> int:
	return packages.size()


# ----------------------------------------------------------------------------
# Count packages of a specific rarity hint.
# ----------------------------------------------------------------------------
func count_by_rarity(rarity_hint: String) -> int:
	var n := 0
	for pkg in packages:
		if pkg.get("rarity_hint", "") == rarity_hint:
			n += 1
	return n


# ----------------------------------------------------------------------------
# Empty the pouch and return its contents. Used by the extraction and
# death paths to drain the pouch into the MetaState.
# ----------------------------------------------------------------------------
func drain() -> Array:
	var contents := packages.duplicate()
	packages.clear()
	return contents


# ----------------------------------------------------------------------------
# Degrade every package to common rarity. Used on death — the variant
# identity is lost; only the base card type survives.
#
# Returns the degraded contents (and clears the pouch).
# ----------------------------------------------------------------------------
func degrade_to_commons() -> Array:
	var degraded: Array = []
	for pkg in packages:
		degraded.append({
			"rarity_hint": "common",
			"card_type_hint": pkg.get("card_type_hint", "ATTACK"),
			"base_card_id": pkg.get("base_card_id", ""),
			"variant_id": "",   # variant is lost; will resolve to the common variant of the base card
			"discovery_room": pkg.get("discovery_room", 0),
			"discovery_rite": pkg.get("discovery_rite", 1),
			"degraded_from_death": true,
		})
	packages.clear()
	return degraded


# ----------------------------------------------------------------------------
# Quick summary string for UI display.
# ----------------------------------------------------------------------------
func summary() -> String:
	if packages.size() == 0:
		return "empty"
	var commons := count_by_rarity("common")
	var uncommons := count_by_rarity("uncommon")
	var rares := count_by_rarity("rare")
	var legendaries := count_by_rarity("legendary")
	var parts: Array[String] = []
	if commons > 0:
		parts.append("%d common" % commons)
	if uncommons > 0:
		parts.append("%d uncommon" % uncommons)
	if rares > 0:
		parts.append("%d rare" % rares)
	if legendaries > 0:
		parts.append("%d legendary" % legendaries)
	return ", ".join(parts)
