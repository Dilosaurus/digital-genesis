extends Control

signal equipment_done

# ---------------------------------------------------------------------------
# Rarity data
# ---------------------------------------------------------------------------
const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Legendary"]

const RARITY_COLORS: Array[Color] = [
	Color(0.75, 0.75, 0.78),  # Common   — silver-grey
	Color(0.35, 0.80, 0.45),  # Uncommon — green
	Color(0.30, 0.55, 1.00),  # Rare     — blue
	Color(1.00, 0.75, 0.15),  # Legendary — gold
]

const SLOT_NAMES: Dictionary = {
	Enums.EquipSlot.HEAD:      "Head",
	Enums.EquipSlot.CHEST:     "Chest",
	Enums.EquipSlot.WEAPON:    "Weapon",
	Enums.EquipSlot.ACCESSORY: "Accessory",
}

# Slot icon glyphs (Unicode fallback symbols used in header labels)
const SLOT_ICONS: Dictionary = {
	Enums.EquipSlot.HEAD:      "◈",
	Enums.EquipSlot.CHEST:     "◧",
	Enums.EquipSlot.WEAPON:    "⚔",
	Enums.EquipSlot.ACCESSORY: "◉",
}

# ---------------------------------------------------------------------------
# Slot-row style helpers
# ---------------------------------------------------------------------------
const STYLE_SLOT_FILLED := {
	"bg":     Color(0.09, 0.07, 0.18, 0.92),
	"border": Color(0.40, 0.35, 0.65, 0.80),
}
const STYLE_SLOT_EMPTY := {
	"bg":     Color(0.06, 0.05, 0.12, 0.70),
	"border": Color(0.22, 0.18, 0.35, 0.50),
}
const STYLE_SLOT_SELECTED := {
	"bg":     Color(0.12, 0.09, 0.24, 1.00),
	"border": Color(0.55, 0.45, 0.90, 1.00),
}

# ---------------------------------------------------------------------------
# Node refs
# ---------------------------------------------------------------------------
@onready var slot_container: VBoxContainer = $Panel/MainLayout/SlotArea/SlotContainer
@onready var done_button: Button = $Panel/ButtonRow/DoneButton
@onready var detail_name: Label = $Panel/MainLayout/DetailPanel/DetailContent/DetailName
@onready var detail_rarity: Label = $Panel/MainLayout/DetailPanel/DetailContent/DetailRarity
@onready var detail_desc: Label = $Panel/MainLayout/DetailPanel/DetailContent/DetailDesc
@onready var detail_stats: VBoxContainer = $Panel/MainLayout/DetailPanel/DetailContent/DetailStats

var _selected_slot: int = -1

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	done_button.pressed.connect(_on_done_pressed)
	hide()


func show_equipment() -> void:
	_selected_slot = -1
	_rebuild_slots()
	_update_detail_panel(null)
	show()


# ---------------------------------------------------------------------------
# Slot list
# ---------------------------------------------------------------------------
func _rebuild_slots() -> void:
	for child in slot_container.get_children():
		child.queue_free()

	var run: RunState = GameManager.current_run
	var slot_order: Array[Enums.EquipSlot] = [
		Enums.EquipSlot.HEAD,
		Enums.EquipSlot.CHEST,
		Enums.EquipSlot.WEAPON,
		Enums.EquipSlot.ACCESSORY,
	]

	for slot in slot_order:
		var row := _build_slot_row(run, slot)
		slot_container.add_child(row)


func _build_slot_row(run: RunState, slot: Enums.EquipSlot) -> PanelContainer:
	var slot_int: int = int(slot)
	var equip_id: String = run.equipment.get(slot_int, "") if run else ""
	var equip_data: EquipmentData = null
	if equip_id != "":
		equip_data = EquipmentSystem.get_equipment(equip_id)

	var is_selected := (_selected_slot == slot_int)
	var style_src: Dictionary = STYLE_SLOT_SELECTED if is_selected else (STYLE_SLOT_FILLED if equip_data else STYLE_SLOT_EMPTY)

	# Outer panel with rounded styled border
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 62)
	var sb := StyleBoxFlat.new()
	sb.bg_color = style_src["bg"]
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = style_src["border"]
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_right = 6
	sb.corner_radius_bottom_left = 6
	sb.content_margin_left = 10.0
	sb.content_margin_top = 8.0
	sb.content_margin_right = 10.0
	sb.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", sb)

	# Inner row
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	# Slot icon + name column
	var left_col := VBoxContainer.new()
	left_col.custom_minimum_size = Vector2(100, 0)
	left_col.add_theme_constant_override("separation", 1)
	row.add_child(left_col)

	var icon_label := Label.new()
	icon_label.text = "%s  %s" % [SLOT_ICONS.get(slot, "◇"), SLOT_NAMES[slot].to_upper()]
	icon_label.add_theme_font_size_override("font_size", 11)
	icon_label.add_theme_color_override("font_color", Color(0.45, 0.85, 1.00, 0.85))
	left_col.add_child(icon_label)

	# Item info column
	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 2)
	row.add_child(info_col)

	if equip_data:
		var rarity_color: Color = RARITY_COLORS[clampi(equip_data.rarity, 0, RARITY_COLORS.size() - 1)]

		var name_label := Label.new()
		name_label.text = equip_data.display_name
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.add_theme_color_override("font_color", rarity_color)
		info_col.add_child(name_label)

		var rarity_lbl := Label.new()
		rarity_lbl.text = RARITY_NAMES[clampi(equip_data.rarity, 0, RARITY_NAMES.size() - 1)]
		rarity_lbl.add_theme_font_size_override("font_size", 11)
		rarity_lbl.add_theme_color_override("font_color", rarity_color.lightened(0.1))
		info_col.add_child(rarity_lbl)
	else:
		var empty_label := Label.new()
		empty_label.text = "— Empty —"
		empty_label.add_theme_font_size_override("font_size", 13)
		empty_label.add_theme_color_override("font_color", Color(0.35, 0.33, 0.45, 0.70))
		info_col.add_child(empty_label)

	# Right-side buttons
	var btn_col := VBoxContainer.new()
	btn_col.add_theme_constant_override("separation", 4)
	btn_col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(btn_col)

	if equip_data:
		var select_btn := Button.new()
		select_btn.text = "Details"
		select_btn.custom_minimum_size = Vector2(78, 24)
		select_btn.add_theme_font_size_override("font_size", 12)
		var captured_slot: int = slot_int
		var captured_data: EquipmentData = equip_data
		select_btn.pressed.connect(func() -> void:
			_on_slot_selected(captured_slot, captured_data)
		)
		btn_col.add_child(select_btn)

		var unequip_btn := Button.new()
		unequip_btn.text = "Unequip"
		unequip_btn.custom_minimum_size = Vector2(78, 24)
		unequip_btn.add_theme_font_size_override("font_size", 12)
		unequip_btn.pressed.connect(func() -> void:
			_on_unequip_pressed(captured_slot)
		)
		btn_col.add_child(unequip_btn)
	else:
		# Filler so layout height stays consistent
		var filler := Control.new()
		filler.custom_minimum_size = Vector2(78, 0)
		btn_col.add_child(filler)

	# Make the whole panel row clickable for selection
	if equip_data:
		var captured_slot: int = slot_int
		var captured_data: EquipmentData = equip_data
		panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_slot_selected(captured_slot, captured_data)
		)
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	return panel


