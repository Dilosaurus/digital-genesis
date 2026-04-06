extends Control

signal card_clicked(hand_index: int)

var hand_index: int = -1
var card_id: String = ""
var card_data: CardData = null
var is_playable: bool = true

@onready var background: Panel = $Background
@onready var card_art: TextureRect = $CardArt
@onready var frame_overlay: TextureRect = $FrameOverlay
@onready var name_banner: Panel = $NameBanner
@onready var cost_bg: Panel = $CostBG
@onready var cost_label: Label = $CostBG/CostLabel
@onready var name_label: Label = $NameLabel
@onready var type_strip: Panel = $TypeStrip
@onready var type_label: Label = $TypeStrip/TypeLabel
@onready var desc_box: Panel = $DescBox
@onready var desc_label: RichTextLabel = $DescBox/DescLabel
@onready var hover_highlight: ColorRect = $HoverHighlight
@onready var glow_border: Panel = $GlowBorder
@onready var selected_border: Panel = $SelectedBorder
@onready var rarity_strip: Panel = $RarityStrip
@onready var corruption_overlay: ColorRect = $CorruptionOverlay

# ---------------------------------------------------------------------------
# Color constants — single source of truth for all card palette decisions
# ---------------------------------------------------------------------------

# Card type color palettes: [bg_dark, bg_light, border, banner]
const TYPE_COLORS = {
	"attack": [Color(0.22, 0.08, 0.08), Color(0.35, 0.12, 0.10), Color(0.85, 0.25, 0.2),  Color(0.75, 0.18, 0.13)],
	"skill":  [Color(0.08, 0.12, 0.28), Color(0.12, 0.18, 0.38), Color(0.25, 0.5,  0.95),  Color(0.15, 0.35, 0.8)],
	"power":  [Color(0.18, 0.14, 0.06), Color(0.28, 0.22, 0.06), Color(0.95, 0.75, 0.15),  Color(0.75, 0.55, 0.1)],
	"curse":  [Color(0.12, 0.05, 0.18), Color(0.18, 0.08, 0.25), Color(0.6,  0.1,  0.75),  Color(0.45, 0.08, 0.6)],
}

# Rarity glow colors — used for both the GlowBorder shader and the RarityStrip bar
const RARITY_COLORS = {
	"common":    Color(0.55, 0.55, 0.58, 1.0),   # muted silver-gray
	"uncommon":  Color(0.15, 0.75, 0.25, 1.0),   # bright green
	"rare":      Color(0.20, 0.55, 1.00, 1.0),   # vivid blue
	"legendary": Color(1.00, 0.62, 0.10, 1.0),   # warm gold/orange
}

# Selected state — bright golden outline pulsing gently
const SELECTED_BORDER_COLOR  := Color(1.0,  0.95, 0.45, 1.0)
const SELECTED_GLOW_COLOR    := Color(1.0,  0.90, 0.25, 1.0)

# Corruption visual — semi-transparent purple film + scanline noise (via overlay)
const CORRUPTION_TINT        := Color(0.45, 0.00, 0.65, 0.18)
const CORRUPTION_HOVER_TINT  := Color(0.55, 0.05, 0.80, 0.30)

# Hover highlight tint — subtle white sheen
const HOVER_TINT_ALPHA := 0.12

# Playable glow shader intensity vs. non-playable
const GLOW_INTENSITY_PLAYABLE    := 1.4
const GLOW_INTENSITY_HOVERED     := 2.2
const GLOW_INTENSITY_UNPLAYABLE  := 0.0
const GLOW_PULSE_SPEED_PLAYABLE  := 1.6  # non-zero = pulse enabled

# ---------------------------------------------------------------------------

