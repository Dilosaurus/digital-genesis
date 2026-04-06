extends Node

## Central coordinator for dungeon / floor state.
## Manages the lifecycle of room visits (map -> enter -> interact -> exit -> map)
## without performing scene transitions itself. Other systems (map_screen, etc.)
## connect to signals and drive visual transitions.

# ---------------------------------------------------------------------------
# Phase enum
# ---------------------------------------------------------------------------
enum DungeonPhase {
	IDLE,           ## No active dungeon (main menu, character select)
	ON_MAP,         ## Viewing the branching map, choosing next node
	ENTERING_ROOM,  ## Transition animation into a room
	IN_COMBAT,      ## Combat scene active
	IN_REST,        ## At a rest site
	IN_SHOP,        ## Shopping
	IN_EVENT,       ## Narrative event
	IN_FORGE,       ## Card upgrade forge
	IN_ALTAR,       ## Card removal altar
	IN_SHRINE,      ## Corruption shrine
	IN_JEWELER,     ## Gem socket / reward
	BOSS_DEFEATED,  ## Post-boss, about to advance act
	RUN_COMPLETE,   ## Final boss defeated, epilogue
	RUN_FAILED,     ## Party wiped
}

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal phase_changed(new_phase: int)
signal room_entered(node_type: String, row: int, col: int)
signal room_exited(node_type: String)
signal floor_completed(act: int)
signal act_advanced(new_act: int)

# ---------------------------------------------------------------------------
# Current state
# ---------------------------------------------------------------------------
var current_phase: int = DungeonPhase.IDLE
var current_room_type: String = ""
var current_room_row: int = -1
var current_room_col: int = -1

