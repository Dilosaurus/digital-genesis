extends Control

const EventScreenScene           = preload("res://scenes/ui/event_screen.tscn")
const ShopScreenScene            = preload("res://scenes/ui/shop_screen.tscn")
const DeckViewerScene            = preload("res://scenes/ui/deck_viewer.tscn")
const RelicDisplayScene          = preload("res://scenes/ui/relic_display.tscn")
const EquipmentScreenScene       = preload("res://scenes/ui/equipment_screen.tscn")
const GemSocketScreenScene       = preload("res://scenes/ui/gem_socket_screen.tscn")
const SkillTreeScreenScene       = preload("res://scenes/ui/skill_tree_screen.tscn")
const CorruptionShrineScreenScene = preload("res://scenes/ui/corruption_shrine_screen.tscn")

# Fonts
const FONT_MEDIEVAL  = preload("res://assets/fonts/MedievalSharp.ttf")
const FONT_MONO      = preload("res://assets/fonts/ShareTechMono-Regular.ttf")
const FONT_LATO      = preload("res://assets/fonts/Lato-Regular.ttf")
const FONT_LATO_BOLD = preload("res://assets/fonts/Lato-Bold.ttf")

var event_screen       = null
var shop_screen        = null
var equipment_screen   = null
var gem_socket_screen  = null
var skill_tree_screen  = null
var shrine_screen      = null
var deck_viewer        = null
var relic_display      = null

# Programmatic stat labels (created in _ready)
var souls_label: Label    = null
var crystals_label: Label = null
var level_label: Label    = null

# Map layout constants
const NODE_W        := 88     # button width
const NODE_H        := 56     # button height
const ROW_HEIGHT    := 120    # vertical pixels per row (bottom-to-top)
const COL_SPACING   := 130    # horizontal pixels between columns
const MAX_COLS      := 4      # max columns in a row
const CANVAS_MARGIN := 70     # padding around canvas edges

# Canvas and line-drawing overlay
var map_canvas: Control = null
var line_overlay: Control = null

# Node buttons: map_buttons[row][col_idx] -> Button
var map_buttons: Array = []

# Active pulse tweens on accessible buttons (cleared on rebuild)
var _pulse_tweens: Array = []

@onready var node_container: ScrollContainer = $NodeContainer
@onready var hp_label:       Label           = $TopBar/TopBarLayout/InfoBar/HPBlock/HPBarRow/HPLabel
@onready var hp_bar:         ProgressBar     = $TopBar/TopBarLayout/InfoBar/HPBlock/HPBar
@onready var deck_label:     Label           = $TopBar/TopBarLayout/InfoBar/StatsBlock/DeckLabel
@onready var gold_label:     Label           = $TopBar/TopBarLayout/InfoBar/StatsBlock/GoldLabel
@onready var relic_label:    Label           = $TopBar/TopBarLayout/InfoBar/StatsBlock/RelicLabel
@onready var act_label:      Label           = $TopBar/TopBarLayout/TitleBlock/ActLabel
@onready var info_bar:       HBoxContainer   = $TopBar/TopBarLayout/InfoBar
@onready var relic_holder:   HBoxContainer   = $TopBar/TopBarLayout/InfoBar/RelicDisplayHolder

# ---------------------------------------------------------------------------
# Type display helpers
# ---------------------------------------------------------------------------
const NODE_LABELS: Dictionary = {
	"fight":   "⚔  COMBAT",
	"elite":   "★  ELITE",
	"rest":    "☽  REST",
	"event":   "?  EVENT",
	"shop":    "$  SHOP",
	"boss":    "☠  BOSS",
	"forge":   "⚒  FORGE",
	"jeweler": "◆  JEWELER",
	"altar":   "✦  ALTAR",
	"shrine":  "⛧  SHRINE",
}

# Base accent color per encounter type
const NODE_COLORS: Dictionary = {
	"fight":   Color(0.90, 0.28, 0.28, 1.0),   # red
	"elite":   Color(0.95, 0.65, 0.10, 1.0),   # gold
	"rest":    Color(0.25, 0.85, 0.55, 1.0),   # teal-green
	"event":   Color(0.40, 0.75, 0.95, 1.0),   # sky blue
	"shop":    Color(0.90, 0.85, 0.20, 1.0),   # yellow
	"boss":    Color(0.85, 0.15, 0.85, 1.0),   # crimson-magenta
	"forge":   Color(0.90, 0.50, 0.18, 1.0),   # orange
	"jeweler": Color(0.40, 0.90, 0.90, 1.0),   # cyan
	"altar":   Color(0.78, 0.55, 1.00, 1.0),   # lavender
	"shrine":  Color(0.70, 0.15, 0.40, 1.0),   # deep rose
}

