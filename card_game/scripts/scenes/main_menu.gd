extends Control

const SettingsScene = preload("res://scenes/settings/settings_screen.tscn")
var settings_screen = null

var _title_tween: Tween = null
var _scanline_offset: float = 0.0

func _ready() -> void:
	$VBox/PortInput.text = "9999"
	EventBus.player_connected.connect(_on_player_joined)

	var has_save = FileAccess.file_exists("user://save.json")
	if has_node("VBox/ContinueButton"):
		$VBox/ContinueButton.disabled = not has_save
		$VBox/ContinueButton.visible = has_save

	var args = OS.get_cmdline_user_args()
	if "--host" in args:
		_on_host_pressed.call_deferred()
	elif "--join" in args:
		_on_join_pressed.call_deferred()
	elif "--solo" in args:
		_on_solo_pressed.call_deferred()

	# Fade in on entry
	TransitionManager.fade_in(0.5)

	# Title glow pulse
	_start_title_glow()

	# Add hover animations to all buttons
	_setup_button_hover_effects()

func _start_title_glow() -> void:
	if _title_tween and _title_tween.is_valid():
		_title_tween.kill()
	var title = $VBox/TitleLabel
	_title_tween = create_tween().set_loops()
	_title_tween.tween_property(title, "modulate", Color(1.2, 1.4, 1.6, 1.0), 1.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_title_tween.tween_property(title, "modulate", Color(0.85, 1.0, 1.2, 1.0), 1.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _setup_button_hover_effects() -> void:
	for child in $VBox.get_children():
		if child is Button:
			child.mouse_entered.connect(_on_button_hover.bind(child))
			child.mouse_exited.connect(_on_button_unhover.bind(child))

func _on_button_hover(btn: Button) -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.12)
	tween.parallel().tween_property(btn, "modulate", Color(1.15, 1.1, 1.0), 0.12)

func _on_button_unhover(btn: Button) -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.12)
	tween.parallel().tween_property(btn, "modulate", Color.WHITE, 0.12)

func _process(delta: float) -> void:
	# Animate scan lines slowly scrolling
	_scanline_offset += delta * 30.0
	if _scanline_offset > 4.0:
		_scanline_offset -= 4.0
	if has_node("ScanLines"):
		$ScanLines.material.set_shader_parameter("scroll_offset", _scanline_offset)

func _on_host_pressed() -> void:
	var port = int($VBox/PortInput.text) if $VBox/PortInput.text.is_valid_int() else 9999
	var err = NetworkManager.host_game(port)
	if err == OK:
		$StatusLabel.text = "Hosting on port %d... waiting for player" % port
		$VBox/HostButton.disabled = true
		$VBox/JoinButton.disabled = true
		$VBox/StartButton.visible = true

func _on_join_pressed() -> void:
	var address = $VBox/AddressInput.text if $VBox/AddressInput.text != "" else "127.0.0.1"
	var port = int($VBox/PortInput.text) if $VBox/PortInput.text.is_valid_int() else 9999
	var err = NetworkManager.join_game(address, port)
	if err == OK:
		$StatusLabel.text = "Connecting to %s:%d..." % [address, port]
		$VBox/HostButton.disabled = true
		$VBox/JoinButton.disabled = true
		multiplayer.connected_to_server.connect(func():
			$StatusLabel.text = "Connected! Waiting for host to start..."
		)

func _on_solo_pressed() -> void:
	GameManager.start_new_run()
	TransitionManager.transition_to_scene("res://scenes/map/map_screen.tscn")

func _on_continue_pressed() -> void:
	if GameManager.load_saved_run():
		TransitionManager.transition_to_scene("res://scenes/map/map_screen.tscn")

func _on_settings_pressed() -> void:
	settings_screen = SettingsScene.instantiate()
	add_child(settings_screen)
	settings_screen.settings_closed.connect(func():
		settings_screen.queue_free()
		settings_screen = null
	)

func _on_start_pressed() -> void:
	if not NetworkManager.is_host:
		return
	_load_combat.rpc()

func _on_player_joined(_peer_id: int) -> void:
	var count = NetworkManager.connected_peers.size()
	$StatusLabel.text = "%d / 4 player(s) in lobby" % count
	if NetworkManager.is_host and count >= 2:
		$StatusLabel.text += " — Ready! Click Start (up to 4)."

@rpc("authority", "call_local", "reliable")
func _load_combat() -> void:
	TransitionManager.transition_to_scene("res://scenes/combat/combat_scene.tscn")
