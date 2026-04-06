extends Node2D
## Tommy puppet controller — armored ninja ranger boss.
## Fast, flashy martial arts animations — kicks, spins, combat stances.

@onready var torso: Sprite2D = $Torso
@onready var head: Sprite2D = $Torso/Head
@onready var arm_l: Sprite2D = $Torso/ArmLeft
@onready var arm_r: Sprite2D = $Torso/ArmRight
@onready var leg_l: Sprite2D = $LegLeft
@onready var leg_r: Sprite2D = $LegRight
@onready var shin_l: Sprite2D = $LegLeft/ShinLeft
@onready var shin_r: Sprite2D = $LegRight/ShinRight
@onready var foot_l: Sprite2D = $LegLeft/ShinLeft/FootLeft
@onready var foot_r: Sprite2D = $LegRight/ShinRight/FootRight

var _idle_tween: Tween = null
var _current_anim: String = ""
var _active_tweens: Array[Tween] = []
var _rest_positions: Dictionary = {}  # Node -> Vector2

# VFX systems
var _effects: Node2D = null

signal animation_finished(anim_name: String)


func _ready() -> void:
	_capture_rest_positions()
	_setup_effects()
	play_idle()


func _capture_rest_positions() -> void:
	var nodes: Array = [torso, head, arm_l, arm_r,
		leg_l, leg_r, shin_l, shin_r, foot_l, foot_r]
	for node in nodes:
		if node:
			_rest_positions[node] = node.position


func _rest_pos(node: Node2D) -> Vector2:
	var pos: Vector2 = _rest_positions.get(node, node.position)
	return pos


func _setup_effects() -> void:
	var EffectsScript = load("res://scripts/enemies/tommy_effects.gd")
	if EffectsScript:
		_effects = Node2D.new()
		_effects.set_script(EffectsScript)
		add_child(_effects)


## Debug keys (remove for production):
## 1=idle  2=attack  3=hit  4=stagger  5=telegraph
## 6=cast  7=death   8=buff  9=taunt  0=summon

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	match event.keycode:
		KEY_1: play_idle()
		KEY_2: play_attack()
		KEY_3: play_hit()
		KEY_4: play_stagger()
		KEY_5: play_telegraph()
		KEY_6: play_cast()
		KEY_7: play_death()
		KEY_8: play_buff()
		KEY_9: play_taunt()
		KEY_0: play_summon()


# ── IDLE — fighting stance with weight shifting ───────────────────────────
func play_idle() -> void:
	_kill_current()
	_current_anim = "idle"
	_reset_pose(0.3)
	if _effects: _effects.reset()
	await get_tree().create_timer(0.35).timeout
	if _current_anim != "idle":
		return
	if not is_inside_tree():
		return
	_idle_loop()


