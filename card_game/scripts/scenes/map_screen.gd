extends Control

const NODE_DATA = [
	{"type": "fight", "enemies": ["jaw_worm", "louse_red", "cultist"], "label": "COMBAT"},
	{"type": "fight", "enemies": ["cultist", "louse_red", "jaw_worm"], "label": "COMBAT"},
	{"type": "rest", "label": "REST SITE"},
	{"type": "fight", "enemies": ["jaw_worm", "cultist", "louse_red"], "label": "COMBAT"},
	{"type": "fight", "enemies": ["louse_red", "jaw_worm", "cultist"], "label": "COMBAT"},
	{"type": "elite", "enemies": ["hexaghost"], "label": ">> ELITE <<"},
	{"type": "boss", "enemies": ["michael"], "label": ">>> BOSS <<<"},
]

@onready var node_container: VBoxContainer = $NodeContainer
@onready var hp_label: Label = $InfoBar/HPLabel
@onready var deck_label: Label = $InfoBar/DeckLabel
@onready var act_label: Label = $InfoBar/ActLabel

func _ready() -> void:
	_build_map()
	_update_info()

func _build_map() -> void:
	for child in node_container.get_children():
		child.queue_free()

	var run = GameManager.current_run
	if not run:
		return

	# Build nodes from top (boss) to bottom (first fight)
	for i in range(NODE_DATA.size() - 1, -1, -1):
		var node = NODE_DATA[i]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(300, 50)
		btn.text = node["label"]

		if i in run.completed_nodes:
			btn.disabled = true
			btn.modulate = Color(0.4, 0.4, 0.4)
		elif i == _get_next_node():
			btn.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
			btn.pressed.connect(_on_node_selected.bind(i))
		else:
			btn.disabled = true
			btn.modulate = Color(0.6, 0.6, 0.6)

		# Color by type (only for non-disabled buttons)
		if not btn.disabled:
			match node["type"]:
				"fight":
					btn.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
				"rest":
					btn.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
				"elite":
					btn.add_theme_color_override("font_color", Color(0.9, 0.6, 0.1))
				"boss":
					btn.add_theme_color_override("font_color", Color(0.9, 0.2, 0.9))

		node_container.add_child(btn)

func _get_next_node() -> int:
	var run = GameManager.current_run
	for i in NODE_DATA.size():
		if i not in run.completed_nodes:
			return i
	return -1

func _update_info() -> void:
	var run = GameManager.current_run
	if not run:
		return
	hp_label.text = "HP: %d / %d" % [run.current_hp, run.max_hp]
	deck_label.text = "Deck: %d cards" % run.deck.size()
	act_label.text = "ACT %d" % run.act

func _on_node_selected(node_index: int) -> void:
	var node = NODE_DATA[node_index]
	GameManager.current_run.current_node = node_index

	if node["type"] == "rest":
		_show_rest()
		return

	var enemy = node["enemies"][randi() % node["enemies"].size()]
	GameManager.current_enemy = enemy
	get_tree().change_scene_to_file("res://scenes/combat/combat_scene.tscn")

var rest_panel: Panel = null

func _show_rest() -> void:
	rest_panel = Panel.new()
	rest_panel.custom_minimum_size = Vector2(400, 200)
	rest_panel.position = Vector2(get_viewport_rect().size.x / 2 - 200, get_viewport_rect().size.y / 2 - 100)
	add_child(rest_panel)

	var title = Label.new()
	title.text = "REST SITE"
	title.position = Vector2(100, 20)
	title.add_theme_font_size_override("font_size", 24)
	rest_panel.add_child(title)

	var run = GameManager.current_run
	var heal_amount = int(run.max_hp * 0.3)

	var rest_btn = Button.new()
	rest_btn.text = "Rest (Heal %d HP)" % heal_amount
	rest_btn.position = Vector2(50, 80)
	rest_btn.custom_minimum_size = Vector2(300, 40)
	rest_btn.pressed.connect(func():
		run.heal(heal_amount)
		_finish_rest()
	)
	rest_panel.add_child(rest_btn)

	var skip_btn = Button.new()
	skip_btn.text = "Skip"
	skip_btn.position = Vector2(50, 140)
	skip_btn.custom_minimum_size = Vector2(300, 40)
	skip_btn.pressed.connect(_finish_rest)
	rest_panel.add_child(skip_btn)

func _finish_rest() -> void:
	GameManager.current_run.completed_nodes.append(GameManager.current_run.current_node)
	if rest_panel:
		rest_panel.queue_free()
		rest_panel = null
	_build_map()
	_update_info()
