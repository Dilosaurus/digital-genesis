class_name SimulateTab
extends VBoxContainer

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
const COLOR_SECTION_BG  := Color(0.14, 0.14, 0.18, 1.0)
const COLOR_RESULTS_BG  := Color(0.10, 0.10, 0.13, 1.0)
const COLOR_RUN_NORMAL  := Color(0.20, 0.55, 0.85, 1.0)
const COLOR_RUN_HOVER   := Color(0.30, 0.70, 1.00, 1.0)
const HIST_CHAR         := "█"
const HIST_BUCKETS      := 10
const HIST_MAX_BAR_COLS := 40

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var _player: PlayerState = null
var _target = null

# Config controls
var _card_option: OptionButton
var _iter_spin: SpinBox
var _vuln_check: CheckBox
var _weak_check: CheckBox
var _strength_check: CheckBox
var _strength_spin: SpinBox

# Results display nodes
var _results_grid: GridContainer
var _histogram_vbox: VBoxContainer
var _status_label: Label

# Card id list parallel to OptionButton entries
var _card_ids: Array[String] = []

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

func _ready() -> void:
	name = "SimulateTab"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)

	_build_config_section()
	_build_run_button()
	_build_results_section()

	_populate_card_list()

func _make_section_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SECTION_BG
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _make_row_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.80, 0.80, 0.80))
	lbl.custom_minimum_size = Vector2(180, 0)
	return lbl

func _build_config_section() -> void:
	var section := _make_section_panel()
	add_child(section)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	section.add_child(vbox)

	var header := Label.new()
	header.text = "Simulation Config"
	header.add_theme_color_override("font_color", Color.WHITE)
	header.add_theme_font_size_override("font_size", 14)
	vbox.add_child(header)

	# Row 1: Card selector
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	vbox.add_child(row1)
	row1.add_child(_make_row_label("Card:"))
	_card_option = OptionButton.new()
	_card_option.custom_minimum_size = Vector2(320, 0)
	_card_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(_card_option)

	# Row 2: Iterations
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	vbox.add_child(row2)
	row2.add_child(_make_row_label("Iterations:"))
	_iter_spin = SpinBox.new()
	_iter_spin.min_value = 10
	_iter_spin.max_value = 10000
	_iter_spin.step = 10
	_iter_spin.value = 1000
	_iter_spin.custom_minimum_size = Vector2(140, 0)
	row2.add_child(_iter_spin)

	# Row 3: Scenario toggles
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 16)
	vbox.add_child(row3)

	_vuln_check = CheckBox.new()
	_vuln_check.text = "Target Vulnerable"
	_vuln_check.button_pressed = false
	row3.add_child(_vuln_check)

	_weak_check = CheckBox.new()
	_weak_check.text = "Player Weak"
	_weak_check.button_pressed = false
	row3.add_child(_weak_check)

	# Row 4: Strength toggle + spinbox
	var row4 := HBoxContainer.new()
	row4.add_theme_constant_override("separation", 8)
	vbox.add_child(row4)

	_strength_check = CheckBox.new()
	_strength_check.text = "Include Strength:"
	_strength_check.button_pressed = true
	row4.add_child(_strength_check)

	_strength_spin = SpinBox.new()
	_strength_spin.min_value = 0
	_strength_spin.max_value = 50
	_strength_spin.step = 1
	_strength_spin.value = 0
	_strength_spin.custom_minimum_size = Vector2(100, 0)
	row4.add_child(_strength_spin)

	var strength_note := Label.new()
	strength_note.text = "(overrides player strength for simulation)"
	strength_note.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	strength_note.add_theme_font_size_override("font_size", 12)
	row4.add_child(strength_note)

func _build_run_button() -> void:
	var btn_panel := PanelContainer.new()
	btn_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(btn_panel)

	var run_btn := Button.new()
	run_btn.text = "  Run Simulation  "
	run_btn.custom_minimum_size = Vector2(200, 44)
	run_btn.add_theme_font_size_override("font_size", 16)

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = COLOR_RUN_NORMAL
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6
	run_btn.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = COLOR_RUN_HOVER
	btn_hover.corner_radius_top_left = 6
	btn_hover.corner_radius_top_right = 6
	btn_hover.corner_radius_bottom_left = 6
	btn_hover.corner_radius_bottom_right = 6
	run_btn.add_theme_stylebox_override("hover", btn_hover)

	run_btn.add_theme_color_override("font_color", Color.WHITE)
	run_btn.pressed.connect(_run_simulation)
	btn_panel.add_child(run_btn)

