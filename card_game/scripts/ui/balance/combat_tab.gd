class_name CombatTab
extends VBoxContainer

# ── Colors ───────────────────────────────────────────────────────────────────
const COLOR_WHITE    := Color(0.95, 0.95, 0.95)
const COLOR_GREEN    := Color(0.3,  0.95, 0.4)
const COLOR_YELLOW   := Color(1.0,  0.88, 0.2)
const COLOR_RED      := Color(1.0,  0.3,  0.3)
const COLOR_BLUE     := Color(0.4,  0.7,  1.0)
const COLOR_GRAY     := Color(0.55, 0.55, 0.6)
const COLOR_PURPLE   := Color(0.75, 0.35, 1.0)
const COLOR_HEADER   := Color(0.8,  0.8,  0.85)
const COLOR_PANEL_BG := Color(0.10, 0.10, 0.13, 1.0)

# ── State ─────────────────────────────────────────────────────────────────────
var _combat_state: CombatState = null

# ── UI nodes rebuilt on each refresh ─────────────────────────────────────────
var _header_phase_label:  Label
var _header_turn_label:   Label
var _players_vbox:        VBoxContainer
var _enemies_vbox:        VBoxContainer
var _auto_refresh_timer:  Timer
var _auto_refresh_check:  CheckBox

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_theme_constant_override("separation", 6)

	# Wrap everything in a ScrollContainer so the tab is usable at any screen size
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	add_child(scroll)

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	scroll.add_child(inner)

	# Header row
	var header_hbox := HBoxContainer.new()
	inner.add_child(header_hbox)

	var title := Label.new()
	title.text = "Combat State"
	title.add_theme_color_override("font_color", COLOR_WHITE)
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title)

	_header_phase_label = Label.new()
	_header_phase_label.text = "Phase: —"
	_header_phase_label.add_theme_color_override("font_color", COLOR_GRAY)
	_header_phase_label.add_theme_font_size_override("font_size", 13)
	header_hbox.add_child(_header_phase_label)

	var sep1 := Label.new()
	sep1.text = "  |  "
	sep1.add_theme_color_override("font_color", COLOR_GRAY)
	header_hbox.add_child(sep1)

	_header_turn_label = Label.new()
	_header_turn_label.text = "Turn: —"
	_header_turn_label.add_theme_color_override("font_color", COLOR_GRAY)
	_header_turn_label.add_theme_font_size_override("font_size", 13)
	header_hbox.add_child(_header_turn_label)

	inner.add_child(_make_separator())

	# Players section header
	var players_header := Label.new()
	players_header.text = "Players"
	players_header.add_theme_color_override("font_color", COLOR_HEADER)
	players_header.add_theme_font_size_override("font_size", 14)
	inner.add_child(players_header)

	_players_vbox = VBoxContainer.new()
	_players_vbox.add_theme_constant_override("separation", 8)
	inner.add_child(_players_vbox)

	inner.add_child(_make_separator())

	# Enemies section header
	var enemies_header := Label.new()
	enemies_header.text = "Enemies"
	enemies_header.add_theme_color_override("font_color", COLOR_HEADER)
	enemies_header.add_theme_font_size_override("font_size", 14)
	inner.add_child(enemies_header)

	_enemies_vbox = VBoxContainer.new()
	_enemies_vbox.add_theme_constant_override("separation", 8)
	inner.add_child(_enemies_vbox)

	inner.add_child(_make_separator())

	# Bottom controls
	var bottom_hbox := HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 12)
	inner.add_child(bottom_hbox)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_refresh)
	bottom_hbox.add_child(refresh_btn)

	_auto_refresh_check = CheckBox.new()
	_auto_refresh_check.text = "Auto-refresh (0.5s)"
	_auto_refresh_check.add_theme_color_override("font_color", COLOR_GRAY)
	_auto_refresh_check.toggled.connect(_on_auto_refresh_toggled)
	bottom_hbox.add_child(_auto_refresh_check)

	# Timer for auto-refresh
	_auto_refresh_timer = Timer.new()
	_auto_refresh_timer.wait_time = 0.5
	_auto_refresh_timer.one_shot = false
	_auto_refresh_timer.timeout.connect(_refresh)
	add_child(_auto_refresh_timer)

