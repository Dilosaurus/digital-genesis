class_name EnemyAI
extends RefCounted

static func pick_intent(enemy: EnemyState, enemy_data: EnemyData) -> void:
	if enemy_data.intent_pool.is_empty():
		enemy.intent_type = Enums.EnemyIntent.ATTACK
		enemy.intent_value = 5
		return

	# If the enemy is in a phase with its own intent pool, use that pool
	if enemy.current_phase_index >= 0 and enemy.current_phase_index < enemy_data.phases.size():
		var phase: Dictionary = enemy_data.phases[enemy.current_phase_index]
		var phase_pool: Array = phase.get("intent_pool", [])
		if phase_pool.size() > 0:
			var intent = phase_pool[enemy.phase_intent_index]
			enemy.intent_type = intent["type"] as Enums.EnemyIntent
			enemy.intent_value = intent["value"]
			enemy.phase_intent_index = (enemy.phase_intent_index + 1) % phase_pool.size()
			return

	# Fall back to base intent pool
	var intent = enemy_data.intent_pool[enemy.intent_index]
	enemy.intent_type = intent["type"] as Enums.EnemyIntent
	enemy.intent_value = intent["value"]
	enemy.intent_index = (enemy.intent_index + 1) % enemy_data.intent_pool.size()
