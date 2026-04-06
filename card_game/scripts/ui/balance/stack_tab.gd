class_name StackTab
extends VBoxContainer

# ── References ───────────────────────────────────────────────────────────────
var _player: PlayerState = null

# ── State ────────────────────────────────────────────────────────────────────
# Modifiers that have been unchecked (removed from stack but kept for re-add)
var _disabled_mods: Array[ModifierData] = []

# ── Enum name tables ──────────────────────────────────────────────────────────
const STAT_NAMES: Array[String] = [
	"DAMAGE", "BLOCK", "HEALING", "MAX_HP", "MAX_ENERGY",
	"DRAW_PER_TURN", "ENERGY_COST", "CORRUPTION_GAIN", "CORRUPTION_RESIST",
]
const STAT_VALUES: Array[int] = [
	Enums.Stat.DAMAGE, Enums.Stat.BLOCK, Enums.Stat.HEALING,
	Enums.Stat.MAX_HP, Enums.Stat.MAX_ENERGY, Enums.Stat.DRAW_PER_TURN,
	Enums.Stat.ENERGY_COST, Enums.Stat.CORRUPTION_GAIN, Enums.Stat.CORRUPTION_RESIST,
]
const OP_NAMES: Array[String] = ["FLAT_ADD", "PERCENT_ADD", "PERCENT_MULT", "OVERRIDE"]
const OP_VALUES: Array[int] = [
	Enums.ModOp.FLAT_ADD, Enums.ModOp.PERCENT_ADD,
	Enums.ModOp.PERCENT_MULT, Enums.ModOp.OVERRIDE,
]
const LIFECYCLE_NAMES: Array[String] = [
	"PERMANENT", "COMBAT", "TURN", "CARD_PLAY", "CONDITIONAL",
]
const LIFECYCLE_VALUES: Array[int] = [
	Enums.ModLifecycle.PERMANENT, Enums.ModLifecycle.COMBAT,
	Enums.ModLifecycle.TURN, Enums.ModLifecycle.CARD_PLAY,
	Enums.ModLifecycle.CONDITIONAL,
]

# ── Op colors ─────────────────────────────────────────────────────────────────
const OP_COLORS: Array[Color] = [
	Color(0.35, 1.0, 0.45),   # FLAT_ADD    — green
	Color(0.25, 0.95, 1.0),   # PERCENT_ADD — cyan
	Color(1.0, 0.92, 0.25),   # PERCENT_MULT — yellow
	Color(1.0, 0.30, 0.30),   # OVERRIDE    — red
]
const COLOR_WHITE  := Color(0.95, 0.95, 0.95)
const COLOR_GRAY   := Color(0.50, 0.50, 0.55)
const COLOR_HEADER := Color(0.75, 0.75, 0.80)

# ── UI nodes ──────────────────────────────────────────────────────────────────
var _count_label: Label
var _filter_stat: OptionButton
var _filter_source: OptionButton
var _filter_lifecycle: OptionButton
var _list_vbox: VBoxContainer

# "Add modifier" section
var _add_stat_opt: OptionButton
var _add_op_opt: OptionButton
var _add_value_spin: SpinBox
var _add_lifecycle_opt: OptionButton
var _add_source_type_edit: LineEdit
var _add_source_id_edit: LineEdit

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_theme_constant_override("separation", 8)

	_build_header()
	_build_filter_bar()
	_build_list_area()
	_build_add_section()
	_rebuild_list()


func set_player(player: PlayerState) -> void:
	_player = player
	_disabled_mods.clear()
	_rebuild_list()


# ── UI construction ───────────────────────────────────────────────────────────

func _build_header() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 44)
	add_child(row)

	var title := Label.new()
	title.text = "Active Modifiers"
	title.add_theme_color_override("font_color", COLOR_HEADER)
	title.add_theme_font_size_override("font_size", 20)
	row.add_child(title)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.custom_minimum_size = Vector2(100, 0)
	refresh_btn.add_theme_font_size_override("font_size", 16)
	refresh_btn.pressed.connect(_on_refresh_pressed)
	row.add_child(refresh_btn)

	_count_label = Label.new()
	_count_label.text = "0 modifiers"
	_count_label.add_theme_color_override("font_color", COLOR_GRAY)
	_count_label.add_theme_font_size_override("font_size", 16)
	row.add_child(_count_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)