var _base_position := Vector2.ZERO
# Base rotation set by hand_display for the arc layout; hover temporarily zeroes it.
var _base_rotation := 0.0
var _is_hovered := false
var _is_selected := false
var _is_corrupted := false
var _is_on_cooldown := false
var _cooldown_remaining := 0
var _idle_tween: Tween = null
var _resolved_type_key := "skill"  # set during setup(), used for SFX
var _rarity_key := "common"
var _cooldown_label: Label = null

func setup(p_card_id: String, p_hand_index: int, p_energy: int, p_corruption_tier: int = 0, _run = null, p_cooldowns: Dictionary = {}) -> void:
	card_id = p_card_id
	hand_index = p_hand_index
	card_data = GameManager.get_card_data(card_id)
	if not card_data:
		return

	# Check cooldown state
	_cooldown_remaining = p_cooldowns.get(card_id, 0)
	_is_on_cooldown = _cooldown_remaining > 0

	is_playable = p_energy >= card_data.energy_cost and not _is_on_cooldown

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
	_is_corrupted = CardCorruption.should_corrupt(card_id, p_corruption_tier)
	if _is_corrupted:
		var overrides = CardCorruption.get_corrupted_overrides(card_id)
		name_label.text = overrides.get("display_name", card_data.display_name)
		desc_label.text = overrides.get("description", card_data.description)
		type_key = "curse"

	# Type label
	type_label.text = type_key.to_upper()
	_resolved_type_key = type_key
	_apply_card_colors(type_key)

	# Rarity — read from card_data if available, fall back to "common"
	if card_data.get("rarity"):
		_rarity_key = str(card_data.rarity).to_lower()
		if not _rarity_key in RARITY_COLORS:
			_rarity_key = "common"
	else:
		_rarity_key = "common"
	_apply_rarity_visuals(_rarity_key)

	# Corruption overlay
	_apply_corruption_overlay(_is_corrupted)

	# Card art
	if card_data.artwork:
		card_art.texture = card_data.artwork
	else:
		var art_path := "res://assets/cards/illustrations/%s/%s_base.png" % [card_id, card_id]
		if ResourceLoader.exists(art_path):
			card_art.texture = load(art_path)

	# Frame overlay — card skin by type, then act fallback
	var skin_map := {
		"attack": "res://assets/cards/frames/card_skin_red.png",
		"skill":  "res://assets/cards/frames/card_skin_blue.png",
		"power":  "res://assets/cards/frames/card_skin_red.png",
		"curse":  "res://assets/cards/frames/card_skin_red.png",
	}
	var skin_path: String = skin_map.get(type_key, "")
	if skin_path and ResourceLoader.exists(skin_path):
		frame_overlay.texture = load(skin_path)
	else:
		var current_act := 1
		if GameManager.current_run:
			current_act = GameManager.current_run.act
		var act_frame_path := "res://assets/cards/frames/frame_act%d.png" % current_act
		if ResourceLoader.exists(act_frame_path):
			frame_overlay.texture = load(act_frame_path)

	# Playability visual
	if is_playable:
		modulate = Color.WHITE
		_set_glow(true, false)
	else:
		modulate = Color(0.55, 0.55, 0.6, 0.9)
		_set_glow(false, false)

	# Cooldown badge overlay
	_update_cooldown_badge()

# ---------------------------------------------------------------------------
# Cooldown badge
# ---------------------------------------------------------------------------

func _update_cooldown_badge() -> void:
	if not _cooldown_label:
		return
	if _is_on_cooldown:
		_cooldown_label.text = str(_cooldown_remaining)
		_cooldown_label.visible = true
	else:
		_cooldown_label.visible = false

func _create_cooldown_label() -> void:
	_cooldown_label = Label.new()
	_cooldown_label.name = "CooldownLabel"
	_cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cooldown_label.add_theme_font_size_override("font_size", 22)
	_cooldown_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_cooldown_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_cooldown_label.add_theme_constant_override("shadow_offset_x", 1)
	_cooldown_label.add_theme_constant_override("shadow_offset_y", 1)
	# Position the badge in the center of the card
	_cooldown_label.set_anchors_preset(Control.PRESET_CENTER)
	_cooldown_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cooldown_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_cooldown_label.size = Vector2(60, 36)
	_cooldown_label.position = Vector2((size.x - 60) / 2.0, (size.y - 36) / 2.0)
	_cooldown_label.visible = false
	_cooldown_label.z_index = 5
	add_child(_cooldown_label)

