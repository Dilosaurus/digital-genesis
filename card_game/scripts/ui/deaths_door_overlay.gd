extends Control

@onready var vignette: ColorRect = $Vignette
@onready var status_label: Label = $StatusLabel
var pulse_tween: Tween

func show_deaths_door(turns_remaining: int) -> void:
	visible = true
	status_label.text = "DEATH'S DOOR — %d turns remain" % turns_remaining
	_start_pulse()

func hide_overlay() -> void:
	visible = false
	if pulse_tween:
		pulse_tween.kill()

func show_dead() -> void:
	visible = true
	status_label.text = "ELIMINATED"
	status_label.add_theme_color_override("font_color", Color(0.5, 0.1, 0.1))
	vignette.color = Color(0.2, 0, 0, 0.6)
	if pulse_tween:
		pulse_tween.kill()

func _start_pulse() -> void:
	if pulse_tween:
		pulse_tween.kill()
	pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(vignette, "color:a", 0.4, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(vignette, "color:a", 0.15, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