# ── Public API ────────────────────────────────────────────────────────────────

func set_combat_state(state: CombatState) -> void:
	_combat_state = state
	_refresh()

func _refresh() -> void:
	if _combat_state == null:
		_header_phase_label.text = "Phase: (no combat)"
		_header_turn_label.text  = "Turn: —"
		_clear_children(_players_vbox)
		_clear_children(_enemies_vbox)
		return

	# Header
	_header_phase_label.text = "Phase: %s" % _phase_name(_combat_state.phase)
	_header_turn_label.text  = "Turn: %d" % _combat_state.turn_number

	# Players
	_clear_children(_players_vbox)
	for peer_id in _combat_state.players:
		var ps: PlayerState = _combat_state.players[peer_id]
		_players_vbox.add_child(_build_player_panel(ps))

	# Enemies
	_clear_children(_enemies_vbox)
	for i in _combat_state.enemies.size():
		var es: EnemyState = _combat_state.enemies[i]
		_enemies_vbox.add_child(_build_enemy_panel(es, i))

# ── Player panel ──────────────────────────────────────────────────────────────

func _build_player_panel(ps: PlayerState) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style())

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Panel header
	var header := Label.new()
	header.text = "Player %s  (peer %d)" % [ps.display_name, ps.peer_id]
	header.add_theme_color_override("font_color", COLOR_WHITE)
	header.add_theme_font_size_override("font_size", 13)
	vbox.add_child(header)

	# Stats grid
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 3)
	vbox.add_child(grid)

	# HP
	var hp_pct: float = float(ps.current_hp) / float(ps.max_hp) if ps.max_hp > 0 else 0.0
	var hp_color: Color
	if hp_pct > 0.5:
		hp_color = COLOR_GREEN
	elif hp_pct > 0.25:
		hp_color = COLOR_YELLOW
	else:
		hp_color = COLOR_RED
	_add_grid_row(grid, "HP", "%d / %d" % [ps.current_hp, ps.max_hp], hp_color)

	# Block
	_add_grid_row(grid, "Block", str(ps.block), COLOR_BLUE)

	# Energy
	_add_grid_row(grid, "Energy", "%d / %d" % [ps.energy, ps.max_energy], COLOR_WHITE)

	# Strength / Dexterity
	_add_grid_row(grid, "Strength", str(ps.strength), COLOR_WHITE)
	_add_grid_row(grid, "Dexterity", str(ps.dexterity), COLOR_WHITE)

	# Status debuffs
	_add_grid_row(grid, "Vulnerable", "%d turns" % ps.vulnerable, COLOR_YELLOW if ps.vulnerable > 0 else COLOR_GRAY)
	_add_grid_row(grid, "Weak",       "%d turns" % ps.weak,       COLOR_YELLOW if ps.weak > 0       else COLOR_GRAY)

	# Corruption
	_add_grid_row(grid, "Corruption",
		"%d / %d  (Tier %d)" % [ps.corruption, ps.max_corruption, ps.corruption_tier],
		COLOR_PURPLE if ps.corruption > 0 else COLOR_GRAY)

	# Sins
	_add_grid_row(grid, "Sins",
		"W:%d  S:%d  P:%d" % [ps.sin_wrath, ps.sin_sloth, ps.sin_pride],
		COLOR_RED if (ps.sin_wrath + ps.sin_sloth + ps.sin_pride) > 0 else COLOR_GRAY)

	# Pile sizes
	_add_grid_row(grid, "Hand / Draw",
		"%d cards  /  %d" % [ps.hand.size(), ps.draw_pile.size()], COLOR_WHITE)
	_add_grid_row(grid, "Discard / Exhaust",
		"%d  /  %d" % [ps.discard_pile.size(), ps.exhaust_pile.size()], COLOR_GRAY)

	# Death's Door
	var dd_color: Color = COLOR_RED if ps.is_on_deaths_door else COLOR_GRAY
	_add_grid_row(grid, "Deaths Door",
		"%s  (%d turns)" % ["YES" if ps.is_on_deaths_door else "no", ps.deaths_door_turns],
		dd_color)

	# SpinBox tweaks
	vbox.add_child(_make_separator_thin())
	var tweak_label := Label.new()
	tweak_label.text = "Live tweaks:"
	tweak_label.add_theme_color_override("font_color", COLOR_GRAY)
	tweak_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(tweak_label)

	var tweak_grid := GridContainer.new()
	tweak_grid.columns = 4
	tweak_grid.add_theme_constant_override("h_separation", 8)
	tweak_grid.add_theme_constant_override("v_separation", 3)
	vbox.add_child(tweak_grid)

	_add_player_spinbox(tweak_grid, "HP",         ps.current_hp, 0, ps.max_hp,    func(v): ps.current_hp = v)
	_add_player_spinbox(tweak_grid, "Block",      ps.block,      0, 999,           func(v): ps.block = v)
	_add_player_spinbox(tweak_grid, "Energy",     ps.energy,     0, ps.max_energy, func(v): ps.energy = v)
	_add_player_spinbox(tweak_grid, "Strength",   ps.strength,   -10, 99,          func(v): ps.strength = v)
	_add_player_spinbox(tweak_grid, "Dexterity",  ps.dexterity,  -10, 99,          func(v): ps.dexterity = v)
	_add_player_spinbox(tweak_grid, "Vulnerable", ps.vulnerable, 0, 99,            func(v): ps.vulnerable = v)
	_add_player_spinbox(tweak_grid, "Weak",       ps.weak,       0, 99,            func(v): ps.weak = v)

	return panel