# ---------------------------------------------------------------------------
# Color application helpers
# ---------------------------------------------------------------------------

func _apply_card_colors(type_key: String) -> void:
	var colors = TYPE_COLORS.get(type_key, TYPE_COLORS["skill"])
	var border_col: Color = colors[2]
	var banner_col: Color = colors[3]

	# Cost orb — keep colored so it pops on the frame
	var cost_style = cost_bg.get_theme_stylebox("panel") as StyleBoxFlat
	if cost_style:
		var ns = cost_style.duplicate() as StyleBoxFlat
		ns.bg_color = border_col.darkened(0.35)
		ns.border_color = border_col
		ns.shadow_color = border_col.lightened(0.1)
		cost_bg.add_theme_stylebox_override("panel", ns)

	# Type strip — semi-transparent tint over the frame
	var strip_style = type_strip.get_theme_stylebox("panel") as StyleBoxFlat
	if strip_style:
		var ss = strip_style.duplicate() as StyleBoxFlat
		ss.bg_color = Color(banner_col.r, banner_col.g, banner_col.b, 0.45)
		type_strip.add_theme_stylebox_override("panel", ss)

func _apply_rarity_visuals(rarity: String) -> void:
	var col: Color = RARITY_COLORS.get(rarity, RARITY_COLORS["common"])

	# Rarity strip at bottom of card
	var strip_style = rarity_strip.get_theme_stylebox("panel") as StyleBoxFlat
	if strip_style:
		var ns = strip_style.duplicate() as StyleBoxFlat
		ns.bg_color = col
		rarity_strip.add_theme_stylebox_override("panel", ns)

	# Override the glow color to use rarity color
	_set_glow_color(col)

func _apply_corruption_overlay(corrupted: bool) -> void:
	if not corruption_overlay:
		return
	var tween = create_tween()
	var target_color = CORRUPTION_TINT if corrupted else Color(CORRUPTION_TINT.r, CORRUPTION_TINT.g, CORRUPTION_TINT.b, 0.0)
	tween.tween_property(corruption_overlay, "color", target_color, 0.3)

# ---------------------------------------------------------------------------
# Glow control
# ---------------------------------------------------------------------------

func _set_glow_color(col: Color) -> void:
	if glow_border and glow_border.material:
		glow_border.material.set_shader_parameter("glow_color", col)

func _set_glow(_visible_state: bool, _hovered: bool) -> void:
	# Glow border disabled — frame template handles card visuals
	pass

# ---------------------------------------------------------------------------
# Selected state (called externally by hand_display or combat_scene)
# ---------------------------------------------------------------------------

func set_selected(selected: bool) -> void:
	_is_selected = selected
	# Tint the frame overlay to show selection instead of a rectangular border
	if frame_overlay:
		var tween = create_tween()
		if selected:
			tween.tween_property(frame_overlay, "modulate", Color(1.2, 1.1, 0.7, 1.0), 0.15)
		else:
			tween.tween_property(frame_overlay, "modulate", Color.WHITE, 0.15)

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	pivot_offset = size / 2.0
	_create_cooldown_label()

