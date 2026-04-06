extends Control

signal shrine_done

# How much corruption a shrine visit costs per corruption
const CORRUPTION_PER_USE := 10
# Max corruptions allowed per single shrine visit
const MAX_CORRUPTIONS_PER_VISIT := 2

# ── State ─────────────────────────────────────────────────────────────────────
var _corruptions_this_visit: int = 0
var _selected_card_id: String = ""

# ── Node references ───────────────────────────────────────────────────────────
@onready var corruption_label: Label = $Panel/CorruptionLabel
@onready var card_list: VBoxContainer = $Panel/CardListScroll/CardList
@onready var preview_panel: VBoxContainer = $Panel/PreviewPanel
@onready var preview_title: Label = $Panel/PreviewPanel/PreviewTitle
@onready var preview_desc: Label = $Panel/PreviewPanel/PreviewDesc
@onready var preview_cost: Label = $Panel/PreviewPanel/PreviewCost
@onready var confirm_btn: Button = $Panel/ConfirmButton
@onready var done_btn: Button = $Panel/DoneButton

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	visible = false
	confirm_btn.pressed.connect(_on_confirm_pressed)
	done_btn.pressed.connect(_on_done_pressed)

func open_shrine() -> void:
	_corruptions_this_visit = 0
	_selected_card_id = ""
	_build_ui()
	visible = true

# ── UI build ──────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var run := GameManager.current_run
	if not run:
		return

	var uses_left := MAX_CORRUPTIONS_PER_VISIT - _corruptions_this_visit
	var tier := CorruptionSystem._calculate_tier(run.run_corruption)

	corruption_label.text = "Corruption: %d / %d  (Tier %d)" % [
		run.run_corruption,
		run.max_corruption,
		tier,
	]
	if uses_left <= 0:
		corruption_label.text += "  — SHRINE EXPENDED"

	# Rebuild card list — show each unique card_id once
	for child in card_list.get_children():
		child.queue_free()

	var seen_ids: Array[String] = []
	for card_id in run.deck:
		if card_id in seen_ids:
			continue
		seen_ids.append(card_id)

		var card_data: CardData = GameManager.get_card_data(card_id)
		if not card_data:
			continue

		var is_already_shrine := CardCorruption.is_shrine_corrupted(card_id, run)
		var has_variant := CardCorruption.can_shrine_corrupt(card_id)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(580, 38)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var status_str: String
		if is_already_shrine:
			status_str = " [SHRINE CORRUPTED]"
		elif not has_variant:
			status_str = " [no shrine variant]"
		else:
			var sc: Dictionary = CardCorruption.get_shrine_corruption(card_id)
			status_str = "  ->  " + sc.get("preview", "???")

		btn.text = "[%d] %s%s" % [card_data.energy_cost, card_data.display_name, status_str]

		if is_already_shrine:
			btn.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
			btn.disabled = true
		elif not has_variant:
			btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			btn.disabled = true
		elif uses_left <= 0:
			btn.add_theme_color_override("font_color", Color(0.6, 0.5, 0.5))
			btn.disabled = true
		else:
			btn.add_theme_color_override("font_color", Color(0.9, 0.6, 0.8))
			btn.disabled = false
			btn.pressed.connect(_on_card_selected.bind(card_id))

		card_list.add_child(btn)

	_update_preview()
	_update_confirm_button()

# ── Card selection ─────────────────────────────────────────────────────────────
func _on_card_selected(card_id: String) -> void:
	_selected_card_id = card_id
	_update_preview()
	_update_confirm_button()

func _update_preview() -> void:
	if _selected_card_id == "":
		preview_panel.visible = false
		return

	var card_data := GameManager.get_card_data(_selected_card_id)
	if not card_data:
		preview_panel.visible = false
		return

	var sc := CardCorruption.get_shrine_corruption(_selected_card_id)
	if sc.is_empty():
		preview_panel.visible = false
		return

	preview_panel.visible = true
	preview_title.text = "%s  ->  %s" % [card_data.display_name, sc.get("display_name", "???")]
	preview_desc.text = sc.get("description", "")

	# Build upgrade/drawback summary lines
	var lines: PackedStringArray = []
	lines.append("Upgrades:")
	var upgrades: Dictionary = sc.get("upgrades", {})
	for field in upgrades.keys():
		var base_val = card_data.get(field)
		lines.append("  + %s: %s -> %s" % [field, str(base_val) if base_val != null else "0", str(upgrades[field])])
	var drawbacks: Dictionary = sc.get("drawbacks", {})
	if drawbacks.size() > 0:
		lines.append("Drawbacks:")
		for field in drawbacks.keys():
			lines.append("  - %s: %s" % [field, str(drawbacks[field])])
	lines.append("")
	lines.append("Cost: +%d Corruption" % CORRUPTION_PER_USE)
	preview_cost.text = "\n".join(lines)

func _update_confirm_button() -> void:
	var run := GameManager.current_run
	if not run:
		confirm_btn.disabled = true
		return
	var uses_left := MAX_CORRUPTIONS_PER_VISIT - _corruptions_this_visit
	var can_confirm: bool = (
		_selected_card_id != ""
		and uses_left > 0
		and CardCorruption.can_shrine_corrupt(_selected_card_id)
		and not CardCorruption.is_shrine_corrupted(_selected_card_id, run)
	)
	confirm_btn.disabled = not can_confirm

# ── Corruption action ─────────────────────────────────────────────────────────
func _on_confirm_pressed() -> void:
	if _selected_card_id == "":
		return
	var run := GameManager.current_run
	if not run:
		return
	if _corruptions_this_visit >= MAX_CORRUPTIONS_PER_VISIT:
		return
	if CardCorruption.is_shrine_corrupted(_selected_card_id, run):
		return

	# Permanently mark the card as shrine-corrupted in RunState
	var result := CardCorruption.apply_shrine_corruption(_selected_card_id, run)
	if result.is_empty():
		return

	# Add corruption to the run-level tracker
	run.run_corruption = mini(run.run_corruption + CORRUPTION_PER_USE, run.max_corruption)

	_corruptions_this_visit += 1
	_selected_card_id = ""

	SFXManager.play_button_click()
	GameManager.save_run()
	_build_ui()

func _on_done_pressed() -> void:
	visible = false
	shrine_done.emit()