# ── Enemy panel ───────────────────────────────────────────────────────────────

func _build_enemy_panel(es: EnemyState, index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.12, 0.10, 0.10, 1.0)))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Header
	var header := Label.new()
	header.text = "[%d] %s" % [index, es.enemy_data_id]
	header.add_theme_color_override("font_color", COLOR_RED)
	header.add_theme_font_size_override("font_size", 13)
	vbox.add_child(header)

	# HP bar (ColorRect + Label overlay)
	var hp_bar_container := Control.new()
	hp_bar_container.custom_minimum_size = Vector2(0, 22)
	hp_bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hp_bar_container)

	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0.25, 0.08, 0.08, 1.0)
	hp_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_bar_container.add_child(hp_bg)

	var hp_pct: float = float(es.current_hp) / float(es.max_hp) if es.max_hp > 0 else 0.0
	var hp_fill := ColorRect.new()
	hp_fill.color = COLOR_RED.lerp(COLOR_GREEN, hp_pct)
	hp_fill.anchor_left   = 0.0
	hp_fill.anchor_right  = 0.0
	hp_fill.anchor_top    = 0.0
	hp_fill.anchor_bottom = 1.0
	hp_fill.offset_right  = hp_pct  # will be sized in deferred call below
	hp_bar_container.add_child(hp_fill)

	# Defer the hp fill width so the container has laid out
	hp_fill.set_deferred("offset_right", 0.0)  # reset; use size instead
	# We use a different approach: size via a MarginContainer stretch trick is complex;
	# instead set the fill as a ratio using scale
	hp_fill.anchor_right = hp_pct
	hp_fill.offset_right = 0.0

	var hp_label := Label.new()
	hp_label.text = "HP: %d / %d" % [es.current_hp, es.max_hp]
	hp_label.add_theme_color_override("font_color", COLOR_WHITE)
	hp_label.add_theme_font_size_override("font_size", 11)
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_label.add_theme_constant_override("margin_left", 4)
	hp_bar_container.add_child(hp_label)

	# Stats grid
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 3)
	vbox.add_child(grid)

	_add_grid_row(grid, "Block",    str(es.block),    COLOR_BLUE)
	_add_grid_row(grid, "Intent",   _format_intent(es), COLOR_WHITE)
	_add_grid_row(grid, "Strength", str(es.strength), COLOR_WHITE if es.strength == 0 else COLOR_RED)
	_add_grid_row(grid, "Vulnerable", "%d turns" % es.vulnerable, COLOR_YELLOW if es.vulnerable > 0 else COLOR_GRAY)
	_add_grid_row(grid, "Weak",       "%d turns" % es.weak,       COLOR_YELLOW if es.weak > 0       else COLOR_GRAY)

	# SpinBox tweaks
	vbox.add_child(_make_separator_thin())
	var tweak_label := Label.new()
	tweak_label.text = "Live tweaks:"
	tweak_label.add_theme_color_override("font_color", COLOR_GRAY)
	tweak_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(tweak_label)

	var tweak_grid := GridContainer.new()
	tweak_grid.columns = 4
	tweak_grid.add_theme_constant_override("h_separation", 8)
	tweak_grid.add_theme_constant_override("v_separation", 3)
	vbox.add_child(tweak_grid)

	_add_player_spinbox(tweak_grid, "HP",         es.current_hp, 0,   es.max_hp, func(v): es.current_hp = v)
	_add_player_spinbox(tweak_grid, "Block",      es.block,      0,   999,        func(v): es.block = v)
	_add_player_spinbox(tweak_grid, "Strength",   es.strength,   -10, 99,         func(v): es.strength = v)
	_add_player_spinbox(tweak_grid, "Vulnerable", es.vulnerable, 0,   99,         func(v): es.vulnerable = v)
	_add_player_spinbox(tweak_grid, "Weak",       es.weak,       0,   99,         func(v): es.weak = v)

	return panel

