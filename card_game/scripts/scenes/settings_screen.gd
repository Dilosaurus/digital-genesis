extends Control

signal settings_closed

@onready var window_mode_option: OptionButton = $Panel/WindowModeOption
@onready var resolution_option: OptionButton = $Panel/ResolutionOption
@onready var vsync_option: OptionButton = $Panel/VSyncOption
@onready var max_fps_option: OptionButton = $Panel/MaxFPSOption
@onready var msaa_option: OptionButton = $Panel/MSAAOption
@onready var ui_scale_slider: HSlider = $Panel/UIScaleSlider
@onready var ui_scale_value: Label = $Panel/UIScaleValue
@onready var stretch_mode_option: OptionButton = $Panel/StretchModeOption
@onready var master_slider: HSlider = $Panel/MasterSlider
@onready var sfx_slider: HSlider = $Panel/SFXSlider
@onready var music_slider: HSlider = $Panel/MusicSlider
@onready var ambience_slider: HSlider = $Panel/AmbienceSlider

const RESOLUTIONS = [
	Vector2i(1024, 576),
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
	Vector2i(3440, 1440),
	Vector2i(3840, 2160),
]

const FPS_OPTIONS = [30, 60, 90, 120, 144, 240, 0] # 0 = unlimited
const SETTINGS_PATH = "user://settings.cfg"

func _ready() -> void:
	_setup_window_mode()
	_setup_resolution()
	_setup_vsync()
	_setup_max_fps()
	_setup_msaa()
	_setup_ui_scale()
	_setup_stretch_mode()
	_setup_audio()

	$Panel/ApplyButton.pressed.connect(_on_apply_pressed)
	$Panel/BackButton.pressed.connect(func():
		visible = false
		settings_closed.emit()
	)

# --- Helpers ---

## Apply a resolution: sets both the OS window size and the viewport content scale
## so that the game actually renders at the chosen resolution.
static func _apply_resolution(res: Vector2i, root: Window) -> void:
	# Set the window size
	DisplayServer.window_set_size(res)
	# Update the content scale size so the viewport matches
	root.content_scale_size = res
	# Center the window on screen
	var screen_size := DisplayServer.screen_get_size()
	var win_pos := Vector2i(
		max(0, (screen_size.x - res.x) / 2),
		max(0, (screen_size.y - res.y) / 2)
	)
	DisplayServer.window_set_position(win_pos)

# --- Save / Load ---

static func load_and_apply_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return

	var tree := Engine.get_main_loop() as SceneTree
	if not tree:
		return
	var root := tree.root

	# Window mode
	var win_mode: int = config.get_value("video", "window_mode", 0)
	match win_mode:
		0: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

	# Resolution
	var res_x: int = config.get_value("video", "resolution_x", 1920)
	var res_y: int = config.get_value("video", "resolution_y", 1080)
	var res := Vector2i(res_x, res_y)
	if win_mode == 0:
		_apply_resolution(res, root)
	else:
		# In fullscreen, just set the content scale to match chosen resolution
		root.content_scale_size = res

	# VSync
	var vsync: int = config.get_value("video", "vsync", 1)
	DisplayServer.window_set_vsync_mode(vsync as DisplayServer.VSyncMode)

	# Max FPS
	var fps: int = config.get_value("video", "max_fps", 0)
	Engine.max_fps = fps

	# MSAA
	var msaa: int = config.get_value("video", "msaa", 0)
	var vp := root.get_viewport()
	match msaa:
		1: vp.msaa_2d = Viewport.MSAA_2X
		2: vp.msaa_2d = Viewport.MSAA_4X
		3: vp.msaa_2d = Viewport.MSAA_8X
		_: vp.msaa_2d = Viewport.MSAA_DISABLED

	# UI Scale
	var ui_scale: float = config.get_value("scaling", "ui_scale", 1.0)
	root.content_scale_factor = ui_scale

	# Stretch mode
	var stretch: int = config.get_value("scaling", "stretch_mode", 0)
	match stretch:
		1: root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		_: root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS

	# Audio
	var master_vol: float = config.get_value("audio", "master_volume", 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(master_vol))

	var sfx_vol: float = config.get_value("audio", "sfx_volume", 1.0)
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(sfx_vol))

	var music_vol: float = config.get_value("audio", "music_volume", 0.8)
	var music_idx: int = AudioServer.get_bus_index("Music")
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(music_vol))

	var amb_vol: float = config.get_value("audio", "ambience_volume", 0.5)
	var amb_idx: int = AudioServer.get_bus_index("Ambience")
	if amb_idx >= 0:
		AudioServer.set_bus_volume_db(amb_idx, linear_to_db(amb_vol))

