extends Control

const EventScreenScene = preload("res://scenes/ui/event_screen.tscn")
const ShopScreenScene  = preload("res://scenes/ui/shop_screen.tscn")
const DeckViewerScene  = preload("res://scenes/ui/deck_viewer.tscn")
const RelicDisplayScene = preload("res://scenes/ui/relic_display.tscn")

var event_screen = null
var shop_screen  = null
var deck_viewer  = null
var relic_display = null

# Map layout constants
const NODE_W        := 80     # button width
const NODE_H        := 50     # button height
const ROW_HEIGHT    := 110    # vertical pixels per row (bottom-to-top)
const COL_SPACING   := 120    # horizontal pixels between columns (centred on canvas)
const MAX_COLS      := 4      # max columns in a row
const CANVAS_MARGIN := 60     # padding around the canvas edges

# Canvas and line-drawing overlay
var map_canvas: Control = null
var line_overlay: Control = null

# Node buttons: map_buttons[row][col_idx] -> Button
var map_buttons: Array = []

@onready var node_container: ScrollContainer = $NodeContainer
@onready var hp_label:  Label = $InfoBar/HPLabel
@onready var deck_label: Label = $InfoBar/DeckLabel
@onready var act_label:  Label = $InfoBar/ActLabel
@onready var info_bar: HBoxContainer = $InfoBar

# ---------------------------------------------------------------------------
# Type display helpers
# ---------------------------------------------------------------------------
const NODE_LABELS: Dictionary = {
	"fight": "⚔ COMBAT",
	"elite": "★ ELITE",
	"rest":  "☽ REST",
	"event": "? EVENT",
	"shop":  "$ SHOP",
	"boss":  "☠ BOSS",
}

const NODE_COLORS: Dictionary = {
	"fight": Color(0.9, 0.3, 0.3),
	"elite": Color(0.9, 0.6, 0.1),
	"rest":  Color(0.3, 0.9, 0.4),
	"event": Color(0.4, 0.7, 0.9),
	"shop":  Color(0.9, 0.85, 0.2),
	"boss":  Color(0.9, 0.2, 0.9),
}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	map_canvas = $NodeContainer/MapCanvas

	# Ensure the run has map data (handles saves that predate this feature)
	var run := GameManager.current_run
	if run and run.map_data.size() == 0:
		run.map_data = RunState.generate_map(run.act)

	_build_map()
	_update_info()
	_setup_relic_display()
	GameManager.save_run()
	TransitionManager.fade_in(0.4)

	# "View Deck" button fixed in top-right
	var deck_btn := Button.new()
	deck_btn.text = "View Deck"
	deck_btn.custom_minimum_size = Vector2(120, 35)
	deck_btn.position = Vector2(get_viewport_rect().size.x - 150, 70)
	deck_btn.pressed.connect(_show_deck)
	add_child(deck_btn)