# ---------------------------------------------------------------------------
# Convenience lookups
# ---------------------------------------------------------------------------
## Maps node-type strings to their corresponding DungeonPhase value.
var _type_to_phase: Dictionary = {
	"rest":    DungeonPhase.IN_REST,
	"shop":    DungeonPhase.IN_SHOP,
	"event":   DungeonPhase.IN_EVENT,
	"forge":   DungeonPhase.IN_FORGE,
	"altar":   DungeonPhase.IN_ALTAR,
	"shrine":  DungeonPhase.IN_SHRINE,
	"jeweler": DungeonPhase.IN_JEWELER,
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Called when the player selects a node on the map.
func enter_room(row: int, col: int) -> void:
	if current_phase != DungeonPhase.ON_MAP:
		push_warning("DungeonManager: can't enter room, not on map (phase: %d)" % current_phase)
		return

	var run := GameManager.current_run
	if not run:
		push_warning("DungeonManager: no active run")
		return

	var node := _get_node(run, row, col)
	if node.is_empty():
		push_warning("DungeonManager: no node at row %d col %d" % [row, col])
		return

	current_room_type = node["type"]
	current_room_row = row
	current_room_col = col

	# Keep RunState in sync
	run.current_row = row
	run.current_node_col = col
	run.current_node = row * 100 + col

	_set_phase(DungeonPhase.ENTERING_ROOM)
	room_entered.emit(current_room_type, row, col)

	# Route to the appropriate phase based on node type
	match node["type"]:
		"fight", "elite", "boss":
			_start_combat(node)
		_:
			var phase: int = _type_to_phase.get(node["type"], DungeonPhase.IN_EVENT)
			_set_phase(phase)


## Called when a room interaction is complete (combat won, rest done, etc.).
## [param success]: true if the player succeeded / finished normally.
func exit_room(success: bool = true) -> void:
	var exiting_type := current_room_type
	var run := GameManager.current_run

	if run and success:
		run.mark_node_complete(current_room_row, current_room_col)

		# Check boss completion
		if current_room_type == "boss":
			if run.act >= 3:
				_set_phase(DungeonPhase.RUN_COMPLETE)
				room_exited.emit(exiting_type)
				_clear_room_state()
				return
			else:
				_set_phase(DungeonPhase.BOSS_DEFEATED)
				floor_completed.emit(run.act)
				room_exited.emit(exiting_type)
				_clear_room_state()
				return

	room_exited.emit(exiting_type)
	_clear_room_state()
	_set_phase(DungeonPhase.ON_MAP)


## Advance to the next act after boss defeat.
func advance_act() -> void:
	if current_phase != DungeonPhase.BOSS_DEFEATED:
		push_warning("DungeonManager: can't advance act, not in BOSS_DEFEATED (phase: %d)" % current_phase)
		return

	var run := GameManager.current_run
	if not run:
		return

	run.advance_act()
	act_advanced.emit(run.act)
	_set_phase(DungeonPhase.ON_MAP)


## Start a new dungeon run (called after character select / new game).
func start_run() -> void:
	_clear_room_state()
	_set_phase(DungeonPhase.ON_MAP)


## End the run due to party wipe or voluntary abandon.
func fail_run() -> void:
	_clear_room_state()
	_set_phase(DungeonPhase.RUN_FAILED)


## Reset back to idle (returning to main menu, etc.).
func reset() -> void:
	_clear_room_state()
	_set_phase(DungeonPhase.IDLE)

# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

## Returns a human-readable name for the current act.
func get_current_act_name() -> String:
	var run := GameManager.current_run
	if not run:
		return ""
	match run.act:
		1: return "Act 1: Corrupted Server Farm"
		2: return "Act 2: Neural Cathedral"
		3: return "Act 3: The Void Core"
	return "Act %d" % run.act


## Returns progress through the current act's map.
func get_floor_progress() -> Dictionary:
	var run := GameManager.current_run
	if not run:
		return {"completed": 0, "total": 0}

	var total := 0
	var completed := 0
	for row_idx in run.map_data.size():
		for node in run.map_data[row_idx]:
			total += 1
			if run.is_node_completed(row_idx, node["col"]):
				completed += 1
	return {"completed": completed, "total": total}


## Returns a human-readable string for a DungeonPhase enum value.
func phase_name(phase: int) -> String:
	match phase:
		DungeonPhase.IDLE:           return "IDLE"
		DungeonPhase.ON_MAP:         return "ON_MAP"
		DungeonPhase.ENTERING_ROOM:  return "ENTERING_ROOM"
		DungeonPhase.IN_COMBAT:      return "IN_COMBAT"
		DungeonPhase.IN_REST:        return "IN_REST"
		DungeonPhase.IN_SHOP:        return "IN_SHOP"
		DungeonPhase.IN_EVENT:       return "IN_EVENT"
		DungeonPhase.IN_FORGE:       return "IN_FORGE"
		DungeonPhase.IN_ALTAR:       return "IN_ALTAR"
		DungeonPhase.IN_SHRINE:      return "IN_SHRINE"
		DungeonPhase.IN_JEWELER:     return "IN_JEWELER"
		DungeonPhase.BOSS_DEFEATED:  return "BOSS_DEFEATED"
		DungeonPhase.RUN_COMPLETE:   return "RUN_COMPLETE"
		DungeonPhase.RUN_FAILED:     return "RUN_FAILED"
	return "UNKNOWN(%d)" % phase

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _start_combat(node: Dictionary) -> void:
	var enemies: Array = node.get("enemies", [])
	GameManager.current_enemies.clear()
	for e in enemies:
		GameManager.current_enemies.append(e)
	GameManager.current_enemy = enemies[0] if enemies.size() > 0 else ""
	GameManager.current_node_type = node["type"]
	_set_phase(DungeonPhase.IN_COMBAT)


func _set_phase(new_phase: int) -> void:
	var old_phase := current_phase
	current_phase = new_phase
	if old_phase != new_phase:
		phase_changed.emit(new_phase)


func _clear_room_state() -> void:
	current_room_type = ""
	current_room_row = -1
	current_room_col = -1


func _get_node(run: RunState, row: int, col: int) -> Dictionary:
	if row < 0 or row >= run.map_data.size():
		return {}
	for node in run.map_data[row]:
		if node["col"] == col:
			return node
	return {}
