class_name VoteOverlay
extends Control

signal vote_cast(option_index: int)
signal vote_timed_out()

var _vote_context: VoteSystem.VoteContext = null
var _timer: float = 0.0
var _panel: Panel = null
var _title_label: Label = null
var _prompt_label: Label = null
var _timer_label: Label = null
var _option_buttons: Array[Button] = []
var _vote_indicators: Dictionary = {}  # peer_id -> Label showing their vote status
var _has_voted: bool = false


func _ready() -> void:
	# Full-screen semi-transparent overlay
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP  # Block input to elements behind

	# Dim background
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	# Center panel
	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(500, 350)
	_panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	_panel.offset_left = -250
	_panel.offset_right = 250
	_panel.offset_top = -175
	_panel.offset_bottom = 175

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.95)
	style.border_color = Color(0.6, 0.5, 0.2, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	# Title
	_title_label = Label.new()
	_title_label.text = "PARTY VOTE"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.position = Vector2(0, 12)
	_title_label.size = Vector2(500, 30)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.2))
	_title_label.add_theme_font_size_override("font_size", 20)
	_panel.add_child(_title_label)

	# Prompt
	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.position = Vector2(20, 48)
	_prompt_label.size = Vector2(460, 50)
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_prompt_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90))
	_prompt_label.add_theme_font_size_override("font_size", 14)
	_panel.add_child(_prompt_label)

	# Timer
	_timer_label = Label.new()
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.position = Vector2(0, 310)
	_timer_label.size = Vector2(500, 30)
	_timer_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	_timer_label.add_theme_font_size_override("font_size", 16)
	_panel.add_child(_timer_label)


func show_vote(ctx: VoteSystem.VoteContext) -> void:
	_vote_context = ctx
	_has_voted = false
	_prompt_label.text = ctx.prompt
	_timer = ctx.time_remaining

	# Clear old buttons
	for btn in _option_buttons:
		btn.queue_free()
	_option_buttons.clear()

	# Create option buttons
	var y: float = 110.0
	for i in ctx.options.size():
		var btn := Button.new()
		btn.text = ctx.options[i]
		btn.custom_minimum_size = Vector2(400, 40)
		btn.position = Vector2(50, y)
		var idx = i
		btn.pressed.connect(func(): _on_option_pressed(idx))

		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.15, 0.13, 0.22)
		btn_style.border_color = Color(0.5, 0.45, 0.65)
		btn_style.set_border_width_all(1)
		btn_style.set_corner_radius_all(5)
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))

		_panel.add_child(btn)
		_option_buttons.append(btn)
		y += 48

	visible = true


func _on_option_pressed(option_index: int) -> void:
	if _has_voted:
		return
	_has_voted = true
	# Gray out all buttons
	for btn in _option_buttons:
		btn.disabled = true
	# Highlight chosen option
	if option_index < _option_buttons.size():
		_option_buttons[option_index].add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
	vote_cast.emit(option_index)


func update_vote_state(summary: Dictionary) -> void:
	# Update timer display
	_timer_label.text = "Time: %.0f" % summary.get("time_remaining", 0)
	# Could also update vote count indicators here


func _process(delta: float) -> void:
	if not visible or _vote_context == null:
		return
	_timer -= delta
	_timer_label.text = "Time: %.0f" % maxf(_timer, 0)
	if _timer <= 0 and not _vote_context.is_resolved:
		vote_timed_out.emit()
		visible = false


func close() -> void:
	visible = false
	queue_free()