# Dark background tint per type (BG = accent darkened significantly)
const NODE_BG_COLORS: Dictionary = {
	"fight":   Color(0.18, 0.05, 0.05, 1.0),
	"elite":   Color(0.18, 0.12, 0.02, 1.0),
	"rest":    Color(0.04, 0.14, 0.09, 1.0),
	"event":   Color(0.05, 0.10, 0.18, 1.0),
	"shop":    Color(0.16, 0.15, 0.03, 1.0),
	"boss":    Color(0.18, 0.03, 0.18, 1.0),
	"forge":   Color(0.18, 0.09, 0.02, 1.0),
	"jeweler": Color(0.04, 0.14, 0.14, 1.0),
	"altar":   Color(0.12, 0.06, 0.20, 1.0),
	"shrine":  Color(0.14, 0.03, 0.08, 1.0),
}

# Tooltip descriptions for non-combat node types
const NODE_TOOLTIPS: Dictionary = {
	"rest":    "Heal, upgrade, or remove a card",
	"shop":    "Buy cards, relics, equipment, and gems",
	"event":   "Random narrative encounter",
	"forge":   "Upgrade equipment",
	"jeweler": "Socket gems into cards",
	"altar":   "Remove a card from your deck",
	"shrine":  "Corruption shrine — risk for power",
}

## Build a hover tooltip string for a given map node dictionary.
static func _build_node_tooltip(node: Dictionary) -> String:
	var ntype: String = node.get("type", "")
	# Combat-type nodes list the enemies
	if ntype in ["fight", "elite", "boss"]:
		var enemies: Array = node.get("enemies", [])
		if enemies.size() == 0:
			return "Unknown enemies"
		var names: PackedStringArray = PackedStringArray()
		for enemy_id in enemies:
			var path := "res://data/enemies/%s.tres" % enemy_id
			var enemy_data: EnemyData = load(path) if ResourceLoader.exists(path) else null
			if enemy_data:
				names.append(enemy_data.display_name)
			else:
				names.append(enemy_id.capitalize())
		return "Enemies: %s" % ", ".join(names)
	return NODE_TOOLTIPS.get(ntype, "")

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	map_canvas = $NodeContainer/MapCanvas

	# Apply ShareTechMono to stat labels so numbers look techy
	for lbl in [hp_label, deck_label, gold_label, relic_label]:
		lbl.add_theme_font_override("font", FONT_MONO)
	act_label.add_theme_font_override("font", FONT_LATO)

	var run := GameManager.current_run
	if run and run.map_data.size() == 0:
		run.map_data = RunState.generate_map(run.act)

	# Ensure DungeonManager is tracking (covers loaded saves and post-boss transitions)
	if DungeonManager.current_phase == DungeonManager.DungeonPhase.IDLE:
		DungeonManager.start_run()
	elif DungeonManager.current_phase == DungeonManager.DungeonPhase.BOSS_DEFEATED:
		DungeonManager.advance_act()

	# Color the gold label to match currency theme
	gold_label.add_theme_color_override("font_color", Color(1.00, 0.84, 0.0))

	# Create additional stat labels programmatically
	var stats_block = gold_label.get_parent()  # StatsBlock HBoxContainer

	souls_label = Label.new()
	souls_label.add_theme_font_override("font", FONT_MONO)
	souls_label.add_theme_font_size_override("font_size", 13)
	souls_label.add_theme_color_override("font_color", Color(0.70, 0.50, 1.00))  # purple for souls
	stats_block.add_child(souls_label)

	crystals_label = Label.new()
	crystals_label.add_theme_font_override("font", FONT_MONO)
	crystals_label.add_theme_font_size_override("font_size", 13)
	crystals_label.add_theme_color_override("font_color", Color(0.30, 0.85, 0.95))  # cyan for crystals
	stats_block.add_child(crystals_label)

	level_label = Label.new()
	level_label.add_theme_font_override("font", FONT_MONO)
	level_label.add_theme_font_size_override("font_size", 13)
	level_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.30))  # gold for level
	stats_block.add_child(level_label)

	_build_map()
	_update_info()
	_setup_relic_display()
	MusicManager.play_map_music(run.act if run else 1)
	GameManager.save_run()
	TransitionManager.fade_in(0.4)

	# "View Deck" button anchored top-right
	var deck_btn := _make_secondary_button("View Deck", Vector2(120, 34))
	deck_btn.position = Vector2(get_viewport_rect().size.x - 148, 14)
	add_child(deck_btn)
	deck_btn.pressed.connect(_show_deck)

