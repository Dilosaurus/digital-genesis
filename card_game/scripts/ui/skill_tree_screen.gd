extends Control

signal skill_tree_done

# ---------------------------------------------------------------------------
# Exported font refs — assigned in .tscn via @export
# ---------------------------------------------------------------------------
@export var _font_medieval: FontFile
@export var _font_mono: FontFile
@export var _font_body: FontFile

# ---------------------------------------------------------------------------
# Layout constants
# ---------------------------------------------------------------------------
const PANEL_W      := 860
const PANEL_H      := 590
const NODE_W       := 148
const NODE_H       := 56
const COL_SPACING  := 176.0
const ROW_SPACING  := 118.0
const TREE_OFFSET_X := 48.0
const TREE_OFFSET_Y := 86.0

# ---------------------------------------------------------------------------
# Node state colors
# ---------------------------------------------------------------------------
const COLOR_LOCKED_BG       := Color(0.10, 0.09, 0.16, 0.85)
const COLOR_LOCKED_BORDER    := Color(0.22, 0.20, 0.32, 0.60)
const COLOR_LOCKED_TEXT      := Color(0.38, 0.36, 0.48, 0.70)

const COLOR_AVAILABLE_BG     := Color(0.10, 0.14, 0.28, 0.95)
const COLOR_AVAILABLE_BORDER := Color(0.30, 0.55, 1.00, 0.90)
const COLOR_AVAILABLE_TEXT   := Color(0.55, 0.80, 1.00, 1.00)

const COLOR_UNLOCKED_BG      := Color(0.16, 0.14, 0.06, 0.95)
const COLOR_UNLOCKED_BORDER  := Color(0.85, 0.65, 0.10, 1.00)
const COLOR_UNLOCKED_TEXT    := Color(1.00, 0.88, 0.40, 1.00)

