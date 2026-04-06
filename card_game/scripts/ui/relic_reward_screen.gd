extends Control

signal relic_chosen(relic_id: String)

const FONT_MEDIEVAL = preload("res://assets/fonts/MedievalSharp.ttf")
const FONT_MONO = preload("res://assets/fonts/ShareTechMono-Regular.ttf")
const FONT_LATO = preload("res://assets/fonts/Lato-Regular.ttf")

@onready var title_label: Label = $Panel/TitleLabel
@onready var relic_container: VBoxContainer = $Panel/RelicContainer

func _ready() -> void:
	visible = false

func show_relics(relic_ids: Array[String]) -> void:
	for child in relic_container.get_children():
		child.queue_free()

	title_label.text = "CHOOSE A RELIC"
	title_label.add_theme_font_override("font", FONT_MEDIEVAL)
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

	for rid in relic_ids:
		var relic = RelicSystem.get_relic(rid)
		if not relic:
			continue
		var rarity_tag = _rarity_tag(relic.rarity)
		var btn = Button.new()
		btn.text = "  %s  [%s]  —  %s" % [relic.display_name, rarity_tag, relic.description]
		btn.custom_minimum_size = Vector2(512, 48)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.tooltip_text = relic.description
		btn.add_theme_font_override("font", FONT_LATO)
		btn.add_theme_font_size_override("font_size", 15)
		btn.add_theme_color_override("font_color", _rarity_color(relic.rarity))
		# Rarity-tinted border override
		var style := _rarity_style(relic.rarity)
		if style:
			btn.add_theme_stylebox_override("normal", style)
		btn.pressed.connect(func():
			visible = false
			relic_chosen.emit(rid)
		)
		relic_container.add_child(btn)

	var skip_btn = Button.new()
	skip_btn.text = "Skip"
	skip_btn.custom_minimum_size = Vector2(512, 38)
	skip_btn.add_theme_font_override("font", FONT_LATO)
	skip_btn.add_theme_font_size_override("font_size", 15)
	skip_btn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	skip_btn.pressed.connect(func():
		visible = false
		relic_chosen.emit("")
	)
	relic_container.add_child(skip_btn)

	visible = true

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
		0:  # Common — silver-grey border
			s.bg_color = Color(0.10, 0.08, 0.20, 0.90)
			s.border_color = Color(0.55, 0.55, 0.60, 0.70)
		1:  # Uncommon — green border
			s.bg_color = Color(0.06, 0.14, 0.10, 0.90)
			s.border_color = Color(0.35, 0.80, 0.45, 0.80)
		2:  # Rare — gold border
			s.bg_color = Color(0.12, 0.10, 0.06, 0.90)
			s.border_color = Color(1.00, 0.75, 0.15, 0.90)
		_:
			s.bg_color = Color(0.10, 0.08, 0.20, 0.90)
			s.border_color = Color(0.55, 0.55, 0.60, 0.70)
	return s
