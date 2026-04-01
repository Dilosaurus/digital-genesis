class_name DeathsDoorSystem
extends RefCounted

const DEATHS_DOOR_DURATION = 3

# Check if a player should enter Death's Door (called when HP hits 0)
static func check_deaths_door(ps: PlayerState) -> bool:
	if ps.current_hp <= 0 and not ps.is_on_deaths_door and not ps.is_dead:
		ps.is_on_deaths_door = true
		ps.deaths_door_turns = DEATHS_DOOR_DURATION
		ps.current_hp = 1  # Kept alive at 1 HP
		ps.max_energy = maxi(ps.max_energy - 1, 1)  # Lose 1 max energy while on door
		return true
	return false

# Tick Death's Door at start of each turn. Returns true if player dies.
static func tick(ps: PlayerState) -> bool:
	if not ps.is_on_deaths_door:
		return false
	ps.deaths_door_turns -= 1
	if ps.deaths_door_turns <= 0:
		# Time's up — player dies
		ps.is_dead = true
		ps.is_on_deaths_door = false
		ps.current_hp = 0
		return true
	return false

# Revive a player from Death's Door (e.g., team wins, or a revive card)
static func revive(ps: PlayerState, heal_amount: int = 15) -> void:
	ps.is_on_deaths_door = false
	ps.deaths_door_turns = 0
	ps.current_hp = heal_amount
	ps.max_energy = 3  # Restore energy

# Check if player can still act (on Death's Door they can, dead they can't)
static func can_act(ps: PlayerState) -> bool:
	if ps.is_dead:
		return false
	return true  # Can act even on Death's Door

# Should the combat check use is_dead instead of current_hp <= 0
static func is_truly_dead(ps: PlayerState) -> bool:
	return ps.is_dead

# Get status text for UI display
static func get_status_text(ps: PlayerState) -> String:
	if ps.is_dead:
		return "DEAD"
	if ps.is_on_deaths_door:
		return "DEATH'S DOOR (%d)" % ps.deaths_door_turns
	return ""