func _idle_loop() -> void:
	if _current_anim != "idle" or not is_inside_tree():
		return
	var tp := _rest_pos(torso)

	# Core bob — low, coiled, ready to spring
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(torso, "position:y", tp.y - 6.0, 1.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_property(torso, "position:y", tp.y + 3.0, 1.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# Guard arms — left forward, right cocked back (fighting stance)
	var guard_l = create_tween().set_loops()
	guard_l.tween_property(arm_l, "rotation_degrees", -12.0, 1.3) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	guard_l.tween_property(arm_l, "rotation_degrees", -6.0, 1.3) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(guard_l)

	var guard_r = create_tween().set_loops()
	guard_r.tween_property(arm_r, "rotation_degrees", 8.0, 1.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	guard_r.tween_property(arm_r, "rotation_degrees", 14.0, 1.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(guard_r)

	# Head — slow tracking, like watching the opponent
	var head_tw = create_tween().set_loops()
	head_tw.tween_property(head, "rotation_degrees", -4.0, 3.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	head_tw.tween_interval(0.4)
	head_tw.tween_property(head, "rotation_degrees", 4.0, 3.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	head_tw.tween_interval(0.6)
	_active_tweens.append(head_tw)

	# Legs — alternating weight shift, like bouncing on balls of feet
	var bounce_l = create_tween().set_loops()
	bounce_l.tween_property(leg_l, "rotation_degrees", -2.0, 0.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bounce_l.tween_property(leg_l, "rotation_degrees", 2.0, 0.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(bounce_l)

	var bounce_r = create_tween().set_loops()
	bounce_r.tween_property(leg_r, "rotation_degrees", 2.0, 0.9) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bounce_r.tween_property(leg_r, "rotation_degrees", -2.0, 0.9) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(bounce_r)

	# Shins — slight flex, coiled energy
	var shin_tw = create_tween().set_loops()
	shin_tw.tween_property(shin_l, "rotation_degrees", 3.0, 1.1) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	shin_tw.tween_property(shin_l, "rotation_degrees", -1.0, 1.1) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(shin_tw)


# ── ATTACK — spinning backfist combo ──────────────────────────────────────
func play_attack() -> void:
	_kill_current()
	_current_anim = "attack"
	if _effects: _effects.intensify()
	SFXManager.play_boss_attack_telegraph()
	var tp := _rest_pos(torso)

	# 1. Chamber — coil back, drop low
	var t1 = create_tween()
	t1.set_parallel()
	t1.tween_property(torso, "rotation_degrees", -15.0, 0.1)
	t1.tween_property(torso, "position:y", tp.y + 8.0, 0.1)
	t1.tween_property(arm_r, "rotation_degrees", 45.0, 0.1)
	t1.tween_property(arm_l, "rotation_degrees", -20.0, 0.08)
	t1.tween_property(leg_l, "rotation_degrees", -8.0, 0.1)
	t1.tween_property(shin_l, "rotation_degrees", 12.0, 0.1)
	t1.tween_property(head, "rotation_degrees", -8.0, 0.08)
	await t1.finished

	# 2. Spin through — full body rotation with trailing arm
	var t2 = create_tween()
	t2.set_parallel()
	t2.tween_property(torso, "rotation_degrees", 20.0, 0.06) \
		.set_trans(Tween.TRANS_BACK)
	t2.tween_property(torso, "position:y", tp.y - 25.0, 0.06)
	t2.tween_property(arm_r, "rotation_degrees", -50.0, 0.06)
	t2.tween_property(arm_l, "rotation_degrees", 35.0, 0.06)
	t2.tween_property(head, "rotation_degrees", 12.0, 0.05)
	t2.tween_property(leg_l, "rotation_degrees", 10.0, 0.06)
	t2.tween_property(leg_r, "rotation_degrees", -6.0, 0.06)
	t2.tween_property(shin_l, "rotation_degrees", -8.0, 0.05)
	await t2.finished

	# 3. Impact freeze frame
	ScreenShake.shake_heavy()
	SFXManager.play_boss_attack_impact()
	modulate = Color(2.0, 2.5, 2.0, 1.0)  # green-white flash
	await get_tree().create_timer(0.08).timeout
	modulate = Color(1.0, 1.0, 1.0, 1.0)

	# 4. Follow-through — overshoot then settle
	var t3 = create_tween()
	t3.set_parallel()
	t3.tween_property(torso, "rotation_degrees", 8.0, 0.08)
	t3.tween_property(arm_r, "rotation_degrees", -20.0, 0.1)
	t3.tween_property(arm_l, "rotation_degrees", 15.0, 0.1)
	await t3.finished

	_reset_pose(0.3)
	await get_tree().create_timer(0.35).timeout
	animation_finished.emit("attack")
	play_idle()


# ── HIT — absorb and counter-stance ──────────────────────────────────────
func play_hit() -> void:
	_kill_current()
	_current_anim = "hit"
	ScreenShake.shake_light()
	SFXManager.play_boss_hit()
	var tp := _rest_pos(torso)

	modulate = Color(3.0, 3.0, 3.0, 1.0)

	# Snap back — martial recoil, arms guard up
	var t = create_tween()
	t.set_parallel()
	t.tween_property(torso, "rotation_degrees", -10.0, 0.04)
	t.tween_property(torso, "position:x", tp.x + 15.0, 0.04)
	t.tween_property(torso, "position:y", tp.y + 5.0, 0.04)
	t.tween_property(head, "rotation_degrees", -12.0, 0.03)
	t.tween_property(arm_l, "rotation_degrees", -25.0, 0.04)  # guard snaps up
	t.tween_property(arm_r, "rotation_degrees", 20.0, 0.04)
	t.tween_property(leg_r, "rotation_degrees", 5.0, 0.04)
	await t.finished

	modulate = Color(1.0, 1.0, 1.0, 1.0)

	# Quick recovery — snap into counter-ready stance
	var t2 = create_tween()
	t2.set_parallel()
	t2.tween_property(torso, "rotation_degrees", 4.0, 0.06)
	t2.tween_property(torso, "position:x", tp.x - 3.0, 0.06)
	t2.tween_property(head, "rotation_degrees", 5.0, 0.05)
	t2.tween_property(arm_l, "rotation_degrees", -15.0, 0.06)
	await t2.finished

	# Settle
	var t3 = create_tween()
	t3.set_parallel()
	t3.tween_property(torso, "rotation_degrees", 0.0, 0.1)
	t3.tween_property(torso, "position", tp, 0.1)
	t3.tween_property(head, "rotation_degrees", 0.0, 0.1)
	t3.tween_property(arm_l, "rotation_degrees", 0.0, 0.1)
	t3.tween_property(arm_r, "rotation_degrees", 0.0, 0.1)
	t3.tween_property(leg_r, "rotation_degrees", 0.0, 0.1)
	await t3.finished

	animation_finished.emit("hit")
	play_idle()


# ── STAGGER — broken stance, barely recovering ───────────────────────────
func play_stagger() -> void:
	_kill_current()
	_current_anim = "stagger"
	ScreenShake.shake(15.0, 0.4)
	SFXManager.play_boss_stagger()
	var tp := _rest_pos(torso)

	# Big hit — crumple
	modulate = Color(4.0, 2.0, 2.0, 1.0)
	var t = create_tween()
	t.set_parallel()
	t.tween_property(torso, "rotation_degrees", -18.0, 0.04)
	t.tween_property(torso, "position", tp + Vector2(25, 30), 0.04)
	t.tween_property(head, "rotation_degrees", -25.0, 0.03)
	t.tween_property(arm_l, "rotation_degrees", 30.0, 0.04)
	t.tween_property(arm_r, "rotation_degrees", -20.0, 0.04)
	t.tween_property(leg_l, "rotation_degrees", -8.0, 0.04)
	t.tween_property(leg_r, "rotation_degrees", 10.0, 0.04)
	t.tween_property(shin_l, "rotation_degrees", 15.0, 0.04)
	t.tween_property(shin_r, "rotation_degrees", -10.0, 0.04)
	await t.finished

	modulate = Color(1.0, 1.0, 1.0, 1.0)

	# Stumble — trying to regain footing
	for i in 3:
		var intensity = 1.0 - (i * 0.3)
		var w1 = create_tween()
		w1.set_parallel()
		w1.tween_property(torso, "rotation_degrees", 8.0 * intensity, 0.1)
		w1.tween_property(torso, "position:x", tp.x - 10.0 * intensity, 0.1)
		w1.tween_property(head, "rotation_degrees", 10.0 * intensity, 0.08)
		w1.tween_property(shin_l, "rotation_degrees", -5.0 * intensity, 0.1)
		await w1.finished

		var w2 = create_tween()
		w2.set_parallel()
		w2.tween_property(torso, "rotation_degrees", -5.0 * intensity, 0.1)
		w2.tween_property(torso, "position:x", tp.x + 5.0 * intensity, 0.1)
		w2.tween_property(head, "rotation_degrees", -6.0 * intensity, 0.08)
		await w2.finished

	_reset_pose(0.25)
	await get_tree().create_timer(0.3).timeout
	animation_finished.emit("stagger")
	play_idle()


# ── TELEGRAPH — crane stance, one leg raised ──────────────────────────────
func play_telegraph() -> void:
	_kill_current()
	_current_anim = "telegraph"
	SFXManager.play_boss_telegraph()
	var tp := _rest_pos(torso)

	# Rise into crane stance — one leg lifts, arms in guard
	var t = create_tween()
	t.set_parallel()
	t.tween_property(torso, "position:y", tp.y - 20.0, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(torso, "rotation_degrees", 5.0, 0.25)
	t.tween_property(arm_l, "rotation_degrees", -35.0, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(arm_r, "rotation_degrees", 15.0, 0.25)
	t.tween_property(leg_r, "rotation_degrees", -20.0, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(shin_r, "rotation_degrees", 30.0, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(head, "rotation_degrees", -5.0, 0.2)
	await t.finished

	# Hold — menacing stillness with slight energy pulse
	var pulse = create_tween().set_loops(3)
	pulse.tween_property(self, "modulate", Color(0.9, 1.3, 0.9, 1.0), 0.2) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# Subtle sway while holding the pose
	var sway = create_tween().set_loops(3)
	sway.tween_property(torso, "position:y", tp.y - 22.0, 0.4) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	sway.tween_property(torso, "position:y", tp.y - 18.0, 0.4) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await pulse.finished

	animation_finished.emit("telegraph")
	play_idle()


# ── CAST — cross-arm power channel, then release ─────────────────────────
func play_cast() -> void:
	_kill_current()
	_current_anim = "cast"
	if _effects: _effects.intensify()
	SFXManager.play_boss_cast()
	var tp := _rest_pos(torso)

	# Arms cross over chest — channeling through the gem
	var t = create_tween()
	t.set_parallel()
	t.tween_property(arm_l, "rotation_degrees", 25.0, 0.2)
	t.tween_property(arm_r, "rotation_degrees", -25.0, 0.2)
	t.tween_property(torso, "position:y", tp.y - 10.0, 0.2)
	t.tween_property(head, "rotation_degrees", -10.0, 0.15)
	t.tween_property(leg_l, "rotation_degrees", -3.0, 0.2)
	t.tween_property(leg_r, "rotation_degrees", 3.0, 0.2)
	await t.finished

	# Energy builds — vibration + green pulses
	var tremble = create_tween().set_loops(8)
	tremble.tween_property(torso, "rotation_degrees", 2.0, 0.03)
	tremble.tween_property(torso, "rotation_degrees", -2.0, 0.03)
	var glow = create_tween().set_loops(3)
	glow.tween_property(self, "modulate", Color(0.5, 2.0, 0.5, 1.0), 0.1)
	glow.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)
	await tremble.finished

	# RELEASE — arms explode outward, scale burst
	var t2 = create_tween()
	t2.set_parallel()
	t2.tween_property(arm_l, "rotation_degrees", -45.0, 0.06) \
		.set_trans(Tween.TRANS_BACK)
	t2.tween_property(arm_r, "rotation_degrees", 45.0, 0.06) \
		.set_trans(Tween.TRANS_BACK)
	t2.tween_property(torso, "position:y", tp.y + 5.0, 0.08)
	t2.tween_property(torso, "rotation_degrees", 0.0, 0.06)
	t2.tween_property(head, "rotation_degrees", 5.0, 0.05)
	t2.tween_property(self, "scale", Vector2(0.92, 0.92), 0.06)
	await t2.finished

	ScreenShake.shake()
	modulate = Color(1.5, 2.0, 1.5, 1.0)
	await get_tree().create_timer(0.08).timeout
	modulate = Color(1.0, 1.0, 1.0, 1.0)

	var t3 = create_tween()
	t3.tween_property(self, "scale", Vector2(0.85, 0.85), 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	await t3.finished

	animation_finished.emit("cast")
	play_idle()


# ── DEATH — dramatic knee drop ───────────────────────────────────────────
func play_death() -> void:
	_kill_current()
	_current_anim = "death"
	if _effects: _effects.dim()
	ScreenShake.shake_heavy()
	SFXManager.play_boss_death()
	var tp := _rest_pos(torso)

	# 1. Seize up — last flash of power
	modulate = Color(2.5, 3.0, 2.5, 1.0)
	var t0 = create_tween()
	t0.set_parallel()
	t0.tween_property(torso, "position:y", tp.y - 15.0, 0.1)
	t0.tween_property(arm_l, "rotation_degrees", -30.0, 0.1)
	t0.tween_property(arm_r, "rotation_degrees", 30.0, 0.1)
	await t0.finished
	modulate = Color(1.0, 1.0, 1.0, 1.0)

	# 2. Drop to knees — legs buckle
	var t = create_tween()
	t.set_parallel()
	t.tween_property(torso, "position:y", tp.y + 50.0, 0.4) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_property(torso, "rotation_degrees", 12.0, 0.4)
	t.tween_property(arm_l, "rotation_degrees", 20.0, 0.35)
	t.tween_property(arm_r, "rotation_degrees", -15.0, 0.35)
	t.tween_property(head, "rotation_degrees", 25.0, 0.4)
	t.tween_property(leg_l, "rotation_degrees", -15.0, 0.35)
	t.tween_property(leg_r, "rotation_degrees", 10.0, 0.35)
	t.tween_property(shin_l, "rotation_degrees", 25.0, 0.35)
	t.tween_property(shin_r, "rotation_degrees", -20.0, 0.35)
	await t.finished

	# 3. Hold the kneeling pose... then collapse
	await get_tree().create_timer(0.3).timeout

	var t2 = create_tween()
	t2.set_parallel()
	t2.tween_property(torso, "position:y", tp.y + 90.0, 0.4)
	t2.tween_property(torso, "rotation_degrees", 25.0, 0.4)
	t2.tween_property(head, "rotation_degrees", 35.0, 0.3)
	t2.tween_property(self, "modulate:a", 0.0, 0.8)
	t2.tween_property(arm_l, "rotation_degrees", 35.0, 0.4)
	t2.tween_property(arm_r, "rotation_degrees", -30.0, 0.4)
	await t2.finished

	animation_finished.emit("death")


# ── BUFF — kata power-up sequence ────────────────────────────────────────
func play_buff() -> void:
	_kill_current()
	_current_anim = "buff"
	if _effects: _effects.intensify()
	SFXManager.play_boss_buff()
	var tp := _rest_pos(torso)

	# Kata opening — low horse stance
	var t = create_tween()
	t.set_parallel()
	t.tween_property(torso, "position:y", tp.y + 10.0, 0.2)
	t.tween_property(leg_l, "rotation_degrees", -10.0, 0.2)
	t.tween_property(leg_r, "rotation_degrees", 10.0, 0.2)
	t.tween_property(arm_l, "rotation_degrees", -20.0, 0.2)
	t.tween_property(arm_r, "rotation_degrees", 20.0, 0.2)
	await t.finished

	# Rising power — straighten up with arms in
	var t2 = create_tween()
	t2.set_parallel()
	t2.tween_property(torso, "position:y", tp.y - 25.0, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t2.tween_property(arm_l, "rotation_degrees", 15.0, 0.25)  # arms pull in tight
	t2.tween_property(arm_r, "rotation_degrees", -15.0, 0.25)
	t2.tween_property(leg_l, "rotation_degrees", 0.0, 0.25)
	t2.tween_property(leg_r, "rotation_degrees", 0.0, 0.25)
	t2.tween_property(head, "rotation_degrees", -8.0, 0.2)
	await t2.finished

	# Green energy burst — scale pop + color
	var glow = create_tween().set_loops(3)
	glow.tween_property(self, "modulate", Color(0.5, 2.0, 0.5, 1.0), 0.1)
	glow.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)
	var pop = create_tween().set_loops(3)
	pop.tween_property(self, "scale", Vector2(0.88, 0.88), 0.1) \
		.set_trans(Tween.TRANS_BACK)
	pop.tween_property(self, "scale", Vector2(0.85, 0.85), 0.1)
	await glow.finished

	animation_finished.emit("buff")
	play_idle()


# ── TAUNT — beckoning combat stance ──────────────────────────────────────
func play_taunt() -> void:
	_kill_current()
	_current_anim = "taunt"
	SFXManager.play_boss_taunt()
	var tp := _rest_pos(torso)

	# Drop into aggressive forward stance
	var t = create_tween()
	t.set_parallel()
	t.tween_property(torso, "rotation_degrees", 10.0, 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(torso, "position:y", tp.y + 8.0, 0.15)
	t.tween_property(arm_l, "rotation_degrees", -30.0, 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(arm_r, "rotation_degrees", 5.0, 0.12)
	t.tween_property(head, "rotation_degrees", 10.0, 0.12)
	t.tween_property(leg_l, "rotation_degrees", -5.0, 0.15)
	t.tween_property(shin_l, "rotation_degrees", 8.0, 0.15)
	await t.finished

	# "Come on" — rapid beckoning with lead hand
	var beckon = create_tween()
	for i in 4:
		beckon.tween_property(arm_l, "rotation_degrees", -15.0, 0.06) \
			.set_trans(Tween.TRANS_BACK)
		beckon.tween_property(arm_l, "rotation_degrees", -30.0, 0.08)
	await beckon.finished

	# Head nod — cocky
	var nod = create_tween()
	nod.tween_property(head, "rotation_degrees", 15.0, 0.08)
	nod.tween_property(head, "rotation_degrees", 8.0, 0.1)
	await nod.finished

	await get_tree().create_timer(0.15).timeout
	animation_finished.emit("taunt")
	play_idle()


# ── SUMMON — ground slam, calling allies ──────────────────────────────────
func play_summon() -> void:
	_kill_current()
	_current_anim = "summon"
	if _effects: _effects.intensify()
	SFXManager.play_boss_summon()
	var tp := _rest_pos(torso)

	# Jump up — coil and spring
	var t = create_tween()
	t.set_parallel()
	t.tween_property(torso, "position:y", tp.y + 8.0, 0.1)
	t.tween_property(leg_l, "rotation_degrees", -8.0, 0.1)
	t.tween_property(leg_r, "rotation_degrees", 8.0, 0.1)
	t.tween_property(shin_l, "rotation_degrees", 15.0, 0.1)
	t.tween_property(shin_r, "rotation_degrees", -15.0, 0.1)
	await t.finished

	var t2 = create_tween()
	t2.set_parallel()
	t2.tween_property(torso, "position:y", tp.y - 45.0, 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t2.tween_property(arm_l, "rotation_degrees", -50.0, 0.12)
	t2.tween_property(arm_r, "rotation_degrees", 50.0, 0.12)
	t2.tween_property(leg_l, "rotation_degrees", 5.0, 0.12)
	t2.tween_property(leg_r, "rotation_degrees", -5.0, 0.12)
	t2.tween_property(shin_l, "rotation_degrees", -5.0, 0.12)
	t2.tween_property(shin_r, "rotation_degrees", 5.0, 0.12)
	t2.tween_property(head, "rotation_degrees", -10.0, 0.1)
	await t2.finished

	# Airborne hold
	await get_tree().create_timer(0.1).timeout

	# SLAM DOWN — fists into ground
	var t3 = create_tween()
	t3.set_parallel()
	t3.tween_property(torso, "position:y", tp.y + 15.0, 0.06)
	t3.tween_property(torso, "rotation_degrees", 15.0, 0.06)
	t3.tween_property(arm_l, "rotation_degrees", 30.0, 0.05)
	t3.tween_property(arm_r, "rotation_degrees", -30.0, 0.05)
	t3.tween_property(head, "rotation_degrees", 12.0, 0.05)
	t3.tween_property(leg_l, "rotation_degrees", -12.0, 0.06)
	t3.tween_property(leg_r, "rotation_degrees", 12.0, 0.06)
	t3.tween_property(shin_l, "rotation_degrees", 20.0, 0.06)
	t3.tween_property(shin_r, "rotation_degrees", -20.0, 0.06)
	await t3.finished

	ScreenShake.shake_heavy()
	modulate = Color(0.5, 2.5, 0.5, 1.0)
	await get_tree().create_timer(0.1).timeout
	modulate = Color(1.0, 1.0, 1.0, 1.0)

	# Shockwave ripple
	var ripple = create_tween().set_loops(4)
	ripple.tween_property(self, "position:x", position.x + 4, 0.03)
	ripple.tween_property(self, "position:x", position.x - 4, 0.03)
	ripple.tween_property(self, "position:x", position.x, 0.02)
	await ripple.finished

	_reset_pose(0.3)
	await get_tree().create_timer(0.3).timeout
	animation_finished.emit("summon")
	play_idle()


# ── UTILITY ────────────────────────────────────────────────────────────────
func _kill_current() -> void:
	_current_anim = ""
	for tw in _active_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_active_tweens.clear()
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
		_idle_tween = null


func _reset_pose(duration: float = 0.3) -> void:
	var t = create_tween()
	t.set_parallel()
	t.tween_property(torso, "position", _rest_pos(torso), duration)
	t.tween_property(torso, "rotation_degrees", 0.0, duration)
	t.tween_property(head, "rotation_degrees", 0.0, duration)
	t.tween_property(arm_l, "rotation_degrees", 0.0, duration)
	t.tween_property(arm_r, "rotation_degrees", 0.0, duration)
	t.tween_property(leg_l, "rotation_degrees", 0.0, duration)
	t.tween_property(leg_r, "rotation_degrees", 0.0, duration)
	t.tween_property(shin_l, "rotation_degrees", 0.0, duration)
	t.tween_property(shin_r, "rotation_degrees", 0.0, duration)
	t.tween_property(foot_l, "rotation_degrees", 0.0, duration)
	t.tween_property(foot_r, "rotation_degrees", 0.0, duration)
	t.tween_property(self, "scale", Vector2(0.85, 0.85), duration)
	t.tween_property(self, "modulate", Color(1, 1, 1, 1), duration)
