extends Control

signal card_clicked(hand_index: int)

var hand_index: int = -1
var card_id: String = ""
var card_data: CardData = null
var is_playable: bool = true

@onready var background: Panel = $Background
@onready var cost_label: Label = $CostLabel
@onready var name_label: Label = $NameLabel
@onready var type_banner: ColorRect = $TypeBanner
@onready var desc_label: RichTextLabel = $DescLabel
@onready var hover_highlight: ColorRect = $HoverHighlight

var _base_position := Vector2.ZERO
var _is_hovered := false
var _original_y := 0.0

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

	# Corruption visual override
	if CardCorruption.should_corrupt(card_id, p_corruption_tier):
		var overrides = CardCorruption.get_corrupted_overrides(card_id)
		name_label.text = overrides.get("display_name", card_data.display_name)
		desc_label.text = overrides.get("description", card_data.description)
		# Corrupted cards get a sinister purple/red border
		_set_border_color(Color(0.6, 0.1, 0.5))

	# Color by card type
	match card_data.card_type:
		Enums.CardType.ATTACK:
			type_banner.color = Color(0.85, 0.2, 0.15)
			_set_border_color(Color(0.7, 0.25, 0.2))
		Enums.CardType.SKILL:
			type_banner.color = Color(0.15, 0.45, 0.85)
			_set_border_color(Color(0.2, 0.35, 0.7))
		_:
			type_banner.color = Color(0.6, 0.4, 0.8)
			_set_border_color(Color(0.5, 0.35, 0.7))

	# Dim if not playable
	if is_playable:
		modulate = Color.WHITE
		cost_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	else:
		modulate = Color(0.5, 0.5, 0.5)
		cost_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

func _set_border_color(color: Color) -> void:
	var style = background.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		var new_style = style.duplicate()
		new_style.border_color = color
		background.add_theme_stylebox_override("panel", new_style)

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	pivot_offset = size / 2.0

func _on_mouse_entered() -> void:
	if not is_playable:
		return
	_is_hovered = true
	_original_y = _base_position.y
	var tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.2)
	tween.tween_property(self, "position:y", _base_position.y - 40, 0.2)
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
	hover_highlight.modulate.a = 0.12
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
	# Disable input during animation
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20

	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel()
	tween.tween_property(self, "global_position", target_pos, 0.35)
	tween.tween_property(self, "scale", Vector2(0.6, 0.6), 0.35)
	tween.tween_property(self, "modulate:a", 0.0, 0.15).set_delay(0.25)
	tween.chain().tween_callback(queue_free)