func _build_filter_bar() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	bar.custom_minimum_size = Vector2(0, 40)
	add_child(bar)

	var stat_lbl := Label.new()
	stat_lbl.text = "Stat:"
	stat_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	stat_lbl.add_theme_font_size_override("font_size", 16)
	bar.add_child(stat_lbl)

	_filter_stat = OptionButton.new()
	_filter_stat.custom_minimum_size = Vector2(170, 0)
	_filter_stat.add_theme_font_size_override("font_size", 15)
	_filter_stat.add_item("All")
	for name in STAT_NAMES:
		_filter_stat.add_item(name)
	_filter_stat.item_selected.connect(_on_filter_changed)
	bar.add_child(_filter_stat)

	var src_lbl := Label.new()
	src_lbl.text = "Source:"
	src_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	src_lbl.add_theme_font_size_override("font_size", 16)
	bar.add_child(src_lbl)

	_filter_source = OptionButton.new()
	_filter_source.custom_minimum_size = Vector2(160, 0)
	_filter_source.add_theme_font_size_override("font_size", 15)
	_filter_source.add_item("All")
	_filter_source.item_selected.connect(_on_filter_changed)
	bar.add_child(_filter_source)

	var lc_lbl := Label.new()
	lc_lbl.text = "Lifecycle:"
	lc_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	lc_lbl.add_theme_font_size_override("font_size", 16)
	bar.add_child(lc_lbl)

	_filter_lifecycle = OptionButton.new()
	_filter_lifecycle.custom_minimum_size = Vector2(160, 0)
	_filter_lifecycle.add_theme_font_size_override("font_size", 15)
	_filter_lifecycle.add_item("All")
	for name in LIFECYCLE_NAMES:
		_filter_lifecycle.add_item(name)
	_filter_lifecycle.item_selected.connect(_on_filter_changed)
	bar.add_child(_filter_lifecycle)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)


func _build_list_area() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.add_theme_constant_override("separation", 4)
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_vbox)


func _build_add_section() -> void:
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.35, 0.35, 0.40))
	add_child(sep)

	var title := Label.new()
	title.text = "Add Modifier"
	title.add_theme_color_override("font_color", COLOR_HEADER)
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 44)
	add_child(row)

	_add_stat_opt = OptionButton.new()
	_add_stat_opt.custom_minimum_size = Vector2(160, 0)
	_add_stat_opt.add_theme_font_size_override("font_size", 15)
	for name in STAT_NAMES:
		_add_stat_opt.add_item(name)
	row.add_child(_add_stat_opt)

	_add_op_opt = OptionButton.new()
	_add_op_opt.custom_minimum_size = Vector2(150, 0)
	_add_op_opt.add_theme_font_size_override("font_size", 15)
	for name in OP_NAMES:
		_add_op_opt.add_item(name)
	row.add_child(_add_op_opt)

	_add_value_spin = SpinBox.new()
	_add_value_spin.min_value = -100.0
	_add_value_spin.max_value = 1000.0
	_add_value_spin.step = 0.1
	_add_value_spin.value = 5.0
	_add_value_spin.custom_minimum_size = Vector2(130, 0)
	_add_value_spin.add_theme_font_size_override("font_size", 15)
	row.add_child(_add_value_spin)

	_add_lifecycle_opt = OptionButton.new()
	_add_lifecycle_opt.custom_minimum_size = Vector2(150, 0)
	_add_lifecycle_opt.add_theme_font_size_override("font_size", 15)
	for name in LIFECYCLE_NAMES:
		_add_lifecycle_opt.add_item(name)
	row.add_child(_add_lifecycle_opt)

	_add_source_type_edit = LineEdit.new()
	_add_source_type_edit.placeholder_text = "source_type"
	_add_source_type_edit.custom_minimum_size = Vector2(140, 0)
	_add_source_type_edit.add_theme_font_size_override("font_size", 15)
	row.add_child(_add_source_type_edit)

	_add_source_id_edit = LineEdit.new()
	_add_source_id_edit.placeholder_text = "source_id"
	_add_source_id_edit.custom_minimum_size = Vector2(140, 0)
	_add_source_id_edit.add_theme_font_size_override("font_size", 15)
	row.add_child(_add_source_id_edit)

	var add_btn := Button.new()
	add_btn.text = "Add"
	add_btn.custom_minimum_size = Vector2(80, 0)
	add_btn.add_theme_font_size_override("font_size", 16)
	add_btn.pressed.connect(_on_add_pressed)
	row.add_child(add_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)