# Connection line colors
const COLOR_LINE_ACTIVE  := Color(0.85, 0.65, 0.10, 0.70)
const COLOR_LINE_AVAIL   := Color(0.35, 0.58, 1.00, 0.55)
const COLOR_LINE_INACTIVE := Color(0.22, 0.20, 0.32, 0.45)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var _run: RunState = null
var _panel: Panel = null
var _points_label: Label = null
var _tree_container: Control = null
var _node_buttons: Dictionary = {}   # node_id -> Button
var _tooltip_panel: PanelContainer = null
var _tooltip_name: Label = null
var _tooltip_desc: Label = null
var _tooltip_cost: Label = null
var _active_tree_id: String = "warrior"

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
func open_skill_tree() -> void:
	_run = GameManager.current_run
	if _run:
		var char_tree := SkillTreeSystem.get_tree(_run.character_id)
		if char_tree:
			_active_tree_id = _run.character_id
		else:
			_active_tree_id = "warrior"
	_build_ui()
	visible = true


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Full-screen dimmer
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.0, 0.0, 0.0, 0.78)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dimmer)


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null
	_node_buttons.clear()

	var viewport_size := get_viewport_rect().size

	# ── Main panel ────────────────────────────────────────────────────────
	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	_panel.position = Vector2(
		viewport_size.x / 2.0 - PANEL_W / 2.0,
		viewport_size.y / 2.0 - PANEL_H / 2.0
	)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.04, 0.12, 0.98)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.50, 0.40, 0.80, 0.90)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.corner_radius_bottom_left = 10
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	# ── Title ─────────────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "SKILL TREE"
	title.position = Vector2(0, 14)
	title.custom_minimum_size = Vector2(PANEL_W, 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font_medieval:
		title.add_theme_font_override("font", _font_medieval)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.45, 0.85, 1.00, 1.00))
	_panel.add_child(title)

	# Decorative underline
	var underline := ColorRect.new()
	underline.position = Vector2(30, 52)
	underline.size = Vector2(PANEL_W - 60, 2)
	underline.color = Color(0.45, 0.85, 1.00, 0.40)
	_panel.add_child(underline)

	# ── Skill points counter ───────────────────────────────────────────────
	_points_label = Label.new()
	_points_label.position = Vector2(PANEL_W - 200, 14)
	_points_label.custom_minimum_size = Vector2(188, 30)
	_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if _font_mono:
		_points_label.add_theme_font_override("font", _font_mono)
	_points_label.add_theme_font_size_override("font_size", 16)
	_points_label.add_theme_color_override("font_color", Color(0.50, 1.00, 0.60, 1.00))
	_panel.add_child(_points_label)
	_refresh_points_label()

	# ── Connection-line layer (drawn first, behind node buttons) ──────────
	var line_layer := _SkillLineLayer.new()
	line_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(line_layer)

	# ── Tree container ─────────────────────────────────────────────────────
	_tree_container = Control.new()
	_tree_container.position = Vector2(TREE_OFFSET_X, TREE_OFFSET_Y)
	_tree_container.custom_minimum_size = Vector2(
		PANEL_W - TREE_OFFSET_X * 2,
		PANEL_H - TREE_OFFSET_Y - 130
	)
	_panel.add_child(_tree_container)

	# ── Skill nodes ────────────────────────────────────────────────────────
	var tree := SkillTreeSystem.get_tree(_active_tree_id)
	var lines: Array = []
	if tree:
		for node in tree.nodes:
			_build_node_button(node)
		for node in tree.nodes:
			for prereq_id in node.prerequisites:
				var prereq_node := SkillTreeSystem.get_node(_active_tree_id, prereq_id)
				if prereq_node:
					var from_pos := _node_center(prereq_node) + _tree_container.position
					var to_pos   := _node_center(node)        + _tree_container.position
					var both_unlocked: bool = (node.id in _run.unlocked_skills) and (prereq_id in _run.unlocked_skills) if _run else false
					var prereq_unlocked: bool = (prereq_id in _run.unlocked_skills) if _run else false
					lines.append({
						"from": from_pos,
						"to": to_pos,
						"active": both_unlocked,
						"prereq_unlocked": prereq_unlocked,
					})
	line_layer.line_data = lines
	line_layer.queue_redraw()

	# ── Tooltip panel ──────────────────────────────────────────────────────
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.position = Vector2(14, PANEL_H - 112)
	_tooltip_panel.custom_minimum_size = Vector2(PANEL_W - 170, 80)
	var tt_style := StyleBoxFlat.new()
	tt_style.bg_color = Color(0.05, 0.03, 0.10, 0.95)
	tt_style.border_width_left = 1
	tt_style.border_width_top = 1
	tt_style.border_width_right = 1
	tt_style.border_width_bottom = 1
	tt_style.border_color = Color(0.38, 0.32, 0.58, 0.70)
	tt_style.corner_radius_top_left = 6
	tt_style.corner_radius_top_right = 6
	tt_style.corner_radius_bottom_right = 6
	tt_style.corner_radius_bottom_left = 6
	tt_style.content_margin_left = 12.0
	tt_style.content_margin_top = 8.0
	tt_style.content_margin_right = 12.0
	tt_style.content_margin_bottom = 8.0
	_tooltip_panel.add_theme_stylebox_override("panel", tt_style)
	_panel.add_child(_tooltip_panel)

	var tt_content := VBoxContainer.new()
	tt_content.add_theme_constant_override("separation", 3)
	_tooltip_panel.add_child(tt_content)

	_tooltip_name = Label.new()
	_tooltip_name.text = ""
	if _font_medieval:
		_tooltip_name.add_theme_font_override("font", _font_medieval)
	_tooltip_name.add_theme_font_size_override("font_size", 15)
	_tooltip_name.add_theme_color_override("font_color", Color(0.95, 0.88, 0.50, 1.00))
	tt_content.add_child(_tooltip_name)

	_tooltip_desc = Label.new()
	_tooltip_desc.text = "Hover a skill node to preview it."
	if _font_body:
		_tooltip_desc.add_theme_font_override("font", _font_body)
	_tooltip_desc.add_theme_font_size_override("font_size", 13)
	_tooltip_desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.82, 1.00))
	_tooltip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tt_content.add_child(_tooltip_desc)

	_tooltip_cost = Label.new()
	_tooltip_cost.text = ""
	if _font_mono:
		_tooltip_cost.add_theme_font_override("font", _font_mono)
	_tooltip_cost.add_theme_font_size_override("font_size", 11)
	_tooltip_cost.add_theme_color_override("font_color", Color(0.50, 0.90, 0.55, 1.00))
	tt_content.add_child(_tooltip_cost)

	# ── Done button ────────────────────────────────────────────────────────
	var done_btn := Button.new()
	done_btn.text = "Done"
	done_btn.custom_minimum_size = Vector2(140, 36)
	done_btn.position = Vector2(PANEL_W - 158, PANEL_H - 52)
	if _font_mono:
		done_btn.add_theme_font_override("font", _font_mono)
	done_btn.add_theme_font_size_override("font_size", 14)
	done_btn.pressed.connect(_on_done_pressed)
	_panel.add_child(done_btn)


