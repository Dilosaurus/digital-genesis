extends Control

## Hack Challenge minigame — player must mash-click to fill bar before timer expires.
## Success = resist hack. Failure = hack effect applies.

signal challenge_completed(success: bool)

@onready var title_label: Label = $Panel/TitleLabel
@onready var timer_bar: ColorRect = $Panel/TimerBarBG/TimerBarFill
@onready var timer_bar_bg: ColorRect = $Panel/TimerBarBG
@onready var progress_bar: ColorRect = $Panel/ProgressBarBG/ProgressBarFill
@onready var progress_bar_bg: ColorRect = $Panel/ProgressBarBG
@onready var mash_button: Button = $Panel/MashButton
@onready var status_label: Label = $Panel/StatusLabel

var time_limit: float = 3.0
var time_remaining: float = 3.0
var clicks_needed: int = 15
var click_count: int = 0
var is_active: bool = false
var decay_rate: float = 0.8  # Progress decays over time for tension

func _ready() -> void:
	visible = false
	mash_button.pressed.connect(_on_mash)

func start_challenge(difficulty: float = 1.0) -> void:
	# Difficulty scales clicks needed and reduces time
	clicks_needed = int(12 + 8 * difficulty)
	time_limit = maxf(2.0, 3.5 - 0.5 * difficulty)
	time_remaining = time_limit
	click_count = 0
	decay_rate = 0.3 + 0.4 * difficulty

	title_label.text = ">> HACK DETECTED <<"
	status_label.text = "MASH TO RESIST!"
	mash_button.text = "[ RESIST ]"

	_update_bars()
	visible = true
	is_active = true

func _process(delta: float) -> void:
	if not is_active:
		return

	time_remaining -= delta

	# Progress decays over time — can't just front-load clicks
	click_count = maxf(click_count - decay_rate * delta, 0)

	_update_bars()

	if time_remaining <= 0:
		_end_challenge(false)
	elif click_count >= clicks_needed:
		_end_challenge(true)

func _on_mash() -> void:
	if not is_active:
		return
	click_count += 1
	# Visual feedback — flash the button
	mash_button.modulate = Color(1.5, 1.5, 1.5)
	var tween = create_tween()
	tween.tween_property(mash_button, "modulate", Color.WHITE, 0.1)

func _update_bars() -> void:
	var time_pct = clampf(time_remaining / time_limit, 0, 1)
	timer_bar.scale.x = time_pct
	# Color shifts red as time runs out
	timer_bar.color = Color(1.0 - time_pct, time_pct, 0.2)

	var progress_pct = clampf(float(click_count) / clicks_needed, 0, 1)
	progress_bar.scale.x = progress_pct
	progress_bar.color = Color(0.2, 0.4 + 0.6 * progress_pct, 1.0)

func _end_challenge(success: bool) -> void:
	is_active = false
	if success:
		title_label.text = ">> HACK RESISTED <<"
		status_label.text = "FIREWALL HELD!"
		status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	else:
		title_label.text = ">> SYSTEM BREACHED <<"
		status_label.text = "HACK SUCCESSFUL..."
		status_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	mash_button.disabled = true
	# Brief delay then dismiss
	await get_tree().create_timer(1.2).timeout
	visible = false
	mash_button.disabled = false
	challenge_completed.emit(success)
