extends CanvasLayer

# Balance Dashboard — debug overlay toggled with F12
# Layer 100 ensures it renders above all game content
# Each tab is an empty VBoxContainer placeholder for population by content scripts

const BACKGROUND_COLOR := Color(0.12, 0.12, 0.15, 0.95)
const TITLE_BAR_COLOR := Color(0.08, 0.08, 0.10, 1.0)
const CLOSE_BUTTON_COLOR := Color(0.8, 0.2, 0.2, 1.0)
const CLOSE_BUTTON_HOVER_COLOR := Color(1.0, 0.3, 0.3, 1.0)
const MARGIN := 40

var _panel: PanelContainer
var _tab_container: TabContainer

# Publicly accessible tab container references
var pipeline_tab: VBoxContainer
var stack_tab: VBoxContainer
var cards_tab: VBoxContainer
var combat_tab: VBoxContainer
var simulate_tab: VBoxContainer
var run_tab: VBoxContainer

# Tab content instances (the actual interactive panels)
var _pipeline_content: PipelineTab
var _stack_content: StackTab
var _cards_content: CardsTab
var _combat_content: CombatTab
var _simulate_content: SimulateTab
var _run_content: RunTab

# Gallery overlay
var _gallery_panel: CardGalleryPanel

func _ready() -> void:
	layer = 100
	_build_ui()
	_populate_tabs()
	hide()

func _build_ui() -> void:
	# Root panel with dark semi-transparent background
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = MARGIN
	_panel.offset_top = MARGIN
	_panel.offset_right = -MARGIN
	_panel.offset_bottom = -MARGIN

	var style := StyleBoxFlat.new()
	style.bg_color = BACKGROUND_COLOR
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.4, 1.0)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	# Outer VBox: title bar + tab container
	var outer_vbox := VBoxContainer.new()
	outer_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(outer_vbox)

	# Title bar
	var title_bar := _build_title_bar()
	outer_vbox.add_child(title_bar)

	# Separator line beneath title bar
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.3, 0.3, 0.4, 1.0))
	outer_vbox.add_child(sep)

	# TabContainer
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_theme_color_override("font_selected_color", Color.WHITE)
	_tab_container.add_theme_color_override("font_unselected_color", Color(0.7, 0.7, 0.7, 1.0))
	outer_vbox.add_child(_tab_container)

	# Build tab pages
	pipeline_tab = _make_tab("PipelineTab")
	stack_tab    = _make_tab("StackTab")
	cards_tab    = _make_tab("CardsTab")
	combat_tab   = _make_tab("CombatTab")
	simulate_tab = _make_tab("SimulateTab")
	run_tab      = _make_tab("RunTab")

	var tab_pages: Array[Dictionary] = [
		{"label": "Pipeline", "node": pipeline_tab},
		{"label": "Stack",    "node": stack_tab},
		{"label": "Cards",    "node": cards_tab},
		{"label": "Combat",   "node": combat_tab},
		{"label": "Simulate", "node": simulate_tab},
		{"label": "Run",      "node": run_tab},
	]
	for entry in tab_pages:
		_tab_container.add_child(entry["node"])
		_tab_container.set_tab_title(
			_tab_container.get_tab_count() - 1,
			entry["label"]
		)

func _build_title_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 36)

	var title_style := StyleBoxFlat.new()
	title_style.bg_color = TITLE_BAR_COLOR
	title_style.content_margin_left = 12.0
	title_style.content_margin_right = 6.0
	title_style.content_margin_top = 4.0
	title_style.content_margin_bottom = 4.0
	title_style.corner_radius_top_left = 6
	title_style.corner_radius_top_right = 6

	var panel_wrap := PanelContainer.new()
	panel_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_wrap.add_theme_stylebox_override("panel", title_style)
	bar.add_child(panel_wrap)

	var inner_bar := HBoxContainer.new()
	panel_wrap.add_child(inner_bar)

	var title_label := Label.new()
	title_label.text = "Balance Dashboard"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_font_size_override("font_size", 16)
	inner_bar.add_child(title_label)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.flat = false

	var close_normal := StyleBoxFlat.new()
	close_normal.bg_color = CLOSE_BUTTON_COLOR
	close_normal.corner_radius_top_left = 4
	close_normal.corner_radius_top_right = 4
	close_normal.corner_radius_bottom_left = 4
	close_normal.corner_radius_bottom_right = 4
	close_btn.add_theme_stylebox_override("normal", close_normal)

	var close_hover := StyleBoxFlat.new()
	close_hover.bg_color = CLOSE_BUTTON_HOVER_COLOR
	close_hover.corner_radius_top_left = 4
	close_hover.corner_radius_top_right = 4
	close_hover.corner_radius_bottom_left = 4
	close_hover.corner_radius_bottom_right = 4
	close_btn.add_theme_stylebox_override("hover", close_hover)

	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.pressed.connect(_on_close_pressed)
	inner_bar.add_child(close_btn)

	return bar

