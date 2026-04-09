extends Control

const StatusIconScene = preload("res://scenes/ui/status_icon.tscn")

signal enemy_clicked(enemy_index: int)

@onready var name_label: Label            = $NameLabel
@onready var hp_bar                       = $HPBar
@onready var intent_label: Label          = $IntentContainer/IntentLabel
@onready var intent_icon_label: Label     = $IntentContainer/IntentIconLabel
@onready var intent_icon_panel: Panel     = $IntentContainer/IntentIconPanel
@onready var intent_container: Control    = $IntentContainer
@onready var block_label: Label           = $BlockLabel
@onready var enemy_rect: ColorRect        = $EnemyRect
@onready var status_icons_container: HBoxContainer = $StatusIconsContainer

# Keep IntentBG accessible so existing code that reads it won't crash.
@onready var intent_bg: Panel = $IntentContainer/IntentBG

var _idle_tween: Tween    = null
var _intent_tween: Tween  = null
var _base_rect_y: float   = 44.0
var enemy_index: int      = 0
var _is_targetable: bool  = false
var _highlight_tween: Tween = null
var _puppet: Node2D        = null
var _boss_label: Label     = null

# Map enemy IDs to puppet scenes (add entries as puppets are created)
const ENEMY_PUPPETS = {
	"metatron": preload("res://scenes/enemies/metatron_puppet.tscn"),
	"azrael":   preload("res://scenes/enemies/azrael_puppet.tscn"),
	"michael":  preload("res://scenes/enemies/michael_puppet.tscn"),
}

# Track active icon instances keyed by status type
var _icons: Dictionary = {}

# Status types tracked for enemies
const TRACKED_STATUSES = [
	StatusIcon.TYPE_STRENGTH,
	StatusIcon.TYPE_VULNERABLE,
	StatusIcon.TYPE_WEAK,
]

# Enemy visual colors: [primary, secondary (slightly lighter)]
const ENEMY_COLORS = {
	"michael":   [Color(0.8, 0.6, 0.1),   Color(0.95, 0.75, 0.2)],
	"hexaghost": [Color(0.15, 0.4, 0.15),  Color(0.2, 0.55, 0.2)],
	"cultist":   [Color(0.35, 0.12, 0.45), Color(0.48, 0.18, 0.6)],
	"louse_red": [Color(0.55, 0.18, 0.12), Color(0.7, 0.25, 0.18)],
	"gabriel":   [Color(0.3, 0.5, 0.8),    Color(0.4, 0.65, 0.95)],
	"raphael":   [Color(0.2, 0.7, 0.4),    Color(0.28, 0.85, 0.5)],
	"uriel":     [Color(0.7, 0.5, 0.1),    Color(0.85, 0.65, 0.15)],
	"azrael":    [Color(0.15, 0.1, 0.2),   Color(0.22, 0.15, 0.3)],
	"metatron":  [Color(0.9, 0.85, 0.7),   Color(1.0, 0.95, 0.8)],
	"jaw_worm":     [Color(0.3, 0.55, 0.18),  Color(0.4, 0.7, 0.25)],
	"seraph_drone": [Color(0.85, 0.75, 0.2),  Color(1.0, 0.9, 0.4)],
}

# StyleBoxFlat sub-resources for intent icon background (loaded once)
# We swap them on the IntentIconPanel by name-match at runtime.
# The actual StyleBoxFlat objects are authored in the .tscn; here we drive
# modulate colours on IntentIconLabel instead, which is simpler.

const _INTENT_ICON_DATA = {
	Enums.EnemyIntent.ATTACK: { "glyph": "⚔", "color": Color(1.0, 0.35, 0.35),  "bg": Color(0.55, 0.08, 0.08, 0.9), "border": Color(1.0, 0.4, 0.4, 0.9) },
	Enums.EnemyIntent.DEFEND: { "glyph": "🛡", "color": Color(0.45, 0.75, 1.0),  "bg": Color(0.08, 0.25, 0.55, 0.9), "border": Color(0.4, 0.7, 1.0, 0.9) },
	Enums.EnemyIntent.HACK:   { "glyph": "⚡", "color": Color(0.85, 0.30, 1.0),  "bg": Color(0.28, 0.05, 0.45, 0.9), "border": Color(0.75, 0.45, 1.0, 0.9) },
	Enums.EnemyIntent.BUFF:   { "glyph": "▲",  "color": Color(1.00, 0.88, 0.20), "bg": Color(0.45, 0.35, 0.05, 0.9), "border": Color(1.0, 0.85, 0.2, 0.9) },
}

func _ready() -> void:
	_base_rect_y = enemy_rect.position.y
	_start_idle_animation()
	_start_intent_float_animation()
	_init_icons()
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered_enemy)
	mouse_exited.connect(_on_mouse_exited_enemy)
	pivot_offset = custom_minimum_size / 2.0

func _init_icons() -> void:
	for type in TRACKED_STATUSES:
		var icon = StatusIconScene.instantiate()
		status_icons_container.add_child(icon)
		icon.setup(type, 0)
		_icons[type] = icon

