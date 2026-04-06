## deck_viewer.gd
## Overlay panel that displays the player's current deck in a scrollable card grid.
## Supports filter by card type and sort by cost / type / name.
## Shows a styled tooltip on card hover.
extends Control

signal closed

# ---------------------------------------------------------------------------
# Card type enum mapping (mirrors card_data.gd CardType enum)
# ---------------------------------------------------------------------------
const TYPE_ATTACK := 0
const TYPE_SKILL  := 1
const TYPE_POWER  := 2
const TYPE_CURSE  := 3

# Sort modes
enum SortMode { NAME, COST, TYPE }

# ---------------------------------------------------------------------------
# Node references — match deck_viewer.tscn structure exactly
# ---------------------------------------------------------------------------
@onready var title_label: Label        = $Panel/Header/TitleLabel
@onready var count_label: Label        = $Panel/Header/CountLabel
@onready var card_grid: GridContainer  = $Panel/ScrollContainer/CardGrid
@onready var close_btn: Button         = $Panel/Footer/CloseButton
@onready var tooltip_panel: Panel      = $Panel/CardTooltip
@onready var tooltip_name: Label       = $Panel/CardTooltip/TooltipName
@onready var tooltip_cost: Label       = $Panel/CardTooltip/TooltipCost
@onready var tooltip_type: Label       = $Panel/CardTooltip/TooltipType
@onready var tooltip_desc: RichTextLabel = $Panel/CardTooltip/TooltipDesc

# Filter buttons
@onready var filter_all: Button    = $Panel/FilterBar/FilterRow/FilterAll
@onready var filter_attack: Button = $Panel/FilterBar/FilterRow/FilterAttack
@onready var filter_skill: Button  = $Panel/FilterBar/FilterRow/FilterSkill
@onready var filter_power: Button  = $Panel/FilterBar/FilterRow/FilterPower
@onready var filter_curse: Button  = $Panel/FilterBar/FilterRow/FilterCurse

# Sort buttons
@onready var sort_cost: Button = $Panel/FilterBar/FilterRow/SortCost
@onready var sort_type: Button = $Panel/FilterBar/FilterRow/SortType
@onready var sort_name: Button = $Panel/FilterBar/FilterRow/SortName

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
const CARD_VISUAL_SCENE := preload("res://scenes/cards/card_visual.tscn")
const FONT_MEDIEVAL = preload("res://assets/fonts/MedievalSharp.ttf")
const FONT_MONO = preload("res://assets/fonts/ShareTechMono-Regular.ttf")
const FONT_LATO = preload("res://assets/fonts/Lato-Regular.ttf")

# Color accents per type (matches UIConstants)
const TYPE_COLORS := {
	TYPE_ATTACK: Color(1.0,  0.45, 0.35, 1.0),
	TYPE_SKILL:  Color(0.40, 0.70, 1.00, 1.0),
	TYPE_POWER:  Color(0.95, 0.75, 0.25, 1.0),
	TYPE_CURSE:  Color(0.75, 0.35, 0.90, 1.0),
}

const TYPE_NAMES := {
	TYPE_ATTACK: "ATTACK",
	TYPE_SKILL:  "SKILL",
	TYPE_POWER:  "POWER",
	TYPE_CURSE:  "CURSE",
}