func _build_results_section() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(outer_vbox)

	# Status / error label
	_status_label = Label.new()
	_status_label.text = "Configure settings above and click Run Simulation."
	_status_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer_vbox.add_child(_status_label)

	# Summary stats grid
	var stats_section := _make_section_panel()
	stats_section.visible = false
	outer_vbox.add_child(stats_section)
	stats_section.name = "StatsSectionPanel"

	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 4)
	stats_section.add_child(stats_vbox)

	var stats_header := Label.new()
	stats_header.text = "Summary Statistics"
	stats_header.add_theme_color_override("font_color", Color.WHITE)
	stats_header.add_theme_font_size_override("font_size", 13)
	stats_vbox.add_child(stats_header)

	_results_grid = GridContainer.new()
	_results_grid.columns = 2
	_results_grid.add_theme_constant_override("h_separation", 24)
	_results_grid.add_theme_constant_override("v_separation", 4)
	stats_vbox.add_child(_results_grid)

	# Histogram section
	var hist_section := _make_section_panel()
	hist_section.visible = false
	outer_vbox.add_child(hist_section)
	hist_section.name = "HistSectionPanel"

	var hist_vbox_outer := VBoxContainer.new()
	hist_vbox_outer.add_theme_constant_override("separation", 4)
	hist_section.add_child(hist_vbox_outer)

	var hist_header := Label.new()
	hist_header.text = "Damage Distribution"
	hist_header.add_theme_color_override("font_color", Color.WHITE)
	hist_header.add_theme_font_size_override("font_size", 13)
	hist_vbox_outer.add_child(hist_header)

	_histogram_vbox = VBoxContainer.new()
	_histogram_vbox.add_theme_constant_override("separation", 2)
	hist_vbox_outer.add_child(_histogram_vbox)

# ---------------------------------------------------------------------------
# Card list population
# ---------------------------------------------------------------------------

func _populate_card_list() -> void:
	_card_option.clear()
	_card_ids.clear()

	var db: Dictionary = GameManager.card_database
	# Collect all cards sorted by name; allow all card types (block sim works too)
	var sorted_cards: Array[CardData] = []
	for card_id in db:
		var card: CardData = db[card_id]
		sorted_cards.append(card)
	sorted_cards.sort_custom(func(a: CardData, b: CardData): return a.display_name < b.display_name)

	for card in sorted_cards:
		var label_text := "%s (%dE)" % [card.display_name, card.energy_cost]
		if card.damage > 0:
			label_text += " [Dmg:%d×%d]" % [card.damage, card.hits]
		elif card.block > 0:
			label_text += " [Blk:%d]" % card.block
		_card_option.add_item(label_text)
		_card_ids.append(card.id)

# ---------------------------------------------------------------------------
# Simulation
# ---------------------------------------------------------------------------

func _run_simulation() -> void:
	if _card_ids.is_empty():
		_status_label.text = "No cards loaded. Check GameManager.card_database."
		return

	var selected_idx: int = _card_option.selected
	if selected_idx < 0 or selected_idx >= _card_ids.size():
		_status_label.text = "Select a card to simulate."
		return

	var card_id: String = _card_ids[selected_idx]
	var card: CardData = GameManager.get_card_data(card_id)
	if card == null:
		_status_label.text = "Card data not found for id: %s" % card_id
		return

	var iterations: int = int(_iter_spin.value)
	var use_vulnerable: bool = _vuln_check.button_pressed
	var use_weak: bool = _weak_check.button_pressed
	var use_strength: bool = _strength_check.button_pressed
	var strength_val: int = int(_strength_spin.value)

	var is_damage_sim: bool = card.damage > 0
	var is_block_sim: bool  = card.block > 0

	if not is_damage_sim and not is_block_sim:
		_status_label.text = "Selected card has no damage or block. Simulation not applicable."
		_set_results_visible(false)
		return

	# Build a temporary PlayerState for simulation
	var sim_player := PlayerState.new()
	if _player != null:
		# Copy modifier stack entries from real player
		for mod_entry in _player.modifier_stack.get_all():
			sim_player.modifier_stack.add(mod_entry)
		sim_player.max_hp = _player.max_hp
		sim_player.current_hp = _player.current_hp
	else:
		sim_player.max_hp = 80
		sim_player.current_hp = 80

	# Build a temporary target for vulnerable simulation
	var sim_target: EnemyState = null
	if use_vulnerable:
		sim_target = EnemyState.new()
		sim_target.vulnerable = 1
		sim_target.weak = 0
	elif _target != null:
		sim_target = _target

	var results: Array[int] = []
	results.resize(iterations)

	for i in iterations:
		# Set per-iteration state
		sim_player.strength = strength_val if use_strength else 0
		sim_player.weak = 1 if use_weak else 0
		sim_player.dexterity = _player.dexterity if _player != null else 0

		if is_damage_sim:
			var dmg := StatResolver.resolve_damage(card.damage, sim_player, sim_target, card)
			results[i] = dmg * card.hits
		else:
			var blk := StatResolver.resolve_block(card.block, sim_player, card)
			results[i] = blk

	_display_results(results, card, is_damage_sim, iterations)
	_status_label.text = "Simulation complete: %d iterations for '%s'." % [iterations, card.display_name]

# ---------------------------------------------------------------------------
# Results display
# ---------------------------------------------------------------------------

