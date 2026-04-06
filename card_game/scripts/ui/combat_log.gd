## combat_log.gd
## Compact scrollable combat log positioned in a screen corner.
##
## Features:
##   - Color-coded entries per action type
##   - Fade-in animation for each new entry
##   - Older entries gradually dim toward MIN_ALPHA
##   - Max 50 entries; oldest pruned automatically
##   - Toggle visibility via ToggleButton or L hotkey
##   - ShareTechMono font for monospace alignment
extends Control

const MAX_ENTRIES     := 50
const FADE_IN_TIME    := 0.18
const MIN_ALPHA       := 0.35   # oldest entries floor alpha
const ALPHA_STEP      := 0.04   # how much alpha drops per entry as it ages

# Color palette for entry types
const COLOR_DAMAGE  := Color(1.00, 0.40, 0.32, 1.0)   # red-orange
const COLOR_BLOCK   := Color(0.35, 0.80, 1.00, 1.0)   # cyan
const COLOR_HEAL    := Color(0.25, 0.95, 0.45, 1.0)   # green
const COLOR_STATUS  := Color(1.00, 0.88, 0.30, 1.0)   # yellow
const COLOR_CARD    := Color(0.92, 0.90, 0.88, 1.0)   # off-white
const COLOR_SYSTEM  := Color(0.55, 0.60, 0.72, 0.85)  # muted grey-blue
const COLOR_ENEMY   := Color(0.90, 0.55, 0.80, 1.0)   # pink-purple for enemy actions

@onready var _toggle_button: Button         = $ToggleButton
@onready var _log_panel:     PanelContainer = $LogPanel
@onready var _scroll:        ScrollContainer = $LogPanel/VBox/ScrollContainer
@onready var _entry_list:    VBoxContainer  = $LogPanel/VBox/ScrollContainer/EntryList

var _entries: Array[Label] = []
var _log_visible: bool = false


func _ready() -> void:
	_log_panel.visible = false
	_toggle_button.pressed.connect(_toggle_log)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_L:
			_toggle_log()


# ---------------------------------------------------------------------------
# Public API — preserved from original, extended with new types
# ---------------------------------------------------------------------------

func add_entry(text: String, color: Color = COLOR_CARD) -> void:
	_create_entry(text, color)


func add_damage(source: String, target: String, amount: int) -> void:
	_create_entry("%-10s  ->  %-10s  %d dmg" % [source, target, amount], COLOR_DAMAGE)


func add_block(source: String, amount: int) -> void:
	_create_entry("%-16s  +%d Block" % [source, amount], COLOR_BLOCK)


func add_heal(source: String, amount: int) -> void:
	_create_entry("%-16s  +%d HP" % [source, amount], COLOR_HEAL)


func add_status(text: String) -> void:
	_create_entry(text, COLOR_STATUS)


func add_system(text: String) -> void:
	_create_entry(text, COLOR_SYSTEM)


func add_card_played(card_name: String, source: String = "Player") -> void:
	_create_entry("[%s] played %s" % [source, card_name], COLOR_CARD)


func add_enemy_action(enemy_name: String, action: String) -> void:
	_create_entry("[%s] %s" % [enemy_name, action], COLOR_ENEMY)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _create_entry(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 11)
	label.modulate.a = 0.0
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Set ShareTechMono font directly so it works regardless of theme propagation
	var font_res := load("res://assets/fonts/ShareTechMono-Regular.ttf")
	if font_res:
		label.add_theme_font_override("font", font_res)

	_entry_list.add_child(label)
	_entries.append(label)

	# Prune old entries if over limit
	while _entries.size() > MAX_ENTRIES:
		var old: Label = _entries.pop_front()
		if is_instance_valid(old):
			old.queue_free()

	# Fade in new entry
	var t := label.create_tween()
	t.tween_property(label, "modulate:a", 1.0, FADE_IN_TIME).set_ease(Tween.EASE_OUT)

	# Re-apply age-based alpha to all entries
	_refresh_entry_alphas()

	# Scroll to bottom on next frame
	await get_tree().process_frame
	_scroll.scroll_vertical = _scroll.get_v_scroll_bar().max_value


func _refresh_entry_alphas() -> void:
	var count := _entries.size()
	for i in count:
		var entry: Label = _entries[i]
		if not is_instance_valid(entry):
			continue
		# Newer entries (high index) get full alpha; oldest get MIN_ALPHA
		var age_ratio: float = float(count - 1 - i) / max(count - 1, 1)
		var target_alpha := lerpf(1.0, MIN_ALPHA, age_ratio * (1.0 - MIN_ALPHA / 1.0))
		target_alpha = maxf(target_alpha, MIN_ALPHA)
		# Only dim entries that have already faded in (avoid fighting the fade-in tween)
		if i < count - 1:
			entry.modulate.a = target_alpha


func _toggle_log() -> void:
	_log_visible = not _log_visible
	if _log_visible:
		_log_panel.visible = true
		_log_panel.modulate.a = 0.0
		var t := _log_panel.create_tween()
		t.tween_property(_log_panel, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT)
	else:
		var t := _log_panel.create_tween()
		t.tween_property(_log_panel, "modulate:a", 0.0, 0.12).set_ease(Tween.EASE_IN)
		t.tween_callback(func(): _log_panel.visible = false)
