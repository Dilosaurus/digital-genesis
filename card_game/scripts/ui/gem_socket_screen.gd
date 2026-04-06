extends Control

signal socketing_done

# ---------------------------------------------------------------------------
# Rarity palette
# ---------------------------------------------------------------------------
const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Legendary"]

const RARITY_COLORS: Array[Color] = [
	Color(0.75, 0.75, 0.78),  # Common
	Color(0.35, 0.80, 0.45),  # Uncommon
	Color(0.30, 0.55, 1.00),  # Rare
	Color(1.00, 0.75, 0.15),  # Legendary
]

# Socket-type indicator colors
const SOCKET_COLOR_RED   := Color(1.00, 0.35, 0.35, 1.00)
const SOCKET_COLOR_BLUE  := Color(0.35, 0.65, 1.00, 1.00)
const SOCKET_COLOR_GREEN := Color(0.35, 0.90, 0.50, 1.00)
const SOCKET_COLOR_EMPTY := Color(0.40, 0.38, 0.55, 0.70)

# Left-column card button style helpers
const CARD_BTN_NORMAL_BG     := Color(0.07, 0.05, 0.15, 0.80)
const CARD_BTN_NORMAL_BORDER := Color(0.28, 0.24, 0.45, 0.55)
const CARD_BTN_SEL_BG        := Color(0.14, 0.10, 0.28, 1.00)
const CARD_BTN_SEL_BORDER    := Color(0.55, 0.45, 0.90, 1.00)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var _selected_card_id: String = ""

# ---------------------------------------------------------------------------
# Node refs — matched to gem_socket_screen.tscn
# ---------------------------------------------------------------------------
@onready var _card_list: VBoxContainer = $Panel/ContentLayout/LeftPane/CardListScroll/CardList
@onready var _gem_panel: VBoxContainer = $Panel/ContentLayout/RightPane/GemPanel
@onready var _done_button: Button = $Panel/ButtonRow/DoneButton

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	visible = false
	_done_button.pressed.connect(func() -> void:
		visible = false
		socketing_done.emit()
	)


func open_screen() -> void:
	_selected_card_id = ""
	_build_card_list()
	_build_gem_panel()
	visible = true


# ---------------------------------------------------------------------------
# Left panel — card list
# ---------------------------------------------------------------------------
func _build_card_list() -> void:
	for child in _card_list.get_children():
		child.queue_free()

	# Section header
	var header := Label.new()
	header.text = "SOCKETABLE CARDS"
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(0.45, 0.85, 1.00, 0.75))
	_card_list.add_child(header)

	var sep := HSeparator.new()
	_card_list.add_child(sep)

	var run := GameManager.current_run
	if not run:
		return

	var has_any := false
	for card_id in run.deck:
		var cd: CardData = GameManager.get_card_data(card_id)
		if not cd or cd.gem_sockets <= 0:
			continue
		has_any = true

		var is_selected := (card_id == _selected_card_id)
		var btn := Button.new()
		btn.text = _card_list_label(run, card_id, cd)
		btn.custom_minimum_size = Vector2(0, 44)
		btn.clip_text = false
		btn.autowrap_mode = TextServer.AUTOWRAP_OFF
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 13)

		# Inline style override to show selection
		var sb := StyleBoxFlat.new()
		sb.bg_color = CARD_BTN_SEL_BG if is_selected else CARD_BTN_NORMAL_BG
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = CARD_BTN_SEL_BORDER if is_selected else CARD_BTN_NORMAL_BORDER
		sb.corner_radius_top_left = 5
		sb.corner_radius_top_right = 5
		sb.corner_radius_bottom_right = 5
		sb.corner_radius_bottom_left = 5
		sb.content_margin_left = 10.0
		sb.content_margin_top = 5.0
		sb.content_margin_right = 8.0
		sb.content_margin_bottom = 5.0
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("pressed", sb)

		if is_selected:
			btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5, 1.0))

		btn.pressed.connect(_select_card.bind(card_id))
		_card_list.add_child(btn)

	if not has_any:
		var lbl := Label.new()
		lbl.text = "No socketable cards\nin your deck."
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55, 0.90))
		_card_list.add_child(lbl)


