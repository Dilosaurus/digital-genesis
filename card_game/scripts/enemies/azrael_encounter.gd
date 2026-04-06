class_name AzraelEncounter
extends BossEncounter

## Azrael -- "The Reaper" (Act 3 Elite).
## The punishment fight that tests the party's willingness to sacrifice.
##
## Death Mark:    Every DEATH_MARK_INTERVAL turns, marks one random living
##                player.  After DEATH_MARK_COUNTDOWN turns the mark triggers
##                and the target is forced into Death's Door.  Another player
##                can volunteer to take the mark via transfer_mark().
##
## Soul Harvest:  When non-boss minions die (Azrael's "harvest"), ALL living
##                players permanently lose max HP for the rest of the floor.
##                Creates a dilemma: kill minions quickly before Azrael does,
##                or focus the boss and race the clock?

const DEATH_MARK_INTERVAL: int = 4    # Apply a new mark every N turns
const DEATH_MARK_COUNTDOWN: int = 3   # Turns until mark triggers
const SOUL_HARVEST_HP_LOSS: int = 1   # Max HP lost per player per minion death

# ---------------------------------------------------------------------------
# Death Mark tracking
# ---------------------------------------------------------------------------
var marked_peer_id: int = -1
var mark_countdown: int = 0
var mark_active: bool = false

# ---------------------------------------------------------------------------
# Soul Harvest tracking
# ---------------------------------------------------------------------------
var _total_dead_minions: int = 0  # Running count of dead non-boss enemies


# ---------------------------------------------------------------------------
# Turn start -- Death Mark tick + application
# ---------------------------------------------------------------------------
func on_player_turn_start(turn_number: int) -> Array:
	var results: Array = []

	# --- Tick active Death Mark ---
	if mark_active and marked_peer_id >= 0:
		mark_countdown -= 1

		if mark_countdown <= 0:
			# Mark triggers -- target goes DOWN
			var marked_ps: PlayerState = state.players.get(marked_peer_id)
			if marked_ps and not marked_ps.is_dead:
				marked_ps.current_hp = 0
				DeathsDoorSystem.check_deaths_door(marked_ps)

				var data := {
					"mechanic": "death_mark_triggered",
					"target_peer_id": marked_peer_id,
					"description": "Death Mark expires! Player %d enters Death's Door!" % marked_peer_id,
				}
				results.append(data)
				mechanic_triggered.emit("death_mark_triggered", data)

			_clear_mark()
		else:
			var data := {
				"mechanic": "death_mark_tick",
				"target_peer_id": marked_peer_id,
				"countdown": mark_countdown,
				"description": "Death Mark: %d turn%s remaining on Player %d" % [
					mark_countdown,
					"s" if mark_countdown != 1 else "",
					marked_peer_id,
				],
			}
			results.append(data)
			mechanic_triggered.emit("death_mark_tick", data)

	# --- Apply a new mark on the interval (only when none is active) ---
	if turn_number > 0 and turn_number % DEATH_MARK_INTERVAL == 0 and not mark_active:
		_apply_death_mark()

		if mark_active:
			var data := {
				"mechanic": "death_mark_applied",
				"target_peer_id": marked_peer_id,
				"countdown": mark_countdown,
				"description": "Azrael marks Player %d for death! %d turns to act!" % [
					marked_peer_id, mark_countdown,
				],
			}
			results.append(data)
			mechanic_triggered.emit("death_mark_applied", data)

	return results


# ---------------------------------------------------------------------------
# Enemy turn end -- Soul Harvest
# ---------------------------------------------------------------------------
func on_enemy_turn_end(turn_number: int) -> Array:
	var results: Array = []

	# Count all currently dead non-boss enemies
	var dead_minions := 0
	for enemy: EnemyState in state.enemies:
		if enemy != boss_enemy and enemy.current_hp <= 0:
			dead_minions += 1

	var new_kills := dead_minions - _total_dead_minions
	if new_kills > 0:
		_total_dead_minions = dead_minions

		# ALL living players lose max HP permanently
		var hp_loss := SOUL_HARVEST_HP_LOSS * new_kills
		for peer_id: int in state.players:
			var ps: PlayerState = state.players[peer_id]
			if not ps.is_dead:
				ps.max_hp = maxi(ps.max_hp - hp_loss, 1)
				ps.current_hp = mini(ps.current_hp, ps.max_hp)

		var data := {
			"mechanic": "soul_harvest",
			"minions_killed": new_kills,
			"hp_loss_per_player": hp_loss,
			"total_minions_harvested": _total_dead_minions,
			"description": "Azrael harvests %d fallen minion%s! All players lose %d max HP!" % [
				new_kills,
				"s" if new_kills != 1 else "",
				hp_loss,
			],
		}
		results.append(data)
		mechanic_triggered.emit("soul_harvest", data)

	return results


# ---------------------------------------------------------------------------
# Death Mark -- volunteer transfer
# ---------------------------------------------------------------------------

## Allow another player to take the Death Mark from the current target.
## Called from combat_scene.gd when a player clicks "Take Mark".
func transfer_mark(volunteer_peer_id: int) -> Dictionary:
	if not mark_active or marked_peer_id < 0:
		return {"success": false, "reason": "No active mark"}

	var volunteer: PlayerState = state.players.get(volunteer_peer_id)
	if not volunteer or volunteer.is_dead:
		return {"success": false, "reason": "Invalid volunteer"}

	if volunteer_peer_id == marked_peer_id:
		return {"success": false, "reason": "Already marked"}

	var old_target := marked_peer_id
	marked_peer_id = volunteer_peer_id
	# Reset countdown -- the new bearer gets the full duration
	mark_countdown = DEATH_MARK_COUNTDOWN

	var result := {
		"success": true,
		"mechanic": "death_mark_transferred",
		"from_peer_id": old_target,
		"to_peer_id": volunteer_peer_id,
		"new_countdown": mark_countdown,
		"description": "Player %d takes the Death Mark from Player %d!" % [
			volunteer_peer_id, old_target,
		],
	}
	mechanic_triggered.emit("death_mark_transferred", result)
	return result


# ---------------------------------------------------------------------------
# Query -- Death Mark state for UI
# ---------------------------------------------------------------------------

## Returns the current state of the Death Mark for UI display.
func get_mark_state() -> Dictionary:
	return {
		"active": mark_active,
		"target_peer_id": marked_peer_id,
		"countdown": mark_countdown,
	}


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _apply_death_mark() -> void:
	# Pick a random living, non-downed player
	var candidates: Array[int] = []
	for peer_id: int in state.players:
		var ps: PlayerState = state.players[peer_id]
		if not ps.is_dead and not ps.is_on_deaths_door:
			candidates.append(peer_id)

	if candidates.is_empty():
		return

	marked_peer_id = candidates[randi() % candidates.size()]
	mark_countdown = DEATH_MARK_COUNTDOWN
	mark_active = true


func _clear_mark() -> void:
	mark_active = false
	marked_peer_id = -1
	mark_countdown = 0
