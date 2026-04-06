## Dark shadowy tendrils that reach outward during summon animations.
##
## Place as a child of a puppet node at approximately the robe/waist area.
## Call emerge() to grow the tendrils outward, writhe() to start the idle
## animation loop, and retract() to pull them back in and stop.
##
## Usage:
##   tendrils.emerge(0.5)
##   tendrils.writhe()
##   # ... later ...
##   tendrils.retract(0.3)
extends Node2D

const DEFAULT_TENDRIL_COUNT := 5
const POINTS_PER_TENDRIL := 10
const BASE_WIDTH := 8.0
const TENDRIL_LENGTH := 100.0

const COLOR_TENDRIL := Color(0.15, 0.08, 0.2, 0.7)

## Base directions for tendrils — radiating from the lower body area.
## Down-left, left, down, right, down-right. Extra tendrils wrap around.
const BASE_DIRECTIONS: Array[Vector2] = [
	Vector2(-0.7, 0.7),   # down-left
	Vector2(-1.0, 0.2),   # left
	Vector2(-0.3, 0.9),   # down-center-left
	Vector2(1.0, 0.2),    # right
	Vector2(0.7, 0.7),    # down-right
	Vector2(0.0, 1.0),    # straight down
]

var _tendrils: Array[Line2D] = []

## Each tendril stores its base (non-animated) point positions.
var _tendril_base_points: Array[PackedVector2Array] = []

## Per-tendril random offsets for varied sine wave phases.
var _tendril_phase_offsets: PackedFloat32Array = []

var _writhing := false
var _time := 0.0

## 0.0 = fully retracted (all points at center), 1.0 = fully emerged.
var _emerge_progress := 0.0


func _ready() -> void:
	modulate.a = 0.0
	set_tendril_count(DEFAULT_TENDRIL_COUNT)


func _process(delta: float) -> void:
	if not _writhing:
		return

	_time += delta
	_animate_writhe()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Creates the Line2D children for [param count] tendrils.
func set_tendril_count(count: int) -> void:
	# Clear existing tendrils.
	for tendril in _tendrils:
		tendril.queue_free()
	_tendrils.clear()
	_tendril_base_points.clear()
	_tendril_phase_offsets.clear()

	var width_curve := _create_width_curve()

	for i in count:
		var line := Line2D.new()
		line.width = BASE_WIDTH
		line.width_curve = width_curve
		line.default_color = COLOR_TENDRIL
		line.antialiased = true
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND

		# Build the base (target) points along a direction.
		var direction: Vector2 = BASE_DIRECTIONS[i % BASE_DIRECTIONS.size()].normalized()
		# Add some angular spread so overlapping tendrils aren't identical.
		var angle_offset := randf_range(-0.3, 0.3)
		direction = direction.rotated(angle_offset)

		var base_points := PackedVector2Array()
		for p in POINTS_PER_TENDRIL:
			var t := float(p) / (POINTS_PER_TENDRIL - 1)
			# Slight outward curve using a quadratic ease.
			var dist := TENDRIL_LENGTH * t * t
			# Add a gentle lateral curve so they aren't perfectly straight.
			var lateral := sin(t * PI) * randf_range(8.0, 20.0)
			var perp := Vector2(-direction.y, direction.x)
			base_points.append(direction * dist + perp * lateral)

		# Initialize all points at center (retracted).
		var initial_points := PackedVector2Array()
		initial_points.resize(POINTS_PER_TENDRIL)
		initial_points.fill(Vector2.ZERO)
		line.points = initial_points

		add_child(line)
		_tendrils.append(line)
		_tendril_base_points.append(base_points)
		_tendril_phase_offsets.append(randf_range(0.0, TAU))


## Grows tendrils outward from center and fades in. Call writhe() after to
## start idle animation.
func emerge(duration: float = 0.5) -> void:
	_emerge_progress = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, duration * 0.5)
	tween.tween_method(_set_emerge_progress, 0.0, 1.0, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Starts the continuous writhing idle loop. Safe to call multiple times.
func writhe() -> void:
	_writhing = true


## Retracts tendrils back to center, fades out, and stops writhing.
func retract(duration: float = 0.3) -> void:
	_writhing = false
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 0.0, duration)
	tween.tween_method(_set_emerge_progress, _emerge_progress, 0.0, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

## Applies the emerge/retract interpolation — lerps every point between
## Vector2.ZERO and its target base position.
func _set_emerge_progress(progress: float) -> void:
	_emerge_progress = progress
	for i in _tendrils.size():
		var line: Line2D = _tendrils[i]
		var base_pts: PackedVector2Array = _tendril_base_points[i]
		for p in POINTS_PER_TENDRIL:
			var target: Vector2 = base_pts[p] * progress
			line.set_point_position(p, target)


## Called every frame while writhing. Adds sine-wave displacement to each
## point, with increasing amplitude further from the base.
func _animate_writhe() -> void:
	for i in _tendrils.size():
		var line: Line2D = _tendrils[i]
		var base_pts: PackedVector2Array = _tendril_base_points[i]
		var phase: float = _tendril_phase_offsets[i]

		for p in POINTS_PER_TENDRIL:
			var t := float(p) / (POINTS_PER_TENDRIL - 1)
			# Points further from base move more.
			var amplitude := t * 6.0
			var freq1 := 2.5 + float(i) * 0.4
			var freq2 := 3.0 + float(i) * 0.3
			var offset1 := phase + float(p) * 0.8
			var offset2 := phase * 1.3 + float(p) * 0.6

			var displacement := Vector2(
				sin(_time * freq1 + offset1) * amplitude,
				cos(_time * freq2 + offset2) * amplitude * 0.7,
			)

			var base_pos: Vector2 = base_pts[p] * _emerge_progress
			line.set_point_position(p, base_pos + displacement)


## Builds a Curve that tapers from full width at the base to zero at the tip.
func _create_width_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.3, 0.7))
	curve.add_point(Vector2(0.7, 0.3))
	curve.add_point(Vector2(1.0, 0.0))
	return curve
