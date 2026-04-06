class_name GabrielEncounter
extends BossEncounter

## Gabriel -- "The Herald" (Act 2 Boss).
## The introductory boss that teaches co-op coordination mechanics.
##
## Divine Trumpet:   Every 3 turns, the player with the lowest block takes
##                   massive damage (20 + 5 * trigger_count).  Forces the party
##                   to coordinate blocking.
##
## Blessing of the Worthy:  At the end of each enemy turn, Gabriel heals the
##                           player who dealt the LEAST damage last turn for
##                           10 HP.  Prevents one player from turtling -- the
##                           "punishment" is healing the weakest contributor,
##                           creating a strategic dilemma.

const TRUMPET_INTERVAL: int = 3      # Every N turns
const TRUMPET_BASE_DAMAGE: int = 20
const TRUMPET_SCALING: int = 5       # +5 per trigger
const BLESSING_HEAL: int = 10

var trumpet_count: int = 0  # How many times trumpet has triggered

# ---------------------------------------------------------------------------
# Turn start -- Divine Trumpet
# ---------------------------------------------------------------------------
func on_player_turn_start(turn_number: int) -> Array:
	var results: Array = []

	# Divine Trumpet -- every 3 turns
	if turn_number > 0 and turn_number % TRUMPET_INTERVAL == 0:
		trumpet_count += 1
		var target = PartyManager.get_lowest_block_player(state)
		if target:
			var damage = TRUMPET_BASE_DAMAGE + TRUMPET_SCALING * trumpet_count
			# Apply through block
			var actual_damage = damage
			if target.block > 0:
				var blocked = mini(actual_damage, target.block)
				target.block -= blocked
				actual_damage -= blocked
			target.current_hp = maxi(target.current_hp - actual_damage, 0)

			results.append({
				"mechanic": "divine_trumpet",
				"target_peer_id": target.peer_id,
				"damage": actual_damage,
				"total_damage": damage,
				"blocked": damage - actual_damage,
				"trumpet_count": trumpet_count,
			})

			mechanic_triggered.emit("divine_trumpet", results[-1])

	return results

# ---------------------------------------------------------------------------
# Enemy turn end -- Blessing of the Worthy
# ---------------------------------------------------------------------------
func on_enemy_turn_end(turn_number: int) -> Array:
	var results: Array = []

	# Blessing of the Worthy -- heal the player who dealt least damage
	var weakest = PartyManager.get_least_damage_player(state, state.turn_damage)
	if weakest and weakest.current_hp > 0 and weakest.current_hp < weakest.max_hp:
		var actual_heal = mini(BLESSING_HEAL, weakest.max_hp - weakest.current_hp)
		weakest.current_hp += actual_heal

		results.append({
			"mechanic": "blessing_of_worthy",
			"target_peer_id": weakest.peer_id,
			"heal": actual_heal,
		})

		mechanic_triggered.emit("blessing_of_worthy", results[-1])

	return results