func _start_idle_animation() -> void:
	if _idle_tween:
		_idle_tween.kill()
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(enemy_rect, "position:y", _base_rect_y - 6.0, 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_property(enemy_rect, "position:y", _base_rect_y + 2.0, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _start_intent_float_animation() -> void:
	# Gentle up/down float for the entire intent area, offset from idle to look
	# independent.  Base Y is 0 (its offset_top in the scene).
	if _intent_tween:
		_intent_tween.kill()
	var base_y := intent_container.position.y
	_intent_tween = create_tween().set_loops()
	_intent_tween.tween_property(intent_container, "position:y", base_y - 4.0, 1.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_intent_tween.tween_property(intent_container, "position:y", base_y + 2.0, 1.1).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

# ── Target highlighting ──────────────────────────────────────────────────────

func set_targetable(targetable: bool) -> void:
	_is_targetable = targetable
	mouse_filter = Control.MOUSE_FILTER_STOP if targetable else Control.MOUSE_FILTER_IGNORE
	if _highlight_tween and _highlight_tween.is_valid():
		_highlight_tween.kill()
	var target_node: Node = _puppet if _puppet else enemy_rect
	if targetable:
		_highlight_tween = create_tween().set_loops()
		_highlight_tween.tween_property(target_node, "modulate", Color(1.6, 1.4, 0.5, 1.0), 0.4).set_ease(Tween.EASE_IN_OUT)
		_highlight_tween.tween_property(target_node, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4).set_ease(Tween.EASE_IN_OUT)
	else:
		target_node.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_targetable:
			enemy_clicked.emit(enemy_index)

func _on_mouse_entered_enemy() -> void:
	if _is_targetable:
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.1)

func _on_mouse_exited_enemy() -> void:
	if _is_targetable:
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

# ── Main update ──────────────────────────────────────────────────────────────

func update_enemy(state_dict: Dictionary) -> void:
	var enemy_id: String = state_dict["enemy_data_id"]
	var enemy_data: EnemyData = load("res://data/enemies/%s.tres" % enemy_id)
	if enemy_data:
		name_label.text = enemy_data.display_name
		if enemy_data.description != "":
			tooltip_text = enemy_data.description

	# Load puppet if available, then try fullbody sprite, then colored rect
	if enemy_id in ENEMY_PUPPETS and _puppet == null:
		_puppet = ENEMY_PUPPETS[enemy_id].instantiate()
		_puppet.position = Vector2(100, 560)
		add_child(_puppet)
		enemy_rect.visible = false
		if _idle_tween:
			_idle_tween.kill()
			_idle_tween = null
	elif _puppet == null and not has_node("EnemySprite"):
		# Painted 2D enemies render via painted_arena.tscn's PaintedEnemySprite_*
		# nodes at editor-placed fixed positions (see combat_scene.gd's
		# _configure_painted_enemy_slot). The EnemyDisplay Control only hosts
		# the HP / intent / status UI overlaid above that sprite — we do NOT
		# create a fullbody TextureRect here.
		if enemy_id in Combat3DStage.PAINTED_2D_ENEMIES:
			enemy_rect.visible = false
		else:
			var fullbody_path := "res://assets/characters/%s/fullbody.png" % enemy_id
			if ResourceLoader.exists(fullbody_path):
				var sprite := TextureRect.new()
				sprite.texture = load(fullbody_path)
				sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				# Fix: expand_mode defaults to EXPAND_KEEP_SIZE which forces the
				# control's minimum size to match the source texture's native
				# dimensions. IGNORE_SIZE lets us size it freely.
				sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				sprite.custom_minimum_size = enemy_rect.size
				sprite.size = enemy_rect.size
				sprite.position = enemy_rect.position
				sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
				sprite.name = "EnemySprite"
				add_child(sprite)
				move_child(sprite, 0)
				enemy_rect.visible = false
			else:
				var cols = ENEMY_COLORS.get(enemy_id, [Color(0.5, 0.15, 0.15), Color(0.65, 0.22, 0.22)])
				enemy_rect.color = cols[0]
				if enemy_rect.has_node("EnemyLabel"):
					enemy_rect.get_node("EnemyLabel").add_theme_color_override("font_color", cols[1].lightened(0.4))

	hp_bar.set_values(state_dict["current_hp"], state_dict["max_hp"])

	# Block — forward to hp_bar for overlay, keep label as secondary indicator
	var block_val: int = state_dict["block"]
	hp_bar.set_block(block_val)
	if block_val > 0:
		block_label.text = "Shield: %d" % block_val
		block_label.visible = true
	else:
		block_label.visible = false

	# Intent display with typed icon
	var intent_type = state_dict["intent_type"] as Enums.EnemyIntent
	var intent_value = state_dict["intent_value"]
	_update_intent_display(intent_type, intent_value)

	# Update status icons
	_update_icon(StatusIcon.TYPE_STRENGTH,   state_dict.get("strength",   0))
	_update_icon(StatusIcon.TYPE_VULNERABLE, state_dict.get("vulnerable", 0))
	_update_icon(StatusIcon.TYPE_WEAK,       state_dict.get("weak",       0))

	# Boss mechanic indicators
	update_boss_indicators(state_dict)

func _update_intent_display(intent_type: Enums.EnemyIntent, intent_value: int) -> void:
	# Pulse animation when intent changes
	var current_text = intent_label.text

	if _INTENT_ICON_DATA.has(intent_type):
		var data = _INTENT_ICON_DATA[intent_type]
		intent_icon_label.text = data["glyph"]

		# Drive the icon panel background colour via modulate on the label.
		intent_icon_label.add_theme_color_override("font_color", data["color"])

		# Recolour the icon panel StyleBoxFlat dynamically.
		var style := intent_icon_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		style.bg_color     = data["bg"]
		style.border_color = data["border"]
		intent_icon_panel.add_theme_stylebox_override("panel", style)
	else:
		intent_icon_label.text = "?"
		intent_icon_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	match intent_type:
		Enums.EnemyIntent.ATTACK:
			intent_label.text = "ATK %d" % intent_value
			intent_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		Enums.EnemyIntent.DEFEND:
			intent_label.text = "BLOCK %d" % intent_value
			intent_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
		Enums.EnemyIntent.HACK:
			intent_label.text = "HACK %d" % intent_value
			intent_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.9))
		Enums.EnemyIntent.BUFF:
			intent_label.text = "BUFF +%d" % intent_value
			intent_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		_:
			intent_label.text = "…"
			intent_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	# Animate intent change
	if current_text != "" and current_text != intent_label.text:
		var pulse = create_tween()
		pulse.tween_property(intent_container, "scale", Vector2(1.3, 1.3), 0.1).set_ease(Tween.EASE_OUT)
		pulse.tween_property(intent_container, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_IN_OUT)