# ---------------------------------------------------------------------------
# Map building
# ---------------------------------------------------------------------------
func _build_map() -> void:
	# Clear previous children on the canvas
	for child in map_canvas.get_children():
		child.queue_free()
	map_buttons.clear()
	line_overlay = null

	var run := GameManager.current_run
	if not run or run.map_data.size() == 0:
		return

	var map_data: Array = run.map_data
	var num_rows: int = map_data.size()

	# Calculate canvas size
	var canvas_w: float = MAX_COLS * COL_SPACING + CANVAS_MARGIN * 2
	var canvas_h: float = num_rows * ROW_HEIGHT + CANVAS_MARGIN * 2
	map_canvas.custom_minimum_size = Vector2(canvas_w, canvas_h)

	# Figure out which nodes are accessible right now
	var accessible := run.get_accessible_nodes()  # Array of {"row": r, "col": c}

	# Create the line-drawing overlay (added first so lines appear behind buttons)
	var overlay := _LineOverlay.new()
	map_canvas.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_overlay = overlay

	# Build buttons, row by row
	for row_idx in num_rows:
		var row: Array = map_data[row_idx]
		var row_arr: Array = []

		# Y position: row 0 is at the BOTTOM of the canvas (STS style — start at bottom)
		# row 6 (boss) is at the top
		var row_y: float = canvas_h - CANVAS_MARGIN - (row_idx + 1) * ROW_HEIGHT + (ROW_HEIGHT - NODE_H) / 2.0

		for node in row:
			var col: int = node["col"]
			var row_size: int = row.size()

			# Spread cols evenly across canvas width
			var total_span: float = (row_size - 1) * COL_SPACING
			var start_x: float = canvas_w / 2.0 - total_span / 2.0
			var node_x: float = start_x + col * COL_SPACING - NODE_W / 2.0

			var btn := Button.new()
			btn.custom_minimum_size = Vector2(NODE_W, NODE_H)
			btn.position = Vector2(node_x, row_y)
			btn.text = NODE_LABELS.get(node["type"], node["type"].to_upper())

			var is_completed: bool = run.is_node_completed(row_idx, col)
			var is_accessible: bool = _is_in_accessible(row_idx, col, accessible)
			var is_current: bool = (row_idx == run.current_row and col == run.current_node_col)

			_style_button(btn, node["type"], is_completed, is_accessible, is_current)

			if is_accessible and not is_completed:
				btn.pressed.connect(_on_node_selected.bind(row_idx, col))

			map_canvas.add_child(btn)
			row_arr.append({"col": col, "button": btn, "node": node, "row": row_idx})

		map_buttons.append(row_arr)

	# Draw connection lines via a dedicated node
	_draw_lines(map_data, canvas_w, canvas_h, run, accessible)

func _is_in_accessible(row: int, col: int, accessible: Array) -> bool:
	for a in accessible:
		if a["row"] == row and a["col"] == col:
			return true
	return false

func _style_button(btn: Button, ntype: String, completed: bool, accessible: bool, is_current: bool) -> void:
	var base_color: Color = NODE_COLORS.get(ntype, Color.WHITE)
	if completed:
		btn.modulate = Color(0.35, 0.35, 0.35, 0.8)
		btn.disabled = true
	elif is_current:
		# The node the player is standing on (already completed but highlight it anyway)
		btn.modulate = Color(0.6, 0.6, 0.6, 0.9)
		btn.disabled = true
	elif accessible:
		btn.disabled = false
		btn.add_theme_color_override("font_color", base_color)
		# Give it a bright modulate pulse feel via modulate
		btn.modulate = Color(1.2, 1.2, 1.0, 1.0)
	else:
		btn.disabled = true
		btn.modulate = Color(0.55, 0.55, 0.55, 0.7)
		btn.add_theme_color_override("font_color", base_color.darkened(0.3))

# ---------------------------------------------------------------------------
# Line drawing  (we use a sub-Control with a custom _draw)
# ---------------------------------------------------------------------------
# We store a lightweight helper class on the canvas so we can use _draw().
# GDScript doesn't support anonymous inner classes with _draw, so we attach
# all line data as metadata and drive it from _build_lines.

var _line_segments: Array = []   # Array of {"from": Vector2, "to": Vector2, "color": Color}

