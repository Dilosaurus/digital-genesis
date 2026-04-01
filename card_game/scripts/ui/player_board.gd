extends Control

@onready var name_label: Label = $NameLabel
@onready var hp_bar = $HPBar
@onready var energy_label: Label = $EnergyLabel
@onready var block_label: Label = $BlockLabel
@onready var status_label: Label = $StatusLabel
@onready var turn_status: Label = $TurnStatus

func update_player(state_dict: Dictionary, is_local: bool) -> void:
	name_label.text = state_dict.get("display_name", "Player")
	if is_local:
		name_label.text += " (You)"

	hp_bar.set_values(state_dict["current_hp"], state_dict["max_hp"])

	energy_label.text = "%d / %d" % [state_dict["energy"], state_dict["max_energy"]]

	if state_dict["block"] > 0:
		block_label.text = "Block: %d" % state_dict["block"]
		block_label.visible = true
	else:
		block_label.visible = false

	# Status effects
	var statuses = []
	if state_dict.get("vulnerable", 0) > 0:
		statuses.append("Vuln %d" % state_dict["vulnerable"])
	if state_dict.get("weak", 0) > 0:
		statuses.append("Weak %d" % state_dict["weak"])
	status_label.text = " | ".join(statuses) if statuses.size() > 0 else ""

	# Turn status
	if state_dict.get("is_dead", false):
		turn_status.text = "DEAD"
		turn_status.add_theme_color_override("font_color", Color(0.5, 0.1, 0.1))
	elif state_dict.get("is_on_deaths_door", false):
		turn_status.text = "DEATH'S DOOR (%d)" % state_dict.get("deaths_door_turns", 0)
		turn_status.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	elif state_dict.get("has_ended_turn", false):
		turn_status.text = "READY"
		turn_status.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	else:
		turn_status.text = "PLAYING..."
		turn_status.add_theme_color_override("font_color", Color(0.8, 0.8, 0.3))
