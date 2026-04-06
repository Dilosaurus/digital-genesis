class_name MetatronEncounter
extends BossEncounter

## Metatron -- "Reality Breaks" (Final Boss).
## Every mechanic subverts the co-op formula and tests party coordination.
##
## Reality Split:       At 75% HP, the party is randomly split into pairs.
##                      One group is debuffed (Weak 2), the other faces a
##                      buffed boss (+5 Strength).  One-time trigger.
##
## The Cube:            Every 5 turns, a rotating cube appears.  The party
##                      votes on which debuff face to endure:
##                      DAMAGE / WEAKNESS / CORRUPTION / MANA_DRAIN.
##
## Final Convergence:   At 25% HP, all players play blind for 2 turns --
##                      hands are hidden from other players.  Tests how well
##                      the party has internalized each other's builds.


# ---------------------------------------------------------------
# Constants
# ---------------------------------------------------------------

const CUBE_INTERVAL: int = 5
const REALITY_SPLIT_HP_PCT: float = 0.75
const CONVERGENCE_HP_PCT: float = 0.25
const CONVERGENCE_DURATION: int = 2

const CUBE_DAMAGE_AMOUNT: int = 10
const CUBE_WEAK_TURNS: int = 2
const CUBE_CORRUPTION_AMOUNT: int = 15
const CUBE_MANA_DRAIN_AMOUNT: int = 3

const SPLIT_WEAK_TURNS: int = 2
const SPLIT_BOSS_STRENGTH: int = 5

## Cube face indices.
enum CubeFace { DAMAGE, WEAKNESS, CORRUPTION, MANA_DRAIN }

const CUBE_FACE_NAMES: Dictionary = {
	CubeFace.DAMAGE:      "Face of Pain",
	CubeFace.WEAKNESS:    "Face of Frailty",
	CubeFace.CORRUPTION:  "Face of Corruption",
	CubeFace.MANA_DRAIN:  "Face of Void",
}

const CUBE_FACE_DESCRIPTIONS: Dictionary = {
	CubeFace.DAMAGE:      "All players take 10 damage",
	CubeFace.WEAKNESS:    "All players gain 2 turns of Weak",
	CubeFace.CORRUPTION:  "All players gain 15 corruption",
	CubeFace.MANA_DRAIN:  "All players lose 3 mana",
}


# ---------------------------------------------------------------
# State
# ---------------------------------------------------------------

var reality_split_triggered: bool = false
var convergence_active: bool = false
var convergence_turns_remaining: int = 0
var cube_pending: bool = false
var split_pairs: Array = []       ## Array of Array[int] -- each sub-array is a group of peer_ids
var _split_strength_added: int = 0  ## Track boss strength added by Reality Split for cleanup


# ---------------------------------------------------------------
# Lifecycle: turn start
# ---------------------------------------------------------------

func on_player_turn_start(turn_number: int) -> Array:
	var results: Array = []

	var hp_pct := float(boss_enemy.current_hp) / float(boss_enemy.max_hp)

	# --- Reality Split (one-time at 75% HP) ---
	if not reality_split_triggered and hp_pct <= REALITY_SPLIT_HP_PCT:
		reality_split_triggered = true
		results.append_array(_trigger_reality_split())

	# --- Final Convergence (at 25% HP) ---
	if not convergence_active and hp_pct <= CONVERGENCE_HP_PCT:
		convergence_active = true
		convergence_turns_remaining = CONVERGENCE_DURATION
		var data := {
			"mechanic": "final_convergence_start",
			"turns": CONVERGENCE_DURATION,
			"description": "FINAL CONVERGENCE! All players must play blind for %d turns!" % CONVERGENCE_DURATION,
		}
		results.append(data)
		mechanic_triggered.emit("final_convergence_start", data)

	# --- Tick convergence ---
	if convergence_active:
		convergence_turns_remaining -= 1
		if convergence_turns_remaining <= 0:
			convergence_active = false
			var data := {
				"mechanic": "final_convergence_end",
				"description": "Final Convergence ends. Communication restored.",
			}
			results.append(data)
			mechanic_triggered.emit("final_convergence_end", data)

	# --- The Cube (every CUBE_INTERVAL turns) ---
	if turn_number > 0 and turn_number % CUBE_INTERVAL == 0:
		cube_pending = true
		var options: Array[String] = []
		for face in [CubeFace.DAMAGE, CubeFace.WEAKNESS, CubeFace.CORRUPTION, CubeFace.MANA_DRAIN]:
			options.append("%s: %s" % [CUBE_FACE_NAMES[face], CUBE_FACE_DESCRIPTIONS[face]])

		var voter_ids := PartyManager.get_living_peer_ids(state)
		var data := {
			"mechanic": "the_cube",
			"description": "The Cube rotates! Choose which face to endure:",
			"options": options,
			"voter_peer_ids": voter_ids,
			"requires_vote": true,
		}
		results.append(data)
		mechanic_triggered.emit("the_cube", data)

	return results