func _card_list_label(run: RunState, card_id: String, cd: CardData) -> String:
	var slots: Array = run.gem_assignments.get(card_id, [])
	var socket_str := ""
	for i in cd.gem_sockets:
		if i < slots.size():
			socket_str += "◆"
		else:
			socket_str += "○"
	return "%s  %s" % [cd.display_name, socket_str]


# ---------------------------------------------------------------------------
# Right panel — gem management for selected card
# ---------------------------------------------------------------------------
func _build_gem_panel() -> void:
	for child in _gem_panel.get_children():
		child.queue_free()

	if _selected_card_id == "":
		_build_empty_state_hint()
		return

	var run := GameManager.current_run
	var cd: CardData = GameManager.get_card_data(_selected_card_id)
	if not cd:
		return

	# Card header
	var name_lbl := Label.new()
	name_lbl.text = cd.display_name
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7, 1.0))
	_gem_panel.add_child(name_lbl)

	if cd.description != "":
		var desc_lbl := Label.new()
		desc_lbl.text = cd.description
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", Color(0.70, 0.70, 0.78, 1.0))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_gem_panel.add_child(desc_lbl)

	var header_sep := HSeparator.new()
	_gem_panel.add_child(header_sep)

	# Socket count sub-header
	var slots: Array = run.gem_assignments.get(_selected_card_id, [])
	var slots_lbl := Label.new()
	slots_lbl.text = "SOCKETS  %d / %d" % [slots.size(), cd.gem_sockets]
	slots_lbl.add_theme_font_size_override("font_size", 11)
	slots_lbl.add_theme_color_override("font_color", Color(0.45, 0.85, 1.00, 0.80))
	_gem_panel.add_child(slots_lbl)

	# Socket rows
	for i in cd.gem_sockets:
		if i < slots.size():
			_build_filled_slot(i, slots[i])
		else:
			_build_empty_slot(i)


func _build_empty_state_hint() -> void:
	var hint := Label.new()
	hint.text = "Select a card on the left\nto manage its gem sockets."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.50, 0.50, 0.62, 0.90))
	_gem_panel.add_child(hint)


func _build_filled_slot(slot_index: int, gem_id: String) -> void:
	var gem: GemData = GemSystem.get_gem(gem_id)

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 40)
	row.add_theme_constant_override("separation", 8)
	_gem_panel.add_child(row)

	# Colored socket indicator
	var socket_dot := Label.new()
	socket_dot.text = "◆"
	socket_dot.add_theme_font_size_override("font_size", 16)
	socket_dot.add_theme_color_override("font_color", _gem_socket_color(gem))
	socket_dot.custom_minimum_size = Vector2(20, 0)
	row.add_child(socket_dot)

	# Gem name + description
	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 1)
	row.add_child(info_col)

	if gem:
		var gem_name := Label.new()
		gem_name.text = gem.display_name
		gem_name.add_theme_font_size_override("font_size", 13)
		gem_name.add_theme_color_override("font_color", _rarity_color(gem.rarity))
		info_col.add_child(gem_name)

		var gem_desc := Label.new()
		gem_desc.text = gem.description
		gem_desc.add_theme_font_size_override("font_size", 11)
		gem_desc.add_theme_color_override("font_color", Color(0.60, 0.60, 0.68, 1.0))
		gem_desc.clip_text = true
		info_col.add_child(gem_desc)
	else:
		var unknown := Label.new()
		unknown.text = "(unknown gem)"
		unknown.add_theme_font_size_override("font_size", 13)
		unknown.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55, 1.0))
		info_col.add_child(unknown)

	var unsocket_btn := Button.new()
	unsocket_btn.text = "Unsocket"
	unsocket_btn.custom_minimum_size = Vector2(82, 28)
	unsocket_btn.add_theme_font_size_override("font_size", 12)
	unsocket_btn.pressed.connect(_on_unsocket.bind(slot_index))
	row.add_child(unsocket_btn)