func _on_mouse_entered() -> void:
	SFXManager.play_button_hover()
	_is_hovered = true

	# Playable cards: big lift + scale; unplayable: subtle lift only
	var hover_scale: Vector2 = Vector2(1.15, 1.15) if is_playable else Vector2(1.05, 1.05)
	var hover_lift: float = -90.0 if is_playable else -22.0

	var tween := create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", hover_scale, 0.15)
	tween.tween_property(self, "position:y", _base_position.y + hover_lift, 0.15)
	# Straighten the card to 0 rotation regardless of its arc angle
	tween.tween_property(self, "rotation", 0.0, 0.15)

	# Glow intensifies on hover
	_set_glow(true, true)

	# Corruption overlay brightens on hover
	if _is_corrupted and corruption_overlay:
		var ctween := create_tween()
		ctween.tween_property(corruption_overlay, "color", CORRUPTION_HOVER_TINT, 0.15)

	if card_data:
		var tip := card_data.display_name
		if _is_on_cooldown:
			tip += "\n[Cooldown: %d turn%s]" % [_cooldown_remaining, "s" if _cooldown_remaining != 1 else ""]
		elif not is_playable:
			tip += "\n[Not enough energy]"
		if card_data.damage > 0:
			tip += "\nDmg: %d" % card_data.damage
			if card_data.hits > 1:
				tip += " x%d" % card_data.hits
		if card_data.block > 0:
			tip += "\nBlock: %d" % card_data.block
		if card_data.heal > 0:
			tip += "\nHeal: %d" % card_data.heal
		tooltip_text = tip

	z_index = 10

func _on_mouse_exited() -> void:
	_is_hovered = false
	var tween := create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector2.ONE, 0.15)
	tween.tween_property(self, "position:y", _base_position.y, 0.15)
	# Restore the arc rotation that hand_display assigned
	tween.tween_property(self, "rotation", _base_rotation, 0.15)

	# Restore glow to normal playable state (or off if unplayable)
	if _is_selected:
		# Selected state maintains its own glow — don't reset it
		pass
	else:
		_set_glow(is_playable, false)

	# Restore corruption overlay to resting alpha
	if _is_corrupted and corruption_overlay:
		var ctween := create_tween()
		ctween.tween_property(corruption_overlay, "color", CORRUPTION_TINT, 0.2)

	z_index = 0

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_playable:
			card_clicked.emit(hand_index)
		else:
			# Shake feedback for unplayable card — use base_position.x as anchor
			# so the shake always centres on the correct resting position
			var shake_tw := create_tween()
			var orig_x := _base_position.x
			shake_tw.tween_property(self, "position:x", orig_x + 6, 0.04)
			shake_tw.tween_property(self, "position:x", orig_x - 6, 0.04)
			shake_tw.tween_property(self, "position:x", orig_x + 3, 0.04)
			shake_tw.tween_property(self, "position:x", orig_x, 0.04)
			# Flash red briefly
			var flash_tw := create_tween()
			flash_tw.tween_property(self, "modulate", Color(1.0, 0.4, 0.4, 0.9), 0.08)
			flash_tw.tween_property(self, "modulate", Color(0.55, 0.55, 0.6, 0.9), 0.15)

# ---------------------------------------------------------------------------
# Animate the card flying to a target position then disappearing
# ---------------------------------------------------------------------------

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

## Play a dissolve effect for exhausted cards (purple edge glow dissolving away)
func play_exhaust_dissolve() -> void:
	# Disable input during animation
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20

	# Apply dissolve shader to the card background
	var shader = load("res://shaders/dissolve.gdshader") as Shader
	if not shader:
		# Fallback: just fade out
		var tw = create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.5)
		tw.tween_callback(queue_free)
		return

	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("dissolve_amount", 0.0)
	mat.set_shader_parameter("edge_color", Color(0.6, 0.3, 1.0, 1.0))  # Purple edge
	mat.set_shader_parameter("edge_width", 0.08)
	material = mat

	# Animate dissolve from 0 to 1
	var tween = create_tween()
	tween.tween_method(func(val: float):
		if is_instance_valid(self) and material is ShaderMaterial:
			material.set_shader_parameter("dissolve_amount", val)
	, 0.0, 1.1, 0.6)
	tween.tween_callback(queue_free)
