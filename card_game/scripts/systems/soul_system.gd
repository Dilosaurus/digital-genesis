class_name SoulSystem
extends RefCounted

# Fragments dropped per hit (scales with damage dealt)
static func calculate_fragments(damage_dealt: int) -> int:
	if damage_dealt <= 0:
		return 0
	if damage_dealt >= 15:
		return 3
	if damage_dealt >= 8:
		return 2
	return 1

# Add fragments to the shared pool
static func collect_fragments(state: CombatState, amount: int) -> void:
	state.soul_fragments += amount

# Boss absorbs uncollected fragments at end of each enemy turn
# Returns how many were absorbed
static func boss_absorb(state: CombatState) -> int:
	var to_absorb = mini(state.soul_fragments, 3)  # Boss absorbs up to 3 per turn
	if to_absorb <= 0:
		return 0
	state.soul_fragments -= to_absorb
	state.boss_absorbed_souls += to_absorb
	return to_absorb

# Get boss damage bonus from absorbed souls (flat bonus per 5 absorbed)
static func get_boss_damage_bonus(state: CombatState) -> int:
	return int(state.boss_absorbed_souls / 5) * 2

# Spend fragments for powerful effects. Returns true if affordable.
static func can_afford(state: CombatState, cost: int) -> bool:
	return state.soul_fragments >= cost

static func spend(state: CombatState, cost: int) -> bool:
	if state.soul_fragments < cost:
		return false
	state.soul_fragments -= cost
	return true

# Soul abilities and their costs
const SOUL_ABILITIES = {
	"heal_all": {"cost": 8, "description": "Heal all players for 15 HP"},
	"energy_surge": {"cost": 5, "description": "All players gain +2 energy this turn"},
	"purify": {"cost": 10, "description": "Remove 20 corruption from a player"},
	"soul_blast": {"cost": 12, "description": "Deal 30 damage to all enemies"},
}

# Execute a soul ability
static func execute_ability(ability_id: String, state: CombatState) -> Dictionary:
	var ability = SOUL_ABILITIES.get(ability_id)
	if not ability:
		return {"success": false}
	if not spend(state, ability["cost"]):
		return {"success": false, "reason": "Not enough fragments"}

	var result = {"success": true, "ability": ability_id, "description": ability["description"]}

	match ability_id:
		"heal_all":
			for peer_id in state.players:
				var ps = state.players[peer_id]
				if ps.current_hp > 0:
					ps.current_hp = mini(ps.current_hp + 15, ps.max_hp)
			result["heal"] = 15
		"energy_surge":
			for peer_id in state.players:
				var ps = state.players[peer_id]
				if ps.current_hp > 0:
					ps.energy += 2
			result["energy"] = 2
		"purify":
			# Purify the most corrupted living player
			var most_corrupt_id = -1
			var most_corrupt_val = 0
			for peer_id in state.players:
				var ps = state.players[peer_id]
				if ps.current_hp > 0 and ps.corruption > most_corrupt_val:
					most_corrupt_val = ps.corruption
					most_corrupt_id = peer_id
			if most_corrupt_id >= 0:
				var ps = state.players[most_corrupt_id]
				ps.corruption = maxi(ps.corruption - 20, 0)
			result["purified"] = most_corrupt_id
		"soul_blast":
			for enemy in state.enemies:
				if enemy.current_hp > 0:
					enemy.current_hp = maxi(enemy.current_hp - 30, 0)
			result["damage"] = 30

	return result
