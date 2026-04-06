class_name PipelineTab
extends VBoxContainer

# ── References ──────────────────────────────────────────────────────────────
var _player: PlayerState = null
var _target = null  # EnemyState or similar — used for vulnerable check

# ── Stat name tables ─────────────────────────────────────────────────────────
const STAT_NAMES: Array[String] = ["DAMAGE", "BLOCK", "HEALING"]
const STAT_VALUES: Array[int] = [
	Enums.Stat.DAMAGE,
	Enums.Stat.BLOCK,
	Enums.Stat.HEALING,
]
const STAT_DEFAULTS: Array[float] = [6.0, 5.0, 4.0]

# ── UI nodes ─────────────────────────────────────────────────────────────────
var _stat_option: OptionButton
var _base_spin: SpinBox
var _resolve_btn: Button
var _pipeline_vbox: VBoxContainer

# ── Colors ───────────────────────────────────────────────────────────────────
const COLOR_WHITE   := Color(0.95, 0.95, 0.95)
const COLOR_GREEN   := Color(0.35, 1.0, 0.45)
const COLOR_RED     := Color(1.0, 0.35, 0.35)
const COLOR_CYAN    := Color(0.3, 0.9, 1.0)
const COLOR_YELLOW  := Color(1.0, 0.92, 0.25)
const COLOR_GRAY    := Color(0.5, 0.5, 0.55)
const COLOR_HEADER  := Color(0.75, 0.75, 0.80)
const COLOR_FINAL   := Color(0.4, 1.0, 0.5)

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_theme_constant_override("separation", 8)

	_build_top_bar()
	_build_pipeline_area()
	_show_placeholder("Click Resolve to run the pipeline.")


func set_player(player: PlayerState) -> void:
	_player = player


func set_target(target) -> void:
	_target = target


# ── UI construction ───────────────────────────────────────────────────────────

func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	bar.custom_minimum_size = Vector2(0, 48)
	add_child(bar)

	var stat_label := Label.new()
	stat_label.text = "Stat:"
	stat_label.add_theme_color_override("font_color", COLOR_HEADER)
	stat_label.add_theme_font_size_override("font_size", 18)
	bar.add_child(stat_label)

	_stat_option = OptionButton.new()
	_stat_option.custom_minimum_size = Vector2(150, 0)
	_stat_option.add_theme_font_size_override("font_size", 17)
	for name in STAT_NAMES:
		_stat_option.add_item(name)
	_stat_option.selected = 0
	_stat_option.item_selected.connect(_on_stat_changed)
	bar.add_child(_stat_option)

	var sep1 := Control.new()
	sep1.custom_minimum_size = Vector2(20, 0)
	bar.add_child(sep1)

	var base_label := Label.new()
	base_label.text = "Base:"
	base_label.add_theme_color_override("font_color", COLOR_HEADER)
	base_label.add_theme_font_size_override("font_size", 18)
	bar.add_child(base_label)

	_base_spin = SpinBox.new()
	_base_spin.min_value = 0
	_base_spin.max_value = 100
	_base_spin.step = 1
	_base_spin.value = STAT_DEFAULTS[0]
	_base_spin.custom_minimum_size = Vector2(120, 0)
	_base_spin.add_theme_font_size_override("font_size", 17)
	_base_spin.value_changed.connect(_on_base_changed)
	bar.add_child(_base_spin)

	var sep2 := Control.new()
	sep2.custom_minimum_size = Vector2(20, 0)
	bar.add_child(sep2)

	_resolve_btn = Button.new()
	_resolve_btn.text = "Resolve"
	_resolve_btn.custom_minimum_size = Vector2(120, 0)
	_resolve_btn.add_theme_font_size_override("font_size", 17)
	_resolve_btn.pressed.connect(_on_resolve_pressed)
	bar.add_child(_resolve_btn)

	# Spacer to push controls left
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)


func _build_pipeline_area() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_pipeline_vbox = VBoxContainer.new()
	_pipeline_vbox.add_theme_constant_override("separation", 4)
	_pipeline_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_pipeline_vbox)


# ── Event handlers ────────────────────────────────────────────────────────────

func _on_stat_changed(index: int) -> void:
	_base_spin.value = STAT_DEFAULTS[index]


func _on_base_changed(_value: float) -> void:
	pass  # Resolve is manual — do not auto-run on every spinbox tick


func _on_resolve_pressed() -> void:
	_run_trace()


# ── Pipeline logic ────────────────────────────────────────────────────────────

