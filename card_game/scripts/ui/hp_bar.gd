extends Control

@onready var bar_fill: ColorRect        = $BarFill
@onready var bar_damage_preview: ColorRect = $BarDamagePreview
@onready var bar_block: Panel           = $BarBlock
@onready var flash_overlay: Panel       = $FlashOverlay
@onready var tick_marks: Control        = $TickMarks
@onready var hp_label: Label            = $HPLabel

var max_value: int   = 80
var current_value: int = 80
var _block_value: int  = 0
var _tween: Tween      = null
var _flash_tween: Tween = null

# Cached ShaderMaterial so we can drive uniforms directly.
var _fill_mat: ShaderMaterial = null

# Colours for the gradient fill, keyed by health ratio thresholds.
# Each entry: [ratio_threshold, top_color, bottom_color]
const _GRADIENT_STAGES = [
	[0.60, Color(0.28, 1.00, 0.45), Color(0.08, 0.55, 0.18)],  # green
	[0.35, Color(1.00, 0.88, 0.15), Color(0.65, 0.50, 0.05)],  # yellow
	[0.15, Color(1.00, 0.50, 0.12), Color(0.65, 0.22, 0.06)],  # orange
	[0.00, Color(1.00, 0.18, 0.18), Color(0.60, 0.06, 0.06)],  # red
]

func _ready() -> void:
	if bar_damage_preview:
		bar_damage_preview.visible = false
	if bar_block:
		bar_block.visible = false

	_fill_mat = bar_fill.material as ShaderMaterial
	_refresh_tick_positions()

# ── Public API (same surface as before) ──────────────────────────────────────

func set_values(current: int, maximum: int) -> void:
	var old_value := current_value
	max_value     = maximum
	current_value = current
	_update_display_animated(old_value > current)

## Show projected damage on the bar (called when hovering over attack cards)
func show_damage_preview(damage: int) -> void:
	if not bar_damage_preview:
		return
	var ratio       = _ratio(current_value)
	var ratio_after = _ratio(maxi(current_value - damage, 0))
	bar_damage_preview.scale.x = ratio
	bar_damage_preview.visible = true
	bar_fill.scale.x           = ratio_after

## Hide the damage preview
func hide_damage_preview() -> void:
	if not bar_damage_preview:
		return
	bar_damage_preview.visible = false
	bar_fill.scale.x = _ratio(current_value)

## Update the block overlay.  Call from enemy_display after set_values.
func set_block(block: int) -> void:
	_block_value = block
	_refresh_block_overlay()

# ── Internal helpers ──────────────────────────────────────────────────────────

func _ratio(value: int) -> float:
	return float(value) / float(max_value) if max_value > 0 else 0.0

func _update_display_animated(took_damage: bool) -> void:
	if not is_node_ready():
		return

	hp_label.text = "%d / %d" % [current_value, max_value]

	var target_ratio := _ratio(current_value)
	var start_ratio  := bar_fill.scale.x

	# Kill existing tween
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Smooth drain over 0.35 s
	_tween.tween_property(bar_fill, "scale:x", target_ratio, 0.35)

	# Update shader gradient colours in parallel
	_tween.parallel().tween_method(_update_shader_color, start_ratio, target_ratio, 0.35)

	# Low-HP shader flag
	if _fill_mat:
		_fill_mat.set_shader_parameter("low_hp", 1.0 if target_ratio < 0.25 else 0.0)

	# Damage flash — brief white-red highlight
	if took_damage:
		_trigger_damage_flash()

	_refresh_block_overlay()

func _trigger_damage_flash() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	if _fill_mat:
		_fill_mat.set_shader_parameter("flash_amount", 1.0)
		_flash_tween = create_tween()
		_flash_tween.tween_method(
			func(v: float): _fill_mat.set_shader_parameter("flash_amount", v),
			1.0, 0.0, 0.4
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _update_shader_color(ratio: float) -> void:
	if not _fill_mat:
		return
	var top    := Color(0.28, 1.00, 0.45)
	var bottom := Color(0.08, 0.55, 0.18)

	for stage in _GRADIENT_STAGES:
		if ratio >= stage[0]:
			top    = stage[1]
			bottom = stage[2]
			break

	_fill_mat.set_shader_parameter("color_top",    top)
	_fill_mat.set_shader_parameter("color_bottom", bottom)

func _refresh_block_overlay() -> void:
	if not bar_block:
		return
	if _block_value <= 0:
		bar_block.visible = false
		return

	# Block sits on the right edge of the current HP fill.
	var bar_width: float = size.x if size.x > 0 else 200.0
	var fill_end_px  := bar_fill.scale.x * bar_width
	var block_width  := minf(float(_block_value) / float(max_value) * bar_width, bar_width - fill_end_px)
	block_width       = maxf(block_width, 4.0)   # always at least a sliver

	bar_block.offset_left  = fill_end_px
	bar_block.offset_right = fill_end_px + block_width
	bar_block.visible      = true

func _refresh_tick_positions() -> void:
	# Ticks are fixed at 25 / 50 / 75 % of the bar width.
	# They are set correctly in the .tscn already; this is a no-op unless
	# the bar is resized.  Override if needed for dynamic widths.
	pass