var _full_deck: Array       = []   # all card ids from show_deck()
var _active_filter: int     = -1   # -1 = All, else CardType value
var _sort_mode: SortMode    = SortMode.NAME
# Track active sort button for visual state
var _active_sort_btn: Button = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(_on_close_pressed)

	# Apply design-system fonts to header labels
	title_label.add_theme_font_override("font", FONT_MEDIEVAL)
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

	count_label.add_theme_font_override("font", FONT_MONO)
	count_label.add_theme_font_size_override("font_size", 16)
	count_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))

	# Tooltip label fonts
	tooltip_name.add_theme_font_override("font", FONT_MEDIEVAL)
	tooltip_name.add_theme_font_size_override("font_size", 18)

	tooltip_cost.add_theme_font_override("font", FONT_MONO)
	tooltip_cost.add_theme_font_size_override("font_size", 14)
	tooltip_cost.add_theme_color_override("font_color", Color(0.40, 0.75, 1.00))

	tooltip_type.add_theme_font_override("font", FONT_MONO)
	tooltip_type.add_theme_font_size_override("font_size", 13)

	# Filter buttons
	filter_all.pressed.connect(func(): _set_filter(-1))
	filter_attack.pressed.connect(func(): _set_filter(TYPE_ATTACK))
	filter_skill.pressed.connect(func(): _set_filter(TYPE_SKILL))
	filter_power.pressed.connect(func(): _set_filter(TYPE_POWER))
	filter_curse.pressed.connect(func(): _set_filter(TYPE_CURSE))

	# Sort buttons
	sort_name.pressed.connect(func(): _set_sort(SortMode.NAME, sort_name))
	sort_cost.pressed.connect(func(): _set_sort(SortMode.COST, sort_cost))
	sort_type.pressed.connect(func(): _set_sort(SortMode.TYPE, sort_type))

	# Mark Name as the initial active sort
	_active_sort_btn = sort_name
	_apply_sort_highlight()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			_on_close_pressed()
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func show_deck(deck: Array) -> void:
	_full_deck = deck.duplicate()
	_active_filter = -1
	_sort_mode = SortMode.NAME
	filter_all.button_pressed = true
	filter_attack.button_pressed = false
	filter_skill.button_pressed = false
	filter_power.button_pressed = false
	filter_curse.button_pressed = false
	sort_name.button_pressed = true
	sort_cost.button_pressed = false
	sort_type.button_pressed = false
	_active_sort_btn = sort_name
	_apply_sort_highlight()

	count_label.text = "%d cards" % deck.size()
	_rebuild_grid()
	tooltip_panel.visible = false
	visible = true

# ---------------------------------------------------------------------------
# Filter / sort logic
# ---------------------------------------------------------------------------

func _set_filter(type_value: int) -> void:
	_active_filter = type_value
	# Sync toggle visual state
	filter_all.button_pressed    = (type_value == -1)
	filter_attack.button_pressed = (type_value == TYPE_ATTACK)
	filter_skill.button_pressed  = (type_value == TYPE_SKILL)
	filter_power.button_pressed  = (type_value == TYPE_POWER)
	filter_curse.button_pressed  = (type_value == TYPE_CURSE)
	tooltip_panel.visible = false
	_rebuild_grid()

func _set_sort(mode: SortMode, btn: Button) -> void:
	_sort_mode = mode
	sort_name.button_pressed = (mode == SortMode.NAME)
	sort_cost.button_pressed = (mode == SortMode.COST)
	sort_type.button_pressed = (mode == SortMode.TYPE)
	_active_sort_btn = btn
	_apply_sort_highlight()
	tooltip_panel.visible = false
	_rebuild_grid()

func _apply_sort_highlight() -> void:
	# The active sort button gets the accent colour override; others reset.
	for btn in [sort_name, sort_cost, sort_type]:
		if btn == _active_sort_btn:
			btn.add_theme_color_override("font_color", Color(0.45, 0.85, 1.00, 1.00))
		else:
			btn.remove_theme_color_override("font_color")

# ---------------------------------------------------------------------------
# Grid population
# ---------------------------------------------------------------------------