func _update_icon(type: String, count: int) -> void:
	if _icons.has(type):
		_icons[type].update_count(count)

func update_boss_indicators(state_dict: Dictionary) -> void:
	var indicators: Array[String] = []
	var indicator_color := Color(0.9, 0.9, 0.9)

	# Shield active (block >= 50)
	var block_val: int = state_dict.get("block", 0)
	if block_val >= 50:
		indicators.append("SHIELDED")
		indicator_color = Color(0.4, 0.75, 1.0)

	# Phase indicator
	var phase: int = state_dict.get("current_phase_index", 0)
	if phase > 0:
		indicators.append("PHASE %d" % (phase + 1))
		indicator_color = Color(1.0, 0.5, 0.0)

	# High strength warning
	var str_val: int = state_dict.get("strength", 0)
	if str_val >= 5:
		indicators.append("ENRAGED +%d" % str_val)
		indicator_color = Color(1.0, 0.3, 0.3)

	if indicators.is_empty():
		if _boss_label:
			_boss_label.visible = false
		return

	if not _boss_label:
		_boss_label = Label.new()
		_boss_label.name = "BossIndicator"
		_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_boss_label.add_theme_font_size_override("font_size", 11)
		_boss_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		_boss_label.add_theme_constant_override("shadow_offset_x", 1)
		_boss_label.add_theme_constant_override("shadow_offset_y", 1)
		_boss_label.position = Vector2(0, -18)
		_boss_label.size = Vector2(200, 20)
		add_child(_boss_label)

	_boss_label.text = " | ".join(indicators)
	_boss_label.add_theme_color_override("font_color", indicator_color)
	_boss_label.visible = true

# ── Animations ───────────────────────────────────────────────────────────────

func shake() -> void:
	if _puppet:
		_puppet.play_hit()
	else:
		TransitionManager.flash_white(enemy_rect, 0.1)
		await get_tree().create_timer(0.05).timeout

		var orig = enemy_rect.position
		var tween = create_tween()
		tween.tween_property(enemy_rect, "position", orig + Vector2(10, 0), 0.04)
		tween.tween_property(enemy_rect, "position", orig - Vector2(10, 0), 0.04)
		tween.tween_property(enemy_rect, "position", orig + Vector2(5, 0), 0.04)
		tween.tween_property(enemy_rect, "position", orig - Vector2(3, 0), 0.04)
		tween.tween_property(enemy_rect, "position", orig, 0.04)


func play_attack_animation() -> void:
	if _puppet:
		_puppet.play_attack()


func play_telegraph_animation() -> void:
	if _puppet:
		_puppet.play_telegraph()


func play_buff_animation() -> void:
	if _puppet:
		_puppet.play_buff()


func play_cast_animation() -> void:
	if _puppet:
		_puppet.play_cast()


func play_death_animation() -> void:
	if _puppet:
		_puppet.play_death()
	else:
		if _idle_tween:
			_idle_tween.kill()
			_idle_tween = null
		if _intent_tween:
			_intent_tween.kill()
			_intent_tween = null
		var tween = create_tween().set_parallel()
		tween.tween_property(enemy_rect, "modulate:a", 0.0, 0.6)
		tween.tween_property(enemy_rect, "scale", Vector2(1.3, 0.1), 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		tween.tween_property(self, "modulate:a", 0.0, 0.8).set_delay(0.2)