func _save_settings() -> void:
	var config := ConfigFile.new()

	# Video
	config.set_value("video", "window_mode", window_mode_option.selected)
	var res_idx := resolution_option.selected
	if res_idx >= 0 and res_idx < RESOLUTIONS.size():
		config.set_value("video", "resolution_x", RESOLUTIONS[res_idx].x)
		config.set_value("video", "resolution_y", RESOLUTIONS[res_idx].y)
	config.set_value("video", "vsync", vsync_option.selected)
	var fps_idx := max_fps_option.selected
	if fps_idx >= 0 and fps_idx < FPS_OPTIONS.size():
		config.set_value("video", "max_fps", FPS_OPTIONS[fps_idx])
	config.set_value("video", "msaa", msaa_option.selected)

	# Scaling
	config.set_value("scaling", "ui_scale", ui_scale_slider.value)
	config.set_value("scaling", "stretch_mode", stretch_mode_option.selected)

	# Audio
	config.set_value("audio", "master_volume", master_slider.value)
	config.set_value("audio", "sfx_volume", sfx_slider.value)
	config.set_value("audio", "music_volume", music_slider.value)
	config.set_value("audio", "ambience_volume", ambience_slider.value)

	config.save(SETTINGS_PATH)

# --- Apply ---

func _on_apply_pressed() -> void:
	_on_window_mode_selected(window_mode_option.selected)
	_on_resolution_selected(resolution_option.selected)
	_on_vsync_selected(vsync_option.selected)
	_on_max_fps_selected(max_fps_option.selected)
	_on_msaa_selected(msaa_option.selected)
	_on_ui_scale_changed(ui_scale_slider.value)
	_on_stretch_mode_selected(stretch_mode_option.selected)
	_on_master_changed(master_slider.value)
	_on_sfx_changed(sfx_slider.value)
	_on_music_changed(music_slider.value)
	_on_ambience_changed(ambience_slider.value)
	_save_settings()

# --- Window Mode ---

func _setup_window_mode() -> void:
	window_mode_option.add_item("Windowed", 0)
	window_mode_option.add_item("Borderless Fullscreen", 1)
	window_mode_option.add_item("Exclusive Fullscreen", 2)

	var current_mode := DisplayServer.window_get_mode()
	match current_mode:
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			window_mode_option.selected = 1
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			window_mode_option.selected = 2
		_:
			window_mode_option.selected = 0

	window_mode_option.item_selected.connect(_on_window_mode_selected)

func _on_window_mode_selected(index: int) -> void:
	match index:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			resolution_option.disabled = false
			# Apply selected resolution when switching to windowed
			_on_resolution_selected(resolution_option.selected)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			resolution_option.disabled = true
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			resolution_option.disabled = true

# --- Resolution ---

func _setup_resolution() -> void:
	var current_size := get_tree().root.content_scale_size
	if current_size == Vector2i.ZERO:
		current_size = DisplayServer.window_get_size()
	var best_match := 0
	for i in RESOLUTIONS.size():
		var res: Vector2i = RESOLUTIONS[i]
		resolution_option.add_item("%dx%d" % [res.x, res.y], i)
		if res == current_size:
			best_match = i
		elif RESOLUTIONS[best_match] != current_size:
			if abs(res.x - current_size.x) < abs(RESOLUTIONS[best_match].x - current_size.x):
				best_match = i
	resolution_option.selected = best_match

	var is_fullscreen := DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED
	resolution_option.disabled = is_fullscreen
	resolution_option.item_selected.connect(_on_resolution_selected)

func _on_resolution_selected(index: int) -> void:
	if index < 0 or index >= RESOLUTIONS.size():
		return
	var res: Vector2i = RESOLUTIONS[index]
	var root := get_tree().root
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		_apply_resolution(res, root)
	else:
		# In fullscreen, only change the render resolution
		root.content_scale_size = res

# --- VSync ---

func _setup_vsync() -> void:
	vsync_option.add_item("Disabled", 0)
	vsync_option.add_item("Enabled", 1)
	vsync_option.add_item("Adaptive", 2)
	vsync_option.add_item("Mailbox", 3)

	var current_vsync := DisplayServer.window_get_vsync_mode()
	vsync_option.selected = current_vsync
	vsync_option.item_selected.connect(_on_vsync_selected)

