extends Control

@onready var name_label: Label = $NameLabel
@onready var hp_bar = $HPBar
@onready var intent_label: Label = $IntentLabel
@onready var block_label: Label = $BlockLabel
@onready var enemy_rect: ColorRect = $EnemyRect
@onready var status_label: Label = $StatusLabel

func update_enemy(state_dict: Dictionary) -> void:
	var enemy_data: EnemyData = load("res://data/enemies/%s.tres" % state_dict["enemy_data_id"])
	if enemy_data:
		name_label.text = enemy_data.display_name

	hp_bar.set_values(state_dict["current_hp"], state_dict["max_hp"])

	# Block display
	if state_dict["block"] > 0:
		block_label.text = "Block: %d" % state_dict["block"]
		block_label.visible = true
	else:
		block_label.visible = false

	# Intent display
	var intent_type = state_dict["intent_type"] as Enums.EnemyIntent
	var intent_value = state_dict["intent_value"]
	match intent_type:
		Enums.EnemyIntent.ATTACK:
			intent_label.text = "ATK %d" % intent_value
			intent_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		Enums.EnemyIntent.DEFEND:
			intent_label.text = "DEF %d" % intent_value
			intent_label.add_theme_color_override("font_color", Color(0.3, 0.6, 1))
		Enums.EnemyIntent.HACK:
			intent_label.text = "HACK %d" % intent_value
			intent_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.9))
		_:
			intent_label.text = "???"

	# Status effects
	var statuses = []
	if state_dict.get("vulnerable", 0) > 0:
		statuses.append("Vuln %d" % state_dict["vulnerable"])
	if state_dict.get("weak", 0) > 0:
		statuses.append("Weak %d" % state_dict["weak"])
	status_label.text = " | ".join(statuses) if statuses.size() > 0 else ""

func shake() -> void:
	var tween = create_tween()
	var orig = enemy_rect.position
	tween.tween_property(enemy_rect, "position", orig + Vector2(8, 0), 0.05)
	tween.tween_property(enemy_rect, "position", orig - Vector2(8, 0), 0.05)
	tween.tween_property(enemy_rect, "position", orig + Vector2(4, 0), 0.05)
	tween.tween_property(enemy_rect, "position", orig, 0.05)
