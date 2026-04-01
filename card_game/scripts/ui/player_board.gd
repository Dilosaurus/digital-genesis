extends Control

const StatusIconScene = preload("res://scenes/ui/status_icon.tscn")

@onready var name_label: Label = $NameLabel
@onready var hp_bar = $HPBar
@onready var energy_label: Label = $EnergyLabel
@onready var block_label: Label = $BlockLabel
@onready var status_icons_container: HBoxContainer = $StatusIconsContainer
@onready var turn_status: Label = $TurnStatus

# Track active icon instances keyed by status type
var _icons: Dictionary = {}

# Status types we track for the player
const TRACKED_STATUSES = [
	StatusIcon.TYPE_STRENGTH,
	StatusIcon.TYPE_DEXTERITY,
	StatusIcon.TYPE_VULNERABLE,
	StatusIcon.TYPE_WEAK,
	StatusIcon.TYPE_CORRUPTION,
]

func _ready() -> void:
	_init_icons()

func _init_icons() -> void:
	for type in TRACKED_STATUSES:
		var icon = StatusIconScene.instantiate()
		status_icons_container.add_child(icon)
		icon.setup(type, 0)
		_icons[type] = icon

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

	# Update status icons
	_update_icon(StatusIcon.TYPE_STRENGTH,   state_dict.get("strength",    0))
	_update_icon(StatusIcon.TYPE_DEXTERITY,  state_dict.get("dexterity",   0))
	_update_icon(StatusIcon.TYPE_VULNERABLE, state_dict.get("vulnerable",  0))
	_update_icon(StatusIcon.TYPE_WEAK,       state_dict.get("weak",        0))
	_update_icon(StatusIcon.TYPE_CORRUPTION, state_dict.get("corruption",  0))

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

func _update_icon(type: String, count: int) -> void:
	if _icons.has(type):
		_icons[type].update_count(count)