func _display_results(results: Array[int], card: CardData, is_damage: bool, iterations: int) -> void:
	var sorted_results := results.duplicate()
	sorted_results.sort()

	var min_val: int = sorted_results[0]
	var max_val: int = sorted_results[sorted_results.size() - 1]
	var mean_val: float = _compute_mean(results)
	var median_val: float = _compute_median(sorted_results)
	var std_dev: float = _compute_std_dev(results, mean_val)
	var dpe_mean: float = mean_val / max(card.energy_cost, 1)

	# Populate grid
	_clear_results_grid()

	var stat_label: String = "Damage" if is_damage else "Block"
	var per_energy_label: String = "DPE (mean):" if is_damage else "BPE (mean):"

	var grid_data: Array[String] = [
		"Min %s:" % stat_label, "%d" % min_val,
		"Max %s:" % stat_label, "%d" % max_val,
		"Mean %s:" % stat_label, "%.2f" % mean_val,
		"Median:", "%.1f" % median_val,
		"Std Dev:", "%.2f" % std_dev,
		per_energy_label, "%.2f" % dpe_mean,
	]

	for i in range(0, grid_data.size(), 2):
		var key_lbl := Label.new()
		key_lbl.text = grid_data[i]
		key_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))

		var val_lbl := Label.new()
		val_lbl.text = grid_data[i + 1]
		val_lbl.add_theme_color_override("font_color", Color.WHITE)

		_results_grid.add_child(key_lbl)
		_results_grid.add_child(val_lbl)

	# Histogram
	_build_histogram(sorted_results, min_val, max_val, iterations)

	_set_results_visible(true)

func _clear_results_grid() -> void:
	for child in _results_grid.get_children():
		child.queue_free()

func _build_histogram(sorted_results: Array[int], min_val: int, max_val: int, total: int) -> void:
	for child in _histogram_vbox.get_children():
		child.queue_free()

	if min_val == max_val:
		var flat_lbl := Label.new()
		flat_lbl.text = "  All results: %d  (deterministic — no variance)" % min_val
		flat_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		_histogram_vbox.add_child(flat_lbl)
		return

	var range_size: float = float(max_val - min_val)
	var bucket_width: float = range_size / HIST_BUCKETS

	# Count per bucket
	var counts: Array[int] = []
	counts.resize(HIST_BUCKETS)
	for v in sorted_results:
		var bucket_idx: int = int(float(v - min_val) / bucket_width)
		# Clamp max value into last bucket
		bucket_idx = min(bucket_idx, HIST_BUCKETS - 1)
		counts[bucket_idx] += 1

	var max_count: int = 0
	for c in counts:
		if c > max_count:
			max_count = c

	for b in HIST_BUCKETS:
		var bucket_lo: int = min_val + int(b * bucket_width)
		var bucket_hi: int = min_val + int((b + 1) * bucket_width) - 1
		if b == HIST_BUCKETS - 1:
			bucket_hi = max_val

		var count: int = counts[b]
		var bar_len: int = 0
		if max_count > 0:
			bar_len = int(float(count) / float(max_count) * HIST_MAX_BAR_COLS)

		var bar_str: String = HIST_CHAR.repeat(bar_len)
		var range_str: String = "%4d–%4d" % [bucket_lo, bucket_hi]
		var pct: float = float(count) / float(total) * 100.0

		var row_lbl := Label.new()
		# Pad bar string to fixed width for alignment
		var padded_bar: String = bar_str + " ".repeat(max(0, HIST_MAX_BAR_COLS - bar_len))
		row_lbl.text = "  %s: %s (%d, %.1f%%)" % [range_str, padded_bar, count, pct]
		row_lbl.add_theme_color_override("font_color", Color(0.80, 0.85, 0.95))
		row_lbl.add_theme_font_size_override("font_size", 12)
		_histogram_vbox.add_child(row_lbl)

func _set_results_visible(visible_state: bool) -> void:
	# panels were named during _build_results_section
	var stats_panel: Node = find_child("StatsSectionPanel", true, false)
	if stats_panel != null:
		stats_panel.visible = visible_state

	var hist_panel: Node = find_child("HistSectionPanel", true, false)
	if hist_panel != null:
		hist_panel.visible = visible_state

# ---------------------------------------------------------------------------
# Statistics helpers
# ---------------------------------------------------------------------------

func _compute_mean(data: Array[int]) -> float:
	if data.is_empty():
		return 0.0
	var total: float = 0.0
	for v in data:
		total += float(v)
	return total / float(data.size())

func _compute_median(sorted_data: Array[int]) -> float:
	var n: int = sorted_data.size()
	if n == 0:
		return 0.0
	if n % 2 == 0:
		return float(sorted_data[n / 2 - 1] + sorted_data[n / 2]) / 2.0
	return float(sorted_data[n / 2])

func _compute_std_dev(data: Array[int], mean: float) -> float:
	if data.size() < 2:
		return 0.0
	var variance: float = 0.0
	for v in data:
		var diff: float = float(v) - mean
		variance += diff * diff
	variance /= float(data.size())
	return sqrt(variance)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func set_player(player: PlayerState) -> void:
	_player = player

func set_target(target) -> void:
	_target = target
