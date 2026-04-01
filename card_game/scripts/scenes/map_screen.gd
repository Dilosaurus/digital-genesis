extends Control

const EventScreenScene = preload("res://scenes/ui/event_screen.tscn")
const ShopScreenScene = preload("res://scenes/ui/shop_screen.tscn")
const DeckViewerScene = preload("res://scenes/ui/deck_viewer.tscn")
const RelicDisplayScene = preload("res://scenes/ui/relic_display.tscn")

var event_screen = null
var shop_screen = null
var deck_viewer = null
var relic_display = null

const NODE_DATA = [
	# Act 1
	{"type": "fight", "enemies": ["jaw_worm", "louse_red"], "label": "COMBAT"},
	{"type": "fight", "enemies": ["cultist", "louse_red", "jaw_worm"], "label": "COMBAT"},
	{"type": "rest", "label": "REST SITE"},
	{"type": "fight", "enemies": ["cultist", "jaw_worm"], "label": "COMBAT"},
	{"type": "elite", "enemies": ["hexaghost"], "label": ">> ELITE <<"},
	{"type": "boss", "enemies": ["michael"], "label": ">>> MICHAEL <<<"},
	# Act 2
	{"type": "fight", "enemies": ["cultist", "jaw_worm", "louse_red"], "label": "COMBAT"},
	{"type": "fight", "enemies": ["louse_red", "cultist"], "label": "COMBAT"},
	{"type": "rest", "label": "REST SITE"},
	{"type": "elite", "enemies": ["gabriel"], "label": ">> ELITE <<"},
	{"type": "fight", "enemies": ["jaw_worm", "cultist", "louse_red"], "label": "COMBAT"},
	{"type": "boss", "enemies": ["raphael"], "label": ">>> RAPHAEL <<<"},
	# Act 3
	{"type": "fight", "enemies": ["cultist", "jaw_worm"], "label": "COMBAT"},
	{"type": "elite", "enemies": ["uriel"], "label": ">> ELITE <<"},
	{"type": "rest", "label": "REST SITE"},
	{"type": "elite", "enemies": ["azrael"], "label": ">> ELITE <<"},
	{"type": "boss", "enemies": ["metatron"], "label": ">>> METATRON <<<"},
]

@onready var node_container: VBoxContainer = $NodeContainer
@onready var hp_label: Label = $InfoBar/HPLabel
@onready var deck_label: Label = $InfoBar/DeckLabel
@onready var act_label: Label = $InfoBar/ActLabel
@onready var info_bar: HBoxContainer = $InfoBar

func _ready() -> void:
	_build_map()
	_update_info()
	_setup_relic_display()
	GameManager.save_run()

	var deck_btn = Button.new()
	deck_btn.text = "View Deck"
	deck_btn.position = Vector2(20, get_viewport_rect().size.y - 50)
	deck_btn.custom_minimum_size = Vector2(120, 35)
	deck_btn.pressed.connect(_show_deck)
	add_child(deck_btn)

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
				"event":
					btn.add_theme_color_override("font_color", Color(0.4, 0.7, 0.9))
				"shop":
					btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.2))

		node_container.add_child(btn)

		# Add act headers after the first node of each act (displayed above in reverse-order loop)
		if i == 0:
			var header = Label.new()
			header.text = "— ACT I: THE AWAKENING —"
			header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
			node_container.add_child(header)
		elif i == 6:
			var header = Label.new()
			header.text = "— ACT II: THE ASCENSION —"
			header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
			node_container.add_child(header)
		elif i == 12:
			var header = Label.new()
			header.text = "— ACT III: DIGITAL GENESIS —"
			header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
			node_container.add_child(header)

func _get_next_node() -> int:
	var run = GameManager.current_run
	for i in NODE_DATA.size():
		if i not in run.completed_nodes:
			return i
	return -1

func _setup_relic_display() -> void:
	relic_display = RelicDisplayScene.instantiate()
	info_bar.add_child(relic_display)
	var run = GameManager.current_run
	if run:
		relic_display.update_relics(run.relics)

func _update_info() -> void:
	var run = GameManager.current_run
	if not run:
		return
	hp_label.text = "HP: %d / %d" % [run.current_hp, run.max_hp]
	deck_label.text = "Deck: %d cards" % run.deck.size()
	act_label.text = "ACT %d" % run.act
	if relic_display:
		relic_display.update_relics(run.relics)

