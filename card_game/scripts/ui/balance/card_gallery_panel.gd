class_name CardGalleryPanel
extends Panel

signal back_pressed

var _scroll: ScrollContainer
var _grid: GridContainer
var _title_label: Label
var _back_btn: Button

func _ready() -> void:
	# Dark background
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.06, 0.12, 0.98)
	add_theme_stylebox_override("panel", bg)

	# Title bar
	var top_bar := HBoxContainer.new()
	top_bar.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	top_bar.offset_bottom = 32
	add_child(top_bar)

	_back_btn = Button.new()
	_back_btn.text = "< Back"
	_back_btn.pressed.connect(func(): back_pressed.emit(); visible = false)
	top_bar.add_child(_back_btn)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 14)
	top_bar.add_child(_title_label)

	# Spacer to balance the back button
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 60
	top_bar.add_child(spacer)

	# Scroll + grid for cards
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_scroll.offset_top = 36
	add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)


func show_cards(card_ids: Array, title: String) -> void:
	_title_label.text = title
	visible = true

	# Clear old cards
	for c in _grid.get_children():
		c.queue_free()

	# Load card visuals
	var card_scene := preload("res://scenes/cards/card_visual.tscn")
	for card_id in card_ids:
		var path := "res://data/cards/%s.tres" % card_id
		if not ResourceLoader.exists(path):
			continue
		var card_data = load(path)
		if card_data == null:
			continue
		var card_vis := card_scene.instantiate()
		_grid.add_child(card_vis)
		card_vis.setup(card_data)
