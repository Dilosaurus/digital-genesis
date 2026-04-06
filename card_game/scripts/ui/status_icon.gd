## status_icon.gd
## Displays a single status effect with stack count, duration bar, tooltip,
## buff/debuff border colouring, and an expiry pulse animation.
extends Control
class_name StatusIcon

# ---------------------------------------------------------------------------
# Icon type constants
# ---------------------------------------------------------------------------

const TYPE_STRENGTH    = "strength"
const TYPE_DEXTERITY   = "dexterity"
const TYPE_VULNERABLE  = "vulnerable"
const TYPE_WEAK        = "weak"
const TYPE_CORRUPTION  = "corruption"
const TYPE_BLOCK       = "block"

# is_buff: true = green/gold border, false = red/purple border
const ICON_DATA := {
	"strength":   { "glyph": "⚔",  "color": Color(0.20, 0.80, 0.30),  "label": "Strength",   "desc": "Deal +%d damage per attack.",         "is_buff": true  },
	"dexterity":  { "glyph": "✦",  "color": Color(0.20, 0.75, 0.90),  "label": "Dexterity",  "desc": "Gain +%d Block per Defend card.",      "is_buff": true  },
	"vulnerable": { "glyph": "💥", "color": Color(0.90, 0.25, 0.25),  "label": "Vulnerable", "desc": "Take 50%% more damage.  (%d turns)",   "is_buff": false },
	"weak":       { "glyph": "🔽", "color": Color(0.85, 0.55, 0.15),  "label": "Weak",       "desc": "Deal 25%% less damage.  (%d turns)",   "is_buff": false },
	"corruption": { "glyph": "🔥", "color": Color(0.70, 0.10, 0.80),  "label": "Corruption", "desc": "Corruption level: %d",                 "is_buff": false },
	"block":      { "glyph": "🛡", "color": Color(0.35, 0.60, 1.00),  "label": "Block",      "desc": "Absorbs %d incoming damage.",          "is_buff": true  },
}

# ---------------------------------------------------------------------------
# Cached style boxes (built once)
# ---------------------------------------------------------------------------

const _BUFF_BG    := Color(0.12, 0.18, 0.12, 1.0)
const _BUFF_BORDER := Color(0.30, 0.90, 0.35, 0.90)
const _DEBUFF_BG   := Color(0.18, 0.08, 0.08, 1.0)
const _DEBUFF_BORDER := Color(0.85, 0.15, 0.20, 0.90)

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

@onready var _icon_frame:    Panel  = $IconFrame
@onready var _glyph_label:   Label  = $GlyphLabel
@onready var _count_label:   Label  = $CountLabel
@onready var _dur_bar_bg:    Panel  = $DurBarBG
@onready var _dur_bar_fill:  Panel  = $DurBarBG/DurBarFill
@onready var _tooltip_panel: Panel  = $TooltipPanel
@onready var _tooltip_label: Label  = $TooltipPanel/TooltipLabel

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _icon_type:   String = ""
var _count:       int    = 0
var _duration:    int    = -1   # -1 = permanent / not shown
var _max_duration: int   = -1

var _pulse_tween: Tween  = null


func _ready() -> void:
	_tooltip_panel.visible = false
	_dur_bar_bg.visible    = false
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


# ---------------------------------------------------------------------------
# Public API — preserves original, extends with duration
# ---------------------------------------------------------------------------

## Full setup: type, stack count, optional duration tracking.
## duration <= 0 hides the duration bar.
func setup(icon_type: String, count: int, duration: int = -1, max_duration: int = -1) -> void:
	_icon_type    = icon_type
	_max_duration = max_duration if max_duration > 0 else duration

	if not ICON_DATA.has(icon_type):
		push_warning("StatusIcon: unknown type '%s'" % icon_type)
		return

	var data: Dictionary = ICON_DATA[icon_type]
	_glyph_label.text = data["glyph"]
	_apply_border_style(data["is_buff"] as bool)

	_count    = count
	_duration = duration
	_update_count_label()
	_update_dur_bar()
	visible = count > 0

	if count > 0:
		_pop_in()
		_update_expiry_pulse()