func _run_trace() -> void:
	_clear_pipeline()

	if _player == null:
		_show_placeholder("No active combat — call set_player() first.")
		return

	var stat_index: int = _stat_option.selected
	var stat: int = STAT_VALUES[stat_index]
	var base_value: float = _base_spin.value

	match stat:
		Enums.Stat.DAMAGE:
			_display_damage_trace(base_value)
		Enums.Stat.BLOCK:
			_display_block_trace(base_value)
		Enums.Stat.HEALING:
			_display_healing_trace(base_value)


func _display_damage_trace(base_value: float) -> void:
	var player := _player

	# Build trace manually using the same logic as StatResolver / StatResolverTrace
	var strength_add: float = float(player.strength)
	var adjusted_base: float = base_value + strength_add

	_add_line("Base Value:  %.0f" % base_value, COLOR_WHITE)

	if strength_add != 0.0:
		var sign_str: String = "+" if strength_add >= 0.0 else ""
		_add_line("+ Strength:  %s%.0f  →  %.0f" % [sign_str, strength_add, adjusted_base], COLOR_GREEN if strength_add >= 0.0 else COLOR_RED)
	else:
		_add_line("  Strength:  (none)", COLOR_GRAY)

	_add_separator()

	var ctx := _build_context(null)
	_display_stack_phases(Enums.Stat.DAMAGE, adjusted_base, ctx)

	_add_separator()
	_add_line("--- POST-STACK ---", COLOR_HEADER)

	var after_stack: float = _compute_after_stack(Enums.Stat.DAMAGE, adjusted_base, ctx)

	var vuln_label: String
	var weak_label: String
	var final_val: float = after_stack

	if _target != null and _target.vulnerable > 0:
		vuln_label = "Vulnerable:  ×1.5  (active)"
		final_val *= 1.5
	else:
		vuln_label = "Vulnerable:  —"
	_add_line(vuln_label, COLOR_CYAN if (_target != null and _target.vulnerable > 0) else COLOR_GRAY)

	if player.weak > 0:
		weak_label = "Weak:        ×0.75  (active)"
		final_val *= 0.75
	else:
		weak_label = "Weak:        —"
	_add_line(weak_label, COLOR_RED if player.weak > 0 else COLOR_GRAY)

	_add_separator()
	_add_final(final_val)


func _display_block_trace(base_value: float) -> void:
	var player := _player

	var dex_add: float = float(player.dexterity)
	var adjusted_base: float = base_value + dex_add

	_add_line("Base Value:  %.0f" % base_value, COLOR_WHITE)

	if dex_add != 0.0:
		var sign_str: String = "+" if dex_add >= 0.0 else ""
		_add_line("+ Dexterity: %s%.0f  →  %.0f" % [sign_str, dex_add, adjusted_base], COLOR_GREEN if dex_add >= 0.0 else COLOR_RED)
	else:
		_add_line("  Dexterity: (none)", COLOR_GRAY)

	_add_separator()

	var ctx := _build_context(null)
	_display_stack_phases(Enums.Stat.BLOCK, adjusted_base, ctx)

	_add_separator()
	_add_final(_compute_after_stack(Enums.Stat.BLOCK, adjusted_base, ctx))


func _display_healing_trace(base_value: float) -> void:
	_add_line("Base Value:  %.0f" % base_value, COLOR_WHITE)
	_add_separator()

	var ctx := _build_context(null)
	_display_stack_phases(Enums.Stat.HEALING, base_value, ctx)

	_add_separator()
	_add_line("--- POST-STACK ---", COLOR_HEADER)
	_add_line("  (no post-stack multipliers for healing)", COLOR_GRAY)
	_add_separator()
	_add_final(_compute_after_stack(Enums.Stat.HEALING, base_value, ctx))