func _on_vsync_selected(index: int) -> void:
	DisplayServer.window_set_vsync_mode(index as DisplayServer.VSyncMode)

# --- Max FPS ---

func _setup_max_fps() -> void:
	for fps in FPS_OPTIONS:
		if fps == 0:
			max_fps_option.add_item("Unlimited")
		else:
			max_fps_option.add_item("%d FPS" % fps)

	var current_fps := Engine.max_fps
	var found := false
	for i in FPS_OPTIONS.size():
		if FPS_OPTIONS[i] == current_fps:
			max_fps_option.selected = i
			found = true
			break
	if not found:
		max_fps_option.selected = FPS_OPTIONS.size() - 1

	max_fps_option.item_selected.connect(_on_max_fps_selected)

func _on_max_fps_selected(index: int) -> void:
	if index < 0 or index >= FPS_OPTIONS.size():
		return
	Engine.max_fps = FPS_OPTIONS[index]

# --- MSAA ---

func _setup_msaa() -> void:
	msaa_option.add_item("Disabled", 0)
	msaa_option.add_item("2x MSAA", 1)
	msaa_option.add_item("4x MSAA", 2)
	msaa_option.add_item("8x MSAA", 3)

	var vp := get_viewport()
	match vp.msaa_2d:
		Viewport.MSAA_DISABLED: msaa_option.selected = 0
		Viewport.MSAA_2X: msaa_option.selected = 1
		Viewport.MSAA_4X: msaa_option.selected = 2
		Viewport.MSAA_8X: msaa_option.selected = 3

	msaa_option.item_selected.connect(_on_msaa_selected)

func _on_msaa_selected(index: int) -> void:
	var vp := get_viewport()
	match index:
		0: vp.msaa_2d = Viewport.MSAA_DISABLED
		1: vp.msaa_2d = Viewport.MSAA_2X
		2: vp.msaa_2d = Viewport.MSAA_4X
		3: vp.msaa_2d = Viewport.MSAA_8X

# --- UI Scale ---

func _setup_ui_scale() -> void:
	var current_scale: float = get_tree().root.content_scale_factor
	ui_scale_slider.value = current_scale
	ui_scale_value.text = "%d%%" % int(current_scale * 100)
	ui_scale_slider.value_changed.connect(_on_ui_scale_changed)

func _on_ui_scale_changed(value: float) -> void:
	get_tree().root.content_scale_factor = value
	ui_scale_value.text = "%d%%" % int(value * 100)

# --- Stretch Mode ---

func _setup_stretch_mode() -> void:
	stretch_mode_option.add_item("Canvas Items", 0)
	stretch_mode_option.add_item("Viewport", 1)

	var current_mode := get_tree().root.content_scale_mode
	match current_mode:
		Window.CONTENT_SCALE_MODE_CANVAS_ITEMS: stretch_mode_option.selected = 0
		Window.CONTENT_SCALE_MODE_VIEWPORT: stretch_mode_option.selected = 1
		_: stretch_mode_option.selected = 0

	stretch_mode_option.item_selected.connect(_on_stretch_mode_selected)

func _on_stretch_mode_selected(index: int) -> void:
	match index:
		0: get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		1: get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT

# --- Audio ---

func _setup_audio() -> void:
	master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	master_slider.value_changed.connect(_on_master_changed)

	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_idx))
	sfx_slider.value_changed.connect(_on_sfx_changed)

	var music_idx: int = AudioServer.get_bus_index("Music")
	if music_idx >= 0:
		music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(music_idx))
	else:
		music_slider.value = 0.8
	music_slider.value_changed.connect(_on_music_changed)

	var amb_idx: int = AudioServer.get_bus_index("Ambience")
	if amb_idx >= 0:
		ambience_slider.value = db_to_linear(AudioServer.get_bus_volume_db(amb_idx))
	else:
		ambience_slider.value = 0.5
	ambience_slider.value_changed.connect(_on_ambience_changed)

func _on_master_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value))

func _on_sfx_changed(value: float) -> void:
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(value))

func _on_music_changed(value: float) -> void:
	var music_idx: int = AudioServer.get_bus_index("Music")
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(value))
	MusicManager.set_music_volume(value)

func _on_ambience_changed(value: float) -> void:
	var amb_idx: int = AudioServer.get_bus_index("Ambience")
	if amb_idx >= 0:
		AudioServer.set_bus_volume_db(amb_idx, linear_to_db(value))
	MusicManager.set_ambience_volume(value)