# ── List building ─────────────────────────────────────────────────────────────

func _rebuild_list() -> void:
	for child in _list_vbox.get_children():
		child.queue_free()

	if _player == null:
		var lbl := Label.new()
		lbl.text = "No player — call set_player() to populate."
		lbl.add_theme_color_override("font_color", COLOR_GRAY)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list_vbox.add_child(lbl)
		_count_label.text = "0 modifiers"
		return

	# Collect all mods: active (in stack) + disabled (removed but retained)
	var all_mods: Array[ModifierData] = _player.modifier_stack.get_all().duplicate()
	# Include disabled mods so they remain visible with checkbox unchecked
	for mod in _disabled_mods:
		if mod not in all_mods:
			all_mods.append(mod)

	# Refresh source filter options
	_refresh_source_filter(all_mods)

	# Apply filters
	var filtered := _apply_filters(all_mods)

	_count_label.text = "%d modifier%s" % [all_mods.size(), "s" if all_mods.size() != 1 else ""]

	if filtered.is_empty():
		var lbl := Label.new()
		lbl.text = "(no modifiers match filters)"
		lbl.add_theme_color_override("font_color", COLOR_GRAY)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list_vbox.add_child(lbl)
		return

	for mod in filtered:
		_build_mod_row(mod)


func _refresh_source_filter(all_mods: Array[ModifierData]) -> void:
	# Remember current selection text so we can restore it
	var current_text: String = _filter_source.get_item_text(_filter_source.selected)

	# Rebuild source options
	while _filter_source.item_count > 1:
		_filter_source.remove_item(1)

	var seen_sources: Array[String] = []
	for mod in all_mods:
		if mod.source_type != "" and mod.source_type not in seen_sources:
			seen_sources.append(mod.source_type)
			_filter_source.add_item(mod.source_type)

	# Restore selection if possible
	for i in _filter_source.item_count:
		if _filter_source.get_item_text(i) == current_text:
			_filter_source.selected = i
			return
	_filter_source.selected = 0


func _apply_filters(mods: Array[ModifierData]) -> Array[ModifierData]:
	var result: Array[ModifierData] = []

	var stat_idx: int = _filter_stat.selected      # 0 = All, 1+ = STAT_VALUES[idx-1]
	var src_idx: int = _filter_source.selected     # 0 = All, 1+ = source text
	var lc_idx: int = _filter_lifecycle.selected   # 0 = All, 1+ = LIFECYCLE_VALUES[idx-1]

	var filter_stat_val: int = STAT_VALUES[stat_idx - 1] if stat_idx > 0 else -1
	var filter_src_text: String = _filter_source.get_item_text(src_idx) if src_idx > 0 else ""
	var filter_lc_val: int = LIFECYCLE_VALUES[lc_idx - 1] if lc_idx > 0 else -1

	for mod in mods:
		if filter_stat_val >= 0 and mod.stat != filter_stat_val:
			continue
		if filter_src_text != "" and mod.source_type != filter_src_text:
			continue
		if filter_lc_val >= 0 and mod.lifecycle != filter_lc_val:
			continue
		result.append(mod)

	return result


