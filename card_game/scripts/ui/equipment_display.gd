extends Control

# ---------------------------------------------------------------------------
# Font export — assigned in .tscn
# ---------------------------------------------------------------------------
@export var _font_mono: FontFile

# ---------------------------------------------------------------------------
# Rarity colors matching the rest of the UI
# ---------------------------------------------------------------------------
const RARITY_COLORS: Array[Color] = [
	Color(0.65, 0.65, 0.68),   # Common   — muted silver
	Color(0.35, 0.80, 0.45),   # Uncommon — green
	Color(0.30, 0.55, 1.00),   # Rare     — blue
	Color(1.00, 0.75, 0.15),   # Legendary — gold
]

const COLOR_EMPTY  := Color(0.30, 0.28, 0.40, 0.60)
const COLOR_CHIP_BORDER_BASE := Color(0.28, 0.24, 0.42, 0.60)

const SLOT_LABELS := {0: "Head", 1: "Chest", 2: "Wpn", 3: "Acc"}
const SLOT_ICONS  := {0: "◈", 1: "◧", 2: "⚔", 3: "◉"}

@onready var equip_container: HBoxContainer = $EquipContainer


func update_equipment(equipment: Dictionary) -> void:
	for child in equip_container.get_children():
		child.queue_free()

	for slot in [0, 1, 2, 3]:
		var equip_id: String = equipment.get(slot, "")
		var chip := _build_chip(slot, equip_id)
		equip_container.add_child(chip)


func _build_chip(slot: int, equip_id: String) -> PanelContainer:
	var equip: EquipmentData = null
	if equip_id != "":
		equip = EquipmentSystem.get_equipment(equip_id)

	var rarity_color: Color = Color(0.45, 0.85, 1.00, 1.00) if equip else COLOR_EMPTY

	# Panel with rarity-tinted border
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(0, 22)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.05, 0.14, 0.85)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = rarity_color.darkened(0.20) if equip else COLOR_CHIP_BORDER_BASE
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	sb.content_margin_left = 5.0
	sb.content_margin_top = 2.0
	sb.content_margin_right = 5.0
	sb.content_margin_bottom = 2.0
	chip.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	if _font_mono:
		lbl.add_theme_font_override("font", _font_mono)
	lbl.add_theme_font_size_override("font_size", 11)

	if equip:
		var rarity_idx := clampi(equip.rarity, 0, RARITY_COLORS.size() - 1)
		lbl.text = "%s %s" % [SLOT_ICONS.get(slot, "◇"), equip.display_name]
		lbl.add_theme_color_override("font_color", RARITY_COLORS[rarity_idx])
		chip.tooltip_text = "[%s]  %s\n%s" % [SLOT_LABELS.get(slot, "?"), equip.display_name, equip.description]
	else:
		lbl.text = "%s —" % SLOT_ICONS.get(slot, "◇")
		lbl.add_theme_color_override("font_color", COLOR_EMPTY)
		chip.tooltip_text = "%s: Empty" % SLOT_LABELS.get(slot, "Slot")

	chip.add_child(lbl)
	return chip
