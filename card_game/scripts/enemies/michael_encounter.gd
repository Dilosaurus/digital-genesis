class_name MichaelEncounter
extends BossEncounter

## Michael — Act 2 boss.  Mechanics: Judgment (vote to break shield),
## Twin Swords (attack 2 players simultaneously), Holy Fire (escalating AoE
## with vote to extinguish via Soul spend).

# ---------------------------------------------------------------
# Constants
# ---------------------------------------------------------------

const JUDGMENT_INTERVAL: int = 4
const HOLY_FIRE_INTERVAL: int = 5
const HOLY_FIRE_BASE_DAMAGE: int = 3
const HOLY_FIRE_SCALING: int = 2
const HOLY_FIRE_SOUL_COST: int = 2

# ---------------------------------------------------------------
# State
# ---------------------------------------------------------------

var shield_active: bool = false      ## When true, Michael takes no damage
var holy_fire_stacks: int = 0        ## How many times Holy Fire has triggered
var holy_fire_damage: int = 0        ## Current Holy Fire burn per turn
var _pending_judgment: bool = false   ## Whether a Judgment vote is pending
var _pending_holy_fire: bool = false  ## Whether a Holy Fire vote is pending

# ---------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------

func initialize(p_state: CombatState, p_boss: EnemyState) -> void:
	super.initialize(p_state, p_boss)
	shield_active = true  # Michael starts shielded
	_update_shield_state()


func on_player_turn_start(turn_number: int) -> Array:
	var results: Array = []

	# Holy Fire — escalating arena damage each turn
	if holy_fire_damage > 0:
		var fire_results = PartyManager.damage_party(state, holy_fire_damage)
		results.append({
			"mechanic": "holy_fire_burn",
			"damage": holy_fire_damage,
			"player_damage": fire_results,
		})
		mechanic_triggered.emit("holy_fire_burn", results[-1])

	# Judgment — every JUDGMENT_INTERVAL turns, offer vote to break shield
	if turn_number > 0 and turn_number % JUDGMENT_INTERVAL == 0 and shield_active:
		_pending_judgment = true
		var voter_ids = PartyManager.get_living_peer_ids(state)
		results.append({
			"mechanic": "judgment",
			"description": "Sacrifice 50% of a player's HP to shatter Michael's divine shield?",
			"options": ["Sacrifice (Break Shield)", "Endure (Shield Stays)"],
			"voter_peer_ids": voter_ids,
			"requires_vote": true,
		})
		mechanic_triggered.emit("judgment", results[-1])

	# Holy Fire trigger — every HOLY_FIRE_INTERVAL turns
	if turn_number > 0 and turn_number % HOLY_FIRE_INTERVAL == 0:
		holy_fire_stacks += 1
		_pending_holy_fire = true
		var voter_ids = PartyManager.get_living_peer_ids(state)
		results.append({
			"mechanic": "holy_fire",
			"description": "Holy Fire intensifies! Spend %d Soul fragments to extinguish?" % HOLY_FIRE_SOUL_COST,
			"options": ["Spend %d Souls (Extinguish)" % HOLY_FIRE_SOUL_COST, "Endure the Flames"],
			"voter_peer_ids": voter_ids,
			"requires_vote": true,
			"new_damage": HOLY_FIRE_BASE_DAMAGE + HOLY_FIRE_SCALING * holy_fire_stacks,
		})
		mechanic_triggered.emit("holy_fire", results[-1])

	return results


func on_enemy_turn_end(turn_number: int) -> Array:
	var results: Array = []

	# Twin Swords — Michael attacks TWO random living players for bonus damage
	# on top of his normal attack.  Only applies when his intent is ATTACK.
	var living = PartyManager.get_living_peer_ids(state)
	if living.size() >= 2 and boss_enemy.intent_type == Enums.EnemyIntent.ATTACK:
		living.shuffle()
		var twin_targets: Array[int] = [living[0], living[1]]
		var bonus_damage: int = int(boss_enemy.intent_value * 0.5)

		for pid in twin_targets:
			var ps: PlayerState = state.players[pid]
			if ps.is_dead:
				continue
			var actual := bonus_damage
			if ps.block > 0:
				var blocked := mini(actual, ps.block)
				ps.block -= blocked
				actual -= blocked
			ps.current_hp = maxi(ps.current_hp - actual, 0)

		results.append({
			"mechanic": "twin_swords",
			"targets": twin_targets,
			"bonus_damage": bonus_damage,
		})
		mechanic_triggered.emit("twin_swords", results[-1])

	return results


func on_phase_transition(phase_index: int) -> Array:
	# Michael re-raises his shield on phase transition
	shield_active = true
	_update_shield_state()
	return [{
		"mechanic": "shield_raised",
		"phase": phase_index,
	}]

# ---------------------------------------------------------------
# Vote resolution
# ---------------------------------------------------------------

## Called when the Judgment vote resolves.
func resolve_judgment(accepted: bool) -> Dictionary:
	_pending_judgment = false
	if accepted:
		# Sacrifice: highest HP player loses 50% HP, shield breaks
		var sacrifice := PartyManager.get_highest_hp_player(state)
		var hp_cost: int = 0
		var sacrifice_id: int = -1

		if sacrifice:
			hp_cost = int(sacrifice.current_hp * 0.5)
			sacrifice.current_hp -= hp_cost
			sacrifice.current_hp = maxi(sacrifice.current_hp, 1)  # Can't kill
			sacrifice_id = sacrifice.peer_id

		shield_active = false
		_update_shield_state()

		var result := {
			"mechanic": "judgment_resolved",
			"accepted": true,
			"sacrifice_peer_id": sacrifice_id,
			"hp_cost": hp_cost,
			"shield_broken": true,
		}
		mechanic_resolved.emit("judgment", result)
		return result
	else:
		# Shield stays active
		var result := {
			"mechanic": "judgment_resolved",
			"accepted": false,
			"shield_broken": false,
		}
		mechanic_resolved.emit("judgment", result)
		return result


## Called when the Holy Fire vote resolves.
func resolve_holy_fire(accepted: bool) -> Dictionary:
	_pending_holy_fire = false
	if accepted and SoulSystem.can_afford(state, HOLY_FIRE_SOUL_COST):
		SoulSystem.spend(state, HOLY_FIRE_SOUL_COST)
		holy_fire_damage = 0
		holy_fire_stacks = 0

		var result := {
			"mechanic": "holy_fire_resolved",
			"accepted": true,
			"extinguished": true,
			"souls_spent": HOLY_FIRE_SOUL_COST,
		}
		mechanic_resolved.emit("holy_fire", result)
		return result
	else:
		# Fire intensifies
		holy_fire_damage = HOLY_FIRE_BASE_DAMAGE + HOLY_FIRE_SCALING * holy_fire_stacks

		var result := {
			"mechanic": "holy_fire_resolved",
			"accepted": false,
			"extinguished": false,
			"new_burn_damage": holy_fire_damage,
		}
		mechanic_resolved.emit("holy_fire", result)
		return result

# ---------------------------------------------------------------
# Shield helpers
# ---------------------------------------------------------------

## Check if Michael's divine shield is currently blocking all damage.
func is_shielded() -> bool:
	return shield_active


## Sync the shield_active flag to boss_enemy.shielded so that
## CardResolver can check it without knowing about MichaelEncounter.
func _update_shield_state() -> void:
	boss_enemy.shielded = shield_active
