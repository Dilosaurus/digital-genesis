## relic_display.gd
## HUD strip that shows collected relics as styled icon slots with rarity glow.
## On hover, a tooltip panel reveals the relic name and description.
## Empty placeholder slots maintain visual consistency.
extends Control

# ---------------------------------------------------------------------------
# Rarity constants (mirrors relic_data.gd)
# ---------------------------------------------------------------------------
const RARITY_COMMON    := 0
const RARITY_UNCOMMON  := 1
const RARITY_RARE      := 2
const RARITY_LEGENDARY := 3   # if present

# Glow border colours per rarity
const RARITY_GLOW := {
	RARITY_COMMON:   Color(0.60, 0.60, 0.65, 0.60),   # silver-grey
	RARITY_UNCOMMON: Color(0.25, 0.72, 0.40, 0.85),   # green
	RARITY_RARE:     Color(0.30, 0.55, 1.00, 0.90),   # blue
	RARITY_LEGENDARY:Color(1.00, 0.75, 0.15, 1.00),   # gold
}

# Rarity name strings for display
const RARITY_NAMES := {
	RARITY_COMMON:    "Common",
	RARITY_UNCOMMON:  "Uncommon",
	RARITY_RARE:      "Rare",
	RARITY_LEGENDARY: "Legendary",
}

const MAX_DISPLAY_SLOTS := 10   # visual cap; real relics can exceed this, extras wrap
const SLOT_SIZE := Vector2(36, 36)

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------
@onready var relic_container: HBoxContainer = $RelicContainer
@onready var tooltip_panel: Panel           = $RelicTooltip
@onready var tooltip_name: Label            = $RelicTooltip/TooltipName
@onready var tooltip_desc: RichTextLabel    = $RelicTooltip/TooltipDesc

# ---------------------------------------------------------------------------
# Public API — same signature as before; no callers need updating
# ---------------------------------------------------------------------------

func update_relics(relic_ids: Array) -> void:
	for child in relic_container.get_children():
		child.queue_free()
	tooltip_panel.visible = false

	# Build one slot per collected relic
	for rid in relic_ids:
		var relic = RelicSystem.get_relic(rid)
		if not relic:
			continue
		_add_relic_slot(relic)

	# Fill remaining slots with faded placeholders up to MAX_DISPLAY_SLOTS
	var filled := relic_ids.size()
	var empty_count: int = maxi(0, MAX_DISPLAY_SLOTS - filled)
	for _i in range(empty_count):
		_add_empty_slot()

# ---------------------------------------------------------------------------
# Slot builders
# ---------------------------------------------------------------------------

func _add_relic_slot(relic: Resource) -> void:
	var rarity: int = relic.rarity if "rarity" in relic else RARITY_COMMON
	var glow_color: Color = RARITY_GLOW.get(rarity, RARITY_GLOW[RARITY_COMMON])

	var container := _make_slot_container(glow_color, 1.0)
	container.custom_minimum_size = SLOT_SIZE

	var label := Label.new()
	label.text = _relic_abbrev(relic.display_name)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", glow_color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(label)

	# Hover connections — capture vars for the closure
	var tip_name: String = relic.display_name
	var tip_rarity: int  = rarity
	var tip_desc: String = relic.description if "description" in relic else ""

	container.mouse_entered.connect(
		func(): _show_relic_tooltip(container, tip_name, tip_rarity, tip_desc))
	container.mouse_exited.connect(func(): tooltip_panel.visible = false)

	relic_container.add_child(container)

func _add_empty_slot() -> void:
	var container := _make_slot_container(Color(0.25, 0.22, 0.38, 0.35), 0.35)
	container.custom_minimum_size = SLOT_SIZE
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	label.text = "·"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.30, 0.27, 0.45, 0.40))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(label)
	relic_container.add_child(container)

# ---------------------------------------------------------------------------
# Tooltip
# ---------------------------------------------------------------------------

func _show_relic_tooltip(slot: Control, name: String, rarity: int, desc: String) -> void:
	var rarity_color: Color = RARITY_GLOW.get(rarity, RARITY_GLOW[RARITY_COMMON])
	tooltip_name.text = name
	tooltip_name.add_theme_color_override("font_color", rarity_color)
	tooltip_desc.text = desc + "\n[color=#%s]%s[/color]" % [
		_color_to_hex(rarity_color),
		RARITY_NAMES.get(rarity, "Unknown"),
	]

	# Position tooltip above the slot
	var slot_global    := slot.get_global_rect()
	var self_global    := get_global_rect()
	var tip_size       := tooltip_panel.size

	var tx: float = slot_global.position.x - self_global.position.x
	var ty: float = slot_global.position.y - self_global.position.y - tip_size.y - 6.0

	# Keep within horizontal bounds
	var self_w: float = self_global.size.x
	tx = clamp(tx, 0.0, max(0.0, self_w - tip_size.x))
	# If above screen, flip below
	if slot_global.position.y - tip_size.y < 0.0:
		ty = slot_global.position.y - self_global.position.y + SLOT_SIZE.y + 4.0

	tooltip_panel.position = Vector2(tx, ty)
	tooltip_panel.visible  = true

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_slot_container(border_color: Color, alpha: float) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.08, 0.88 * alpha)
	style.set_border_width_all(2)
	style.border_color = Color(0.45, 0.38, 0.25, 0.8)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(2.0)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.10, 0.08, 0.06, alpha)
	hover_style.set_border_width_all(2)
	hover_style.border_color = Color(0.85, 0.70, 0.40, 1.0)
	hover_style.set_corner_radius_all(5)
	hover_style.set_content_margin_all(2.0)
	hover_style.shadow_color = Color(0.85, 0.70, 0.40, 0.45)
	hover_style.shadow_size  = 4

	var container := PanelContainer.new()
	container.add_theme_stylebox_override("panel", style)
	# Store hover style for script-driven highlight on mouse_entered
	container.set_meta("style_normal", style)
	container.set_meta("style_hover", hover_style)
	container.mouse_entered.connect(
		func(): container.add_theme_stylebox_override("panel",
			container.get_meta("style_hover")))
	container.mouse_exited.connect(
		func(): container.add_theme_stylebox_override("panel",
			container.get_meta("style_normal")))
	return container

func _relic_abbrev(name: String) -> String:
	# Build a short abbreviation from first letters of each word, max 3 chars
	var words := name.split(" ")
	var abbrev := ""
	for w in words:
		if w.length() > 0:
			abbrev += w[0].to_upper()
		if abbrev.length() >= 3:
			break
	return abbrev

func _color_to_hex(c: Color) -> String:
	return "%02X%02X%02X" % [
		int(c.r * 255),
		int(c.g * 255),
		int(c.b * 255),
	]