# ---------------------------------------------------------------
# Reality Split
# ---------------------------------------------------------------

func _trigger_reality_split() -> Array:
	var results: Array = []
	var living := PartyManager.get_living_peer_ids(state)

	if living.size() < 2:
		return results  # Can't split a solo player

	# Shuffle and partition into pairs
	living.shuffle()
	split_pairs.clear()

	var pair: Array[int] = []
	for pid in living:
		pair.append(pid)
		if pair.size() == 2:
			split_pairs.append(pair.duplicate())
			pair.clear()

	# Odd player out -- add to first group (becomes a group of 3)
	if pair.size() == 1:
		if split_pairs.size() > 0:
			split_pairs[0].append(pair[0])
		else:
			split_pairs.append(pair.duplicate())

	# Group 1: debuffed with Weak
	if split_pairs.size() >= 1:
		for pid in split_pairs[0]:
			var ps: PlayerState = state.players.get(pid)
			if ps and not ps.is_dead:
				ps.weak += SPLIT_WEAK_TURNS

	# Group 2: boss gains temporary strength
	if split_pairs.size() >= 2:
		boss_enemy.strength += SPLIT_BOSS_STRENGTH
		_split_strength_added = SPLIT_BOSS_STRENGTH

	var data := {
		"mechanic": "reality_split",
		"pairs": split_pairs,
		"description": "Reality fractures! The party is split!",
		"pair_1_debuff": "Weak for %d turns" % SPLIT_WEAK_TURNS,
		"pair_2_debuff": "Boss gains +%d Strength" % SPLIT_BOSS_STRENGTH,
	}
	results.append(data)
	mechanic_triggered.emit("reality_split", data)

	return results


# ---------------------------------------------------------------
# Vote resolution: The Cube
# ---------------------------------------------------------------

## Called by combat_scene.gd after VoteSystem resolves the Cube vote.
## [param chosen_face_index] corresponds to the CubeFace enum (0-3).
func resolve_cube(chosen_face_index: int) -> Dictionary:
	cube_pending = false

	# Clamp to valid range
	var face: int = clampi(chosen_face_index, 0, CubeFace.MANA_DRAIN)

	var result := {
		"mechanic": "cube_resolved",
		"face": face,
		"face_name": CUBE_FACE_NAMES[face],
	}

	match face:
		CubeFace.DAMAGE:
			var damage_results := PartyManager.damage_party(state, CUBE_DAMAGE_AMOUNT)
			result["effect"] = "All players took %d damage" % CUBE_DAMAGE_AMOUNT
			result["player_damage"] = damage_results

		CubeFace.WEAKNESS:
			for peer_id in state.players:
				var ps: PlayerState = state.players[peer_id]
				if not ps.is_dead:
					ps.weak += CUBE_WEAK_TURNS
			result["effect"] = "All players are Weak for %d turns" % CUBE_WEAK_TURNS

		CubeFace.CORRUPTION:
			for peer_id in state.players:
				var ps: PlayerState = state.players[peer_id]
				if not ps.is_dead:
					ps.corruption = mini(ps.corruption + CUBE_CORRUPTION_AMOUNT, ps.max_corruption)
			result["effect"] = "All players gained %d corruption" % CUBE_CORRUPTION_AMOUNT

		CubeFace.MANA_DRAIN:
			for peer_id in state.players:
				var ps: PlayerState = state.players[peer_id]
				if not ps.is_dead:
					ps.energy = maxi(ps.energy - CUBE_MANA_DRAIN_AMOUNT, 0)
			result["effect"] = "All players lost %d mana" % CUBE_MANA_DRAIN_AMOUNT

	mechanic_resolved.emit("the_cube", result)
	return result


# ---------------------------------------------------------------
# State queries (for UI integration)
# ---------------------------------------------------------------

## Returns true when Final Convergence is active -- UI should hide
## other players' hands and disable card-preview tooltips.
func is_convergence_active() -> bool:
	return convergence_active


## Returns true when a Cube vote is pending resolution.
func is_cube_pending() -> bool:
	return cube_pending


## Full encounter state for UI / networking sync.
func get_state() -> Dictionary:
	return {
		"reality_split_triggered": reality_split_triggered,
		"convergence_active": convergence_active,
		"convergence_turns_remaining": convergence_turns_remaining,
		"cube_pending": cube_pending,
		"split_pairs": split_pairs,
	}