## Update stack count only (preserves duration).
func update_count(count: int) -> void:
	var old_count := _count
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
	_update_expiry_pulse()


## Update duration remaining (call each turn).
func update_duration(duration: int) -> void:
	_duration = duration
	_update_dur_bar()
	_update_expiry_pulse()


# ---------------------------------------------------------------------------
# Internal — visuals
# ---------------------------------------------------------------------------

func _apply_border_style(is_buff: bool) -> void:
	var style := StyleBoxFlat.new()
	if is_buff:
		style.bg_color     = _BUFF_BG
		style.border_color = _BUFF_BORDER
	else:
		style.bg_color     = _DEBUFF_BG
		style.border_color = _DEBUFF_BORDER
	style.border_width_left   = 2
	style.border_width_top    = 2
	style.border_width_right  = 2
	style.border_width_bottom = 2
	for r in ["corner_radius_top_left", "corner_radius_top_right",
			"corner_radius_bottom_right", "corner_radius_bottom_left"]:
		style.set(r, 5)
	_icon_frame.add_theme_stylebox_override("panel", style)


func _update_count_label() -> void:
	if _count > 0:
		_count_label.text    = str(_count)
		_count_label.visible = true
	else:
		_count_label.text    = ""
		_count_label.visible = false


func _update_dur_bar() -> void:
	if _duration <= 0 or _max_duration <= 0:
		_dur_bar_bg.visible = false
		return

	_dur_bar_bg.visible = true
	var ratio := clampf(float(_duration) / _max_duration, 0.0, 1.0)
	var bar_w := _dur_bar_bg.size.x * ratio
	_dur_bar_fill.size.x = maxf(bar_w, 1.0)

	# Colour the bar: green > orange > red as it drains
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(
		lerpf(0.20, 1.00, 1.0 - ratio),
		lerpf(0.90, 0.20, 1.0 - ratio),
		0.20, 0.85
	)
	for r in ["corner_radius_top_left", "corner_radius_top_right",
			"corner_radius_bottom_right", "corner_radius_bottom_left"]:
		fill_style.set(r, 2)
	_dur_bar_fill.add_theme_stylebox_override("panel", fill_style)


## Pulse when 1 turn remaining; stop pulse otherwise.
func _update_expiry_pulse() -> void:
	if _duration == 1:
		_start_pulse()
	else:
		_stop_pulse()


func _start_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		return  # already running
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "modulate", Color(1.5, 1.3, 0.6, 1.0), 0.45)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.45)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _stop_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null
	modulate = Color(1.0, 1.0, 1.0, modulate.a)


# ---------------------------------------------------------------------------
# Animations (preserve originals)
# ---------------------------------------------------------------------------

func _pop_in() -> void:
	scale      = Vector2(0.1, 0.1)
	modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(self, "scale",      Vector2(1.0, 1.0), 0.20)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "modulate:a", 1.0,               0.15)


func _flash() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.08)
	t.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)


func _fade_out() -> void:
	_stop_pulse()
	var t := create_tween().set_parallel()
	t.tween_property(self, "modulate:a", 0.0,               0.25)
	t.tween_property(self, "scale",      Vector2(0.5, 0.5), 0.25)\
		.set_ease(Tween.EASE_IN)
	await t.finished
	visible    = false
	scale      = Vector2(1.0, 1.0)
	modulate.a = 1.0


# ---------------------------------------------------------------------------
# Tooltip
# ---------------------------------------------------------------------------

func _on_mouse_entered() -> void:
	if not ICON_DATA.has(_icon_type):
		return
	var data: Dictionary = ICON_DATA[_icon_type]
	var body: String = str(data["desc"]) % _count
	var dur_text: String = ""
	if _duration > 0:
		dur_text = "\n[%d turn%s remaining]" % [_duration, "s" if _duration != 1 else ""]
	_tooltip_label.text = "%s\n%s%s" % [data["label"], body, dur_text]
	_tooltip_panel.visible = true


func _on_mouse_exited() -> void:
	_tooltip_panel.visible = false
