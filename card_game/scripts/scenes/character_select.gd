extends Control

const ALL_CHARACTERS = ["netrunner", "sysadmin", "cryptomancer", "white_hat", "technomancer"]

var selected_id: String = ""
var _portraits: Dictionary = {}  # character_id -> PanelContainer (portrait thumbnail)
var _char_data_cache: Dictionary = {}  # character_id -> CharacterData

# Co-op: tracks which characters are taken by other peers
var _peer_selections: Dictionary = {}  # peer_id -> character_id
var _is_networked: bool = false

@onready var _character_art: TextureRect = %CharacterArt if has_node("%CharacterArt") else $MainContent/ArtContainer/CharacterArt
@onready var _name_label: Label = $MainContent/InfoPanel/InfoVBox/NameLabel
@onready var _title_label: Label = $MainContent/InfoPanel/InfoVBox/TitleLabel2
@onready var _hp_label: Label = $MainContent/InfoPanel/InfoVBox/StatsHBox/HPLabel
@onready var _energy_label: Label = $MainContent/InfoPanel/InfoVBox/StatsHBox/EnergyLabel
@onready var _passive_name: Label = $MainContent/InfoPanel/InfoVBox/PassiveName
@onready var _passive_desc: Label = $MainContent/InfoPanel/InfoVBox/PassiveDesc
@onready var _deck_list: Label = $MainContent/InfoPanel/InfoVBox/DeckList
@onready var _backstory_text: RichTextLabel = $MainContent/InfoPanel/InfoVBox/BackstoryText
@onready var _portrait_row: HBoxContainer = $BottomBar/PortraitRow
@onready var _confirm_btn: Button = $BottomBar/ConfirmButton

func _ready() -> void:
	_is_networked = multiplayer.has_multiplayer_peer() and multiplayer.get_unique_id() != 0
	_load_character_data()
	_build_portraits()
	_confirm_btn.visible = false
	_confirm_btn.pressed.connect(_on_confirm)
	$BackButton.pressed.connect(_on_back)
	# Auto-select first character
	_select(ALL_CHARACTERS[0])
	TransitionManager.fade_in(0.4)

func _load_character_data() -> void:
	for char_id in ALL_CHARACTERS:
		var data: CharacterData = load("res://data/characters/%s.tres" % char_id)
		if data:
			_char_data_cache[char_id] = data

func _build_portraits() -> void:
	for char_id in ALL_CHARACTERS:
		var data: CharacterData = _char_data_cache.get(char_id)
		if not data:
			continue

		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(120, 140)

		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.05, 0.14, 0.9)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.25, 0.25, 0.45, 0.5)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_right = 6
		style.corner_radius_bottom_left = 6
		style.content_margin_left = 4
		style.content_margin_top = 4
		style.content_margin_right = 4
		style.content_margin_bottom = 4
		panel.add_theme_stylebox_override("panel", style)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		panel.add_child(vbox)

		# Portrait image
		var portrait_tex = load("res://assets/characters/%s/portrait.png" % char_id)
		var portrait_img = TextureRect.new()
		portrait_img.texture = portrait_tex
		portrait_img.custom_minimum_size = Vector2(110, 100)
		portrait_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		vbox.add_child(portrait_img)

		# Character name under portrait
		var name_label = Label.new()
		name_label.text = data.display_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", data.color_primary)
		vbox.add_child(name_label)

		panel.gui_input.connect(_on_portrait_input.bind(char_id))
		panel.mouse_entered.connect(_on_portrait_hover.bind(char_id, true))
		panel.mouse_exited.connect(_on_portrait_hover.bind(char_id, false))

		_portrait_row.add_child(panel)
		_portraits[char_id] = panel

