class_name CardsTab
extends VBoxContainer

signal gallery_requested(card_ids: Array, title: String)

# ---------------------------------------------------------------------------
# Color constants
# ---------------------------------------------------------------------------
const COLOR_ATTACK   := Color(0.85, 0.35, 0.20, 1.0)   # red-orange
const COLOR_SKILL    := Color(0.25, 0.55, 0.90, 1.0)   # blue
const COLOR_POWER    := Color(0.85, 0.72, 0.10, 1.0)   # gold
const COLOR_STATUS   := Color(0.55, 0.55, 0.55, 1.0)   # grey
const COLOR_CURSE    := Color(0.60, 0.15, 0.75, 1.0)   # purple

const COLOR_TAG_BG   := Color(0.20, 0.20, 0.25, 1.0)
const COLOR_ROW_BG   := Color(0.14, 0.14, 0.18, 1.0)
const COLOR_ROW_SEL  := Color(0.22, 0.28, 0.38, 1.0)
const COLOR_DETAIL   := Color(0.10, 0.10, 0.13, 1.0)

const TAG_COLORS: Dictionary = {
	Enums.CardTag.MELEE:   Color(0.75, 0.30, 0.20, 1.0),
	Enums.CardTag.RANGED:  Color(0.25, 0.60, 0.35, 1.0),
	Enums.CardTag.FIRE:    Color(0.90, 0.45, 0.10, 1.0),
	Enums.CardTag.ICE:     Color(0.25, 0.65, 0.90, 1.0),
	Enums.CardTag.HOLY:    Color(0.90, 0.85, 0.40, 1.0),
	Enums.CardTag.SHADOW:  Color(0.50, 0.20, 0.70, 1.0),
	Enums.CardTag.TECH:    Color(0.20, 0.75, 0.75, 1.0),
	Enums.CardTag.EXPLOIT: Color(0.85, 0.55, 0.15, 1.0),
	Enums.CardTag.CURSE:   Color(0.55, 0.10, 0.55, 1.0),
}

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var _player: PlayerState = null
var _target = null

var _all_cards: Array[CardData] = []
var _filtered_cards: Array[CardData] = []
var _selected_card: CardData = null

# Filter/sort controls
var _search_edit: LineEdit
var _type_filter: OptionButton
var _tag_filter: OptionButton
var _sort_option: OptionButton

# List
var _list_vbox: VBoxContainer
var _row_nodes: Dictionary = {}          # card id -> PanelContainer

# Detail panel
var _detail_panel: PanelContainer
var _detail_label: Label
var _detail_resolved_label: Label

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

func _ready() -> void:
	name = "CardsTab"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_build_filter_bar()
	_build_card_list()
	_build_detail_panel()

	_load_cards()