func _display_stack_phases(stat: int, adjusted_base: float, ctx: Dictionary) -> void:
	var stack := _player.modifier_stack
	var all_mods: Array[ModifierData] = stack.get_all()

	# Filter to stat + context
	var active_mods: Array[ModifierData] = []
	for mod in all_mods:
		if mod.stat == stat:
			active_mods.append(mod)

	# --- Check for OVERRIDE ---
	var override_mods: Array[ModifierData] = []
	for mod in active_mods:
		if mod.operation == Enums.ModOp.OVERRIDE:
			override_mods.append(mod)

	if override_mods.size() > 0:
		_add_line("--- OVERRIDE ---", COLOR_HEADER)
		var best_override: ModifierData = override_mods[0]
		for mod in override_mods:
			var marker: String = " ← wins" if mod == best_override else ""
			if mod.value > best_override.value:
				best_override = mod
			_add_line("  %s/%s:  =%.2f" % [mod.source_type, mod.source_id, mod.value], COLOR_RED)
		_add_line("= OVERRIDE value:  %.2f" % best_override.value, COLOR_YELLOW)
		return

	# --- FLAT_ADD ---
	var flat_mods: Array[ModifierData] = []
	for mod in active_mods:
		if mod.operation == Enums.ModOp.FLAT_ADD:
			flat_mods.append(mod)

	_add_line("--- FLAT_ADD ---", COLOR_HEADER)
	var flat_total: float = adjusted_base
	if flat_mods.is_empty():
		_add_line("  (none)", COLOR_GRAY)
	else:
		for mod in flat_mods:
			var sign_str: String = "+" if mod.value >= 0.0 else ""
			_add_line("  %s/%s:  %s%.2f" % [mod.source_type, mod.source_id, sign_str, mod.value],
					COLOR_GREEN if mod.value >= 0.0 else COLOR_RED)
			flat_total += mod.value
	_add_line("= After Flat:  %.2f" % flat_total, COLOR_WHITE)

	# --- PERCENT_ADD ---
	var pct_add_mods: Array[ModifierData] = []
	for mod in active_mods:
		if mod.operation == Enums.ModOp.PERCENT_ADD:
			pct_add_mods.append(mod)

	_add_line("--- PERCENT_ADD ---", COLOR_HEADER)
	var pct_add_sum: float = 0.0
	if pct_add_mods.is_empty():
		_add_line("  (none)", COLOR_GRAY)
	else:
		for mod in pct_add_mods:
			var sign_str: String = "+" if mod.value >= 0.0 else ""
			_add_line("  %s/%s:  %s%.1f%%" % [mod.source_type, mod.source_id, sign_str, mod.value * 100.0],
					COLOR_GREEN if mod.value >= 0.0 else COLOR_RED)
			pct_add_sum += mod.value
	var after_pct_add: float = flat_total * (1.0 + pct_add_sum)
	var pct_mult_str: String = "  (×%.3f)" % (1.0 + pct_add_sum) if pct_add_mods.size() > 0 else ""
	_add_line("= After %%Add:  %.2f%s" % [after_pct_add, pct_mult_str], COLOR_WHITE)

	# --- PERCENT_MULT ---
	var pct_mult_mods: Array[ModifierData] = []
	for mod in active_mods:
		if mod.operation == Enums.ModOp.PERCENT_MULT:
			pct_mult_mods.append(mod)

	_add_line("--- PERCENT_MULT ---", COLOR_HEADER)
	var after_pct_mult: float = after_pct_add
	if pct_mult_mods.is_empty():
		_add_line("  (none)", COLOR_GRAY)
	else:
		for mod in pct_mult_mods:
			_add_line("  %s/%s:  ×%.3f" % [mod.source_type, mod.source_id, mod.value],
					COLOR_YELLOW if mod.value >= 1.0 else COLOR_RED)
			after_pct_mult *= mod.value
	_add_line("= After %%Mult:  %.2f" % after_pct_mult, COLOR_WHITE)


func _compute_after_stack(stat: int, adjusted_base: float, ctx: Dictionary) -> float:
	return _player.modifier_stack.resolve(stat, adjusted_base, ctx)


func _build_context(card_data: CardData) -> Dictionary:
	var ctx: Dictionary = {}
	if card_data:
		ctx["card_type"] = card_data.card_type
		ctx["card_tags"] = card_data.tags
	else:
		ctx["card_type"] = -1
		ctx["card_tags"] = []
	ctx["target_vulnerable"] = (_target != null and _target.vulnerable > 0)
	ctx["player_hp_pct"] = float(_player.current_hp) / float(_player.max_hp) if _player.max_hp > 0 else 1.0
	return ctx


# ── Display helpers ───────────────────────────────────────────────────────────

func _clear_pipeline() -> void:
	for child in _pipeline_vbox.get_children():
		child.queue_free()


func _show_placeholder(msg: String) -> void:
	_clear_pipeline()
	var lbl := Label.new()
	lbl.text = msg
	lbl.add_theme_color_override("font_color", COLOR_GRAY)
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pipeline_vbox.add_child(lbl)


func _add_line(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.custom_minimum_size = Vector2(0, 24)
	_pipeline_vbox.add_child(lbl)


func _add_separator() -> void:
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.3, 0.3, 0.35))
	sep.custom_minimum_size = Vector2(0, 6)
	_pipeline_vbox.add_child(sep)


func _add_final(value: float) -> void:
	var lbl := Label.new()
	lbl.text = "═══  FINAL:  %.0f  ═══" % value
	lbl.add_theme_color_override("font_color", COLOR_FINAL)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(0, 36)
	_pipeline_vbox.add_child(lbl)