func _on_portrait_input(event: InputEvent, char_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_character_taken(char_id):
			return
		_select(char_id)
		if _is_networked:
			_rpc_broadcast_selection.rpc(multiplayer.get_unique_id(), char_id)

func _on_portrait_hover(char_id: String, entered: bool) -> void:
	var panel = _portraits.get(char_id)
	if not panel:
		return
	if char_id == selected_id:
		return
	if _is_character_taken(char_id):
		return
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if entered:
		tween.tween_property(panel, "scale", Vector2(1.08, 1.08), 0.12)
		panel.pivot_offset = panel.size / 2.0
	else:
		tween.tween_property(panel, "scale", Vector2.ONE, 0.12)

func _select(char_id: String) -> void:
	selected_id = char_id
	var data: CharacterData = _char_data_cache[char_id]

	# Update fullbody art with crossfade
	var fullbody_tex = load("res://assets/characters/%s/fullbody.png" % char_id)
	if fullbody_tex:
		_character_art.modulate.a = 0.0
		_character_art.texture = fullbody_tex
		var art_tween = create_tween().set_ease(Tween.EASE_OUT)
		art_tween.tween_property(_character_art, "modulate:a", 1.0, 0.25)

	# Update info panel
	_name_label.text = data.display_name
	_name_label.add_theme_color_override("font_color", data.color_primary)
	_title_label.text = data.title
	_hp_label.text = "%d HP" % data.starting_hp
	_energy_label.text = "%d Energy" % data.starting_energy
	_passive_name.text = data.passive_name
	_passive_desc.text = data.passive_description

	# Build deck list
	var card_counts: Dictionary = {}
	for card_id in data.starter_deck:
		card_counts[card_id] = card_counts.get(card_id, 0) + 1
	var deck_text = ""
	for card_id in card_counts:
		var cd = GameManager.get_card_data(card_id)
		var display = cd.display_name if cd else card_id
		if card_counts[card_id] > 1:
			deck_text += "%s x%d\n" % [display, card_counts[card_id]]
		else:
			deck_text += "%s\n" % display
	_deck_list.text = deck_text.strip_edges()

	# Show backstory
	_backstory_text.text = data.backstory

	# Update portrait highlights
	for cid in _portraits:
		var panel: PanelContainer = _portraits[cid]
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
		if cid == char_id:
			var cdata = _char_data_cache[cid]
			style.border_color = cdata.color_primary
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
			panel.modulate = Color.WHITE
			panel.scale = Vector2.ONE
			panel.pivot_offset = panel.size / 2.0
		elif _is_character_taken(cid):
			style.border_color = Color(0.5, 0.2, 0.2, 0.8)
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			panel.modulate = Color(0.4, 0.4, 0.45, 1.0)
			panel.scale = Vector2.ONE
		else:
			style.border_color = Color(0.25, 0.25, 0.45, 0.5)
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			panel.modulate = Color(0.65, 0.65, 0.7, 1.0)
			panel.scale = Vector2.ONE

	# Show confirm button
	_confirm_btn.visible = true
	_confirm_btn.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(_confirm_btn, "modulate:a", 1.0, 0.3)

func _is_character_taken(char_id: String) -> bool:
	if not _is_networked:
		return false
	var my_peer: int = multiplayer.get_unique_id()
	for peer_id in _peer_selections:
		if peer_id != my_peer and _peer_selections[peer_id] == char_id:
			return true
	return false

func _on_confirm() -> void:
	if selected_id == "":
		return
	GameManager.selected_character_id = selected_id
	LoreManager.unlock_entry("character", selected_id)

	if _is_networked:
		var my_peer: int = multiplayer.get_unique_id()
		GameManager.per_player_characters[my_peer] = selected_id
		_rpc_confirm_selection.rpc(my_peer, selected_id)

	GameManager.start_new_run()
	DungeonManager.start_run()
	TransitionManager.transition_to_scene("res://scenes/map/map_screen.tscn")

func _on_back() -> void:
	TransitionManager.transition_to_scene("res://scenes/main/main_menu.tscn")

# ---------------------------------------------------------------------------
# Co-op RPC methods
# ---------------------------------------------------------------------------
@rpc("any_peer", "call_remote", "reliable")
func _rpc_broadcast_selection(peer_id: int, char_id: String) -> void:
	_peer_selections[peer_id] = char_id
	_refresh_taken_visuals()

@rpc("any_peer", "call_remote", "reliable")
func _rpc_confirm_selection(peer_id: int, char_id: String) -> void:
	GameManager.per_player_characters[peer_id] = char_id
	_peer_selections[peer_id] = char_id
	_refresh_taken_visuals()

func _refresh_taken_visuals() -> void:
	for cid in _portraits:
		var panel: PanelContainer = _portraits[cid]
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
		if cid == selected_id:
			continue
		if _is_character_taken(cid):
			style.border_color = Color(0.5, 0.2, 0.2, 0.8)
			panel.modulate = Color(0.4, 0.4, 0.45, 1.0)
		else:
			style.border_color = Color(0.25, 0.25, 0.45, 0.5)
			panel.modulate = Color(0.65, 0.65, 0.7, 1.0)
