extends CanvasLayer

var pause_menu: Control = null
var settings_panel: Control = null
var is_paused: bool = false

# Persisted settings
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 1.0
var fullscreen: bool = false

const SETTINGS_PATH = "user://settings.json"

func _ready() -> void:
	layer = 99
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_apply_settings()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if is_paused:
			resume()
		else:
			pause()
		get_viewport().set_input_as_handled()

func pause() -> void:
	if is_paused:
		return
	is_paused = true
	get_tree().paused = true
	SFXManager.play_button_click()
	_build_menu()

func resume() -> void:
	if not is_paused:
		return
	is_paused = false
	get_tree().paused = false
	if pause_menu:
		pause_menu.queue_free()
		pause_menu = null

func _build_menu() -> void:
	pause_menu = Control.new()
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_menu)

	# Dimmer
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.75)
	dimmer.modulate = Color(1, 1, 1, 0)
	pause_menu.add_child(dimmer)

	# Fade dimmer in
	var fade_tween := dimmer.create_tween()
	fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_tween.tween_property(dimmer, "modulate", Color(1, 1, 1, 1), 0.15)

	# Panel
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(360, 340)
	panel.position = Vector2(-180, -170)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, 0.95)
	style.border_color = Color(0.4, 0.35, 0.7, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	pause_menu.add_child(panel)

	# Scale-in animation
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = panel.custom_minimum_size / 2.0
	var scale_tween := panel.create_tween()
	scale_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	scale_tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.85, 0.8, 1.0))
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	# Buttons
	_add_button(vbox, "Resume", func(): resume())
	_add_button(vbox, "Settings", func(): _show_settings())
	_add_button(vbox, "Quit to Menu", func():
		resume()
		GameManager.end_run()
		TransitionManager.transition_to_scene("res://scenes/main/main_menu.tscn")
	)
	_add_button(vbox, "Quit to Desktop", func():
		get_tree().quit()
	)

func _add_button(parent: VBoxContainer, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 44)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.14, 0.22)
	btn_style.border_color = Color(0.35, 0.3, 0.55)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(8)
	btn_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", btn_style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.22, 0.2, 0.35)
	hover_style.border_color = Color(0.5, 0.45, 0.8)
	hover_style.set_border_width_all(1)
	hover_style.set_corner_radius_all(8)
	hover_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.25, 0.22, 0.4)
	pressed_style.border_color = Color(0.6, 0.5, 0.9)
	pressed_style.set_border_width_all(1)
	pressed_style.set_corner_radius_all(8)
	pressed_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.9, 0.88, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 1.0))

	btn.pressed.connect(func():
		SFXManager.play_button_click()
		callback.call()
	)
	btn.mouse_entered.connect(func():
		SFXManager.play_button_hover()
	)

	parent.add_child(btn)

# ---------------------------------------------------------------------------
# Settings panel
# ---------------------------------------------------------------------------

func _show_settings() -> void:
	if settings_panel:
		return
	# Hide the main pause buttons by removing the panel's parent
	# We'll rebuild when going back
	if pause_menu:
		for child in pause_menu.get_children():
			if child is PanelContainer:
				child.visible = false

	settings_panel = Control.new()
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.add_child(settings_panel)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(440, 420)
	panel.position = Vector2(-220, -210)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, 0.95)
	style.border_color = Color(0.4, 0.35, 0.7, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	settings_panel.add_child(panel)

	# Scale-in
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = panel.custom_minimum_size / 2.0
	var tween := panel.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.85, 0.8, 1.0))
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	# Audio sliders
	_add_slider(vbox, "Master Volume", master_volume, func(val: float):
		master_volume = val
		_apply_settings()
	)
	_add_slider(vbox, "SFX Volume", sfx_volume, func(val: float):
		sfx_volume = val
		_apply_settings()
	)
	_add_slider(vbox, "Music Volume", music_volume, func(val: float):
		music_volume = val
		_apply_settings()
	)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer2)

	# Fullscreen toggle
	_add_toggle(vbox, "Fullscreen", fullscreen, func(toggled_on: bool):
		fullscreen = toggled_on
		_apply_settings()
	)

	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer3)

	# Back button
	_add_button(vbox, "Back", func():
		_save_settings()
		_close_settings()
	)

func _close_settings() -> void:
	if settings_panel:
		settings_panel.queue_free()
		settings_panel = null
	# Re-show main pause panel
	if pause_menu:
		for child in pause_menu.get_children():
			if child is PanelContainer:
				child.visible = true

func _add_slider(parent: VBoxContainer, label_text: String, initial_value: float, callback: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	parent.add_child(hbox)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(150, 0)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.8, 0.78, 0.95))
	hbox.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial_value
	slider.custom_minimum_size = Vector2(180, 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Style the slider
	var grabber_style := StyleBoxFlat.new()
	grabber_style.bg_color = Color(0.5, 0.45, 0.8)
	grabber_style.set_corner_radius_all(4)
	grabber_style.content_margin_left = 8
	grabber_style.content_margin_right = 8
	grabber_style.content_margin_top = 8
	grabber_style.content_margin_bottom = 8
	slider.add_theme_stylebox_override("grabber_area", grabber_style)

	hbox.add_child(slider)

	var pct_label := Label.new()
	pct_label.text = "%d%%" % int(initial_value * 100)
	pct_label.custom_minimum_size = Vector2(48, 0)
	pct_label.add_theme_font_size_override("font_size", 14)
	pct_label.add_theme_color_override("font_color", Color(0.65, 0.62, 0.85))
	hbox.add_child(pct_label)

	slider.value_changed.connect(func(val: float):
		pct_label.text = "%d%%" % int(val * 100)
		callback.call(val)
	)

func _add_toggle(parent: VBoxContainer, label_text: String, initial_value: bool, callback: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	parent.add_child(hbox)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(150, 0)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.8, 0.78, 0.95))
	hbox.add_child(label)

	var toggle := CheckButton.new()
	toggle.button_pressed = initial_value
	toggle.toggled.connect(func(toggled_on: bool):
		SFXManager.play_button_click()
		callback.call(toggled_on)
	)
	hbox.add_child(toggle)

# ---------------------------------------------------------------------------
# Apply / Save / Load settings
# ---------------------------------------------------------------------------

func _apply_settings() -> void:
	# Audio buses: Master is always index 0
	var master_bus: int = AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(master_volume))
		AudioServer.set_bus_mute(master_bus, master_volume <= 0.01)

	# SFX and Music buses may not exist yet — apply to master as fallback
	var sfx_bus: int = AudioServer.get_bus_index("SFX")
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(sfx_volume))
		AudioServer.set_bus_mute(sfx_bus, sfx_volume <= 0.01)

	var music_bus: int = AudioServer.get_bus_index("Music")
	if music_bus >= 0:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(music_volume))
		AudioServer.set_bus_mute(music_bus, music_volume <= 0.01)

	# Fullscreen
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _save_settings() -> void:
	var data := {
		"master_volume": master_volume,
		"sfx_volume": sfx_volume,
		"music_volume": music_volume,
		"fullscreen": fullscreen,
	}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Dictionary = json.data
	master_volume = data.get("master_volume", 1.0)
	sfx_volume = data.get("sfx_volume", 1.0)
	music_volume = data.get("music_volume", 1.0)
	fullscreen = data.get("fullscreen", false)
