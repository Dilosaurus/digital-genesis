extends Control

signal summary_closed

# Whether this is a victory or defeat screen
var _is_victory: bool = false

# Snapshot of the run state at the time of summary display
var _run_snapshot: Dictionary = {}

# UI node references (resolved at runtime from the scene tree)
@onready var _dimmer: ColorRect               = $Dimmer
@onready var _panel: PanelContainer           = $Panel
@onready var _title_label: Label              = $Panel/VBox/TitleLabel
@onready var _accent_bar: ColorRect           = $Panel/VBox/AccentBar
@onready var _stats_container: VBoxContainer  = $Panel/VBox/StatsContainer
@onready var _deck_header: Label              = $Panel/VBox/DeckSection/DeckHeader
@onready var _deck_list: VBoxContainer        = $Panel/VBox/DeckSection/DeckScroll/DeckList
@onready var _relic_header: Label             = $Panel/VBox/RelicSection/RelicHeader
@onready var _relic_list: HBoxContainer       = $Panel/VBox/RelicSection/RelicList
@onready var _return_btn: Button              = $Panel/VBox/ReturnButton

# Controls animated in one-by-one (stored as untyped to avoid Label-cast issues)
var _stat_rows: Array = []

# Colors
const COLOR_VICTORY := Color(0.15, 0.95, 0.35)
const COLOR_DEFEAT  := Color(0.95, 0.25, 0.25)
const COLOR_GOLD    := Color(1.0, 0.85, 0.2)

func _ready() -> void:
	# Start invisible — show_summary() fades in
	modulate.a = 0.0
	_return_btn.pressed.connect(_on_return_pressed)

## Public API: display the summary.
## is_victory=true for win, false for defeat.
## current_hp is the player's HP at the moment combat ended.
func show_summary(is_victory: bool, run: RunState, current_hp: int) -> void:
	_is_victory = is_victory

	# Snapshot run data before it can be erased by end_run
	_run_snapshot = {
		"current_hp":         current_hp,
		"max_hp":             run.max_hp,
		"gold":               run.gold,
		"deck":               run.deck.duplicate(),
		"relics":             run.relics.duplicate(),
		"act":                run.act,
		"enemies_defeated":   run.enemies_defeated,
		"floors_cleared":     run.floors_cleared,
		"total_gold_earned":  run.total_gold_earned,
		"total_damage_dealt": run.total_damage_dealt,
	}

	_setup_appearance()
	_populate_stats()
	_populate_deck()
	_populate_relics()

	# Play SFX first
	if is_victory:
		SFXManager.play_victory()
	else:
		SFXManager.play_defeat()

	# Fade in the whole overlay
	visible = true
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 1.0, 0.4)
	await fade_tween.finished

	# Slide panel up from below
	_panel.position.y = get_viewport_rect().size.y + 60.0
	var target_y: float = (get_viewport_rect().size.y - _panel.size.y) / 2.0
	var slide_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	slide_tween.tween_property(_panel, "position:y", target_y, 0.45)
	await slide_tween.finished

	# Stagger each stat row in
	for i in _stat_rows.size():
		var row: Control = _stat_rows[i]
		row.modulate.a = 0.0
		var stagger = create_tween()
		stagger.tween_interval(0.07 * i)
		stagger.tween_property(row, "modulate:a", 1.0, 0.2)

	# Victory: golden glow pulse on accent bar
	if is_victory:
		await get_tree().create_timer(0.4).timeout
		var glow = create_tween().set_loops(3)
		glow.tween_property(_accent_bar, "modulate", Color(2.0, 1.8, 0.4, 1.0), 0.3)
		glow.tween_property(_accent_bar, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.35)

func _setup_appearance() -> void:
	var accent: Color = COLOR_VICTORY if _is_victory else COLOR_DEFEAT

	_title_label.text = "DIGITAL GENESIS COMPLETE" if _is_victory else "RUN FAILED"
	_title_label.add_theme_color_override("font_color", accent)
	_accent_bar.color = accent

	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.07, 0.07, 0.12, 0.96)
	stylebox.border_width_top    = 3
	stylebox.border_width_bottom = 3
	stylebox.border_width_left   = 3
	stylebox.border_width_right  = 3
	stylebox.border_color        = accent
	stylebox.corner_radius_top_left     = 8
	stylebox.corner_radius_top_right    = 8
	stylebox.corner_radius_bottom_left  = 8
	stylebox.corner_radius_bottom_right = 8
	_panel.add_theme_stylebox_override("panel", stylebox)

	_return_btn.add_theme_color_override("font_color", accent)

func _populate_stats() -> void:
	# Clear previous stat rows
	for child in _stats_container.get_children():
		child.queue_free()
	_stat_rows.clear()

	var s: Dictionary = _run_snapshot
	var stat_pairs: Array = [
		["Final HP",         "%d / %d" % [s["current_hp"], s["max_hp"]]],
		["Gold Earned",      str(s["total_gold_earned"])],
		["Cards in Deck",    str(s["deck"].size())],
		["Relics Collected", str(s["relics"].size())],
		["Floors Cleared",   str(s["floors_cleared"])],
		["Enemies Defeated", str(s["enemies_defeated"])],
		["Act Reached",      str(s["act"])],
		["Total Damage",     str(s["total_damage_dealt"])],
	]

	for pair in stat_pairs:
		var row := _build_stat_row(pair[0], pair[1])
		_stats_container.add_child(row)
		_stat_rows.append(row)

func _build_stat_row(label_text: String, value_text: String) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var key_lbl := Label.new()
	key_lbl.text = label_text
	key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))

	var val_lbl := Label.new()
	val_lbl.text = value_text
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_lbl.add_theme_color_override("font_color", Color.WHITE)

	hbox.add_child(key_lbl)
	hbox.add_child(val_lbl)
	return hbox

func _populate_deck() -> void:
	for child in _deck_list.get_children():
		child.queue_free()

	var deck: Array = _run_snapshot["deck"]
	_deck_header.text = "Deck  (%d cards)" % deck.size()

	# Count duplicates
	var counts: Dictionary = {}
	for card_id in deck:
		counts[card_id] = counts.get(card_id, 0) + 1

	var sorted_ids: Array = counts.keys()
	sorted_ids.sort()

	for card_id in sorted_ids:
		var count: int = counts[card_id]
		var card_data = GameManager.get_card_data(card_id)
		var display: String = card_data.display_name if card_data else card_id

		var lbl := Label.new()
		lbl.text = "  x%d  %s" % [count, display]
		lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
		_deck_list.add_child(lbl)

func _populate_relics() -> void:
	for child in _relic_list.get_children():
		child.queue_free()

	var relics: Array = _run_snapshot["relics"]
	_relic_header.text = "Relics  (%d)" % relics.size()

	if relics.is_empty():
		var lbl := Label.new()
		lbl.text = "  None"
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		_relic_list.add_child(lbl)
		return

	for relic_id in relics:
		var relic = RelicSystem.get_relic(relic_id)
		var display: String = relic.display_name if relic else relic_id

		var lbl := Label.new()
		lbl.text = display
		lbl.add_theme_color_override("font_color", COLOR_GOLD)
		lbl.custom_minimum_size = Vector2(130, 0)
		_relic_list.add_child(lbl)

func _on_return_pressed() -> void:
	SFXManager.play_button()
	var tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	summary_closed.emit()