func _build_filter_bar() -> void:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 36)
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)

	# Search
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Search name / id..."
	_search_edit.custom_minimum_size = Vector2(280, 0)
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.text_changed.connect(_on_filter_changed.unbind(1))
	bar.add_child(_search_edit)

	# Type filter
	var type_lbl := Label.new()
	type_lbl.text = "Type:"
	type_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	bar.add_child(type_lbl)

	_type_filter = OptionButton.new()
	_type_filter.add_item("All Types", -1)
	_type_filter.add_item("Attack",    Enums.CardType.ATTACK)
	_type_filter.add_item("Skill",     Enums.CardType.SKILL)
	_type_filter.add_item("Power",     Enums.CardType.POWER)
	_type_filter.add_item("Status",    Enums.CardType.STATUS)
	_type_filter.add_item("Curse",     Enums.CardType.CURSE)
	_type_filter.item_selected.connect(_on_filter_changed.unbind(1))
	bar.add_child(_type_filter)

	# Tag filter
	var tag_lbl := Label.new()
	tag_lbl.text = "Tag:"
	tag_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	bar.add_child(tag_lbl)

	_tag_filter = OptionButton.new()
	_tag_filter.add_item("All Tags", -1)
	for tag_val in Enums.CardTag.values():
		var tag_name: String = Enums.CardTag.find_key(tag_val)
		_tag_filter.add_item(tag_name.capitalize(), tag_val)
	_tag_filter.item_selected.connect(_on_filter_changed.unbind(1))
	bar.add_child(_tag_filter)

	# Sort
	var sort_lbl := Label.new()
	sort_lbl.text = "Sort:"
	sort_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	bar.add_child(sort_lbl)

	_sort_option = OptionButton.new()
	_sort_option.add_item("Name",        0)
	_sort_option.add_item("Energy Cost", 1)
	_sort_option.add_item("DPE",         2)
	_sort_option.add_item("BPE",         3)
	_sort_option.add_item("Damage",      4)
	_sort_option.add_item("Block",       5)
	_sort_option.item_selected.connect(_on_filter_changed.unbind(1))
	bar.add_child(_sort_option)

	# Visual Gallery button
	var gallery_btn := Button.new()
	gallery_btn.text = "Visual Gallery"
	var gallery_style := StyleBoxFlat.new()
	gallery_style.bg_color = Color(0.15, 0.3, 0.5, 1.0)
	gallery_style.corner_radius_top_left = 4
	gallery_style.corner_radius_top_right = 4
	gallery_style.corner_radius_bottom_left = 4
	gallery_style.corner_radius_bottom_right = 4
	gallery_btn.add_theme_stylebox_override("normal", gallery_style)
	gallery_btn.add_theme_color_override("font_color", Color.WHITE)
	gallery_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gallery_btn.pressed.connect(_on_gallery_requested)
	bar.add_child(gallery_btn)

	# Refresh button
	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_load_cards)
	bar.add_child(refresh_btn)

func _build_card_list() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 2)
	scroll.add_child(_list_vbox)

func _build_detail_panel() -> void:
	_detail_panel = PanelContainer.new()
	_detail_panel.custom_minimum_size = Vector2(0, 180)
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = COLOR_DETAIL
	detail_style.border_width_top = 1
	detail_style.border_color = Color(0.3, 0.3, 0.4, 1.0)
	detail_style.content_margin_left = 12.0
	detail_style.content_margin_right = 12.0
	detail_style.content_margin_top = 8.0
	detail_style.content_margin_bottom = 8.0
	_detail_panel.add_theme_stylebox_override("panel", detail_style)
	add_child(_detail_panel)

	var detail_vbox := VBoxContainer.new()
	detail_vbox.add_theme_constant_override("separation", 4)
	_detail_panel.add_child(detail_vbox)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.custom_minimum_size = Vector2(0, 160)
	detail_vbox.add_child(detail_scroll)

	var inner_vbox := VBoxContainer.new()
	inner_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_vbox.add_theme_constant_override("separation", 3)
	detail_scroll.add_child(inner_vbox)

	_detail_label = Label.new()
	_detail_label.text = "Click a card to see details."
	_detail_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_vbox.add_child(_detail_label)

	_detail_resolved_label = Label.new()
	_detail_resolved_label.text = ""
	_detail_resolved_label.add_theme_color_override("font_color", Color(0.60, 0.90, 0.60))
	_detail_resolved_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_resolved_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_vbox.add_child(_detail_resolved_label)

# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------

func _load_cards() -> void:
	_all_cards.clear()
	var db: Dictionary = GameManager.card_database
	for card_id in db:
		var card: CardData = db[card_id]
		_all_cards.append(card)
	_apply_filter_and_sort()

# ---------------------------------------------------------------------------
# Filter / Sort
# ---------------------------------------------------------------------------

func _on_filter_changed() -> void:
	_apply_filter_and_sort()

