extends Control

signal settings_closed

@onready var fullscreen_toggle: CheckButton = $Panel/FullscreenToggle
@onready var master_slider: HSlider = $Panel/MasterSlider
@onready var sfx_slider: HSlider = $Panel/SFXSlider

func _ready() -> void:
	fullscreen_toggle.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	master_slider.value_changed.connect(_on_master_changed)
	$Panel/BackButton.pressed.connect(func():
		visible = false
		settings_closed.emit()
	)

func _on_fullscreen_toggled(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_master_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value))