func _draw_lines(map_data: Array, canvas_w: float, canvas_h: float, run: RunState, accessible: Array) -> void:
	_line_segments.clear()

	var num_rows: int = map_data.size()
	for row_idx in num_rows - 1:
		var cur_row: Array = map_data[row_idx]
		var next_row: Array = map_data[row_idx + 1]
		var next_row_size: int = next_row.size()
		var cur_row_size: int = cur_row.size()

		for node in cur_row:
			var col: int = node["col"]

			# Compute button centre for this node
			var cur_total_span: float = (cur_row_size - 1) * COL_SPACING
			var cur_start_x: float = canvas_w / 2.0 - cur_total_span / 2.0
			var cur_cx: float = cur_start_x + col * COL_SPACING
			var cur_row_y: float = canvas_h - CANVAS_MARGIN - (row_idx + 1) * ROW_HEIGHT + (ROW_HEIGHT - NODE_H) / 2.0
			var from_pt := Vector2(cur_cx, cur_row_y)  # top edge of button

			var is_cur_completed: bool = run.is_node_completed(row_idx, col)
			var is_cur_accessible: bool = _is_in_accessible(row_idx, col, accessible)

			for next_col in node["connections"]:
				var next_total_span: float = (next_row_size - 1) * COL_SPACING
				var next_start_x: float = canvas_w / 2.0 - next_total_span / 2.0
				var next_cx: float = next_start_x + next_col * COL_SPACING
				var next_row_y: float = canvas_h - CANVAS_MARGIN - (row_idx + 2) * ROW_HEIGHT + (ROW_HEIGHT - NODE_H) / 2.0 + NODE_H
				var to_pt := Vector2(next_cx, next_row_y)  # bottom edge of next button

				# Color logic: bright if accessible path, dim if completed, grey otherwise
				var line_color: Color
				var is_next_accessible: bool = _is_in_accessible(row_idx + 1, next_col, accessible)
				if is_next_accessible and not is_cur_completed:
					line_color = Color(0.9, 0.85, 0.5, 0.95)  # golden: available path
				elif is_cur_completed:
					line_color = Color(0.4, 0.4, 0.45, 0.6)   # grey: already walked
				else:
					line_color = Color(0.3, 0.3, 0.35, 0.45)  # dim: not yet reachable

				_line_segments.append({"from": from_pt, "to": to_pt, "color": line_color})

	# Pass data to the overlay and trigger redraw
	if line_overlay and line_overlay is _LineOverlay:
		(line_overlay as _LineOverlay).segments = _line_segments
		line_overlay.queue_redraw()

# (Legacy stub — actual drawing done in _LineOverlay._draw)
func _on_overlay_draw() -> void:
	pass

# ---------------------------------------------------------------------------
# Node selection & routing
# ---------------------------------------------------------------------------
func _on_node_selected(row: int, col: int) -> void:
	SFXManager.play_button_click()
	var run := GameManager.current_run
	var map_data: Array = run.map_data
	if row >= map_data.size():
		return
	var row_data: Array = map_data[row]
	var node: Dictionary = {}
	for n in row_data:
		if n["col"] == col:
			node = n
			break
	if node.is_empty():
		return

	# Update tracking
	run.current_row = row
	run.current_node_col = col
	run.current_node = row * 100 + col  # legacy field, keep for compat

	match node["type"]:
		"rest":
			_show_rest()
		"event":
			_show_event()
		"shop":
			_show_shop()
		_:
			# fight / elite / boss — go to combat with ALL listed enemies
			var enemies: Array = node["enemies"]
			# Populate both fields: current_enemies holds the full list,
			# current_enemy holds the first for backward-compat / boss reward logic.
			GameManager.current_enemies.clear()
			for e in enemies:
				GameManager.current_enemies.append(e)
			GameManager.current_enemy = enemies[0] if enemies.size() > 0 else ""
			GameManager.current_node_type = node["type"]
			GameManager.save_run()
			TransitionManager.transition_to_scene("res://scenes/combat/combat_scene.tscn")

# ---------------------------------------------------------------------------
# Rest site
# ---------------------------------------------------------------------------
var rest_panel: Panel = null

