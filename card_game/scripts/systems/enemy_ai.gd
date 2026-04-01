class_name EnemyAI
extends RefCounted

static func pick_intent(enemy: EnemyState, enemy_data: EnemyData) -> void:
	if enemy_data.intent_pool.is_empty():
		enemy.intent_type = Enums.EnemyIntent.ATTACK
		enemy.intent_value = 5
		return

	var intent = enemy_data.intent_pool[enemy.intent_index]
	enemy.intent_type = intent["type"] as Enums.EnemyIntent
	enemy.intent_value = intent["value"]
	enemy.intent_index = (enemy.intent_index + 1) % enemy_data.intent_pool.size()