func _on_node_selected(node_index: int) -> void:
	var node = NODE_DATA[node_index]
	GameManager.current_run.current_node = node_index

	if node["type"] == "rest":
		_show_rest()
		return
	elif node["type"] == "event":
		_show_event()
		return
	elif node["type"] == "shop":
		_show_shop()
		return

	var enemy = node["enemies"][randi() % node["enemies"].size()]
	GameManager.current_enemy = enemy
	GameManager.current_node_type = node["type"]
	get_tree().change_scene_to_file("res://scenes/combat/combat_scene.tscn")

var rest_panel: Panel = null

func _show_rest() -> void:
	rest_panel = Panel.new()
	rest_panel.custom_minimum_size = Vector2(400, 240)
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

	var upgrade_btn = Button.new()
	upgrade_btn.text = "Upgrade a Card"
	upgrade_btn.position = Vector2(50, 110)
	upgrade_btn.custom_minimum_size = Vector2(300, 40)
	upgrade_btn.pressed.connect(_show_upgrade_choices)
	rest_panel.add_child(upgrade_btn)

	var skip_btn = Button.new()
	skip_btn.text = "Skip"
	skip_btn.position = Vector2(50, 170)
	skip_btn.custom_minimum_size = Vector2(300, 40)
	skip_btn.pressed.connect(_finish_rest)
	rest_panel.add_child(skip_btn)

func _show_deck() -> void:
	if deck_viewer:
		deck_viewer.queue_free()
	deck_viewer = DeckViewerScene.instantiate()
	add_child(deck_viewer)
	deck_viewer.show_deck(GameManager.current_run.deck)

func _finish_rest() -> void:
	GameManager.current_run.completed_nodes.append(GameManager.current_run.current_node)
	if rest_panel:
		rest_panel.queue_free()
		rest_panel = null
	_build_map()
	_update_info()

func _show_upgrade_choices() -> void:
	if rest_panel:
		rest_panel.queue_free()
		rest_panel = null

	rest_panel = Panel.new()
	rest_panel.custom_minimum_size = Vector2(500, 400)
	rest_panel.position = Vector2(get_viewport_rect().size.x / 2 - 250, get_viewport_rect().size.y / 2 - 200)
	add_child(rest_panel)

	var title = Label.new()
	title.text = "CHOOSE CARD TO UPGRADE"
	title.position = Vector2(100, 15)
	title.add_theme_font_size_override("font_size", 20)
	rest_panel.add_child(title)

	var run = GameManager.current_run
	var y_pos = 55
	var shown = 0
	for i in run.deck.size():
		var card_id = run.deck[i]
		var card_data = GameManager.get_card_data(card_id)
		if not card_data or card_data.upgraded or card_data.upgrade_id == "":
			continue
		if shown >= 5:
			break
		var btn = Button.new()
		var upgrade_data = GameManager.get_card_data(card_data.upgrade_id)
		var upgrade_name = upgrade_data.display_name if upgrade_data else card_data.upgrade_id
		btn.text = "%s → %s" % [card_data.display_name, upgrade_name]
		btn.position = Vector2(30, y_pos)
		btn.custom_minimum_size = Vector2(440, 35)
		btn.pressed.connect(_do_upgrade.bind(i, card_data.upgrade_id))
		rest_panel.add_child(btn)
		y_pos += 45
		shown += 1

	if shown == 0:
		var no_label = Label.new()
		no_label.text = "No cards available to upgrade."
		no_label.position = Vector2(100, 80)
		rest_panel.add_child(no_label)

	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.position = Vector2(180, y_pos + 15)
	back_btn.custom_minimum_size = Vector2(140, 35)
	back_btn.pressed.connect(func():
		rest_panel.queue_free()
		rest_panel = null
		_show_rest()
	)
	rest_panel.add_child(back_btn)

func _do_upgrade(deck_index: int, upgrade_id: String) -> void:
	var run = GameManager.current_run
	if deck_index < run.deck.size():
		run.deck[deck_index] = upgrade_id
	_finish_rest()

func _show_event() -> void:
	event_screen = EventScreenScene.instantiate()
	add_child(event_screen)
	event_screen.show_random_event()
	event_screen.event_completed.connect(func():
		event_screen.queue_free()
		event_screen = null
		_finish_rest()
	)

func _show_shop() -> void:
	shop_screen = ShopScreenScene.instantiate()
	add_child(shop_screen)
	shop_screen.open_shop()
	shop_screen.shop_closed.connect(func():
		shop_screen.queue_free()
		shop_screen = null
		_finish_rest()
	)
