extends Control
class_name StatusIcon

# Icon type constants
const TYPE_STRENGTH    = "strength"
const TYPE_DEXTERITY   = "dexterity"
const TYPE_VULNERABLE  = "vulnerable"
const TYPE_WEAK        = "weak"
const TYPE_CORRUPTION  = "corruption"
const TYPE_BLOCK       = "block"

# Visual config per type
const ICON_DATA = {
	"strength":   { "glyph": "⚔", "color": Color(0.2, 0.8, 0.3),    "label": "Strength",   "desc": "Deal %d extra damage per attack." },
	"dexterity":  { "glyph": "✦", "color": Color(0.2, 0.75, 0.9),   "label": "Dexterity",  "desc": "Gain %d extra Block per Defend card." },
	"vulnerable": { "glyph": "💥", "color": Color(0.9, 0.25, 0.25),  "label": "Vulnerable", "desc": "Take 50%% more damage. (%d turns)" },
	"weak":       { "glyph": "🔽", "color": Color(0.85, 0.55, 0.15), "label": "Weak",       "desc": "Deal 25%% less damage. (%d turns)" },
	"corruption": { "glyph": "🔥", "color": Color(0.7, 0.1, 0.8),   "label": "Corruption", "desc": "Corruption level: %d" },
	"block":      { "glyph": "🛡", "color": Color(0.35, 0.6, 1.0),   "label": "Block",      "desc": "Absorbs %d incoming damage." },
}

@onready var _bg: ColorRect = $Background
@onready var _glyph_label: Label = $GlyphLabel
@onready var _count_label: Label = $CountLabel
@onready var _tooltip_panel: Panel = $TooltipPanel
@onready var _tooltip_label: Label = $TooltipPanel/TooltipLabel

var _icon_type: String = ""
var _count: int = 0

func _ready() -> void:
	_tooltip_panel.visible = false
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup(icon_type: String, count: int) -> void:
	_icon_type = icon_type
	if not ICON_DATA.has(icon_type):
		push_warning("StatusIcon: unknown type '%s'" % icon_type)
		return

	var data = ICON_DATA[icon_type]
	_bg.color = data["color"].darkened(0.35)
	_glyph_label.text = data["glyph"]

	_count = count
	_update_count_label()
	visible = count > 0

	# Pop-in animation on first appearance
	if count > 0:
		_pop_in()

func update_count(count: int) -> void:
	var old_count = _count
	_count = count

	if count <= 0:
		_fade_out()
		return

	if not visible:
		visible = true
		_pop_in()
	elif old_count != count:
		_flash()

	_update_count_label()

func _update_count_label() -> void:
	if _count > 0:
		_count_label.text = str(_count)
		_count_label.visible = true
	else:
		_count_label.text = ""
		_count_label.visible = false

# ---------- animations ----------

func _pop_in() -> void:
	scale = Vector2(0.1, 0.1)
	modulate.a = 0.0
	var t = create_tween().set_parallel()
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "modulate:a", 1.0, 0.15)

func _flash() -> void:
	var t = create_tween()
	t.tween_property(self, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.08)
	t.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)

func _fade_out() -> void:
	var t = create_tween().set_parallel()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_property(self, "scale", Vector2(0.5, 0.5), 0.25).set_ease(Tween.EASE_IN)
	await t.finished
	visible = false
	scale = Vector2(1.0, 1.0)
	modulate.a = 1.0

# ---------- tooltip ----------

func _on_mouse_entered() -> void:
	if not ICON_DATA.has(_icon_type):
		return
	var data = ICON_DATA[_icon_type]
	_tooltip_label.text = "%s\n%s" % [data["label"], data["desc"] % _count]
	_tooltip_panel.visible = true

func _on_mouse_exited() -> void:
	_tooltip_panel.visible = false