# ---------------------------------------------------------------------------
# Node button creation & styling
# ---------------------------------------------------------------------------
func _build_node_button(node: SkillNodeData) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(NODE_W, NODE_H)
	var total_tiers: float = 3.0
	btn.position = Vector2(
		node.position.x * COL_SPACING,
		(total_tiers - node.position.y) * ROW_SPACING
	)
	btn.clip_text = false

	_style_node_button(btn, node)

	btn.mouse_entered.connect(_on_node_hover.bind(node))
	btn.mouse_exited.connect(_on_node_exit)
	btn.pressed.connect(_on_node_pressed.bind(node))

	_tree_container.add_child(btn)
	_node_buttons[node.id] = btn


func _style_node_button(btn: Button, node: SkillNodeData) -> void:
	if _run == null:
		return

	var is_unlocked: bool  = node.id in _run.unlocked_skills
	var is_available: bool = SkillTreeSystem.can_unlock(node.id, _run.unlocked_skills, _run.skill_points)

	# Build text
	var label_lines: Array[String] = [node.display_name]
	if is_unlocked:
		label_lines.append("✓ Unlocked")
	elif is_available:
		label_lines.append("Cost: %d pt" % node.cost)
	else:
		label_lines.append("Locked")
	btn.text = "\n".join(label_lines)

	# Pick color set
	var bg_color: Color
	var border_color: Color
	var text_color: Color

	if is_unlocked:
		bg_color     = COLOR_UNLOCKED_BG
		border_color = COLOR_UNLOCKED_BORDER
		text_color   = COLOR_UNLOCKED_TEXT
	elif is_available:
		bg_color     = COLOR_AVAILABLE_BG
		border_color = COLOR_AVAILABLE_BORDER
		text_color   = COLOR_AVAILABLE_TEXT
	else:
		bg_color     = COLOR_LOCKED_BG
		border_color = COLOR_LOCKED_BORDER
		text_color   = COLOR_LOCKED_TEXT

	# Normal style
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = bg_color
	sb_n.border_width_left = 2 if is_unlocked else 1
	sb_n.border_width_top = 2 if is_unlocked else 1
	sb_n.border_width_right = 2 if is_unlocked else 1
	sb_n.border_width_bottom = 2 if is_unlocked else 1
	sb_n.border_color = border_color
	sb_n.corner_radius_top_left = 6
	sb_n.corner_radius_top_right = 6
	sb_n.corner_radius_bottom_right = 6
	sb_n.corner_radius_bottom_left = 6
	sb_n.content_margin_left = 8.0
	sb_n.content_margin_top = 5.0
	sb_n.content_margin_right = 8.0
	sb_n.content_margin_bottom = 5.0
	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("pressed", sb_n)

	# Hover style (brighter border)
	var sb_h := sb_n.duplicate() as StyleBoxFlat
	sb_h.bg_color = bg_color.lightened(0.08)
	sb_h.border_color = border_color.lightened(0.15)
	sb_h.border_width_left = 2
	sb_h.border_width_top = 2
	sb_h.border_width_right = 2
	sb_h.border_width_bottom = 2
	btn.add_theme_stylebox_override("hover", sb_h)

	# Disabled style
	var sb_d := sb_n.duplicate() as StyleBoxFlat
	sb_d.bg_color = COLOR_LOCKED_BG
	sb_d.border_color = COLOR_LOCKED_BORDER
	btn.add_theme_stylebox_override("disabled", sb_d)

	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color.lightened(0.15))
	btn.add_theme_color_override("font_disabled_color", COLOR_LOCKED_TEXT)
	if _font_mono:
		btn.add_theme_font_override("font", _font_mono)
	btn.add_theme_font_size_override("font_size", 12)

	btn.disabled = is_unlocked or (not is_available)


func _node_center(node: SkillNodeData) -> Vector2:
	var total_tiers: float = 3.0
	return Vector2(
		node.position.x * COL_SPACING + NODE_W / 2.0,
		(total_tiers - node.position.y) * ROW_SPACING + NODE_H / 2.0
	)


func _refresh_points_label() -> void:
	if _run and _points_label:
		var pts: int = _run.skill_points
		_points_label.text = "◈  %d Skill Point%s" % [pts, "s" if pts != 1 else ""]
		_points_label.add_theme_color_override("font_color",
			Color(0.50, 1.00, 0.60, 1.00) if pts > 0 else Color(0.50, 0.50, 0.60, 0.80)
		)