func _apply_filter_and_sort() -> void:
	var search_text: String = _search_edit.text.to_lower()

	var type_idx: int = _type_filter.get_selected_id()
	var tag_idx: int  = _tag_filter.get_selected_id()
	var sort_idx: int = _sort_option.get_selected_id()

	_filtered_cards.clear()

	for card in _all_cards:
		# Text search
		if search_text != "":
			var matches_text := (
				card.id.to_lower().contains(search_text) or
				card.display_name.to_lower().contains(search_text)
			)
			if not matches_text:
				continue

		# Type filter
		if type_idx >= 0 and card.card_type != type_idx:
			continue

		# Tag filter
		if tag_idx >= 0 and not (tag_idx in card.tags):
			continue

		_filtered_cards.append(card)

	# Sort
	match sort_idx:
		0: _filtered_cards.sort_custom(func(a: CardData, b: CardData): return a.display_name < b.display_name)
		1: _filtered_cards.sort_custom(func(a: CardData, b: CardData): return a.energy_cost < b.energy_cost)
		2: _filtered_cards.sort_custom(func(a: CardData, b: CardData): return _dpe(a) > _dpe(b))
		3: _filtered_cards.sort_custom(func(a: CardData, b: CardData): return _bpe(a) > _bpe(b))
		4: _filtered_cards.sort_custom(func(a: CardData, b: CardData): return (a.damage * a.hits) > (b.damage * b.hits))
		5: _filtered_cards.sort_custom(func(a: CardData, b: CardData): return a.block > b.block)

	_rebuild_list()

# ---------------------------------------------------------------------------
# List rebuild
# ---------------------------------------------------------------------------

func _rebuild_list() -> void:
	# Clear existing rows
	for child in _list_vbox.get_children():
		child.queue_free()
	_row_nodes.clear()

	for card in _filtered_cards:
		var row := _build_card_row(card)
		_list_vbox.add_child(row)
		_row_nodes[card.id] = row

func _build_card_row(card: CardData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 32)

	var row_style := StyleBoxFlat.new()
	row_style.bg_color = COLOR_ROW_BG
	row_style.content_margin_left = 8.0
	row_style.content_margin_right = 8.0
	row_style.content_margin_top = 4.0
	row_style.content_margin_bottom = 4.0
	panel.add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(hbox)

	# Type color stripe
	var stripe := ColorRect.new()
	stripe.custom_minimum_size = Vector2(4, 0)
	stripe.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stripe.color = _type_color(card.card_type)
	hbox.add_child(stripe)

	# Main label (name, cost, raw stats)
	var type_name := _type_label(card.card_type)
	var main_text := "[%s] %s (%dE)" % [type_name, card.display_name, card.energy_cost]

	var stats_parts: Array[String] = []
	if card.damage > 0:
		stats_parts.append("Dmg:%d×%d" % [card.damage, card.hits])
	if card.block > 0:
		stats_parts.append("Blk:%d" % card.block)
	if card.heal > 0:
		stats_parts.append("Heal:%d" % card.heal)
	if card.draw > 0:
		stats_parts.append("Draw:%d" % card.draw)

	# Computed metrics
	var dpe_val := _dpe(card)
	var bpe_val := _bpe(card)
	var metrics: Array[String] = []
	if dpe_val > 0.0:
		metrics.append("DPE:%.1f" % dpe_val)
	if bpe_val > 0.0:
		metrics.append("BPE:%.1f" % bpe_val)

	if _player != null and card.damage > 0:
		var eff_dmg := StatResolver.resolve_damage(card.damage, _player, _target, card)
		var total_eff := eff_dmg * card.hits
		var eff_dpe: float = float(total_eff) / float(maxi(card.energy_cost, 1))
		metrics.append("EffDPE:%.1f" % eff_dpe)

	var full_text := main_text
	if not stats_parts.is_empty():
		full_text += " — " + " ".join(PackedStringArray(stats_parts))
	if not metrics.is_empty():
		full_text += " | " + " ".join(PackedStringArray(metrics))

	var main_lbl := Label.new()
	main_lbl.text = full_text
	main_lbl.add_theme_color_override("font_color", Color.WHITE)
	main_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(main_lbl)

	# Sockets
	if card.gem_sockets > 0:
		var socket_lbl := Label.new()
		var socket_str := ""
		for i in card.gem_sockets:
			socket_str += "◆" if i < _get_equipped_gem_count(card) else "◇"
		socket_lbl.text = socket_str
		socket_lbl.add_theme_color_override("font_color", Color(0.85, 0.72, 0.10))
		hbox.add_child(socket_lbl)

	# Tags as colored chips
	for tag_val in card.tags:
		var chip := _make_tag_chip(tag_val)
		hbox.add_child(chip)

	# Click detection via a transparent button overlay
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.text = ""
	btn.pressed.connect(_on_card_selected.bind(card))
	panel.add_child(btn)

	return panel