# ── Intent formatting ─────────────────────────────────────────────────────────

func _format_intent(es: EnemyState) -> String:
	var icon: String
	match es.intent_type:
		Enums.EnemyIntent.ATTACK:  icon = "⚔"
		Enums.EnemyIntent.DEFEND:  icon = "🛡"
		Enums.EnemyIntent.BUFF:    icon = "⬆"
		Enums.EnemyIntent.DEBUFF:  icon = "⬇"
		Enums.EnemyIntent.HACK:    icon = "💻"
		_:                         icon = "❓"
	return "%s %s for %d" % [icon, _intent_type_name(es.intent_type), es.intent_value]

func _intent_type_name(intent: Enums.EnemyIntent) -> String:
	match intent:
		Enums.EnemyIntent.ATTACK:  return "attack"
		Enums.EnemyIntent.DEFEND:  return "defend"
		Enums.EnemyIntent.BUFF:    return "buff"
		Enums.EnemyIntent.DEBUFF:  return "debuff"
		Enums.EnemyIntent.HACK:    return "hack"
		_:                         return "unknown"

func _phase_name(phase: Enums.CombatPhase) -> String:
	match phase:
		Enums.CombatPhase.WAITING_FOR_PLAYERS: return "WAITING"
		Enums.CombatPhase.PLAYER_TURN:         return "PLAYER TURN"
		Enums.CombatPhase.RESOLVING:           return "RESOLVING"
		Enums.CombatPhase.ENEMY_TURN:          return "ENEMY TURN"
		Enums.CombatPhase.COMBAT_OVER:         return "COMBAT OVER"
	return "UNKNOWN"

# ── Helpers ───────────────────────────────────────────────────────────────────

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

func _add_player_spinbox(grid: GridContainer, label_text: String, current_val: int,
		min_val: int, max_val: int, setter: Callable) -> void:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", COLOR_GRAY)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	grid.add_child(lbl)

	var spin := SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = 1
	spin.value = current_val
	spin.custom_minimum_size = Vector2(80, 0)
	spin.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# Connect after setting value to avoid spurious call on init
	spin.value_changed.connect(func(v: float): setter.call(int(v)))
	grid.add_child(spin)

func _make_panel_style(bg: Color = COLOR_PANEL_BG) -> StyleBoxFlat:
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
	return style

func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.25, 0.25, 0.3, 1.0))
	return sep

func _make_separator_thin() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.2, 0.2, 0.22, 1.0))
	sep.custom_minimum_size = Vector2(0, 1)
	return sep

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _on_auto_refresh_toggled(pressed: bool) -> void:
	if pressed:
		_auto_refresh_timer.start()
	else:
		_auto_refresh_timer.stop()