# ---------------------------------------------------------------------------
# Map building
# ---------------------------------------------------------------------------
func _build_map() -> void:
	# Kill any leftover pulse tweens
	for t in _pulse_tweens:
		if is_instance_valid(t):
			t.kill()
	_pulse_tweens.clear()

	for child in map_canvas.get_children():
		child.queue_free()
	map_buttons.clear()
	line_overlay = null

	var run := GameManager.current_run
	if not run or run.map_data.size() == 0:
		return

	var map_data: Array = run.map_data
	var num_rows: int   = map_data.size()

	var canvas_w: float = MAX_COLS * COL_SPACING + CANVAS_MARGIN * 2
	var canvas_h: float = num_rows * ROW_HEIGHT + CANVAS_MARGIN * 2
	map_canvas.custom_minimum_size = Vector2(canvas_w, canvas_h)

	var accessible: Array = run.get_accessible_nodes()

	# Line overlay behind buttons
	var overlay := _LineOverlay.new()
	map_canvas.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_overlay = overlay

	for row_idx in num_rows:
		var row: Array = map_data[row_idx]
		var row_arr: Array = []

		var row_y: float = canvas_h - CANVAS_MARGIN - (row_idx + 1) * ROW_HEIGHT + (ROW_HEIGHT - NODE_H) / 2.0

		for node in row:
			var col: int      = node["col"]
			var row_size: int = row.size()

			var total_span: float = (row_size - 1) * COL_SPACING
			var start_x: float   = canvas_w / 2.0 - total_span / 2.0
			var node_x: float    = start_x + col * COL_SPACING - NODE_W / 2.0

			var btn := Button.new()
			btn.custom_minimum_size = Vector2(NODE_W, NODE_H)
			btn.position            = Vector2(node_x, row_y)
			btn.text                = NODE_LABELS.get(node["type"], node["type"].to_upper())
			btn.add_theme_font_override("font", FONT_MONO)
			btn.add_theme_font_size_override("font_size", 11)
			btn.clip_text = false

			var is_completed: bool  = run.is_node_completed(row_idx, col)
			btn.tooltip_text = "Completed" if is_completed else _build_node_tooltip(node)
			var is_accessible: bool = _is_in_accessible(row_idx, col, accessible)
			var is_current: bool    = (row_idx == run.current_row and col == run.current_node_col)

			_style_button(btn, node["type"], is_completed, is_accessible, is_current)

			if is_accessible and not is_completed:
				btn.pressed.connect(_on_node_selected_animated.bind(btn, row_idx, col))
				_start_pulse(btn)

			map_canvas.add_child(btn)
			row_arr.append({"col": col, "button": btn, "node": node, "row": row_idx})

		map_buttons.append(row_arr)

	_draw_lines(map_data, canvas_w, canvas_h, run, accessible)

func _is_in_accessible(row: int, col: int, accessible: Array) -> bool:
	for a in accessible:
		if a["row"] == row and a["col"] == col:
			return true
	return false

# ---------------------------------------------------------------------------
# Button styling
# ---------------------------------------------------------------------------
func _style_button(btn: Button, ntype: String, completed: bool, accessible: bool, is_current: bool) -> void:
	var accent: Color = NODE_COLORS.get(ntype, Color.WHITE)
	var bg: Color     = NODE_BG_COLORS.get(ntype, Color(0.08, 0.06, 0.14, 1.0))

	if completed or is_current:
		# Greyed out — already visited
		var grey_bg := _make_flat_style(Color(0.07, 0.06, 0.10, 0.70),
				Color(0.20, 0.18, 0.26, 0.50), 5, 1)
		btn.add_theme_stylebox_override("normal",   grey_bg)
		btn.add_theme_stylebox_override("hover",    grey_bg)
		btn.add_theme_stylebox_override("pressed",  grey_bg)
		btn.add_theme_stylebox_override("disabled", grey_bg)
		btn.add_theme_color_override("font_color",          Color(0.35, 0.33, 0.40, 0.55))
		btn.add_theme_color_override("font_disabled_color", Color(0.35, 0.33, 0.40, 0.55))
		btn.disabled = true
		btn.modulate = Color(1.0, 1.0, 1.0, 1.0)  # modulate handled by style opacity

	elif accessible:
		# Fully lit, clickable
		var sbox_normal  := _make_flat_style(bg, accent, 6, 2)
		var sbox_hover   := _make_flat_style(bg.lightened(0.12), accent.lightened(0.25), 6, 2)
		var sbox_pressed := _make_flat_style(bg.darkened(0.10), accent.darkened(0.10), 6, 2)
		btn.add_theme_stylebox_override("normal",  sbox_normal)
		btn.add_theme_stylebox_override("hover",   sbox_hover)
		btn.add_theme_stylebox_override("pressed", sbox_pressed)
		btn.add_theme_color_override("font_color",       accent.lightened(0.35))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
		btn.disabled = false
		btn.modulate = Color(1.0, 1.0, 1.0, 1.0)

	else:
		# Reachable eventually but not yet
		var dim_bg     := bg.darkened(0.35)
		var dim_border := accent.darkened(0.55)
		var sbox_dim   := _make_flat_style(dim_bg, dim_border, 5, 1)
		btn.add_theme_stylebox_override("normal",   sbox_dim)
		btn.add_theme_stylebox_override("hover",    sbox_dim)
		btn.add_theme_stylebox_override("pressed",  sbox_dim)
		btn.add_theme_stylebox_override("disabled", sbox_dim)
		btn.add_theme_color_override("font_color",          accent.darkened(0.45))
		btn.add_theme_color_override("font_disabled_color", accent.darkened(0.45))
		btn.disabled = true
		btn.modulate = Color(1.0, 1.0, 1.0, 0.70)

