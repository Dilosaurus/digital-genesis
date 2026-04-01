extends Control

const StatusIconScene = preload("res://scenes/ui/status_icon.tscn")

@onready var name_label: Label = $NameLabel
@onready var hp_bar = $HPBar
@onready var intent_label: Label = $IntentLabel
@onready var block_label: Label = $BlockLabel
@onready var enemy_rect: ColorRect = $EnemyRect
@onready var status_icons_container: HBoxContainer = $StatusIconsContainer

var _idle_tween: Tween = null
var _base_rect_y: float = 40.0

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
	"jaw_worm":  [Color(0.3, 0.55, 0.18),  Color(0.4, 0.7, 0.25)],
}

func _ready() -> void:
	_base_rect_y = enemy_rect.position.y
	_start_idle_animation()
	_init_icons()

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

func update_enemy(state_dict: Dictionary) -> void:
	var enemy_id: String = state_dict["enemy_data_id"]
	var enemy_data: EnemyData = load("res://data/enemies/%s.tres" % enemy_id)
	if enemy_data:
		name_label.text = enemy_data.display_name

	# Apply color
	var cols = ENEMY_COLORS.get(enemy_id, [Color(0.5, 0.15, 0.15), Color(0.65, 0.22, 0.22)])
	enemy_rect.color = cols[0]
	# Tint the label inside enemy rect to lighter shade
	if enemy_rect.has_node("EnemyLabel"):
		enemy_rect.get_node("EnemyLabel").add_theme_color_override("font_color", cols[1].lightened(0.4))

	hp_bar.set_values(state_dict["current_hp"], state_dict["max_hp"])

	# Block display
	if state_dict["block"] > 0:
		block_label.text = "Shield: %d" % state_dict["block"]
		block_label.visible = true
	else:
		block_label.visible = false

	# Intent display with icons
	var intent_type = state_dict["intent_type"] as Enums.EnemyIntent
	var intent_value = state_dict["intent_value"]
	match intent_type:
		Enums.EnemyIntent.ATTACK:
			intent_label.text = "⚔ %d" % intent_value
			intent_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		Enums.EnemyIntent.DEFEND:
			intent_label.text = "🛡 %d" % intent_value
			intent_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
		Enums.EnemyIntent.HACK:
			intent_label.text = "⚡ %d" % intent_value
			intent_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.9))
		Enums.EnemyIntent.BUFF:
			intent_label.text = "▲ +%d" % intent_value
			intent_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		_:
			intent_label.text = "?"
			intent_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	# Update status icons
	_update_icon(StatusIcon.TYPE_STRENGTH,   state_dict.get("strength",   0))
	_update_icon(StatusIcon.TYPE_VULNERABLE, state_dict.get("vulnerable", 0))
	_update_icon(StatusIcon.TYPE_WEAK,       state_dict.get("weak",       0))

func _update_icon(type: String, count: int) -> void:
	if _icons.has(type):
		_icons[type].update_count(count)

func shake() -> void:
	# Flash white first, then shake
	TransitionManager.flash_white(enemy_rect, 0.1)
	await get_tree().create_timer(0.05).timeout

	var orig = enemy_rect.position
	var tween = create_tween()
	tween.tween_property(enemy_rect, "position", orig + Vector2(10, 0), 0.04)
	tween.tween_property(enemy_rect, "position", orig - Vector2(10, 0), 0.04)
	tween.tween_property(enemy_rect, "position", orig + Vector2(5, 0), 0.04)
	tween.tween_property(enemy_rect, "position", orig - Vector2(3, 0), 0.04)
	tween.tween_property(enemy_rect, "position", orig, 0.04)

func play_death_animation() -> void:
	if _idle_tween:
		_idle_tween.kill()
		_idle_tween = null
	var tween = create_tween().set_parallel()
	tween.tween_property(enemy_rect, "modulate:a", 0.0, 0.6)
	tween.tween_property(enemy_rect, "scale", Vector2(1.3, 0.1), 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 0.0, 0.8).set_delay(0.2)