func _make_tab(tab_name: String) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.name = tab_name
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Small padding so content scripts have breathing room
	vbox.add_theme_constant_override("separation", 8)
	return vbox

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12:
			_toggle_visibility()
			get_viewport().set_input_as_handled()

func _toggle_visibility() -> void:
	if visible:
		hide()
	else:
		show()

func _on_close_pressed() -> void:
	hide()

# --- Tab population ---

func _populate_tabs() -> void:
	_pipeline_content = PipelineTab.new()
	pipeline_tab.add_child(_pipeline_content)

	_stack_content = StackTab.new()
	stack_tab.add_child(_stack_content)

	_cards_content = CardsTab.new()
	cards_tab.add_child(_cards_content)

	_combat_content = CombatTab.new()
	combat_tab.add_child(_combat_content)

	_simulate_content = SimulateTab.new()
	simulate_tab.add_child(_simulate_content)

	_run_content = RunTab.new()
	run_tab.add_child(_run_content)
	_run_content.set_tracker(BalanceTracker)

	# Wire run state if available
	if GameManager.current_run != null:
		_run_content.set_run(GameManager.current_run)

	# Gallery overlay — covers the tab area when shown
	_gallery_panel = CardGalleryPanel.new()
	_gallery_panel.visible = false
	_panel.add_child(_gallery_panel)
	_gallery_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gallery_panel.offset_left = 8
	_gallery_panel.offset_top = 44  # below title bar
	_gallery_panel.offset_right = -8
	_gallery_panel.offset_bottom = -8
	_gallery_panel.z_index = 1

	_gallery_panel.back_pressed.connect(_on_gallery_back)
	_run_content.gallery_requested.connect(_show_gallery)
	_cards_content.gallery_requested.connect(_show_gallery)

# --- Public API ---

## Feed combat state into all tabs that need it.
## Call from combat_scene after engine initializes.
func set_combat_state(state: CombatState) -> void:
	# Use first player for modifier inspection tabs
	var player: PlayerState = null
	var target: EnemyState = null
	for peer_id in state.players:
		player = state.players[peer_id]
		break
	if not state.enemies.is_empty():
		target = state.enemies[0]

	if player:
		_pipeline_content.set_player(player)
		_stack_content.set_player(player)
		_cards_content.set_player(player)
		_simulate_content.set_player(player)
	if target:
		_pipeline_content.set_target(target)
		_cards_content.set_target(target)
		_simulate_content.set_target(target)

	_combat_content.set_combat_state(state)

	if GameManager.current_run != null:
		_run_content.set_run(GameManager.current_run)

func _show_gallery(card_ids: Array, title: String) -> void:
	_gallery_panel.show_cards(card_ids, title)

func _on_gallery_back() -> void:
	_gallery_panel.visible = false

## Show a specific tab by name. Valid names: Pipeline, Stack, Cards, Combat, Simulate, Run
func show_tab(tab_name: String) -> void:
	show()
	for i in _tab_container.get_tab_count():
		if _tab_container.get_tab_title(i) == tab_name:
			_tab_container.current_tab = i
			return

## Returns the VBoxContainer for the given tab name (for content scripts to populate).
func get_tab_container(tab_name: String) -> VBoxContainer:
	match tab_name:
		"Pipeline": return pipeline_tab
		"Stack":    return stack_tab
		"Cards":    return cards_tab
		"Combat":   return combat_tab
		"Simulate": return simulate_tab
		"Run":      return run_tab
	push_warning("BalanceDashboard: unknown tab name '%s'" % tab_name)
	return null