# ---------------------------------------------------------------------------
# Detail panel
# ---------------------------------------------------------------------------
func _on_slot_selected(slot_int: int, equip_data: EquipmentData) -> void:
	_selected_slot = slot_int
	_rebuild_slots()
	_update_detail_panel(equip_data)


func _update_detail_panel(equip_data: EquipmentData) -> void:
	for child in detail_stats.get_children():
		child.queue_free()

	if equip_data == null:
		detail_name.text = ""
		detail_rarity.text = ""
		detail_desc.text = "Select an equipped item\nto view its details."
		return

	var rarity_idx := clampi(equip_data.rarity, 0, RARITY_COLORS.size() - 1)
	var rarity_color: Color = RARITY_COLORS[rarity_idx]

	detail_name.text = equip_data.display_name
	detail_name.add_theme_color_override("font_color", rarity_color)

	detail_rarity.text = "%s  •  %s" % [
		RARITY_NAMES[rarity_idx],
		_slot_name_from_data(equip_data),
	]
	detail_rarity.add_theme_color_override("font_color", rarity_color.darkened(0.1))

	detail_desc.text = equip_data.description if equip_data.description != "" else "No description."
	detail_desc.add_theme_color_override("font_color", Color(0.80, 0.80, 0.85, 1.00))

	# Modifier stats
	if equip_data.has_method("get_modifiers") or equip_data.get("modifiers") != null:
		var mods = equip_data.get("modifiers")
		if mods and mods.size() > 0:
			for mod in mods:
				var stat_row := HBoxContainer.new()
				stat_row.add_theme_constant_override("separation", 6)
				detail_stats.add_child(stat_row)

				var stat_name := Label.new()
				stat_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				stat_name.text = _format_mod_name(mod)
				stat_name.add_theme_font_size_override("font_size", 12)
				stat_name.add_theme_color_override("font_color", Color(0.70, 0.70, 0.80, 1.00))
				stat_row.add_child(stat_name)

				var stat_val := Label.new()
				stat_val.text = _format_mod_value(mod)
				stat_val.add_theme_font_size_override("font_size", 13)
				stat_val.add_theme_color_override("font_color", Color(0.45, 0.85, 1.00, 1.00))
				stat_row.add_child(stat_val)


func _slot_name_from_data(_equip: EquipmentData) -> String:
	# Try to infer slot from equip_data.slot if present
	var slot_val = _equip.get("equip_slot")
	if slot_val != null and SLOT_NAMES.has(slot_val):
		return SLOT_NAMES[slot_val]
	return "Equipment"


func _format_mod_name(mod: Variant) -> String:
	if mod == null:
		return "?"
	var stat_id = mod.get("stat_id") if mod.get("stat_id") != null else ""
	return stat_id.replace("_", " ").capitalize()


func _format_mod_value(mod: Variant) -> String:
	if mod == null:
		return "?"
	var flat = mod.get("flat_bonus")
	var pct  = mod.get("percent_bonus")
	var parts: Array[String] = []
	if flat != null and flat != 0:
		parts.append("%+d" % int(flat))
	if pct != null and pct != 0:
		parts.append("%+d%%" % int(pct * 100.0))
	return "  ".join(parts) if parts.size() > 0 else "—"


# ---------------------------------------------------------------------------
# Interaction handlers
# ---------------------------------------------------------------------------
func _on_unequip_pressed(slot_int: int) -> void:
	var run: RunState = GameManager.current_run
	EquipmentSystem.unequip(run, slot_int)
	if _selected_slot == slot_int:
		_selected_slot = -1
		_update_detail_panel(null)
	_rebuild_slots()


func _on_done_pressed() -> void:
	hide()
	equipment_done.emit()
