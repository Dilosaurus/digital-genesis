extends Control

# ---------------------------------------------------------------------------
# Scene preloads
# ---------------------------------------------------------------------------
const SettingsScene   = preload("res://scenes/settings/settings_screen.tscn")
const LoreCodexScene  = preload("res://scenes/ui/lore_codex_screen.tscn")

# ---------------------------------------------------------------------------
# Node shortcuts — resolved in _ready to avoid repeated $-lookups
# ---------------------------------------------------------------------------
@onready var _title_label      : Label         = $ContentRoot/MainColumn/TitleBlock/TitleLabel
@onready var _subtitle_label   : Label         = $ContentRoot/MainColumn/TitleBlock/SubtitleLabel
@onready var _separator        : TextureRect   = $ContentRoot/MainColumn/TitleBlock/TitleDivider
@onready var _menu_buttons     : VBoxContainer = $ContentRoot/MainColumn/MenuButtons
@onready var _new_run_btn      : Button        = $ContentRoot/MainColumn/MenuButtons/NewRunButton
@onready var _continue_btn     : Button        = $ContentRoot/MainColumn/MenuButtons/ContinueButton
@onready var _settings_btn     : Button        = $ContentRoot/MainColumn/MenuButtons/SettingsButton
@onready var _codex_btn        : Button        = $ContentRoot/MainColumn/MenuButtons/CodexButton
@onready var _quit_btn         : Button        = $ContentRoot/MainColumn/MenuButtons/QuitButton
@onready var _mp_btn           : Button        = $ContentRoot/MainColumn/MenuButtons/MultiplayerButton
@onready var _lobby_panel      : PanelContainer = $ContentRoot/MainColumn/LobbyPanel
@onready var _host_btn         : Button        = $ContentRoot/MainColumn/LobbyPanel/LobbyInner/LobbyButtonRow/HostButton
@onready var _join_btn         : Button        = $ContentRoot/MainColumn/LobbyPanel/LobbyInner/LobbyButtonRow/JoinButton
@onready var _start_btn        : Button        = $ContentRoot/MainColumn/LobbyPanel/LobbyInner/StartButton
@onready var _address_input    : LineEdit      = $ContentRoot/MainColumn/LobbyPanel/LobbyInner/AddressInput
@onready var _port_input       : LineEdit      = $ContentRoot/MainColumn/LobbyPanel/LobbyInner/PortInput
@onready var _status_label     : Label         = $StatusLabel
@onready var _scan_rect        : ColorRect     = $ScanLines

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------
var _title_tween      : Tween = null
var _separator_tween  : Tween = null
var _scanline_offset  : float = 0.0
var _lobby_visible    : bool  = false

var settings_screen = null
var codex_screen    = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_port_input.text = "9999"

	# Wire up lobby notifications
	EventBus.player_connected.connect(_on_player_joined)

	# Show Continue button only when a save exists
	var has_save := FileAccess.file_exists("user://save.json")
	_continue_btn.visible  = has_save
	_continue_btn.disabled = not has_save

	# Handle CLI launch flags (--host / --join / --solo)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--host" in args:
		_on_multiplayer_toggle_pressed()
		_on_host_pressed.call_deferred()
	elif "--join" in args:
		_on_multiplayer_toggle_pressed()
		_on_join_pressed.call_deferred()
	elif "--solo" in args:
		_on_solo_pressed.call_deferred()

	MusicManager.play("main_menu")
	# Start UI entrance animation, then run idle effects
	_animate_entrance()

func _process(delta: float) -> void:
	# Scroll scanlines
	_scanline_offset += delta * 28.0
	if _scanline_offset > 4.0:
		_scanline_offset -= 4.0
	_scan_rect.material.set_shader_parameter("scroll_offset", _scanline_offset)

# ---------------------------------------------------------------------------
# Entrance animation — staggered fade/slide-in
# ---------------------------------------------------------------------------

func _animate_entrance() -> void:
	# Everything starts invisible and slightly offset
	modulate.a = 0.0
	_title_label.modulate.a   = 0.0
	_subtitle_label.modulate.a = 0.0
	_separator.modulate.a     = 0.0

	for btn in _menu_buttons.get_children():
		btn.modulate.a = 0.0
		btn.position.x = -20.0

	# Fade in the whole scene first
	var scene_tween := create_tween()
	scene_tween.tween_property(self, "modulate:a", 1.0, 0.45).set_ease(Tween.EASE_OUT)

	# Then cascade the title elements
	var t := create_tween().set_parallel(false)
	t.tween_interval(0.3)
	t.tween_property(_title_label, "modulate:a", 1.0, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_interval(0.08)
	t.tween_property(_subtitle_label, "modulate:a", 1.0, 0.40).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.06)
	t.tween_property(_separator, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)

	# Stagger menu buttons sliding in from the left
	var delay := 0.65
	for btn in _menu_buttons.get_children():
		if not btn.visible:
			continue
		var btn_tween := create_tween().set_parallel(true)
		btn_tween.tween_property(btn, "modulate:a", 1.0, 0.30).set_delay(delay).set_ease(Tween.EASE_OUT)
		btn_tween.tween_property(btn, "position:x", 0.0, 0.30).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		delay += 0.06

	# After entrance, start the idle title glow and separator pulse
	await get_tree().create_timer(delay + 0.1).timeout
	_start_title_glow()
	_start_separator_pulse()
	_setup_button_hover_effects()

	# Trigger TransitionManager fade-in after entrance
	TransitionManager.fade_in(0.4)

