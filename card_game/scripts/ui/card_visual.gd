extends Control

signal card_clicked(hand_index: int)

var hand_index: int = -1
var card_id: String = ""
var card_data: CardData = null
var is_playable: bool = true

@onready var background: Panel = $Background
@onready var cost_bg: Panel = $CostBG
@onready var cost_label: Label = $CostBG/CostLabel
@onready var name_label: Label = $NameLabel
@onready var type_banner: ColorRect = $TypeBanner
@onready var desc_label: RichTextLabel = $DescLabel
@onready var hover_highlight: ColorRect = $HoverHighlight
@onready var glow_border: Panel = $GlowBorder

var _base_position := Vector2.ZERO
var _is_hovered := false
var _original_y := 0.0
var _idle_tween: Tween = null
var _resolved_type_key := "skill"  # set during setup(), used for SFX

# Card type color palettes: [bg_dark, bg_light, border, banner]
const TYPE_COLORS = {
	"attack": [Color(0.22, 0.08, 0.08), Color(0.35, 0.12, 0.10), Color(0.85, 0.25, 0.2), Color(0.75, 0.18, 0.13)],
	"skill":  [Color(0.08, 0.12, 0.28), Color(0.12, 0.18, 0.38), Color(0.25, 0.5, 0.95), Color(0.15, 0.35, 0.8)],
	"power":  [Color(0.18, 0.14, 0.06), Color(0.28, 0.22, 0.06), Color(0.95, 0.75, 0.15), Color(0.75, 0.55, 0.1)],
	"curse":  [Color(0.12, 0.05, 0.18), Color(0.18, 0.08, 0.25), Color(0.6, 0.1, 0.75), Color(0.45, 0.08, 0.6)],
}

func setup(p_card_id: String, p_hand_index: int, p_energy: int, p_corruption_tier: int = 0) -> void:
	card_id = p_card_id
	hand_index = p_hand_index
	card_data = GameManager.get_card_data(card_id)
	if not card_data:
		return

	is_playable = p_energy >= card_data.energy_cost

	cost_label.text = str(card_data.energy_cost)
	name_label.text = card_data.display_name
	desc_label.text = card_data.description

	var type_key := "skill"
	match card_data.card_type:
		Enums.CardType.ATTACK: type_key = "attack"
		Enums.CardType.SKILL:  type_key = "skill"
		Enums.CardType.POWER:  type_key = "power"
		_: type_key = "power"

	# Corruption visual override — overrides type to "curse"
	if CardCorruption.should_corrupt(card_id, p_corruption_tier):
		var overrides = CardCorruption.get_corrupted_overrides(card_id)
		name_label.text = overrides.get("display_name", card_data.display_name)
		desc_label.text = overrides.get("description", card_data.description)
		type_key = "curse"

	_resolved_type_key = type_key
	_apply_card_colors(type_key)

	# Playability visual
	if is_playable:
		modulate = Color.WHITE
		_set_glow_visible(true)
	else:
		modulate = Color(0.55, 0.55, 0.6, 0.9)
		_set_glow_visible(false)

func _apply_card_colors(type_key: String) -> void:
	var colors = TYPE_COLORS.get(type_key, TYPE_COLORS["skill"])
	var bg_dark: Color = colors[0]
	var bg_light: Color = colors[1]
	var border_col: Color = colors[2]
	var banner_col: Color = colors[3]

	# Background gradient via StyleBoxFlat
	var card_style = background.get_theme_stylebox("panel") as StyleBoxFlat
	if card_style:
		var new_style = card_style.duplicate() as StyleBoxFlat
		new_style.bg_color = lerp(bg_dark, bg_light, 0.5)
		new_style.border_color = border_col
		background.add_theme_stylebox_override("panel", new_style)

	# Cost circle background
	var cost_style = cost_bg.get_theme_stylebox("panel") as StyleBoxFlat
	if cost_style:
		var ns = cost_style.duplicate() as StyleBoxFlat
		ns.bg_color = border_col.darkened(0.3)
		ns.border_color = border_col
		cost_bg.add_theme_stylebox_override("panel", ns)

	type_banner.color = banner_col

	# Glow border color
	var glow_style = glow_border.get_theme_stylebox("panel") as StyleBoxFlat
	if glow_style:
		var gs = glow_style.duplicate() as StyleBoxFlat
		gs.border_color = border_col
		glow_border.add_theme_stylebox_override("panel", gs)

func _set_glow_visible(visible_state: bool) -> void:
	if glow_border:
		var tween = create_tween()
		var target_alpha = 1.0 if visible_state else 0.0
		tween.tween_property(glow_border, "modulate:a", target_alpha, 0.2)

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	pivot_offset = size / 2.0

func _on_mouse_entered() -> void:
	if not is_playable:
		return
	SFXManager.play_button_hover()
	_is_hovered = true
	_original_y = _base_position.y
	var tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.18)
	tween.tween_property(self, "position:y", _base_position.y - 45, 0.18)
	if card_data:
		var tip = card_data.display_name
		if card_data.damage > 0:
			tip += "\nDmg: %d" % card_data.damage
			if card_data.hits > 1:
				tip += " x%d" % card_data.hits
		if card_data.block > 0:
			tip += "\nBlock: %d" % card_data.block
		if card_data.heal > 0:
			tip += "\nHeal: %d" % card_data.heal
		tooltip_text = tip
	hover_highlight.modulate.a = 0.15
	z_index = 10

func _on_mouse_exited() -> void:
	_is_hovered = false
	var tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector2.ONE, 0.15)
	tween.tween_property(self, "position:y", _base_position.y, 0.15)
	hover_highlight.modulate.a = 0.0
	z_index = 0

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_playable:
			card_clicked.emit(hand_index)

## Animate the card flying to a target position then disappearing
func play_animation(target_pos: Vector2) -> void:
	# Play type-specific card sound based on resolved type (includes corruption override)
	match _resolved_type_key:
		"attack": SFXManager.play_card_attack()
		"skill":  SFXManager.play_card_skill()
		"power":  SFXManager.play_card_power()
		"curse":  SFXManager.play_card_curse()
		_:        SFXManager.play_card()

	# Disable input during animation
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20

	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel()
	tween.tween_property(self, "rotation", randf_range(-0.2, 0.2), 0.35)
	tween.tween_property(self, "global_position", target_pos, 0.35)
	tween.tween_property(self, "scale", Vector2(0.6, 0.6), 0.35)
	tween.tween_property(self, "modulate:a", 0.0, 0.15).set_delay(0.25)
	tween.chain().tween_callback(queue_free)
