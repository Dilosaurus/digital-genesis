class_name LevelSystem
extends RefCounted

# XP thresholds: index = current level, value = total cumulative XP needed to reach that level.
# Example: XP_THRESHOLDS[2] = 150 means you need 150 total XP to reach level 3.
const XP_THRESHOLDS: Array[int] = [
	0,     # Level 1 (starting)
	50,    # Level 2  (50 to reach)
	150,   # Level 3  (100 more)
	325,   # Level 4  (175 more)
	600,   # Level 5  (275 more)
	1000,  # Level 6  (400 more)
	1550,  # Level 7  (550 more)
	2275,  # Level 8  (725 more)
	3200,  # Level 9  (925 more)
	4350,  # Level 10 (1150 more)
]

const MAX_LEVEL: int = 10

## Grant XP and process any level-ups. Returns array of level-up reward dicts.
static func grant_xp(run: RunState, amount: int) -> Array:
	if run.level >= MAX_LEVEL:
		return []

	run.xp += amount
	var level_ups: Array = []

	while run.level < MAX_LEVEL and run.xp >= XP_THRESHOLDS[run.level]:
		run.level += 1
		var rewards = _get_level_rewards(run.level)
		_apply_rewards(run, rewards)
		level_ups.append(rewards)

	return level_ups

## Get rewards for reaching a specific level.
static func _get_level_rewards(level: int) -> Dictionary:
	var rewards = {
		"level": level,
		"max_hp_bonus": 5,
		"skill_points": 1,
		"max_mana_bonus": 0,
	}
	# Every 3 levels, also gain +1 max mana
	if level % 3 == 0:
		rewards["max_mana_bonus"] = 1
	return rewards

## Apply level-up rewards to the persistent run state.
static func _apply_rewards(run: RunState, rewards: Dictionary) -> void:
	run.max_hp += rewards["max_hp_bonus"]
	run.current_hp += rewards["max_hp_bonus"]  # Heal the bonus amount too
	run.skill_points += rewards["skill_points"]
	# max_mana_bonus is tracked in run state; applied during combat via PlayerState
	if rewards["max_mana_bonus"] > 0:
		run.max_mana_bonus += rewards["max_mana_bonus"]

## Get XP value for killing an enemy by its data ID.
static func get_enemy_xp(enemy_data_id: String) -> int:
	var enemy_data: EnemyData = load("res://data/enemies/%s.tres" % enemy_data_id)
	if enemy_data and enemy_data.xp_reward > 0:
		return enemy_data.xp_reward
	# Fallback based on enemy HP tier
	if enemy_data:
		if enemy_data.max_hp >= 200:
			return 200  # Boss
		elif enemy_data.max_hp >= 80:
			return 50   # Elite
		else:
			return 15   # Common
	return 10

## Room completion XP bonus (flat).
static func get_room_completion_xp() -> int:
	return 25

## Get XP needed to reach next level from current state.
static func xp_to_next_level(run: RunState) -> int:
	if run.level >= MAX_LEVEL:
		return 0
	return XP_THRESHOLDS[run.level] - run.xp

## Get progress percentage towards next level (0.0 to 1.0).
static func level_progress_pct(run: RunState) -> float:
	if run.level >= MAX_LEVEL:
		return 1.0
	var prev_threshold = 0 if run.level <= 1 else XP_THRESHOLDS[run.level - 1]
	var next_threshold = XP_THRESHOLDS[run.level]
	var range_size = next_threshold - prev_threshold
	if range_size <= 0:
		return 1.0
	return clampf(float(run.xp - prev_threshold) / float(range_size), 0.0, 1.0)