func _build_empty_slot(slot_index: int) -> void:
	var run := GameManager.current_run

	# Empty socket header
	var empty_row := HBoxContainer.new()
	empty_row.custom_minimum_size = Vector2(0, 34)
	empty_row.add_theme_constant_override("separation", 8)
	_gem_panel.add_child(empty_row)

	var empty_dot := Label.new()
	empty_dot.text = "○"
	empty_dot.add_theme_font_size_override("font_size", 16)
	empty_dot.add_theme_color_override("font_color", SOCKET_COLOR_EMPTY)
	empty_dot.custom_minimum_size = Vector2(20, 0)
	empty_row.add_child(empty_dot)

	var empty_lbl := Label.new()
	empty_lbl.text = "Empty Socket — select a gem below"
	empty_lbl.add_theme_font_size_override("font_size", 13)
	empty_lbl.add_theme_color_override("font_color", Color(0.50, 0.50, 0.60, 0.80))
	empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empty_row.add_child(empty_lbl)

	if not run or run.gems.is_empty():
		var no_gems := Label.new()
		no_gems.text = "    No gems in inventory."
		no_gems.add_theme_font_size_override("font_size", 12)
		no_gems.add_theme_color_override("font_color", Color(0.40, 0.40, 0.50, 0.80))
		_gem_panel.add_child(no_gems)
		return

	# Grid of available gems
	var gems_header := Label.new()
	gems_header.text = "Available Gems:"
	gems_header.add_theme_font_size_override("font_size", 11)
	gems_header.add_theme_color_override("font_color", Color(0.45, 0.85, 1.00, 0.70))
	_gem_panel.add_child(gems_header)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	_gem_panel.add_child(grid)

	var shown: Array[String] = []
	for gem_id in run.gems:
		if gem_id in shown:
			continue
		shown.append(gem_id)

		var gem: GemData = GemSystem.get_gem(gem_id)
		if not gem:
			continue

		var count := _count_gem_in_inventory(run, gem_id)
		var gem_btn := Button.new()
		gem_btn.custom_minimum_size = Vector2(180, 36)
		gem_btn.add_theme_font_size_override("font_size", 12)
		gem_btn.tooltip_text = "%s\n%s\n%s" % [
			gem.display_name,
			RARITY_NAMES[clampi(gem.rarity, 0, RARITY_NAMES.size() - 1)],
			gem.description,
		]
		gem_btn.add_theme_color_override("font_color", _rarity_color(gem.rarity))

		var count_suffix: String = ("  x%d" % count) if count > 1 else ""
		gem_btn.text = "%s%s" % [gem.display_name, count_suffix]

		# Capture for lambda
		var captured_gem_id := gem_id
		gem_btn.pressed.connect(_on_socket.bind(captured_gem_id))
		grid.add_child(gem_btn)


# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------
func _select_card(card_id: String) -> void:
	_selected_card_id = card_id
	_build_card_list()
	_build_gem_panel()


func _on_socket(gem_id: String) -> void:
	var run := GameManager.current_run
	if not run:
		return
	var success := GemSystem.socket_gem(run, _selected_card_id, gem_id)
	if success:
		_build_card_list()
		_build_gem_panel()


func _on_unsocket(slot_index: int) -> void:
	var run := GameManager.current_run
	if not run:
		return
	GemSystem.unsocket_gem(run, _selected_card_id, slot_index)
	_build_card_list()
	_build_gem_panel()


# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------
func _count_gem_in_inventory(run: RunState, gem_id: String) -> int:
	var count := 0
	for g in run.gems:
		if g == gem_id:
			count += 1
	return count


func _gem_socket_color(gem: GemData) -> Color:
	if not gem:
		return SOCKET_COLOR_EMPTY
	# Color by gem rarity as a proxy for socket type
	match gem.rarity:
		1: return SOCKET_COLOR_GREEN
		2: return SOCKET_COLOR_BLUE
		3: return Color(1.00, 0.75, 0.15, 1.0)
		_: return SOCKET_COLOR_RED


func _rarity_color(rarity: int) -> Color:
	return RARITY_COLORS[clampi(rarity, 0, RARITY_COLORS.size() - 1)]