func _show_rest() -> void:
	rest_panel = Panel.new()
	rest_panel.custom_minimum_size = Vector2(500, 290)
	rest_panel.position = Vector2(
		get_viewport_rect().size.x / 2.0 - 250,
		get_viewport_rect().size.y / 2.0 - 145
	)
	add_child(rest_panel)

	var title := Label.new()
	title.text = "REST SITE"
	title.position = Vector2(150, 20)
	title.add_theme_font_size_override("font_size", 24)
	rest_panel.add_child(title)

	var run := GameManager.current_run
	var heal_amount: int = int(run.max_hp * 0.3)

	var rest_btn := Button.new()
	rest_btn.text = "Rest (Heal %d HP)" % heal_amount
	rest_btn.position = Vector2(50, 75)
	rest_btn.custom_minimum_size = Vector2(400, 40)
	rest_btn.pressed.connect(func():
		run.heal(heal_amount)
		_finish_rest()
	)
	rest_panel.add_child(rest_btn)

	var upgrade_btn := Button.new()
	upgrade_btn.text = "Upgrade a Card"
	upgrade_btn.position = Vector2(50, 125)
	upgrade_btn.custom_minimum_size = Vector2(400, 40)
	upgrade_btn.pressed.connect(_show_upgrade_choices)
	rest_panel.add_child(upgrade_btn)

	var remove_btn := Button.new()
	remove_btn.text = "Remove a Card"
	remove_btn.position = Vector2(50, 175)
	remove_btn.custom_minimum_size = Vector2(400, 40)
	remove_btn.pressed.connect(_show_remove_choices)
	rest_panel.add_child(remove_btn)

	var skip_btn := Button.new()
	skip_btn.text = "Skip (Continue)"
	skip_btn.position = Vector2(50, 225)
	skip_btn.custom_minimum_size = Vector2(400, 40)
	skip_btn.pressed.connect(_finish_rest)
	rest_panel.add_child(skip_btn)

func _finish_rest() -> void:
	var run := GameManager.current_run
	run.mark_node_complete(run.current_row, run.current_node_col)
	if rest_panel:
		rest_panel.queue_free()
		rest_panel = null
	_build_map()
	_update_info()
	GameManager.save_run()

func _show_upgrade_choices() -> void:
	if rest_panel:
		rest_panel.queue_free()
		rest_panel = null

	rest_panel = Panel.new()
	rest_panel.custom_minimum_size = Vector2(500, 400)
	rest_panel.position = Vector2(
		get_viewport_rect().size.x / 2.0 - 250,
		get_viewport_rect().size.y / 2.0 - 200
	)
	add_child(rest_panel)

	var title := Label.new()
	title.text = "CHOOSE CARD TO UPGRADE"
	title.position = Vector2(100, 15)
	title.add_theme_font_size_override("font_size", 20)
	rest_panel.add_child(title)

	var run := GameManager.current_run
	var y_pos: int = 55
	var shown: int = 0
	for i in run.deck.size():
		var card_id: String = run.deck[i]
		var card_data = GameManager.get_card_data(card_id)
		if not card_data or card_data.upgraded or card_data.upgrade_id == "":
			continue
		if shown >= 5:
			break
		var btn := Button.new()
		var upgrade_data = GameManager.get_card_data(card_data.upgrade_id)
		var upgrade_name: String = upgrade_data.display_name if upgrade_data else card_data.upgrade_id
		btn.text = "%s → %s" % [card_data.display_name, upgrade_name]
		btn.position = Vector2(30, y_pos)
		btn.custom_minimum_size = Vector2(440, 35)
		btn.pressed.connect(_do_upgrade.bind(i, card_data.upgrade_id))
		rest_panel.add_child(btn)
		y_pos += 45
		shown += 1

	if shown == 0:
		var no_label := Label.new()
		no_label.text = "No cards available to upgrade."
		no_label.position = Vector2(100, 80)
		rest_panel.add_child(no_label)

	var back_btn := Button.new()
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
	var run := GameManager.current_run
	if deck_index < run.deck.size():
		run.deck[deck_index] = upgrade_id
	_finish_rest()