func _build_mod_row(mod: ModifierData) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 38)
	_list_vbox.add_child(row)

	# Enabled checkbox
	var check := CheckBox.new()
	check.button_pressed = mod not in _disabled_mods
	check.custom_minimum_size = Vector2(32, 0)
	check.toggled.connect(_on_mod_toggled.bind(mod))
	row.add_child(check)

	# Info label
	var op_idx: int = OP_VALUES.find(mod.operation)
	var op_color: Color = OP_COLORS[op_idx] if op_idx >= 0 else COLOR_WHITE
	var stat_name: String = STAT_NAMES[mod.stat] if mod.stat < STAT_NAMES.size() else str(mod.stat)
	var op_name: String = OP_NAMES[op_idx] if op_idx >= 0 else str(mod.operation)
	var lc_idx: int = LIFECYCLE_VALUES.find(mod.lifecycle)
	var lc_name: String = LIFECYCLE_NAMES[lc_idx] if lc_idx >= 0 else str(mod.lifecycle)
	var dur_str: String = str(mod.duration) if mod.duration >= 0 else "∞"
	var src: String = "%s/%s" % [mod.source_type, mod.source_id] if mod.source_type != "" else "(no source)"

	var info := Label.new()
	info.text = "[%s]  %s  %.2f  —  %s  —  %s  —  dur: %s" % [
		stat_name, op_name, mod.value, src, lc_name, dur_str
	]
	info.add_theme_color_override("font_color", op_color)
	info.add_theme_font_size_override("font_size", 16)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.clip_text = true
	row.add_child(info)

	# Value spinbox for live tweaking
	var val_spin := SpinBox.new()
	val_spin.min_value = -100.0
	val_spin.max_value = 1000.0
	val_spin.step = 0.1
	val_spin.value = mod.value
	val_spin.custom_minimum_size = Vector2(130, 0)
	val_spin.add_theme_font_size_override("font_size", 15)
	val_spin.value_changed.connect(_on_mod_value_changed.bind(mod, info, op_color, stat_name, op_name, lc_name, dur_str, src))
	row.add_child(val_spin)

	# Remove button
	var remove_btn := Button.new()
	remove_btn.text = "×"
	remove_btn.custom_minimum_size = Vector2(36, 0)
	remove_btn.add_theme_font_size_override("font_size", 18)
	remove_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	remove_btn.pressed.connect(_on_mod_removed.bind(mod))
	row.add_child(remove_btn)


# ── Event handlers ────────────────────────────────────────────────────────────

func _on_refresh_pressed() -> void:
	_rebuild_list()


func _on_filter_changed(_index: int) -> void:
	_rebuild_list()


func _on_mod_toggled(enabled: bool, mod: ModifierData) -> void:
	if _player == null:
		return
	if enabled:
		# Re-add to stack
		_disabled_mods.erase(mod)
		if mod not in _player.modifier_stack.get_all():
			_player.modifier_stack.add(mod)
	else:
		# Remove from stack but retain in _disabled_mods
		if mod not in _disabled_mods:
			_disabled_mods.append(mod)
		_player.modifier_stack.remove(mod)


func _on_mod_value_changed(new_val: float, mod: ModifierData,
		info_label: Label, op_color: Color,
		stat_name: String, op_name: String,
		lc_name: String, dur_str: String, src: String) -> void:
	mod.value = new_val
	info_label.text = "[%s]  %s  %.2f  —  %s  —  %s  —  dur: %s" % [
		stat_name, op_name, new_val, src, lc_name, dur_str
	]


func _on_mod_removed(mod: ModifierData) -> void:
	if _player != null:
		_player.modifier_stack.remove(mod)
	_disabled_mods.erase(mod)
	_rebuild_list()


func _on_add_pressed() -> void:
	if _player == null:
		return

	var stat_idx: int = _add_stat_opt.selected
	var op_idx: int = _add_op_opt.selected
	var lc_idx: int = _add_lifecycle_opt.selected

	var mod := ModifierData.new()
	mod.stat = STAT_VALUES[stat_idx]
	mod.operation = OP_VALUES[op_idx]
	mod.value = _add_value_spin.value
	mod.lifecycle = LIFECYCLE_VALUES[lc_idx]
	mod.source_type = _add_source_type_edit.text.strip_edges()
	mod.source_id = _add_source_id_edit.text.strip_edges()
	mod.id = "debug_%s_%d" % [mod.source_id if mod.source_id != "" else "manual", Time.get_ticks_msec()]

	_player.modifier_stack.add(mod)
	_rebuild_list()