func _make_tag_chip(tag_val: int) -> PanelContainer:
	var chip := PanelContainer.new()
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = TAG_COLORS.get(tag_val, COLOR_TAG_BG)
	chip_style.corner_radius_top_left = 3
	chip_style.corner_radius_top_right = 3
	chip_style.corner_radius_bottom_left = 3
	chip_style.corner_radius_bottom_right = 3
	chip_style.content_margin_left = 4.0
	chip_style.content_margin_right = 4.0
	chip_style.content_margin_top = 1.0
	chip_style.content_margin_bottom = 1.0
	chip.add_theme_stylebox_override("panel", chip_style)

	var tag_name: String = Enums.CardTag.find_key(tag_val)
	var lbl := Label.new()
	lbl.text = tag_name.capitalize()
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_font_size_override("font_size", 11)
	chip.add_child(lbl)
	return chip

# ---------------------------------------------------------------------------
# Detail panel
# ---------------------------------------------------------------------------

func _on_card_selected(card: CardData) -> void:
	_selected_card = card
	_update_detail(card)
	# Highlight selected row
	for card_id in _row_nodes:
		var row_panel: PanelContainer = _row_nodes[card_id]
		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_ROW_SEL if card_id == card.id else COLOR_ROW_BG
		style.content_margin_left = 8.0
		style.content_margin_right = 8.0
		style.content_margin_top = 4.0
		style.content_margin_bottom = 4.0
		row_panel.add_theme_stylebox_override("panel", style)