func _show_remove_choices() -> void:
	if rest_panel:
		rest_panel.queue_free()
		rest_panel = null

	var run := GameManager.current_run

	rest_panel = Panel.new()
	rest_panel.custom_minimum_size = Vector2(500, 400)
	rest_panel.position = Vector2(
		get_viewport_rect().size.x / 2.0 - 250,
		get_viewport_rect().size.y / 2.0 - 200
	)
	add_child(rest_panel)

	var title := Label.new()
	title.text = "CHOOSE CARD TO REMOVE"
	title.position = Vector2(100, 15)
	title.add_theme_font_size_override("font_size", 20)
	rest_panel.add_child(title)

	if run.deck.size() <= 5:
		var warn := Label.new()
		warn.text = "Deck too small to remove cards (minimum 5)."
		warn.position = Vector2(50, 80)
		warn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
		rest_panel.add_child(warn)
	else:
		var y_pos: int = 55
		for i in run.deck.size():
			var card_id: String = run.deck[i]
			var card_data = GameManager.get_card_data(card_id)
			if not card_data:
				continue
			var btn := Button.new()
			var type_label: String = ""
			var type_color: Color = Color.WHITE
			match card_data.card_type:
				Enums.CardType.ATTACK:
					type_label = "Attack"
					type_color = Color(1.0, 0.4, 0.4)
				Enums.CardType.SKILL:
					type_label = "Skill"
					type_color = Color(0.4, 0.6, 1.0)
				Enums.CardType.POWER:
					type_label = "Power"
					type_color = Color(1.0, 0.85, 0.2)
				Enums.CardType.CURSE:
					type_label = "Curse"
					type_color = Color(0.6, 0.3, 0.8)
			btn.text = "%s  [%s]" % [card_data.display_name, type_label]
			btn.position = Vector2(30, y_pos)
			btn.custom_minimum_size = Vector2(440, 35)
			btn.add_theme_color_override("font_color", type_color)
			btn.pressed.connect(_do_remove.bind(i))
			rest_panel.add_child(btn)
			y_pos += 45

	var back_y: int = maxi(rest_panel.custom_minimum_size.y - 60, 310)
	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.position = Vector2(180, back_y)
	back_btn.custom_minimum_size = Vector2(140, 35)
	back_btn.pressed.connect(func():
		rest_panel.queue_free()
		rest_panel = null
		_show_rest()
	)
	rest_panel.add_child(back_btn)

func _do_remove(deck_index: int) -> void:
	var run := GameManager.current_run
	if deck_index < run.deck.size() and run.deck.size() > 5:
		run.deck.remove_at(deck_index)
	_finish_rest()

# ---------------------------------------------------------------------------
# Event / Shop
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Deck viewer
# ---------------------------------------------------------------------------
func _show_deck() -> void:
	if deck_viewer:
		deck_viewer.queue_free()
	deck_viewer = DeckViewerScene.instantiate()
	add_child(deck_viewer)
	deck_viewer.show_deck(GameManager.current_run.deck)

# ---------------------------------------------------------------------------
# Info bar
# ---------------------------------------------------------------------------
func _setup_relic_display() -> void:
	relic_display = RelicDisplayScene.instantiate()
	info_bar.add_child(relic_display)
	var run = GameManager.current_run
	if run:
		relic_display.update_relics(run.relics)

func _update_info() -> void:
	var run := GameManager.current_run
	if not run:
		return
	hp_label.text  = "HP: %d / %d" % [run.current_hp, run.max_hp]
	deck_label.text = "Deck: %d cards" % run.deck.size()
	act_label.text  = "ACT %d" % run.act
	if relic_display:
		relic_display.update_relics(run.relics)

# ---------------------------------------------------------------------------
# Inner class: line-drawing overlay
# Stores line segments and overrides _draw to render them each frame.
# ---------------------------------------------------------------------------
class _LineOverlay extends Control:
	var segments: Array = []

	func _draw() -> void:
		for seg in segments:
			draw_line(seg["from"], seg["to"], seg["color"], 2.5)