func _make_flat_style(bg_col: Color, border_col: Color, corner: int, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color            = bg_col
	s.border_color        = border_col
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(corner)
	s.content_margin_left   = 8.0
	s.content_margin_right  = 8.0
	s.content_margin_top    = 4.0
	s.content_margin_bottom = 4.0
	return s

# ---------------------------------------------------------------------------
# Glow pulse on accessible buttons
# ---------------------------------------------------------------------------
func _start_pulse(btn: Button) -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(btn, "modulate", Color(1.15, 1.12, 1.0, 1.0), 0.7) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(btn, "modulate", Color(0.88, 0.88, 0.95, 1.0), 0.7) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tweens.append(tween)

# ---------------------------------------------------------------------------
# Selection with scale-bounce animation
# ---------------------------------------------------------------------------
func _on_node_selected_animated(btn: Button, row: int, col: int) -> void:
	# Kill all pulse tweens so the button doesn't fight the selection anim
	for t in _pulse_tweens:
		if is_instance_valid(t):
			t.kill()
	_pulse_tweens.clear()

	SFXManager.play_button_click()
	# Brief scale bounce
	var tween := create_tween()
	tween.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.08) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.10) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	await tween.finished
	_on_node_selected(row, col)

# ---------------------------------------------------------------------------
# Line drawing — styled path overlay
# ---------------------------------------------------------------------------
var _line_segments: Array = []

func _draw_lines(map_data: Array, canvas_w: float, canvas_h: float, run: RunState, accessible: Array) -> void:
	_line_segments.clear()

	var num_rows: int = map_data.size()
	for row_idx in num_rows - 1:
		var cur_row: Array  = map_data[row_idx]
		var next_row: Array = map_data[row_idx + 1]
		var next_row_size: int = next_row.size()
		var cur_row_size: int  = cur_row.size()

		for node in cur_row:
			var col: int = node["col"]

			var cur_total_span: float = (cur_row_size - 1) * COL_SPACING
			var cur_start_x: float   = canvas_w / 2.0 - cur_total_span / 2.0
			var cur_cx: float        = cur_start_x + col * COL_SPACING
			var cur_row_y: float     = canvas_h - CANVAS_MARGIN - (row_idx + 1) * ROW_HEIGHT \
					+ (ROW_HEIGHT - NODE_H) / 2.0
			# from = top-centre of current button
			var from_pt := Vector2(cur_cx, cur_row_y)

			var is_cur_completed: bool  = run.is_node_completed(row_idx, col)
			var is_cur_accessible: bool = _is_in_accessible(row_idx, col, accessible)

			for next_col in node["connections"]:
				var next_total_span: float = (next_row_size - 1) * COL_SPACING
				var next_start_x: float   = canvas_w / 2.0 - next_total_span / 2.0
				var next_cx: float        = next_start_x + next_col * COL_SPACING
				var next_row_y: float     = canvas_h - CANVAS_MARGIN - (row_idx + 2) * ROW_HEIGHT \
						+ (ROW_HEIGHT - NODE_H) / 2.0 + NODE_H
				# to = bottom-centre of next button
				var to_pt := Vector2(next_cx, next_row_y)

				var is_next_accessible: bool = _is_in_accessible(row_idx + 1, next_col, accessible)

				var line_color: Color
				var line_width: float
				var dashed: bool

				if is_cur_completed:
					# walked path — dim solid
					line_color = Color(0.38, 0.35, 0.50, 0.55)
					line_width = 1.5
					dashed     = false
				elif is_next_accessible and not is_cur_completed:
					# available path ahead — bright gold dashed
					line_color = Color(0.90, 0.80, 0.35, 0.90)
					line_width = 2.5
					dashed     = true
				else:
					# future unreachable — very dim
					line_color = Color(0.22, 0.20, 0.30, 0.38)
					line_width = 1.5
					dashed     = false

				_line_segments.append({
					"from": from_pt, "to": to_pt,
					"color": line_color, "width": line_width, "dashed": dashed
				})

	if line_overlay and line_overlay is _LineOverlay:
		(line_overlay as _LineOverlay).segments = _line_segments
		line_overlay.queue_redraw()

