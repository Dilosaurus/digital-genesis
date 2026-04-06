## Summoning circle visual effect drawn entirely in code.
## Place as a child of a boss node at foot position. Call appear() to show,
## disappear() to dismiss, and pulse() for impact moments.
extends Node2D

const OUTER_RADIUS := 120.0
const INNER_RADIUS := 80.0
const CORE_RADIUS := 40.0
const POINT_COUNT := 6
const VERTEX_CIRCLE_RADIUS := 6.0

const COLOR_OUTER := Color(0.5, 0.3, 0.8, 0.8)
const COLOR_INNER := Color(0.7, 0.5, 1.0, 0.6)
const COLOR_CORE := Color(0.9, 0.7, 1.0, 0.4)
const COLOR_STAR := Color(0.6, 0.4, 0.9, 0.7)
const COLOR_VERTICES := Color(0.8, 0.6, 1.0, 0.5)

const ROTATION_SPEED := 0.5  ## rad/s

var _idle_tween: Tween
var _light: PointLight2D
var _base_energy := 1.5


func _ready() -> void:
	# Start invisible — caller uses appear() to show.
	modulate.a = 0.0
	scale = Vector2.ZERO

	_setup_light()
	_start_idle_pulse()


func _process(delta: float) -> void:
	rotation += ROTATION_SPEED * delta
	queue_redraw()


func _draw() -> void:
	# --- Rings ---
	draw_arc(Vector2.ZERO, OUTER_RADIUS, 0.0, TAU, 64, COLOR_OUTER, 2.0)
	draw_arc(Vector2.ZERO, INNER_RADIUS, 0.0, TAU, 48, COLOR_INNER, 1.5)
	draw_arc(Vector2.ZERO, CORE_RADIUS, 0.0, TAU, 32, COLOR_CORE, 1.0)

	# --- Hexagram (6-pointed star): two overlapping triangles ---
	var points: Array[Vector2] = []
	for i in POINT_COUNT:
		var angle := TAU * i / POINT_COUNT - PI / 2.0
		points.append(Vector2(cos(angle), sin(angle)) * OUTER_RADIUS)

	# Triangle A: indices 0, 2, 4
	draw_line(points[0], points[2], COLOR_STAR, 1.5)
	draw_line(points[2], points[4], COLOR_STAR, 1.5)
	draw_line(points[4], points[0], COLOR_STAR, 1.5)

	# Triangle B: indices 1, 3, 5
	draw_line(points[1], points[3], COLOR_STAR, 1.5)
	draw_line(points[3], points[5], COLOR_STAR, 1.5)
	draw_line(points[5], points[1], COLOR_STAR, 1.5)

	# --- Small circles at each vertex ---
	for pt in points:
		draw_arc(pt, VERTEX_CIRCLE_RADIUS, 0.0, TAU, 16, COLOR_VERTICES, 1.0)


# ---------- Light Setup ----------

func _setup_light() -> void:
	_light = PointLight2D.new()
	_light.color = Color(0.6, 0.3, 1.0)
	_light.energy = _base_energy
	_light.texture_scale = 4.0

	# Build a radial gradient texture so the light works without external files.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))

	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)

	_light.texture = tex
	add_child(_light)


# ---------- Idle Animation ----------

func _start_idle_pulse() -> void:
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(self, "scale", Vector2(1.05, 1.05), 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(self, "scale", Vector2(0.95, 0.95), 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Pause until appear() is called — scale is zero anyway, but keeps the
	# tween ready without fighting the appear animation.
	_idle_tween.pause()


# ---------- Public API ----------

## Scales and fades the circle into view.
func appear(duration: float = 0.3) -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2.ONE, duration) \
		.from(Vector2.ZERO) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, duration) \
		.from(0.0)
	# Once the appear finishes, start the idle pulse.
	tween.chain().tween_callback(_idle_tween.play)


## Shrinks and fades the circle, then frees it.
func disappear(duration: float = 0.4) -> void:
	if _idle_tween:
		_idle_tween.kill()
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2.ZERO, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(queue_free)


## Quick scale bounce for impact moments (e.g. when a summon lands).
func pulse() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Adjust overall visual intensity (0.0 = dim, 1.0 = full).
func set_intensity(level: float) -> void:
	level = clampf(level, 0.0, 1.0)
	modulate.a = level
	if _light:
		_light.energy = _base_energy * level
