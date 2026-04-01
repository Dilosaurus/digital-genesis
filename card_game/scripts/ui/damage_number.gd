extends Label

func show_number(value: int, type: String = "damage") -> void:
	match type:
		"damage":
			text = str(value)
			add_theme_color_override("font_color", Color(1, 0.3, 0.2))
			add_theme_font_size_override("font_size", 28)
		"block":
			text = str(value)
			add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
			add_theme_font_size_override("font_size", 24)
		"heal":
			text = "+" + str(value)
			add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
			add_theme_font_size_override("font_size", 24)
		"vulnerable":
			text = "VULNERABLE"
			add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
			add_theme_font_size_override("font_size", 18)
		"weak":
			text = "WEAK"
			add_theme_color_override("font_color", Color(0.6, 0.8, 0.2))
			add_theme_font_size_override("font_size", 18)

	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pivot_offset = size / 2.0

	# Start at larger scale for bounce-in effect
	scale = Vector2(1.5, 1.5)

	# Random horizontal offset
	var offset_x = randf_range(-30, 30)

	# Animate: float up, scale bounce down, fade out
	var tween = create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y - 60, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "position:x", position.x + offset_x, 0.8)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.4).set_delay(0.5)
	tween.chain().tween_callback(queue_free)
