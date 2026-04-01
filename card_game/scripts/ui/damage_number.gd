extends Label

func show_number(value: int, type: String = "damage") -> void:
	var font_size := 28
	var color := Color(1, 0.3, 0.2)
	var prefix := ""
	var shadow_col := Color(0, 0, 0, 0.6)

	match type:
		"damage":
			text = str(value)
			color = Color(1.0, 0.28, 0.18)
			font_size = 30
			shadow_col = Color(0.5, 0.0, 0.0, 0.7)
		"block":
			text = str(value)
			color = Color(0.3, 0.65, 1.0)
			font_size = 26
			shadow_col = Color(0.0, 0.1, 0.5, 0.7)
		"heal":
			prefix = "+"
			text = "+" + str(value)
			color = Color(0.25, 1.0, 0.4)
			font_size = 26
			shadow_col = Color(0.0, 0.35, 0.1, 0.7)
		"vulnerable":
			text = "VULN!"
			color = Color(1.0, 0.55, 0.15)
			font_size = 17
		"weak":
			text = "WEAK!"
			color = Color(0.55, 0.85, 0.2)
			font_size = 17
		"corrupt":
			text = "CORRUPT"
			color = Color(0.8, 0.15, 0.9)
			font_size = 17

	add_theme_color_override("font_color", color)
	add_theme_color_override("font_shadow_color", shadow_col)
	add_theme_font_size_override("font_size", font_size)
	add_theme_constant_override("shadow_offset_x", 2)
	add_theme_constant_override("shadow_offset_y", 2)

	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pivot_offset = size / 2.0

	# Start big for pop-in
	scale = Vector2(1.6, 1.6)
	modulate.a = 1.0

	var rand_x = randf_range(-35, 35)
	var rand_y = randf_range(-10, 10)

	var tween = create_tween().set_parallel()
	# Float upward
	tween.tween_property(self, "position:y", position.y - 70.0 + rand_y, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# Drift horizontally
	tween.tween_property(self, "position:x", position.x + rand_x, 1.0)
	# Bounce scale down to 1.0
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Hold then fade out
	tween.tween_property(self, "modulate:a", 0.0, 0.38).set_delay(0.62)
	tween.chain().tween_callback(queue_free)
