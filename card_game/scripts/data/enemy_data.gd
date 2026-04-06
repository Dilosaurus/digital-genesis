class_name EnemyData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export_multiline var lore: String = ""
@export var max_hp: int = 40
@export var artwork: Texture2D = null
@export var intent_pool: Array[Dictionary] = []
# Each entry: { "type": Enums.EnemyIntent, "value": int }

# Optional boss phase system.
# Each phase: { "hp_threshold": float, "intent_pool": Array[Dictionary],
#                "on_enter": String, "on_enter_value": int }
# Phases must be ordered by descending hp_threshold (checked top-to-bottom).
@export var phases: Array[Dictionary] = []

# XP granted when this enemy is killed. If 0, LevelSystem uses an HP-based fallback.
@export var xp_reward: int = 0
