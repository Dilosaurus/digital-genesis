extends Control

signal equipment_chosen(equip_id: String)

const FONT_MEDIEVAL = preload("res://assets/fonts/MedievalSharp.ttf")
const FONT_MONO = preload("res://assets/fonts/ShareTechMono-Regular.ttf")
const FONT_LATO = preload("res://assets/fonts/Lato-Regular.ttf")

@onready var title_label: Label = $Panel/TitleLabel
@onready var item_container: VBoxContainer = $Panel/ItemContainer

func _ready() -> void:
	visible = false

func show_equipment(equip_ids: Array[String]) -> void:
	for child in item_container.get_children():
		child.queue_free()

	title_label.text = "CHOOSE EQUIPMENT"
	title_label.add_theme_font_override("font", FONT_MEDIEVAL)
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

	for eid in equip_ids:
		var equip = EquipmentSystem.get_equipment(eid)
		if not equip:
			continue
		var slot_name = _slot_name(equip.slot)
		var rarity_tag = _rarity_tag(equip.rarity)
		var btn = Button.new()
		btn.text = "  %s  [%s]  (%s)  —  %s" % [equip.display_name, slot_name, rarity_tag, equip.description]
		btn.custom_minimum_size = Vector2(552, 50)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.tooltip_text = equip.description
		btn.add_theme_font_override("font", FONT_LATO)
		btn.add_theme_font_size_override("font_size", 15)
		btn.add_theme_color_override("font_color", _rarity_color(equip.rarity))
		btn.add_theme_stylebox_override("normal", _rarity_style(equip.rarity))
		btn.pressed.connect(func():
			visible = false
			equipment_chosen.emit(eid)
		)
		item_container.add_child(btn)

	var skip_btn = Button.new()
	skip_btn.text = "Skip"
	skip_btn.custom_minimum_size = Vector2(552, 38)
	skip_btn.add_theme_font_override("font", FONT_LATO)
	skip_btn.add_theme_font_size_override("font_size", 15)
	skip_btn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	skip_btn.pressed.connect(func():
		visible = false
		equipment_chosen.emit("")
	)
	item_container.add_child(skip_btn)

	visible = true

func _slot_name(slot: int) -> String:
	match slot:
		Enums.EquipSlot.HEAD: return "Head"
		Enums.EquipSlot.CHEST: return "Chest"
		Enums.EquipSlot.WEAPON: return "Weapon"
		Enums.EquipSlot.ACCESSORY: return "Accessory"
	return "?"

func _rarity_tag(rarity: int) -> String:
	match rarity:
		0: return "Common"
		1: return "Uncommon"
		2: return "Rare"
	return "Common"

func _rarity_color(rarity: int) -> Color:
	match rarity:
		0: return Color(0.75, 0.75, 0.78)
		1: return Color(0.35, 0.80, 0.45)
		2: return Color(1.00, 0.75, 0.15)
	return Color(0.75, 0.75, 0.78)

func _rarity_style(rarity: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.corner_radius_top_left = 6
	s.corner_radius_top_right = 6
	s.corner_radius_bottom_right = 6
	s.corner_radius_bottom_left = 6
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.content_margin_left = 12.0
	s.content_margin_top = 6.0
	s.content_margin_right = 12.0
	s.content_margin_bottom = 6.0
	match rarity:
		0:  # Common
			s.bg_color = Color(0.10, 0.08, 0.20, 0.90)
			s.border_color = Color(0.55, 0.55, 0.60, 0.70)
		1:  # Uncommon — blue-tinted for equipment
			s.bg_color = Color(0.06, 0.10, 0.22, 0.90)
			s.border_color = Color(0.40, 0.75, 1.00, 0.80)
		2:  # Rare — gold
			s.bg_color = Color(0.12, 0.10, 0.06, 0.90)
			s.border_color = Color(1.00, 0.75, 0.15, 0.90)
		_:
			s.bg_color = Color(0.10, 0.08, 0.20, 0.90)
			s.border_color = Color(0.55, 0.55, 0.60, 0.70)
	return s