# ---------------------------------------------------------------------------
# Idle ambient animations
# ---------------------------------------------------------------------------

func _start_title_glow() -> void:
	if _title_tween and _title_tween.is_valid():
		_title_tween.kill()
	_title_tween = create_tween().set_loops()
	_title_tween.tween_property(_title_label, "modulate",
		Color(1.25, 1.45, 1.65, 1.0), 2.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_title_tween.tween_property(_title_label, "modulate",
		Color(0.85, 0.95, 1.10, 1.0), 2.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _start_separator_pulse() -> void:
	if _separator_tween and _separator_tween.is_valid():
		_separator_tween.kill()
	_separator_tween = create_tween().set_loops()
	_separator_tween.tween_property(_separator, "modulate:a", 0.35, 1.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_separator_tween.tween_property(_separator, "modulate:a", 1.0, 1.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

# ---------------------------------------------------------------------------
# Button hover micro-animations
# ---------------------------------------------------------------------------

func _setup_button_hover_effects() -> void:
	for btn in _menu_buttons.get_children():
		if btn is Button:
			btn.mouse_entered.connect(_on_button_hover.bind(btn))
			btn.mouse_exited.connect(_on_button_unhover.bind(btn))
	# Also cover lobby buttons
	for btn in [_host_btn, _join_btn, _start_btn]:
		btn.mouse_entered.connect(_on_button_hover.bind(btn))
		btn.mouse_exited.connect(_on_button_unhover.bind(btn))

func _on_button_hover(btn: Button) -> void:
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.10)
	tw.parallel().tween_property(btn, "modulate", Color(1.12, 1.08, 1.05, 1.0), 0.10)

func _on_button_unhover(btn: Button) -> void:
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.14)
	tw.parallel().tween_property(btn, "modulate", Color.WHITE, 0.14)

# ---------------------------------------------------------------------------
# Button handlers — primary menu
# ---------------------------------------------------------------------------

func _on_solo_pressed() -> void:
	if not LoreManager.has_seen_intro():
		TransitionManager.transition_to_scene("res://scenes/intro/intro_screen.tscn")
	else:
		TransitionManager.transition_to_scene("res://scenes/character_select/character_select.tscn")

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

func _on_codex_pressed() -> void:
	codex_screen = LoreCodexScene.instantiate()
	add_child(codex_screen)
	codex_screen.show_codex()
	codex_screen.codex_closed.connect(func():
		codex_screen.queue_free()
		codex_screen = null
	)

func _on_quit_pressed() -> void:
	# Small fade-out before quitting feels polished
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	await tw.finished
	get_tree().quit()

# ---------------------------------------------------------------------------
# Multiplayer toggle
# ---------------------------------------------------------------------------

func _on_multiplayer_toggle_pressed() -> void:
	_lobby_visible = not _lobby_visible
	_lobby_panel.visible = _lobby_visible
	_mp_btn.text = "HIDE MULTIPLAYER" if _lobby_visible else "MULTIPLAYER"

	if _lobby_visible:
		# Slide the panel in
		_lobby_panel.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_lobby_panel, "modulate:a", 1.0, 0.22).set_ease(Tween.EASE_OUT)

# ---------------------------------------------------------------------------
# Multiplayer lobby handlers
# ---------------------------------------------------------------------------

func _on_host_pressed() -> void:
	var port: int = int(_port_input.text) if _port_input.text.is_valid_int() else 9999
	var err := NetworkManager.host_game(port)
	if err == OK:
		_status_label.text = "Hosting on port %d  —  waiting for player…" % port
		_host_btn.disabled = true
		_join_btn.disabled = true
		_start_btn.visible = true

func _on_join_pressed() -> void:
	var address: String = _address_input.text if _address_input.text != "" else "127.0.0.1"
	var port: int = int(_port_input.text) if _port_input.text.is_valid_int() else 9999
	var err     := NetworkManager.join_game(address, port)
	if err == OK:
		_status_label.text = "Connecting to %s:%d…" % [address, port]
		_host_btn.disabled = true
		_join_btn.disabled = true
		multiplayer.connected_to_server.connect(func():
			_status_label.text = "Connected!  Waiting for host to start…"
		)

func _on_start_pressed() -> void:
	if not NetworkManager.is_host:
		return
	_load_combat.rpc()

func _on_player_joined(_peer_id: int) -> void:
	var count := NetworkManager.connected_peers.size()
	_status_label.text = "%d / 4 player(s) in lobby" % count
	if NetworkManager.is_host and count >= 2:
		_status_label.text += "  —  Ready!  Click Start (up to 4)."

@rpc("authority", "call_local", "reliable")
func _load_combat() -> void:
	TransitionManager.transition_to_scene("res://scenes/combat/combat_scene.tscn")