func _on_overlay_draw() -> void:
	pass

# ---------------------------------------------------------------------------
# Node selection & routing
# ---------------------------------------------------------------------------
func _on_node_selected(row: int, col: int) -> void:
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

	# Route ALL room types through DungeonManager for state tracking
	DungeonManager.enter_room(row, col)

	match node["type"]:
		"rest":
			_show_rest()
		"event":
			_show_event()
		"shop":
			_show_shop()
		"forge":
			_show_forge()
		"jeweler":
			_show_jeweler()
		"altar":
			_show_altar()
		"shrine":
			_show_shrine()
		_:
			# Combat node — DungeonManager already set up enemies in GameManager
			GameManager.save_run()
			TransitionManager.transition_to_scene("res://scenes/combat/combat_scene.tscn")

# ---------------------------------------------------------------------------
# Rest site
# ---------------------------------------------------------------------------
var rest_panel: Panel = null

func _show_rest() -> void:
	rest_panel = _make_modal_panel(Vector2(550, 420))
	add_child(rest_panel)

	var title := _make_header_label("REST SITE", 22)
	title.position = Vector2(0, 14)
	title.size = Vector2(550, 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rest_panel.add_child(title)

	var run := GameManager.current_run
	var heal_amount: int = int(run.max_hp * 0.3)
	var y: int = 58

	# === Primary Actions (pick one, then rest ends) ===
	var section_label := Label.new()
	section_label.text = "— Choose One —"
	section_label.position = Vector2(0, y)
	section_label.size = Vector2(550, 24)
	section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section_label.add_theme_font_override("font", FONT_LATO)
	section_label.add_theme_font_size_override("font_size", 12)
	section_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	rest_panel.add_child(section_label)
	y += 30

	var rest_btn := _make_action_button("Rest  (Heal %d HP)" % heal_amount)
	rest_btn.position = Vector2(50, y)
	rest_btn.pressed.connect(func():
		run.heal(heal_amount)
		_finish_rest()
	)
	rest_panel.add_child(rest_btn)
	y += 44

	var upgrade_btn := _make_action_button("Upgrade a Card")
	upgrade_btn.position = Vector2(50, y)
	upgrade_btn.pressed.connect(_show_upgrade_choices)
	rest_panel.add_child(upgrade_btn)
	y += 44

	var remove_btn := _make_action_button("Remove a Card")
	remove_btn.position = Vector2(50, y)
	remove_btn.pressed.connect(_show_remove_choices)
	rest_panel.add_child(remove_btn)
	y += 50

	# === Secondary Actions (can do any of these, then continue) ===
	var sec_label := Label.new()
	sec_label.text = "— Also Available —"
	sec_label.position = Vector2(0, y)
	sec_label.size = Vector2(550, 24)
	sec_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sec_label.add_theme_font_override("font", FONT_LATO)
	sec_label.add_theme_font_size_override("font_size", 12)
	sec_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	rest_panel.add_child(sec_label)
	y += 28

	var equip_btn := _make_secondary_button("Equipment", Vector2(140, 34))
	equip_btn.position = Vector2(30, y)
	equip_btn.pressed.connect(_show_equipment_at_rest)
	rest_panel.add_child(equip_btn)

	var gem_btn := _make_secondary_button("Gems", Vector2(140, 34))
	gem_btn.position = Vector2(185, y)
	gem_btn.pressed.connect(_show_gems_at_rest)
	rest_panel.add_child(gem_btn)

	var skill_btn := _make_secondary_button("Skill Tree", Vector2(140, 34))
	skill_btn.position = Vector2(340, y)
	skill_btn.pressed.connect(_show_skill_tree_at_rest)
	rest_panel.add_child(skill_btn)
	y += 44

	var save_btn := _make_secondary_button("Save & Quit", Vector2(200, 34))
	save_btn.position = Vector2(175, y)
	save_btn.pressed.connect(_save_and_quit)
	rest_panel.add_child(save_btn)
	y += 44

	var skip_btn := _make_secondary_button("Skip  (Continue)", Vector2(400, 36))
	skip_btn.position = Vector2(75, y)
	skip_btn.pressed.connect(_finish_rest)
	rest_panel.add_child(skip_btn)

func _finish_rest() -> void:
	DungeonManager.exit_room(true)
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

	rest_panel = _make_modal_panel(Vector2(500, 400))
	add_child(rest_panel)

	var title := _make_header_label("CHOOSE CARD TO UPGRADE", 18)
	title.position = Vector2(0, 14)
	title.size = Vector2(500, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rest_panel.add_child(title)

	var run := GameManager.current_run
	var y_pos: int = 54
	var shown: int = 0
	for i in run.deck.size():
		var card_id: String  = run.deck[i]
		var card_data        = GameManager.get_card_data(card_id)
		if not card_data or card_data.upgraded or card_data.upgrade_id == "":
			continue
		if shown >= 5:
			break
		var btn := _make_action_button("")
		var upgrade_data = GameManager.get_card_data(card_data.upgrade_id)
		var upgrade_name: String = upgrade_data.display_name if upgrade_data else card_data.upgrade_id
		btn.text     = "%s  →  %s" % [card_data.display_name, upgrade_name]
		btn.position = Vector2(30, y_pos)
		btn.pressed.connect(_do_upgrade.bind(i, card_data.upgrade_id))
		rest_panel.add_child(btn)
		y_pos += 44
		shown += 1

	if shown == 0:
		var no_label := Label.new()
		no_label.text     = "No cards available to upgrade."
		no_label.position = Vector2(100, 80)
		no_label.add_theme_color_override("font_color", Color(0.60, 0.60, 0.70, 0.80))
		rest_panel.add_child(no_label)

	var back_btn := _make_secondary_button("Back", Vector2(140, 34))
	back_btn.position = Vector2(180, y_pos + 14)
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

	rest_panel = _make_modal_panel(Vector2(500, 400))
	add_child(rest_panel)

	var title := _make_header_label("CHOOSE CARD TO REMOVE", 18)
	title.position = Vector2(0, 14)
	title.size = Vector2(500, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rest_panel.add_child(title)

	if run.deck.size() <= 5:
		var warn := Label.new()
		warn.text     = "Deck too small to remove cards (minimum 5)."
		warn.position = Vector2(50, 80)
		warn.add_theme_color_override("font_color", Color(1.0, 0.55, 0.25, 1.0))
		rest_panel.add_child(warn)
	else:
		var y_pos: int = 54
		for i in run.deck.size():
			var card_id: String = run.deck[i]
			var card_data = GameManager.get_card_data(card_id)
			if not card_data:
				continue
			var btn := _make_action_button("")
			var type_label: String = ""
			var type_color: Color  = Color.WHITE
			match card_data.card_type:
				Enums.CardType.ATTACK:
					type_label = "Attack";  type_color = Color(1.0, 0.42, 0.42, 1.0)
				Enums.CardType.SKILL:
					type_label = "Skill";   type_color = Color(0.42, 0.62, 1.0, 1.0)
				Enums.CardType.POWER:
					type_label = "Power";   type_color = Color(1.0, 0.85, 0.22, 1.0)
				Enums.CardType.CURSE:
					type_label = "Curse";   type_color = Color(0.72, 0.28, 0.85, 1.0)
			btn.text     = "%s  [%s]" % [card_data.display_name, type_label]
			btn.position = Vector2(30, y_pos)
			btn.add_theme_color_override("font_color",       type_color)
			btn.add_theme_color_override("font_hover_color", type_color.lightened(0.3))
			btn.pressed.connect(_do_remove.bind(i))
			rest_panel.add_child(btn)
			y_pos += 44

	var back_y: int = maxi(rest_panel.custom_minimum_size.y - 60, 310)
	var back_btn := _make_secondary_button("Back", Vector2(140, 34))
	back_btn.position = Vector2(180, back_y)
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
# Rest site — secondary screen helpers
# ---------------------------------------------------------------------------
func _show_equipment_at_rest() -> void:
	if rest_panel:
		rest_panel.visible = false
	equipment_screen = EquipmentScreenScene.instantiate()
	add_child(equipment_screen)
	equipment_screen.show_equipment()
	equipment_screen.equipment_done.connect(func():
		equipment_screen.queue_free()
		equipment_screen = null
		if rest_panel:
			rest_panel.visible = true
	)

func _show_gems_at_rest() -> void:
	if rest_panel:
		rest_panel.visible = false
	gem_socket_screen = GemSocketScreenScene.instantiate()
	add_child(gem_socket_screen)
	gem_socket_screen.open_screen()
	gem_socket_screen.socketing_done.connect(func():
		gem_socket_screen.queue_free()
		gem_socket_screen = null
		if rest_panel:
			rest_panel.visible = true
	)

func _show_skill_tree_at_rest() -> void:
	if rest_panel:
		rest_panel.visible = false
	skill_tree_screen = SkillTreeScreenScene.instantiate()
	add_child(skill_tree_screen)
	skill_tree_screen.open_skill_tree()
	skill_tree_screen.skill_tree_done.connect(func():
		skill_tree_screen.queue_free()
		skill_tree_screen = null
		if rest_panel:
			rest_panel.visible = true
	)

func _save_and_quit() -> void:
	DungeonManager.exit_room(true)
	var run := GameManager.current_run
	if run:
		run.save_to_file()
	DungeonManager.reset()
	TransitionManager.transition_to_scene("res://scenes/main/main_menu.tscn")

# ---------------------------------------------------------------------------
# Event / Shop / sub-screens
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

func _show_forge() -> void:
	equipment_screen = EquipmentScreenScene.instantiate()
	add_child(equipment_screen)
	equipment_screen.show_equipment()
	equipment_screen.equipment_done.connect(func():
		equipment_screen.queue_free()
		equipment_screen = null
		_finish_rest()
	)

func _show_jeweler() -> void:
	gem_socket_screen = GemSocketScreenScene.instantiate()
	add_child(gem_socket_screen)
	gem_socket_screen.open_screen()
	gem_socket_screen.socketing_done.connect(func():
		gem_socket_screen.queue_free()
		gem_socket_screen = null
		_finish_rest()
	)

func _show_altar() -> void:
	skill_tree_screen = SkillTreeScreenScene.instantiate()
	add_child(skill_tree_screen)
	skill_tree_screen.open_skill_tree()
	skill_tree_screen.skill_tree_done.connect(func():
		skill_tree_screen.queue_free()
		skill_tree_screen = null
		_finish_rest()
	)

func _show_shrine() -> void:
	shrine_screen = CorruptionShrineScreenScene.instantiate()
	add_child(shrine_screen)
	shrine_screen.open_shrine()
	shrine_screen.shrine_done.connect(func():
		shrine_screen.queue_free()
		shrine_screen = null
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
	relic_holder.add_child(relic_display)
	var run = GameManager.current_run
	if run:
		relic_display.update_relics(run.relics)

func _update_info() -> void:
	var run := GameManager.current_run
	if not run:
		return

	# HP bar + label
	hp_label.text = "%d / %d" % [run.current_hp, run.max_hp]
	hp_bar.max_value = run.max_hp
	hp_bar.value     = run.current_hp

	# Gold
	gold_label.text  = "⬡ %d" % run.gold

	# Deck size
	deck_label.text  = "⧉ %d" % run.deck.size()

	# Relic count
	relic_label.text = "✦ %d" % run.relics.size()

	# Souls
	if souls_label:
		souls_label.text = "Souls: %d" % run.souls

	# Crystals
	if crystals_label:
		crystals_label.text = "Crystals: %d" % run.crystals

	# Level / XP
	if level_label:
		var xp_next = LevelSystem.xp_to_next_level(run)
		if run.level >= LevelSystem.MAX_LEVEL:
			level_label.text = "Lv.%d (MAX)" % run.level
		else:
			level_label.text = "Lv.%d (%d XP to next)" % [run.level, xp_next]

	# Act label with themed name
	match run.act:
		1: act_label.text = "Act 1: Corrupted Server Farm"
		2: act_label.text = "Act 2: Neural Cathedral"
		3: act_label.text = "Act 3: The Void Core"
		_: act_label.text = "Act %d" % run.act
	act_label.text += "  —  FLOOR %d" % maxi(run.current_row + 1, 0)

	if relic_display:
		relic_display.update_relics(run.relics)

# ---------------------------------------------------------------------------
# UI helpers — shared factory methods for consistent styling
# ---------------------------------------------------------------------------

func _make_modal_panel(size: Vector2) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = size
	p.position = Vector2(
		get_viewport_rect().size.x / 2.0 - size.x / 2.0,
		get_viewport_rect().size.y / 2.0 - size.y / 2.0
	)
	# Styled background matching theme
	var sbox := StyleBoxFlat.new()
	sbox.bg_color     = Color(0.06, 0.04, 0.13, 0.97)
	sbox.border_color = Color(0.40, 0.32, 0.70, 0.85)
	sbox.set_border_width_all(2)
	sbox.set_corner_radius_all(8)
	sbox.content_margin_left   = 14.0
	sbox.content_margin_right  = 14.0
	sbox.content_margin_top    = 14.0
	sbox.content_margin_bottom = 14.0
	p.add_theme_stylebox_override("panel", sbox)
	return p

func _make_header_label(text_val: String, size: int) -> Label:
	var l := Label.new()
	l.text = text_val
	l.add_theme_font_override("font", FONT_MEDIEVAL)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0, 1.0))
	return l

func _make_action_button(text_val: String) -> Button:
	var btn := Button.new()
	btn.text = text_val
	btn.custom_minimum_size = Vector2(400, 38)
	btn.add_theme_font_override("font", FONT_LATO_BOLD)
	btn.add_theme_font_size_override("font_size", 14)
	# Green-tinted action style
	var s_normal := _make_flat_style(Color(0.06, 0.14, 0.08, 0.92), Color(0.25, 0.65, 0.30, 0.85), 6, 2)
	var s_hover  := _make_flat_style(Color(0.10, 0.24, 0.13, 1.0),  Color(0.38, 0.90, 0.42, 1.0),  6, 2)
	var s_press  := _make_flat_style(Color(0.04, 0.10, 0.06, 1.0),  Color(0.22, 0.55, 0.26, 1.0),  6, 2)
	btn.add_theme_stylebox_override("normal",  s_normal)
	btn.add_theme_stylebox_override("hover",   s_hover)
	btn.add_theme_stylebox_override("pressed", s_press)
	btn.add_theme_color_override("font_color",       Color(0.72, 1.0, 0.76, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	return btn

func _make_secondary_button(text_val: String, min_size: Vector2 = Vector2(120, 34)) -> Button:
	var btn := Button.new()
	btn.text = text_val
	btn.custom_minimum_size = min_size
	btn.add_theme_font_override("font", FONT_LATO)
	btn.add_theme_font_size_override("font_size", 13)
	# Purple-tinted secondary style
	var s_normal := _make_flat_style(Color(0.10, 0.08, 0.22, 0.90), Color(0.35, 0.30, 0.62, 0.80), 6, 1)
	var s_hover  := _make_flat_style(Color(0.18, 0.14, 0.38, 1.0),  Color(0.55, 0.45, 0.92, 1.0),  6, 2)
	var s_press  := _make_flat_style(Color(0.08, 0.06, 0.18, 1.0),  Color(0.42, 0.36, 0.75, 1.0),  6, 1)
	btn.add_theme_stylebox_override("normal",  s_normal)
	btn.add_theme_stylebox_override("hover",   s_hover)
	btn.add_theme_stylebox_override("pressed", s_press)
	btn.add_theme_color_override("font_color",       Color(0.80, 0.85, 1.0, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	return btn

# ---------------------------------------------------------------------------
# Inner class: line-drawing overlay
# Draws solid or dashed styled paths between nodes.
# ---------------------------------------------------------------------------
class _LineOverlay extends Control:
	var segments: Array = []

	func _draw() -> void:
		for seg in segments:
			var from_pt: Vector2 = seg["from"]
			var to_pt: Vector2   = seg["to"]
			var col: Color       = seg["color"]
			var w: float         = seg.get("width", 2.0)
			var dashed: bool     = seg.get("dashed", false)

			if dashed:
				_draw_dashed(from_pt, to_pt, col, w)
			else:
				draw_line(from_pt, to_pt, col, w, true)

	func _draw_dashed(from_pt: Vector2, to_pt: Vector2, col: Color, width: float) -> void:
		var total_len: float = from_pt.distance_to(to_pt)
		if total_len < 1.0:
			return
		var dir: Vector2    = (to_pt - from_pt).normalized()
		var dash_len: float = 8.0
		var gap_len: float  = 5.0
		var traveled: float = 0.0
		while traveled < total_len:
			var seg_end: float = minf(traveled + dash_len, total_len)
			draw_line(from_pt + dir * traveled, from_pt + dir * seg_end, col, width, true)
			traveled = seg_end + gap_len
