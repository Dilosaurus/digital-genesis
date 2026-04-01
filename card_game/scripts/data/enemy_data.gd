class_name EnemyData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var max_hp: int = 40
@export var artwork: Texture2D = null
@export var intent_pool: Array[Dictionary] = []
# Each entry: { "type": Enums.EnemyIntent, "value": int }