func _rebuild_grid() -> void:
	# Clear existing card nodes
	for child in card_grid.get_children():
		child.queue_free()

	var run := GameManager.current_run

	# Build card data list with count
	var counts: Dictionary = {}
	for card_id in _full_deck:
		counts[card_id] = counts.get(card_id, 0) + 1

	# Gather entries with full metadata
	var entries: Array = []
	for card_id in counts.keys():
		var card_data = GameManager.get_card_data(card_id)
		if not card_data:
			continue
		# Apply filter
		if _active_filter != -1 and card_data.card_type != _active_filter:
			continue
		var is_shrine := run != null and CardCorruption.is_shrine_corrupted(card_id, run)
		entries.append({
			"id":         card_id,
			"data":       card_data,
			"count":      counts[card_id],
			"is_shrine":  is_shrine,
		})

	# Sort
	match _sort_mode:
		SortMode.NAME:
			entries.sort_custom(func(a, b): return a["data"].display_name < b["data"].display_name)
		SortMode.COST:
			var _cmp_cost := func(a: Dictionary, b: Dictionary) -> bool:
				if a["data"].energy_cost != b["data"].energy_cost:
					return a["data"].energy_cost < b["data"].energy_cost
				return a["data"].display_name < b["data"].display_name
			entries.sort_custom(_cmp_cost)
		SortMode.TYPE:
			var _cmp_type := func(a: Dictionary, b: Dictionary) -> bool:
				if a["data"].card_type != b["data"].card_type:
					return a["data"].card_type < b["data"].card_type
				return a["data"].display_name < b["data"].display_name
			entries.sort_custom(_cmp_type)

	# Instantiate a card visual for each entry (one per unique id; count shown as badge)
	for entry in entries:
		var card_data = entry["data"]
		var is_shrine: bool = entry["is_shrine"]

		var sc: Dictionary = CardCorruption.get_shrine_corruption(entry["id"]) if is_shrine else {}

		var display_name: String = card_data.display_name
		var description: String  = card_data.description
		if is_shrine and not sc.is_empty():
			display_name = sc.get("display_name", display_name) + " [C]"
			description  = sc.get("description", description)

		var card_node = CARD_VISUAL_SCENE.instantiate()
		# Scale down slightly so 4 fit comfortably in 700px minus padding/separators
		# 700 - 2*10(scroll pad) - 3*10(gap) = 650 / 4 = 162.5 → keep native 160
		card_node.custom_minimum_size = Vector2(160, 224)
		card_grid.add_child(card_node)

		# Populate via card_visual's standard API
		if card_node.has_method("setup"):
			card_node.setup(entry["id"], card_data)
		elif card_node.has_method("set_card_data"):
			card_node.set_card_data(card_data)

		# Corruption tint
		if is_shrine:
			card_node.modulate = Color(0.90, 0.65, 1.00, 1.00)

		# Count badge — only if > 1
		if entry["count"] > 1:
			var badge := Label.new()
			badge.text = "×%d" % entry["count"]
			badge.add_theme_font_override("font", FONT_MONO)
			badge.add_theme_font_size_override("font_size", 13)
			badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			badge.vertical_alignment   = VERTICAL_ALIGNMENT_TOP
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			badge.offset_right  = -6.0
			badge.offset_top    = 4.0
			card_node.add_child(badge)

		# Hover connections — capture variables for the lambda
		var tip_name: String   = display_name
		var tip_cost: int      = card_data.energy_cost
		var tip_type: int      = card_data.card_type
		var tip_desc: String   = description
		var tip_shrine: bool   = is_shrine

		card_node.mouse_entered.connect(
			func(): _show_tooltip(card_node, tip_name, tip_cost, tip_type, tip_desc, tip_shrine))
		card_node.mouse_exited.connect(func(): tooltip_panel.visible = false)

# ---------------------------------------------------------------------------
# Tooltip
# ---------------------------------------------------------------------------

func _show_tooltip(card_node: Control, name: String, cost: int,
		type: int, desc: String, is_shrine: bool) -> void:
	tooltip_name.text = name + (" (Corrupted)" if is_shrine else "")

	var type_color: Color
	if is_shrine:
		type_color = Color(0.85, 0.25, 0.90, 1.0)
	else:
		type_color = TYPE_COLORS.get(type, Color(0.75, 0.75, 0.78, 1.0))

	tooltip_name.add_theme_color_override("font_color", type_color)
	tooltip_cost.text = "Cost: %d" % cost
	tooltip_type.text = TYPE_NAMES.get(type, "UNKNOWN")
	tooltip_type.add_theme_color_override("font_color", type_color)
	tooltip_desc.text = desc

	# Position tooltip to the right of the card node; clamp to panel bounds
	var card_global: Rect2  = card_node.get_global_rect()
	var panel_global: Rect2 = $Panel.get_global_rect()
	var tip_size: Vector2   = tooltip_panel.size

	var tx: float = card_global.position.x + card_global.size.x + 8.0 - panel_global.position.x
	var ty: float = card_global.position.y - panel_global.position.y

	# Clamp so tooltip stays within panel
	var panel_w: float = panel_global.size.x
	var panel_h: float = panel_global.size.y
	if tx + tip_size.x > panel_w - 8.0:
		tx = card_global.position.x - panel_global.position.x - tip_size.x - 8.0
	ty = clampf(ty, 100.0, panel_h - tip_size.y - 10.0)

	tooltip_panel.position = Vector2(tx, ty)
	tooltip_panel.visible  = true

# ---------------------------------------------------------------------------
# Close
# ---------------------------------------------------------------------------

func _on_close_pressed() -> void:
	tooltip_panel.visible = false
	visible = false
	closed.emit()
