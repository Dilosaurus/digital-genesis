extends Control

func _ready() -> void:
	$VBox/PortInput.text = "9999"
	EventBus.player_connected.connect(_on_player_joined)

	var args = OS.get_cmdline_user_args()
	if "--host" in args:
		_on_host_pressed.call_deferred()
	elif "--join" in args:
		_on_join_pressed.call_deferred()
	elif "--solo" in args:
		_on_solo_pressed.call_deferred()

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
		# Client waits for host to start the game
		multiplayer.connected_to_server.connect(func():
			$StatusLabel.text = "Connected! Waiting for host to start..."
		)

func _on_solo_pressed() -> void:
	GameManager.start_new_run()
	get_tree().change_scene_to_file("res://scenes/map/map_screen.tscn")

func _on_start_pressed() -> void:
	if not NetworkManager.is_host:
		return
	# Tell all clients to load the combat scene
	_load_combat.rpc()

func _on_player_joined(_peer_id: int) -> void:
	var count = NetworkManager.connected_peers.size()
	$StatusLabel.text = "%d / 4 player(s) in lobby" % count
	if NetworkManager.is_host and count >= 2:
		$StatusLabel.text += " — Ready! Click Start (up to 4)."

@rpc("authority", "call_local", "reliable")
func _load_combat() -> void:
	get_tree().change_scene_to_file("res://scenes/combat/combat_scene.tscn")
