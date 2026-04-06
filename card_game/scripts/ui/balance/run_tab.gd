class_name RunTab
extends VBoxContainer

signal gallery_requested(card_ids: Array, title: String)

# ── Colors ───────────────────────────────────────────────────────────────────
const COLOR_WHITE    := Color(0.95, 0.95, 0.95)
const COLOR_GREEN    := Color(0.3,  0.95, 0.4)
const COLOR_YELLOW   := Color(1.0,  0.88, 0.2)
const COLOR_RED      := Color(1.0,  0.3,  0.3)
const COLOR_GRAY     := Color(0.55, 0.55, 0.6)
const COLOR_PURPLE   := Color(0.75, 0.35, 1.0)
const COLOR_HEADER   := Color(0.8,  0.8,  0.85)
const COLOR_PANEL_BG := Color(0.10, 0.10, 0.13, 1.0)
const COLOR_WARNING  := Color(1.0,  0.85, 0.15)
const COLOR_LINK     := Color(0.4,  0.75, 1.0)

# ── State ─────────────────────────────────────────────────────────────────────
var _run: RunState    = null
var _tracker          = null   # BalanceTracker autoload, passed via set_tracker()

# ── UI node references rebuilt on refresh ─────────────────────────────────────
var _overview_grid:    GridContainer
var _corruption_label: Label
var _log_header:       Label
var _log_vbox:         VBoxContainer
var _averages_grid:    GridContainer
var _flags_vbox:       VBoxContainer

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_theme_constant_override("separation", 6)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	add_child(scroll)

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 10)
	scroll.add_child(inner)

	# ── Run Overview ──────────────────────────────────────────────────────────
	inner.add_child(_make_section_header("Run Overview"))

	var overview_panel := _make_panel()
	inner.add_child(overview_panel)
	var overview_vbox := VBoxContainer.new()
	overview_vbox.add_theme_constant_override("separation", 4)
	overview_panel.add_child(overview_vbox)

	_overview_grid = GridContainer.new()
	_overview_grid.columns = 2
	_overview_grid.add_theme_constant_override("h_separation", 20)
	_overview_grid.add_theme_constant_override("v_separation", 3)
	overview_vbox.add_child(_overview_grid)

	_corruption_label = Label.new()
	_corruption_label.add_theme_color_override("font_color", COLOR_GRAY)
	_corruption_label.add_theme_font_size_override("font_size", 12)
	overview_vbox.add_child(_corruption_label)

	inner.add_child(_make_separator())

	# ── Combat History ────────────────────────────────────────────────────────
	_log_header = Label.new()
	_log_header.text = "Combat History"
	_log_header.add_theme_color_override("font_color", COLOR_HEADER)
	_log_header.add_theme_font_size_override("font_size", 14)
	inner.add_child(_log_header)

	var log_scroll := ScrollContainer.new()
	log_scroll.custom_minimum_size = Vector2(0, 160)
	log_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	inner.add_child(log_scroll)

	_log_vbox = VBoxContainer.new()
	_log_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_vbox.add_theme_constant_override("separation", 2)
	log_scroll.add_child(_log_vbox)

	inner.add_child(_make_separator())

	# ── Averages ──────────────────────────────────────────────────────────────
	inner.add_child(_make_section_header("Averages"))

	var avg_panel := _make_panel()
	inner.add_child(avg_panel)

	_averages_grid = GridContainer.new()
	_averages_grid.columns = 2
	_averages_grid.add_theme_constant_override("h_separation", 20)
	_averages_grid.add_theme_constant_override("v_separation", 3)
	avg_panel.add_child(_averages_grid)

	inner.add_child(_make_separator())

	# ── Balance Red Flags ─────────────────────────────────────────────────────
	inner.add_child(_make_section_header("Balance Red Flags"))

	var flags_panel := _make_panel(Color(0.12, 0.10, 0.08, 1.0))
	inner.add_child(flags_panel)

	_flags_vbox = VBoxContainer.new()
	_flags_vbox.add_theme_constant_override("separation", 4)
	flags_panel.add_child(_flags_vbox)

	inner.add_child(_make_separator())

	# ── Bottom controls ───────────────────────────────────────────────────────
	var bottom_hbox := HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 12)
	inner.add_child(bottom_hbox)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_refresh)
	bottom_hbox.add_child(refresh_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear Stats"
	var clear_style := StyleBoxFlat.new()
	clear_style.bg_color = Color(0.4, 0.1, 0.1, 1.0)
	clear_style.corner_radius_top_left     = 4
	clear_style.corner_radius_top_right    = 4
	clear_style.corner_radius_bottom_left  = 4
	clear_style.corner_radius_bottom_right = 4
	clear_btn.add_theme_stylebox_override("normal", clear_style)
	clear_btn.add_theme_color_override("font_color", COLOR_WHITE)
	clear_btn.pressed.connect(_on_clear_stats_pressed)
	bottom_hbox.add_child(clear_btn)

	_refresh()

# ── Public API ────────────────────────────────────────────────────────────────

func set_run(run: RunState) -> void:
	_run = run
	_refresh()

func set_tracker(tracker) -> void:
	_tracker = tracker
	_refresh()

func _refresh() -> void:
	_refresh_overview()
	_refresh_combat_log()
	_refresh_averages()
	_refresh_flags()

# ── Section: Run Overview ─────────────────────────────────────────────────────

func _refresh_overview() -> void:
	_clear_children(_overview_grid)

	if _run == null:
		_add_grid_row(_overview_grid, "Run", "(no active run)", COLOR_GRAY)
		_corruption_label.text = ""
		return

	_add_grid_row(_overview_grid, "Floor",           str(_run.floors_cleared),      COLOR_WHITE)
	_add_grid_row(_overview_grid, "Gold",             str(_run.gold),                COLOR_YELLOW)
	_add_clickable_grid_row(_overview_grid, "Deck Size", str(_run.deck.size()), COLOR_LINK, _on_deck_clicked)
	_add_grid_row(_overview_grid, "Relics",           str(_run.relics.size()),       COLOR_WHITE)

	var equip_count: int = 0
	for slot in _run.equipment:
		if _run.equipment[slot] != null and _run.equipment[slot] != "":
			equip_count += 1
	_add_grid_row(_overview_grid, "Equipment Slots",  str(equip_count),              COLOR_WHITE)
	_add_grid_row(_overview_grid, "Skill Points",     str(_run.skill_points),        COLOR_WHITE)
	_add_grid_row(_overview_grid, "Unlocked Skills",  str(_run.unlocked_skills.size()), COLOR_WHITE)

	# Corruption on its own line with color coding
	var corruption_pct: float = float(_run.run_corruption) / float(_run.max_corruption) if _run.max_corruption > 0 else 0.0
	var c_color: Color
	if corruption_pct >= 0.75:
		c_color = COLOR_RED
	elif corruption_pct >= 0.5:
		c_color = COLOR_YELLOW
	else:
		c_color = COLOR_PURPLE
	_corruption_label.text = "Corruption: %d / %d  (%.0f%%)" % [
		_run.run_corruption, _run.max_corruption, corruption_pct * 100.0
	]
	_corruption_label.add_theme_color_override("font_color", c_color)

# ── Section: Combat History ───────────────────────────────────────────────────

func _refresh_combat_log() -> void:
	_clear_children(_log_vbox)

	if _tracker == null:
		_log_header.text = "Combat History  (tracker not set)"
		_add_log_line("—", COLOR_GRAY)
		return

	var log: Array = _tracker.get_combat_log()
	_log_header.text = "Combat History  (%d fights)" % log.size()

	if log.is_empty():
		_add_log_line("No combats recorded yet.", COLOR_GRAY)
		return

	for i in log.size():
		var entry: Dictionary = log[i]
		var won: bool = entry.get("won", false)
		var turns: int = entry.get("turns_taken", 0)
		var enemy_ids: Array = entry.get("enemy_ids", [])
		var enemy_str: String = ", ".join(PackedStringArray(enemy_ids)) if not enemy_ids.is_empty() else "unknown"

		var row_color: Color = COLOR_GREEN if won else COLOR_RED
		var outcome: String  = "Won" if won else "Lost"

		_add_log_line(
			"Fight %d: %s — %s in %d turns" % [i + 1, enemy_str, outcome, turns],
			row_color
		)

		var dmg_dealt:  int = entry.get("total_damage_dealt",  0)
		var dmg_taken:  int = entry.get("total_damage_taken",  0)
		var block_gain: int = entry.get("total_block_gained",  0)
		var healing:    int = entry.get("total_healing",       0)
		var cards:      int = entry.get("cards_played",        0)

		_add_log_line(
			"   Dmg Dealt: %d   Taken: %d   Block: %d   Heal: %d   Cards: %d" % [
				dmg_dealt, dmg_taken, block_gain, healing, cards
			],
			COLOR_GRAY
		)

# ── Section: Averages ─────────────────────────────────────────────────────────

func _refresh_averages() -> void:
	_clear_children(_averages_grid)

	if _tracker == null:
		_add_grid_row(_averages_grid, "Tracker", "(not set)", COLOR_GRAY)
		return

	var avgs: Dictionary = _tracker.get_averages()
	if avgs.is_empty():
		_add_grid_row(_averages_grid, "Status", "No data yet", COLOR_GRAY)
		return

	var win_pct: float = avgs.get("win_rate", 0.0) * 100.0
	_add_grid_row(_averages_grid, "Win Rate",         "%.0f%%  (%d combats)" % [win_pct, avgs.get("combat_count", 0)],
		COLOR_GREEN if win_pct >= 70.0 else COLOR_RED)
	_add_grid_row(_averages_grid, "Avg Damage/Combat", "%.1f" % avgs.get("avg_total_damage_dealt", 0.0), COLOR_WHITE)
	_add_grid_row(_averages_grid, "Avg Damage Taken",  "%.1f" % avgs.get("avg_total_damage_taken", 0.0), COLOR_WHITE)
	_add_grid_row(_averages_grid, "Avg Block",         "%.1f" % avgs.get("avg_total_block_gained", 0.0), COLOR_WHITE)
	_add_grid_row(_averages_grid, "Avg Heal",          "%.1f" % avgs.get("avg_total_healing",      0.0), COLOR_WHITE)
	_add_grid_row(_averages_grid, "Avg Turns",         "%.1f" % avgs.get("avg_turns_taken",        0.0), COLOR_WHITE)
	_add_grid_row(_averages_grid, "Avg Cards Played",  "%.1f" % avgs.get("avg_cards_played",       0.0), COLOR_WHITE)

# ── Section: Red Flags ────────────────────────────────────────────────────────

func _refresh_flags() -> void:
	_clear_children(_flags_vbox)

	var flags: Array[String] = []
	var avgs: Dictionary = {}
	var log: Array = []

	if _tracker != null:
		avgs = _tracker.get_averages()
		log  = _tracker.get_combat_log()

	# Flag: avg damage taken > avg damage dealt
	if not avgs.is_empty():
		var avg_dealt: float = avgs.get("avg_total_damage_dealt", 0.0)
		var avg_taken: float = avgs.get("avg_total_damage_taken", 0.0)
		if avg_taken > avg_dealt:
			flags.append("Avg damage taken (%.1f) > avg damage dealt (%.1f) — losing the arms race" % [avg_taken, avg_dealt])

	# Flag: avg combat length > 8 turns
	if not avgs.is_empty():
		var avg_turns: float = avgs.get("avg_turns_taken", 0.0)
		if avg_turns > 8.0:
			flags.append("Avg combat length %.1f turns > 8 — fights dragging on" % avg_turns)

	# Flag: win rate below 70%
	if not avgs.is_empty():
		var win_rate: float = avgs.get("win_rate", 1.0)
		if win_rate < 0.70:
			flags.append("Win rate %.0f%% is below 70%%" % (win_rate * 100.0))

	# Flag: corruption > 75% of max
	if _run != null and _run.max_corruption > 0:
		var c_pct: float = float(_run.run_corruption) / float(_run.max_corruption)
		if c_pct > 0.75:
			flags.append("Corruption at %.0f%% of max — approaching Tier 3" % (c_pct * 100.0))

	# Flag: deck size > 25
	if _run != null and _run.deck.size() > 25:
		flags.append("Deck size %d > 25 — deck bloat risk" % _run.deck.size())

	# Flag: no relics acquired after floor 3
	if _run != null and _run.floors_cleared > 3 and _run.relics.is_empty():
		flags.append("No relics acquired by floor %d" % _run.floors_cleared)

	if flags.is_empty():
		var ok := Label.new()
		ok.text = "No red flags detected."
		ok.add_theme_color_override("font_color", COLOR_GREEN)
		ok.add_theme_font_size_override("font_size", 12)
		_flags_vbox.add_child(ok)
	else:
		for flag_text in flags:
			var lbl := Label.new()
			lbl.text = "⚠  " + flag_text
			lbl.add_theme_color_override("font_color", COLOR_WARNING)
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_flags_vbox.add_child(lbl)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _add_clickable_grid_row(grid: GridContainer, key: String, value: String, val_color: Color, callback: Callable) -> void:
	var key_lbl := Label.new()
	key_lbl.text = key + ":"
	key_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	key_lbl.add_theme_font_size_override("font_size", 12)
	grid.add_child(key_lbl)

	var val_btn := LinkButton.new()
	val_btn.text = value
	val_btn.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	val_btn.add_theme_color_override("font_color", val_color)
	val_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	val_btn.add_theme_font_size_override("font_size", 12)
	val_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	val_btn.pressed.connect(callback)
	grid.add_child(val_btn)

func _on_deck_clicked() -> void:
	if _run == null:
		return
	var ids: Array = _run.deck.duplicate()
	gallery_requested.emit(ids, "Deck (%d cards)" % ids.size())

func _add_grid_row(grid: GridContainer, key: String, value: String, val_color: Color) -> void:
	var key_lbl := Label.new()
	key_lbl.text = key + ":"
	key_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	key_lbl.add_theme_font_size_override("font_size", 12)
	grid.add_child(key_lbl)

	var val_lbl := Label.new()
	val_lbl.text = value
	val_lbl.add_theme_color_override("font_color", val_color)
	val_lbl.add_theme_font_size_override("font_size", 12)
	grid.add_child(val_lbl)

func _add_log_line(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_vbox.add_child(lbl)

func _make_section_header(title: String) -> Label:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_color_override("font_color", COLOR_HEADER)
	lbl.add_theme_font_size_override("font_size", 14)
	return lbl

func _make_panel(bg: Color = COLOR_PANEL_BG) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.25, 0.25, 0.3, 1.0)
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left   = 10.0
	style.content_margin_right  = 10.0
	style.content_margin_top    = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.25, 0.25, 0.3, 1.0))
	return sep

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _on_clear_stats_pressed() -> void:
	if _tracker != null:
		_tracker.clear()
	_refresh()