func _update_detail(card: CardData) -> void:
	var lines: Array[String] = []
	lines.append("=== %s ===" % card.display_name)
	lines.append("ID: %s  |  Type: %s  |  Cost: %dE  |  Target: %s" % [
		card.id,
		_type_label(card.card_type),
		card.energy_cost,
		_target_label(card.target_type),
	])

	var stats_row: Array[String] = []
	if card.damage > 0:
		stats_row.append("Damage: %d × %d hits = %d total" % [card.damage, card.hits, card.damage * card.hits])
	if card.block > 0:
		stats_row.append("Block: %d" % card.block)
	if card.heal > 0:
		stats_row.append("Heal: %d" % card.heal)
	if card.draw > 0:
		stats_row.append("Draw: %d" % card.draw)
	if card.apply_vulnerable > 0:
		stats_row.append("Vulnerable: %d" % card.apply_vulnerable)
	if card.apply_weak > 0:
		stats_row.append("Weak: %d" % card.apply_weak)
	if card.corruption_gain > 0:
		stats_row.append("Corruption: +%d" % card.corruption_gain)
	if card.gain_strength > 0:
		stats_row.append("Strength: +%d" % card.gain_strength)
	if card.gain_dexterity > 0:
		stats_row.append("Dexterity: +%d" % card.gain_dexterity)
	if card.exhaust:
		stats_row.append("Exhaust")
	if card.upgraded:
		stats_row.append("Upgraded")
	if card.gem_sockets > 0:
		stats_row.append("Sockets: %d" % card.gem_sockets)

	if not stats_row.is_empty():
		lines.append("  |  ".join(PackedStringArray(stats_row)))

	# Efficiency metrics
	var dpe_val := _dpe(card)
	var bpe_val := _bpe(card)
	var eff_row: Array[String] = []
	if dpe_val > 0.0:
		eff_row.append("DPE: %.2f" % dpe_val)
	if bpe_val > 0.0:
		eff_row.append("BPE: %.2f" % bpe_val)
	if not eff_row.is_empty():
		lines.append("Efficiency — " + "  |  ".join(PackedStringArray(eff_row)))

	# Tags
	if not card.tags.is_empty():
		var tag_names: Array[String] = []
		for t in card.tags:
			tag_names.append((Enums.CardTag.find_key(t) as String).capitalize())
		lines.append("Tags: " + ", ".join(PackedStringArray(tag_names)))

	# Description
	if card.description != "":
		lines.append("")
		lines.append(card.description)

	_detail_label.text = "\n".join(PackedStringArray(lines))

	# Resolved stats with current player
	_detail_resolved_label.text = ""
	if _player != null:
		var resolved_lines: Array[String] = []
		resolved_lines.append("--- With Current Modifiers ---")

		if card.damage > 0:
			var res_dmg := StatResolver.resolve_damage(card.damage, _player, _target, card)
			var total := res_dmg * card.hits
			resolved_lines.append("Resolved Damage: %d × %d hits = %d total" % [res_dmg, card.hits, total])
			var eff_dpe: float = float(total) / float(maxi(card.energy_cost, 1))
			resolved_lines.append("Effective DPE: %.2f" % eff_dpe)

		if card.block > 0:
			var res_blk := StatResolver.resolve_block(card.block, _player, card)
			resolved_lines.append("Resolved Block: %d" % res_blk)
			var eff_bpe: float = float(res_blk) / float(maxi(card.energy_cost, 1))
			resolved_lines.append("Effective BPE: %.2f" % eff_bpe)

		if card.heal > 0:
			var res_heal := StatResolver.resolve_healing(card.heal, _player, card)
			resolved_lines.append("Resolved Heal: %d" % res_heal)

		_detail_resolved_label.text = "\n".join(PackedStringArray(resolved_lines))

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func set_player(player: PlayerState) -> void:
	_player = player
	if _selected_card != null:
		_update_detail(_selected_card)
	_rebuild_list()

func set_target(target) -> void:
	_target = target
	if _selected_card != null:
		_update_detail(_selected_card)
	_rebuild_list()

func _on_gallery_requested() -> void:
	var ids: Array = []
	for card in _filtered_cards:
		ids.append(card.id)
	gallery_requested.emit(ids, "All Cards (%d)" % ids.size())

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _dpe(card: CardData) -> float:
	if card.damage <= 0:
		return 0.0
	return float(card.damage * card.hits) / float(maxi(card.energy_cost, 1))

func _bpe(card: CardData) -> float:
	if card.block <= 0:
		return 0.0
	return float(card.block) / float(maxi(card.energy_cost, 1))

func _get_equipped_gem_count(_card: CardData) -> int:
	# Placeholder: return 0 unless we have a way to look up active gems per card
	return 0

func _type_color(card_type: Enums.CardType) -> Color:
	match card_type:
		Enums.CardType.ATTACK: return COLOR_ATTACK
		Enums.CardType.SKILL:  return COLOR_SKILL
		Enums.CardType.POWER:  return COLOR_POWER
		Enums.CardType.STATUS: return COLOR_STATUS
		Enums.CardType.CURSE:  return COLOR_CURSE
	return Color.WHITE

func _type_label(card_type: Enums.CardType) -> String:
	match card_type:
		Enums.CardType.ATTACK: return "Attack"
		Enums.CardType.SKILL:  return "Skill"
		Enums.CardType.POWER:  return "Power"
		Enums.CardType.STATUS: return "Status"
		Enums.CardType.CURSE:  return "Curse"
	return "Unknown"

func _target_label(target_type: Enums.TargetType) -> String:
	match target_type:
		Enums.TargetType.ENEMY:       return "Enemy"
		Enums.TargetType.SELF:        return "Self"
		Enums.TargetType.ALL_ENEMIES: return "All Enemies"
		Enums.TargetType.ALL_PLAYERS: return "All Players"
		Enums.TargetType.NONE:        return "None"
	return "Unknown"