# ---------------------------------------------------------------------------
# Interaction handlers
# ---------------------------------------------------------------------------
func _on_node_hover(node: SkillNodeData) -> void:
	if not _tooltip_name or not _tooltip_desc or not _tooltip_cost:
		return

	_tooltip_name.text = node.display_name

	var is_unlocked: bool  = _run != null and node.id in _run.unlocked_skills
	var is_available: bool = _run != null and SkillTreeSystem.can_unlock(node.id, _run.unlocked_skills, _run.skill_points)

	_tooltip_desc.text = node.description
	if node.prerequisites.size() > 0:
		_tooltip_desc.text += "\nRequires: " + ", ".join(node.prerequisites)

	if is_unlocked:
		_tooltip_cost.text = "✓  Already unlocked"
		_tooltip_cost.add_theme_color_override("font_color", COLOR_UNLOCKED_TEXT)
	elif is_available:
		_tooltip_cost.text = "Cost: %d skill point(s)  —  click to unlock" % node.cost
		_tooltip_cost.add_theme_color_override("font_color", Color(0.50, 0.90, 0.55, 1.00))
	else:
		var reason := "Prerequisites not met."
		if _run and _run.skill_points < node.cost:
			reason = "Not enough skill points (need %d)." % node.cost
		_tooltip_cost.text = reason
		_tooltip_cost.add_theme_color_override("font_color", Color(0.80, 0.40, 0.40, 1.00))


func _on_node_exit() -> void:
	if _tooltip_name:
		_tooltip_name.text = ""
	if _tooltip_desc:
		_tooltip_desc.text = "Hover a skill node to preview it."
	if _tooltip_cost:
		_tooltip_cost.text = ""


func _on_node_pressed(node: SkillNodeData) -> void:
	if _run == null:
		return
	if not SkillTreeSystem.can_unlock(node.id, _run.unlocked_skills, _run.skill_points):
		return

	var ok := SkillTreeSystem.unlock_node(_active_tree_id, node.id, _run)
	if ok:
		SFXManager.play_button_click()
		GameManager.save_run()
		_refresh_all_buttons()
		_refresh_points_label()
		# Rebuild line layer to update active-line colors
		_rebuild_line_layer()


func _refresh_all_buttons() -> void:
	var tree := SkillTreeSystem.get_tree(_active_tree_id)
	if not tree:
		return
	for node in tree.nodes:
		if _node_buttons.has(node.id):
			_style_node_button(_node_buttons[node.id], node)


func _rebuild_line_layer() -> void:
	# Find the existing _SkillLineLayer child and re-issue line data
	for child in _panel.get_children():
		if child is _SkillLineLayer:
			var lines: Array = []
			var tree := SkillTreeSystem.get_tree(_active_tree_id)
			if tree:
				for node in tree.nodes:
					for prereq_id in node.prerequisites:
						var prereq_node := SkillTreeSystem.get_node(_active_tree_id, prereq_id)
						if prereq_node:
							var from_pos := _node_center(prereq_node) + _tree_container.position
							var to_pos   := _node_center(node)        + _tree_container.position
							var both_unlocked := (node.id in _run.unlocked_skills) and (prereq_id in _run.unlocked_skills)
							var prereq_unlocked := (prereq_id in _run.unlocked_skills)
							lines.append({
								"from": from_pos,
								"to": to_pos,
								"active": both_unlocked,
								"prereq_unlocked": prereq_unlocked,
							})
			child.line_data = lines
			child.queue_redraw()
			break


func _on_done_pressed() -> void:
	SFXManager.play_button_click()
	visible = false
	skill_tree_done.emit()


# ---------------------------------------------------------------------------
# Inner class: connection-line drawing layer
# ---------------------------------------------------------------------------
class _SkillLineLayer extends Control:
	## Each entry: { "from": Vector2, "to": Vector2, "active": bool, "prereq_unlocked": bool }
	var line_data: Array = []

	func _draw() -> void:
		for seg in line_data:
			var color: Color
			if seg.get("active", false):
				color = Color(0.85, 0.65, 0.10, 0.75)   # gold — both ends unlocked
			elif seg.get("prereq_unlocked", false):
				color = Color(0.35, 0.58, 1.00, 0.60)   # blue — prereq done, dest not yet
			else:
				color = Color(0.22, 0.20, 0.32, 0.45)   # dim purple — locked path
			var width: float = 3.0 if seg.get("active", false) else 2.0
			draw_line(seg["from"], seg["to"], color, width)
