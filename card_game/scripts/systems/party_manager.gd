class_name PartyManager
extends RefCounted

# =============================================================================
# PartyManager -- static utility class for party-wide queries and effects.
# NOT an autoload.  Every method takes CombatState (or PlayerState) explicitly.
# =============================================================================

# ---------------------------------------------------------------
# Party queries
# ---------------------------------------------------------------

## Get all living players from combat state.
static func get_living_players(state: CombatState) -> Array[PlayerState]:
	var result: Array[PlayerState] = []
	for peer_id in state.players:
		var ps: PlayerState = state.players[peer_id]
		if not ps.is_dead:
			result.append(ps)
	return result

## Get all living player peer IDs.
static func get_living_peer_ids(state: CombatState) -> Array[int]:
	var result: Array[int] = []
	for peer_id in state.players:
		if not state.players[peer_id].is_dead:
			result.append(peer_id)
	return result

## Get total party size (all players, living or dead).
static func get_party_size(state: CombatState) -> int:
	return state.players.size()

## Get living party size.
static func get_living_count(state: CombatState) -> int:
	var count := 0
	for peer_id in state.players:
		if not state.players[peer_id].is_dead:
			count += 1
	return count

## Check if all players are dead (true death, not death's door).
static func is_party_wiped(state: CombatState) -> bool:
	for peer_id in state.players:
		if not DeathsDoorSystem.is_truly_dead(state.players[peer_id]):
			return false
	return true

## Check if any player is on death's door.
static func has_downed_player(state: CombatState) -> bool:
	for peer_id in state.players:
		if state.players[peer_id].is_on_deaths_door:
			return true
	return false

## Get the player with the lowest HP (for boss targeting).
static func get_lowest_hp_player(state: CombatState) -> PlayerState:
	var lowest: PlayerState = null
	for peer_id in state.players:
		var ps: PlayerState = state.players[peer_id]
		if ps.is_dead:
			continue
		if lowest == null or ps.current_hp < lowest.current_hp:
			lowest = ps
	return lowest

## Get the player with the highest HP.
static func get_highest_hp_player(state: CombatState) -> PlayerState:
	var highest: PlayerState = null
	for peer_id in state.players:
		var ps: PlayerState = state.players[peer_id]
		if ps.is_dead:
			continue
		if highest == null or ps.current_hp > highest.current_hp:
			highest = ps
	return highest

## Get the player with the lowest block (for Gabriel's Divine Trumpet).
static func get_lowest_block_player(state: CombatState) -> PlayerState:
	var lowest: PlayerState = null
	for peer_id in state.players:
		var ps: PlayerState = state.players[peer_id]
		if ps.is_dead:
			continue
		if lowest == null or ps.block < lowest.block:
			lowest = ps
	return lowest

## Get the player who dealt the least damage last turn (for Gabriel's Blessing).
## Requires a damage tracking dict: peer_id -> damage_dealt_this_turn.
static func get_least_damage_player(state: CombatState, turn_damage: Dictionary) -> PlayerState:
	var lowest_id: int = -1
	var lowest_dmg: int = 999999
	for peer_id in state.players:
		if state.players[peer_id].is_dead:
			continue
		var dmg = turn_damage.get(peer_id, 0)
		if dmg < lowest_dmg:
			lowest_dmg = dmg
			lowest_id = peer_id
	if lowest_id >= 0:
		return state.players[lowest_id]
	return null

# ---------------------------------------------------------------
# Party-wide effects
# ---------------------------------------------------------------

## Apply a modifier to ALL living players (e.g., party aura).
static func apply_modifier_to_party(state: CombatState, mod: ModifierData) -> void:
	for peer_id in state.players:
		var ps: PlayerState = state.players[peer_id]
		if not ps.is_dead:
			ps.modifier_stack.add(mod)

## Remove modifiers by source from ALL players.
static func remove_modifier_from_party(state: CombatState, source_type: String, source_id: String = "") -> void:
	for peer_id in state.players:
		state.players[peer_id].modifier_stack.remove_by_source(source_type, source_id)

## Heal all living players. Returns { peer_id -> actual_heal }.
static func heal_party(state: CombatState, amount: int) -> Dictionary:
	var result: Dictionary = {}
	for peer_id in state.players:
		var ps: PlayerState = state.players[peer_id]
		if ps.is_dead:
			continue
		var actual = mini(amount, ps.max_hp - ps.current_hp)
		ps.current_hp += actual
		result[peer_id] = actual
	return result

## Damage all living players (e.g., Holy Fire, arena effect).
## Block absorbs first.  Returns { peer_id -> damage_after_block }.
## Death's Door check is handled by caller.
static func damage_party(state: CombatState, amount: int) -> Dictionary:
	var result: Dictionary = {}
	for peer_id in state.players:
		var ps: PlayerState = state.players[peer_id]
		if ps.is_dead:
			continue
		var actual = amount
		if ps.block > 0:
			var blocked = mini(actual, ps.block)
			ps.block -= blocked
			actual -= blocked
		ps.current_hp = maxi(ps.current_hp - actual, 0)
		result[peer_id] = actual
	return result

## Share block from one player to all others evenly.
static func share_block(source: PlayerState, state: CombatState) -> void:
	var living = get_living_players(state)
	if living.size() <= 1:
		return
	var share_per = int(source.block / living.size())
	source.block = share_per  # Source keeps equal share
	for ps in living:
		if ps.peer_id != source.peer_id:
			ps.block += share_per

## Transfer mana from one player to another.  Returns actual amount moved.
static func transfer_mana(from: PlayerState, to: PlayerState, amount: int) -> int:
	var actual = mini(amount, from.energy)
	from.energy -= actual
	to.energy = mini(to.energy + actual, to.max_energy)
	return actual

## Grant energy to all living players.
static func energy_surge(state: CombatState, amount: int) -> void:
	for peer_id in state.players:
		var ps: PlayerState = state.players[peer_id]
		if not ps.is_dead:
			ps.energy = mini(ps.energy + amount, ps.max_energy)

## Grant draw bonus to all living players next turn (by reducing draw_penalty).
static func party_draw_bonus(state: CombatState, amount: int) -> void:
	for peer_id in state.players:
		var ps: PlayerState = state.players[peer_id]
		if not ps.is_dead:
			ps.draw_penalty -= amount  # Negative penalty = bonus

# ---------------------------------------------------------------
# Turn damage tracking (for boss mechanics)
# ---------------------------------------------------------------

## Initialize damage tracking for a new turn.
static func init_turn_damage(state: CombatState) -> Dictionary:
	var tracking: Dictionary = {}
	for peer_id in state.players:
		tracking[peer_id] = 0
	return tracking

## Record damage dealt by a player.
static func record_damage(tracking: Dictionary, peer_id: int, damage: int) -> void:
	tracking[peer_id] = tracking.get(peer_id, 0) + damage
