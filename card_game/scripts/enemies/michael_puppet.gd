extends Node2D
## Michael puppet controller — South Park-style cutout animation
## Archangel of War: armored knight with dual swords, 2 wings, gold plate armor.
## Drives all poses via tween-based bone rotations on the sprite hierarchy.

@onready var torso: Sprite2D = $Torso
@onready var head: Sprite2D = $Torso/Head
@onready var shoulder_l: Sprite2D = $Torso/ShoulderLeft
@onready var shoulder_r: Sprite2D = $Torso/ShoulderRight
@onready var upper_arm_l: Sprite2D = $Torso/ShoulderLeft/UpperArmLeft
@onready var upper_arm_r: Sprite2D = $Torso/ShoulderRight/UpperArmRight
@onready var sword_l: Sprite2D = $Torso/ShoulderLeft/UpperArmLeft/SwordLeft
@onready var sword_r: Sprite2D = $Torso/ShoulderRight/UpperArmRight/SwordRight
@onready var wing_l: Sprite2D = $Torso/WingLeft
@onready var wing_r: Sprite2D = $Torso/WingRight
@onready var leg_skirt: Sprite2D = $LegSkirt
@onready var chest_plate: Sprite2D = $Torso/ChestPlate
@onready var cape: Sprite2D = $Cape
@onready var upper_leg_l: Sprite2D = $UpperLegLeft
@onready var upper_leg_r: Sprite2D = $UpperLegRight
@onready var leg_left: Sprite2D = $UpperLegLeft/LegLeft
@onready var leg_right: Sprite2D = $UpperLegRight/LegRight
@onready var wing_inner_l: Sprite2D = $Torso/WingInnerLeft
@onready var wing_inner_r: Sprite2D = $Torso/WingInnerRight

var _idle_tween: Tween = null
var _current_anim: String = ""
var _active_tweens: Array[Tween] = []

# Rest positions — captured from editor layout on _ready
var _rest_positions: Dictionary = {}  # Node -> Vector2

# VFX systems
var _effects: Node2D = null          # michael_effects.gd (holy glow + sparks)
var _shader_ctrl: Node = null        # shader_controller.gd (dissolve + aberration)
var _afterimage: Node2D = null       # afterimage.gd (ghost trails)
var _tendrils: Node2D = null         # dark_tendrils.gd (summon tendrils)
var _summon_circle: Node2D = null    # active summoning circle instance

signal animation_finished(anim_name: String)

const SummoningCircleScene = preload("res://scripts/effects/summoning_circle.gd")
const AfterimageScene = preload("res://scripts/effects/afterimage.gd")
const DarkTendrilsScene = preload("res://scripts/effects/dark_tendrils.gd")
const MichaelEffectsScene = preload("res://scripts/enemies/michael_effects.gd")
const ShaderControllerScene = preload("res://scripts/effects/shader_controller.gd")

## Debug keys (remove for production):
## 1=idle  2=attack  3=hit  4=stagger  5=telegraph
## 6=cast  7=death   8=buff  9=taunt  0=summon  -=phase


func _ready() -> void:
	_capture_rest_positions()
	_setup_effects()
	play_idle()


func _capture_rest_positions() -> void:
	var nodes: Array = [torso, head, shoulder_l, shoulder_r, upper_arm_l, upper_arm_r,
		sword_l, sword_r, wing_l, wing_r, leg_skirt, chest_plate, cape,
		upper_leg_l, upper_leg_r, leg_left, leg_right, wing_inner_l, wing_inner_r]
	for node in nodes:
		if node:
			_rest_positions[node] = node.position


func _rest_pos(node: Node2D) -> Vector2:
	var pos: Vector2 = _rest_positions.get(node, node.position)
	return pos


func _process(_delta: float) -> void:
	# Inner wings follow outer wings at 75% intensity for layered depth
	if wing_inner_l and wing_l:
		wing_inner_l.rotation_degrees = wing_l.rotation_degrees * 0.75
	if wing_inner_r and wing_r:
		wing_inner_r.rotation_degrees = wing_r.rotation_degrees * 0.75


func _setup_effects() -> void:
	# Holy glow + divine sparks
	_effects = Node2D.new()
	_effects.set_script(MichaelEffectsScene)
	add_child(_effects)

	# Shader controller (dissolve + chromatic aberration)
	_shader_ctrl = Node.new()
	_shader_ctrl.set_script(ShaderControllerScene)
	add_child(_shader_ctrl)
	_shader_ctrl.call_deferred("setup", self)

	# Afterimage — added as sibling so ghosts stay in world space
	_afterimage = Node2D.new()
	_afterimage.set_script(AfterimageScene)
	get_parent().call_deferred("add_child", _afterimage)

	# Dark tendrils — at leg skirt / waist area
	_tendrils = Node2D.new()
	_tendrils.set_script(DarkTendrilsScene)
	_tendrils.position = Vector2(0, 100)
	add_child(_tendrils)


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
		KEY_MINUS: play_phase_transition()


# ── IDLE ───────────────────────────────────────────────────────────────────
func play_idle() -> void:
	_kill_current()
	_current_anim = "idle"
	_reset_pose(0.3)
	if _effects: _effects.reset()
	if _shader_ctrl: _shader_ctrl.reset_shaders()
	_start_idle_hum()
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
	_idle_tween = create_tween().set_loops()

	# Minimal breathing — torso 3px oscillation, disciplined soldier
	_idle_tween.tween_property(torso, "position:y", tp.y - 2.0, 1.25) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_property(torso, "position:y", tp.y + 3.0, 1.25) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# Head — barely moves, 1 degree tilt range, watchful
	var head_tween = create_tween().set_loops()
	head_tween.tween_property(head, "rotation_degrees", -0.5, 2.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	head_tween.tween_property(head, "rotation_degrees", 0.5, 2.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(head_tween)

	# Shoulders — rigid, almost no movement
	var shoulder_tw_l = create_tween().set_loops()
	shoulder_tw_l.tween_property(shoulder_l, "rotation_degrees", -1.0, 2.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	shoulder_tw_l.tween_property(shoulder_l, "rotation_degrees", 1.0, 2.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(shoulder_tw_l)

	var shoulder_tw_r = create_tween().set_loops()
	shoulder_tw_r.tween_property(shoulder_r, "rotation_degrees", 1.0, 3.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	shoulder_tw_r.tween_property(shoulder_r, "rotation_degrees", -1.0, 3.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(shoulder_tw_r)

	# Swords — held steady at slight angle, almost no movement
	var sword_tw_l = create_tween().set_loops()
	sword_tw_l.tween_property(sword_l, "rotation_degrees", -1.5, 3.2) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	sword_tw_l.tween_property(sword_l, "rotation_degrees", 1.5, 3.2) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(sword_tw_l)

	var sword_tw_r = create_tween().set_loops()
	sword_tw_r.tween_property(sword_r, "rotation_degrees", 1.5, 3.4) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	sword_tw_r.tween_property(sword_r, "rotation_degrees", -1.5, 3.4) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(sword_tw_r)

	# Wings — synchronized graceful flap, 3-5 degree range, 3.0s sine
	var wing_tw_l = create_tween().set_loops()
	wing_tw_l.tween_property(wing_l, "rotation_degrees", -4.0, 1.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	wing_tw_l.tween_property(wing_l, "rotation_degrees", 4.0, 1.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(wing_tw_l)

	var wing_tw_r = create_tween().set_loops()
	wing_tw_r.tween_property(wing_r, "rotation_degrees", 4.0, 1.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	wing_tw_r.tween_property(wing_r, "rotation_degrees", -4.0, 1.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(wing_tw_r)

	# Cape — gentle billow behind
	var cape_tween = create_tween().set_loops()
	cape_tween.tween_property(cape, "rotation_degrees", -2.0, 2.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	cape_tween.tween_property(cape, "rotation_degrees", 2.0, 2.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(cape_tween)

	# Leg skirt — very slight sway, 1-2 degrees
	var skirt_tween = create_tween().set_loops()
	skirt_tween.tween_property(leg_skirt, "rotation_degrees", -1.5, 2.2) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	skirt_tween.tween_property(leg_skirt, "rotation_degrees", 1.5, 2.2) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(skirt_tween)

	# Upper legs — subtle weight shift, alternating lean
	var uleg_tw_l = create_tween().set_loops()
	uleg_tw_l.tween_property(upper_leg_l, "rotation_degrees", -1.0, 2.6) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	uleg_tw_l.tween_property(upper_leg_l, "rotation_degrees", 1.0, 2.6) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(uleg_tw_l)

	var uleg_tw_r = create_tween().set_loops()
	uleg_tw_r.tween_property(upper_leg_r, "rotation_degrees", 1.0, 2.6) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	uleg_tw_r.tween_property(upper_leg_r, "rotation_degrees", -1.0, 2.6) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(uleg_tw_r)

	# Lower legs — slight knee bob, offset from upper legs
	var leg_tw_l = create_tween().set_loops()
	leg_tw_l.tween_property(leg_left, "rotation_degrees", 0.5, 2.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	leg_tw_l.tween_property(leg_left, "rotation_degrees", -0.5, 2.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(leg_tw_l)

	var leg_tw_r = create_tween().set_loops()
	leg_tw_r.tween_property(leg_right, "rotation_degrees", -0.5, 2.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	leg_tw_r.tween_property(leg_right, "rotation_degrees", 0.5, 2.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(leg_tw_r)


# ── ATTACK ─────────────────────────────────────────────────────────────────
func play_attack() -> void:
	_kill_current()
	_current_anim = "attack"
	var tp := _rest_pos(torso)
	if _effects: _effects.intensify()
	if _afterimage: _afterimage.spawn_afterimage(self, 3, 0.06)
	SFXManager.play_boss_attack_telegraph()

	# Raise: both arms up, shoulders rotate outward, swords overhead
	var t1 = create_tween()
	t1.set_parallel()
	t1.tween_property(torso, "rotation_degrees", -10.0, 0.22)
	t1.tween_property(torso, "position:y", tp.y - 10.0, 0.22)
	t1.tween_property(shoulder_l, "rotation_degrees", -45.0, 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t1.tween_property(shoulder_r, "rotation_degrees", 45.0, 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t1.tween_property(upper_arm_l, "rotation_degrees", -25.0, 0.2)
	t1.tween_property(upper_arm_r, "rotation_degrees", 25.0, 0.2)
	t1.tween_property(sword_l, "rotation_degrees", -20.0, 0.18)
	t1.tween_property(sword_r, "rotation_degrees", 20.0, 0.18)
	t1.tween_property(sword_l, "rotation_degrees", -15.0, 0.2)
	t1.tween_property(sword_r, "rotation_degrees", 15.0, 0.2)
	t1.tween_property(wing_l, "rotation_degrees", -18.0, 0.22) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t1.tween_property(wing_r, "rotation_degrees", 18.0, 0.22) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t1.tween_property(head, "rotation_degrees", -5.0, 0.15)
	t1.tween_property(upper_leg_l, "rotation_degrees", 5.0, 0.2)
	t1.tween_property(upper_leg_r, "rotation_degrees", -3.0, 0.2)
	t1.tween_property(leg_left, "rotation_degrees", -4.0, 0.2)
	await t1.finished

	# Slam: torso snaps forward +15, arms slam down, swords follow
	var t2 = create_tween()
	t2.set_parallel()
	t2.tween_property(torso, "rotation_degrees", 15.0, 0.08).set_trans(Tween.TRANS_BACK)
	t2.tween_property(torso, "position:y", tp.y + 15.0, 0.08)
	t2.tween_property(shoulder_l, "rotation_degrees", 30.0, 0.08)
	t2.tween_property(shoulder_r, "rotation_degrees", -30.0, 0.08)
	t2.tween_property(upper_arm_l, "rotation_degrees", 20.0, 0.07)
	t2.tween_property(upper_arm_r, "rotation_degrees", -20.0, 0.07)
	t2.tween_property(sword_l, "rotation_degrees", 25.0, 0.06)
	t2.tween_property(sword_r, "rotation_degrees", -25.0, 0.06)
	t2.tween_property(sword_l, "rotation_degrees", 20.0, 0.06)
	t2.tween_property(sword_r, "rotation_degrees", -20.0, 0.06)
	t2.tween_property(wing_l, "rotation_degrees", 8.0, 0.1)
	t2.tween_property(wing_r, "rotation_degrees", -8.0, 0.1)
	t2.tween_property(head, "rotation_degrees", 10.0, 0.06)
	t2.tween_property(upper_leg_l, "rotation_degrees", -8.0, 0.08)
	t2.tween_property(upper_leg_r, "rotation_degrees", 6.0, 0.08)
	t2.tween_property(leg_left, "rotation_degrees", 5.0, 0.06)
	t2.tween_property(leg_right, "rotation_degrees", -3.0, 0.06)
	await t2.finished

	# Impact
	ScreenShake.shake_heavy()
	if _shader_ctrl: _shader_ctrl.flash_aberration(12.0, 0.15)
	SFXManager.play_boss_attack_impact()

	var flash = create_tween()
	flash.tween_property(self, "modulate", Color(2.5, 2.0, 0.5, 1.0), 0.04)
	flash.tween_property(self, "modulate", Color(1.5, 0.5, 2.5, 1.0), 0.04)
	flash.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08)
	await flash.finished

	_reset_pose(0.4)
	await get_tree().create_timer(0.45).timeout
	animation_finished.emit("attack")
	play_idle()


# ── HIT / DAMAGE ───────────────────────────────────────────────────────────
func play_hit() -> void:
	_kill_current()
	_current_anim = "hit"
	var tp := _rest_pos(torso)
	ScreenShake.shake_light()
	if _shader_ctrl: _shader_ctrl.flash_aberration(6.0, 0.1)
	SFXManager.play_boss_hit()

	modulate = Color(3.0, 3.0, 3.0, 1.0)

	var t = create_tween()
	t.set_parallel()
	t.tween_property(torso, "rotation_degrees", -8.0, 0.06)
	t.tween_property(torso, "position:x", tp.x + 12.0, 0.06)
	t.tween_property(head, "rotation_degrees", -6.0, 0.05)
	t.tween_property(shoulder_l, "rotation_degrees", 8.0, 0.06)
	t.tween_property(shoulder_r, "rotation_degrees", -6.0, 0.06)
	t.tween_property(wing_l, "rotation_degrees", -5.0, 0.06)
	t.tween_property(wing_r, "rotation_degrees", 5.0, 0.06)
	t.tween_property(upper_leg_l, "rotation_degrees", 4.0, 0.06)
	t.tween_property(upper_leg_r, "rotation_degrees", -3.0, 0.06)
	t.tween_property(leg_left, "rotation_degrees", -3.0, 0.05)
	t.tween_property(leg_right, "rotation_degrees", 2.0, 0.05)
	await t.finished

	modulate = Color(1.0, 1.0, 1.0, 1.0)

	var t2 = create_tween()
	t2.set_parallel()
	t2.tween_property(torso, "rotation_degrees", 3.0, 0.05)
	t2.tween_property(torso, "position:x", tp.x - 5.0, 0.05)
	await t2.finished

	var t3 = create_tween()
	t3.set_parallel()
	t3.tween_property(torso, "rotation_degrees", 0.0, 0.15)
	t3.tween_property(torso, "position:x", tp.x, 0.15)
	t3.tween_property(head, "rotation_degrees", 0.0, 0.15)
	t3.tween_property(shoulder_l, "rotation_degrees", 0.0, 0.15)
	t3.tween_property(shoulder_r, "rotation_degrees", 0.0, 0.15)
	t3.tween_property(wing_l, "rotation_degrees", 0.0, 0.15)
	t3.tween_property(wing_r, "rotation_degrees", 0.0, 0.15)
	t3.tween_property(upper_leg_l, "rotation_degrees", 0.0, 0.15)
	t3.tween_property(upper_leg_r, "rotation_degrees", 0.0, 0.15)
	t3.tween_property(leg_left, "rotation_degrees", 0.0, 0.15)
	t3.tween_property(leg_right, "rotation_degrees", 0.0, 0.15)
	await t3.finished

	animation_finished.emit("hit")
	play_idle()


# ── STAGGER (heavy hit) ───────────────────────────────────────────────────
func play_stagger() -> void:
	_kill_current()
	_current_anim = "stagger"
	var tp := _rest_pos(torso)
	ScreenShake.shake(15.0, 0.4)
	if _shader_ctrl: _shader_ctrl.flash_aberration(12.0, 0.2)
	SFXManager.play_boss_stagger()

	modulate = Color(4.0, 2.0, 2.0, 1.0)
	var t = create_tween()
	t.set_parallel()
	t.tween_property(torso, "rotation_degrees", -18.0, 0.05)
	t.tween_property(torso, "position", tp + Vector2(22, 28), 0.05)
	t.tween_property(head, "rotation_degrees", -20.0, 0.04)
	t.tween_property(shoulder_l, "rotation_degrees", 20.0, 0.05)
	t.tween_property(shoulder_r, "rotation_degrees", -18.0, 0.05)
	t.tween_property(sword_l, "rotation_degrees", 12.0, 0.04)
	t.tween_property(sword_r, "rotation_degrees", -10.0, 0.04)
	t.tween_property(sword_l, "rotation_degrees", 15.0, 0.04)
	t.tween_property(sword_r, "rotation_degrees", -12.0, 0.04)
	t.tween_property(wing_l, "rotation_degrees", -12.0, 0.05)
	t.tween_property(wing_r, "rotation_degrees", 12.0, 0.05)
	t.tween_property(upper_leg_l, "rotation_degrees", 12.0, 0.05)
	t.tween_property(upper_leg_r, "rotation_degrees", -8.0, 0.05)
	t.tween_property(leg_left, "rotation_degrees", -10.0, 0.04)
	t.tween_property(leg_right, "rotation_degrees", 6.0, 0.04)
	await t.finished

	modulate = Color(1.0, 1.0, 1.0, 1.0)

	for i in 3:
		var intensity = 1.0 - (i * 0.3)
		var wobble = create_tween()
		wobble.set_parallel()
		wobble.tween_property(torso, "rotation_degrees", 7.0 * intensity, 0.12)
		wobble.tween_property(torso, "position:x", tp.x - 8.0 * intensity, 0.12)
		wobble.tween_property(head, "rotation_degrees", 8.0 * intensity, 0.1)
		wobble.tween_property(sword_l, "rotation_degrees", -6.0 * intensity, 0.1)
		wobble.tween_property(sword_r, "rotation_degrees", 6.0 * intensity, 0.1)
		wobble.tween_property(upper_leg_l, "rotation_degrees", -5.0 * intensity, 0.12)
		wobble.tween_property(upper_leg_r, "rotation_degrees", 4.0 * intensity, 0.12)
		wobble.tween_property(leg_left, "rotation_degrees", 4.0 * intensity, 0.1)
		wobble.tween_property(leg_right, "rotation_degrees", -3.0 * intensity, 0.1)
		await wobble.finished

		var wobble2 = create_tween()
		wobble2.set_parallel()
		wobble2.tween_property(torso, "rotation_degrees", -4.0 * intensity, 0.12)
		wobble2.tween_property(torso, "position:x", tp.x + 4.0 * intensity, 0.12)
		wobble2.tween_property(head, "rotation_degrees", -5.0 * intensity, 0.1)
		wobble2.tween_property(sword_l, "rotation_degrees", 4.0 * intensity, 0.1)
		wobble2.tween_property(sword_r, "rotation_degrees", -4.0 * intensity, 0.1)
		wobble2.tween_property(upper_leg_l, "rotation_degrees", 3.0 * intensity, 0.12)
		wobble2.tween_property(upper_leg_r, "rotation_degrees", -2.0 * intensity, 0.12)
		wobble2.tween_property(leg_left, "rotation_degrees", -2.0 * intensity, 0.1)
		wobble2.tween_property(leg_right, "rotation_degrees", 2.0 * intensity, 0.1)
		await wobble2.finished

	_reset_pose(0.3)
	await get_tree().create_timer(0.35).timeout
	animation_finished.emit("stagger")
	play_idle()


# ── TELEGRAPH (intent preview) ─────────────────────────────────────────────
func play_telegraph() -> void:
	_kill_current()
	_current_anim = "telegraph"
	var tp := _rest_pos(torso)
	SFXManager.play_boss_telegraph()

	var t = create_tween()
	t.set_parallel()
	t.tween_property(wing_l, "rotation_degrees", -25.0, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(wing_r, "rotation_degrees", 25.0, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(shoulder_l, "rotation_degrees", 15.0, 0.25)
	t.tween_property(shoulder_r, "rotation_degrees", -15.0, 0.25)
	t.tween_property(upper_arm_l, "rotation_degrees", 12.0, 0.25)
	t.tween_property(upper_arm_r, "rotation_degrees", -12.0, 0.25)
	t.tween_property(sword_l, "rotation_degrees", 18.0, 0.22)
	t.tween_property(sword_r, "rotation_degrees", -18.0, 0.22)
	t.tween_property(sword_l, "rotation_degrees", 10.0, 0.25)
	t.tween_property(sword_r, "rotation_degrees", -10.0, 0.25)
	t.tween_property(head, "rotation_degrees", -3.0, 0.2)
	t.tween_property(torso, "position:y", tp.y - 8.0, 0.3)
	t.tween_property(upper_leg_l, "rotation_degrees", -6.0, 0.25)
	t.tween_property(upper_leg_r, "rotation_degrees", 6.0, 0.25)
	t.tween_property(leg_left, "rotation_degrees", 3.0, 0.25)
	t.tween_property(leg_right, "rotation_degrees", -3.0, 0.25)
	await t.finished

	var pulse = create_tween().set_loops(3)
	pulse.tween_property(self, "modulate", Color(1.6, 1.4, 0.8, 1.0), 0.15)
	pulse.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)

	var scale_pulse = create_tween().set_loops(3)
	scale_pulse.tween_property(self, "scale", Vector2(0.87, 0.87), 0.3) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	scale_pulse.tween_property(self, "scale", Vector2(0.85, 0.85), 0.3) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await scale_pulse.finished

	animation_finished.emit("telegraph")
	play_idle()


# ── CAST / SKILL ───────────────────────────────────────────────────────────
func play_cast() -> void:
	_kill_current()
	_current_anim = "cast"
	var tp := _rest_pos(torso)
	if _effects: _effects.intensify()
	_spawn_summon_circle()
	SFXManager.play_boss_cast()

	var t = create_tween()
	t.set_parallel()
	t.tween_property(shoulder_l, "rotation_degrees", -40.0, 0.25)
	t.tween_property(shoulder_r, "rotation_degrees", 40.0, 0.25)
	t.tween_property(upper_arm_l, "rotation_degrees", -18.0, 0.25)
	t.tween_property(upper_arm_r, "rotation_degrees", 18.0, 0.25)
	t.tween_property(sword_l, "rotation_degrees", -10.0, 0.22)
	t.tween_property(sword_r, "rotation_degrees", 10.0, 0.22)
	t.tween_property(sword_l, "rotation_degrees", -8.0, 0.25)
	t.tween_property(sword_r, "rotation_degrees", 8.0, 0.25)
	t.tween_property(head, "rotation_degrees", -10.0, 0.2)
	t.tween_property(torso, "position:y", tp.y - 15.0, 0.3)
	t.tween_property(wing_l, "rotation_degrees", -15.0, 0.25)
	t.tween_property(wing_r, "rotation_degrees", 15.0, 0.25)
	t.tween_property(upper_leg_l, "rotation_degrees", 3.0, 0.3)
	t.tween_property(upper_leg_r, "rotation_degrees", -3.0, 0.3)
	t.tween_property(leg_left, "rotation_degrees", -5.0, 0.3)
	t.tween_property(leg_right, "rotation_degrees", 5.0, 0.3)
	await t.finished

	var flutter_l = create_tween().set_loops(6)
	flutter_l.tween_property(wing_l, "rotation_degrees", -18.0, 0.04)
	flutter_l.tween_property(wing_l, "rotation_degrees", -12.0, 0.04)
	_active_tweens.append(flutter_l)

	var flutter_r = create_tween().set_loops(6)
	flutter_r.tween_property(wing_r, "rotation_degrees", 18.0, 0.04)
	flutter_r.tween_property(wing_r, "rotation_degrees", 12.0, 0.04)
	_active_tweens.append(flutter_r)

	var pulse = create_tween()
	pulse.tween_property(self, "modulate", Color(1.8, 1.5, 0.6, 1.0), 0.08)
	pulse.tween_property(self, "scale", Vector2(0.92, 0.92), 0.08)
	pulse.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)
	pulse.tween_property(self, "scale", Vector2(0.85, 0.85), 0.15)
	await pulse.finished

	var t2 = create_tween()
	t2.set_parallel()
	t2.tween_property(shoulder_l, "rotation_degrees", 20.0, 0.1)
	t2.tween_property(shoulder_r, "rotation_degrees", -20.0, 0.1)
	t2.tween_property(upper_arm_l, "rotation_degrees", 10.0, 0.08)
	t2.tween_property(upper_arm_r, "rotation_degrees", -10.0, 0.08)
	t2.tween_property(sword_l, "rotation_degrees", 15.0, 0.08)
	t2.tween_property(sword_r, "rotation_degrees", -15.0, 0.08)
	t2.tween_property(sword_l, "rotation_degrees", 12.0, 0.08)
	t2.tween_property(sword_r, "rotation_degrees", -12.0, 0.08)
	t2.tween_property(head, "rotation_degrees", 6.0, 0.08)
	t2.tween_property(torso, "position:y", tp.y + 10.0, 0.1)
	t2.tween_property(wing_l, "rotation_degrees", 5.0, 0.1)
	t2.tween_property(wing_r, "rotation_degrees", -5.0, 0.1)
	t2.tween_property(upper_leg_l, "rotation_degrees", -5.0, 0.1)
	t2.tween_property(upper_leg_r, "rotation_degrees", 5.0, 0.1)
	t2.tween_property(leg_left, "rotation_degrees", 4.0, 0.08)
	t2.tween_property(leg_right, "rotation_degrees", -4.0, 0.08)
	await t2.finished

	ScreenShake.shake()
	if _summon_circle: _summon_circle.pulse()
	await get_tree().create_timer(0.2).timeout
	_dismiss_summon_circle()
	animation_finished.emit("cast")
	play_idle()


# ── DEATH ──────────────────────────────────────────────────────────────────
func play_death() -> void:
	_kill_current()
	_current_anim = "death"
	var tp := _rest_pos(torso)
	if _effects: _effects.dim()
	ScreenShake.shake_heavy()
	if _shader_ctrl: _shader_ctrl.play_dissolve(1.5)
	SFXManager.play_boss_death()

	var t = create_tween()
	t.set_parallel()
	t.tween_property(shoulder_l, "rotation_degrees", 35.0, 0.3)
	t.tween_property(shoulder_r, "rotation_degrees", -35.0, 0.3)
	t.tween_property(sword_l, "rotation_degrees", 25.0, 0.3)
	t.tween_property(sword_r, "rotation_degrees", -25.0, 0.3)
	t.tween_property(sword_l, "rotation_degrees", 45.0, 0.35) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_property(sword_r, "rotation_degrees", -45.0, 0.35) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_property(wing_l, "rotation_degrees", 20.0, 0.4) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_property(wing_r, "rotation_degrees", -20.0, 0.4) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_property(cape, "rotation_degrees", 8.0, 0.4)
	t.tween_property(head, "rotation_degrees", 25.0, 0.4)
	t.tween_property(torso, "position:y", tp.y + 50.0, 0.5)
	t.tween_property(leg_skirt, "rotation_degrees", -5.0, 0.4)
	t.tween_property(upper_leg_l, "rotation_degrees", 18.0, 0.4)
	t.tween_property(upper_leg_r, "rotation_degrees", -15.0, 0.4)
	t.tween_property(leg_left, "rotation_degrees", -20.0, 0.35)
	t.tween_property(leg_right, "rotation_degrees", 18.0, 0.35)
	await t.finished

	var t2 = create_tween()
	t2.set_parallel()
	t2.tween_property(self, "scale", Vector2(1.0, 0.3), 0.4) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	t2.tween_property(self, "modulate:a", 0.0, 0.6)
	t2.tween_property(torso, "position:y", tp.y + 100.0, 0.4)
	t2.tween_property(sword_l, "rotation_degrees", 90.0, 0.3)
	t2.tween_property(sword_r, "rotation_degrees", -90.0, 0.3)
	t2.tween_property(wing_l, "rotation_degrees", 35.0, 0.35)
	t2.tween_property(wing_r, "rotation_degrees", -35.0, 0.35)
	t2.tween_property(cape, "modulate:a", 0.0, 0.4)
	await t2.finished

	animation_finished.emit("death")


# ── BUFF ───────────────────────────────────────────────────────────────────
func play_buff() -> void:
	_kill_current()
	_current_anim = "buff"
	var tp := _rest_pos(torso)
	if _effects: _effects.intensify()
	SFXManager.play_boss_buff()

	var t = create_tween()
	t.set_parallel()
	t.tween_property(torso, "position:y", tp.y - 30.0, 0.4)
	t.tween_property(shoulder_l, "rotation_degrees", -20.0, 0.3)
	t.tween_property(shoulder_r, "rotation_degrees", 20.0, 0.3)
	t.tween_property(wing_l, "rotation_degrees", -22.0, 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(wing_r, "rotation_degrees", 22.0, 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(sword_l, "rotation_degrees", -10.0, 0.3)
	t.tween_property(sword_r, "rotation_degrees", 10.0, 0.3)
	t.tween_property(head, "rotation_degrees", -6.0, 0.3)
	t.tween_property(upper_leg_l, "rotation_degrees", 6.0, 0.35)
	t.tween_property(upper_leg_r, "rotation_degrees", -6.0, 0.35)
	t.tween_property(leg_left, "rotation_degrees", 8.0, 0.35)
	t.tween_property(leg_right, "rotation_degrees", -8.0, 0.35)
	await t.finished

	var glow = create_tween().set_loops(3)
	glow.tween_property(self, "modulate", Color(2.0, 1.6, 0.5, 1.0), 0.15)
	glow.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)
	await glow.finished

	animation_finished.emit("buff")
	play_idle()


# ── TAUNT ──────────────────────────────────────────────────────────────────
func play_taunt() -> void:
	_kill_current()
	_current_anim = "taunt"
	var tp := _rest_pos(torso)
	SFXManager.play_boss_taunt()

	var t = create_tween()
	t.set_parallel()
	t.tween_property(torso, "rotation_degrees", 10.0, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(torso, "position:y", tp.y + 8.0, 0.3)
	t.tween_property(shoulder_l, "rotation_degrees", 15.0, 0.25)
	t.tween_property(shoulder_r, "rotation_degrees", -15.0, 0.25)
	t.tween_property(upper_arm_l, "rotation_degrees", 10.0, 0.25)
	t.tween_property(upper_arm_r, "rotation_degrees", -10.0, 0.25)
	t.tween_property(sword_l, "rotation_degrees", 20.0, 0.22)
	t.tween_property(sword_r, "rotation_degrees", -20.0, 0.22)
	t.tween_property(sword_l, "rotation_degrees", 15.0, 0.25)
	t.tween_property(sword_r, "rotation_degrees", -15.0, 0.25)
	t.tween_property(head, "rotation_degrees", 8.0, 0.2)
	t.tween_property(wing_l, "rotation_degrees", -10.0, 0.25)
	t.tween_property(wing_r, "rotation_degrees", 10.0, 0.25)
	t.tween_property(upper_leg_l, "rotation_degrees", -8.0, 0.25)
	t.tween_property(upper_leg_r, "rotation_degrees", 8.0, 0.25)
	t.tween_property(leg_left, "rotation_degrees", 5.0, 0.25)
	t.tween_property(leg_right, "rotation_degrees", -5.0, 0.25)
	await t.finished

	var tilt = create_tween()
	tilt.tween_property(head, "rotation_degrees", 12.0, 0.2) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tilt.tween_property(head, "rotation_degrees", 5.0, 0.2) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tilt.tween_property(head, "rotation_degrees", 10.0, 0.15)
	tilt.tween_property(head, "rotation_degrees", 0.0, 0.15)
	await tilt.finished

	await get_tree().create_timer(0.3).timeout
	animation_finished.emit("taunt")
	play_idle()


# ── SUMMON ─────────────────────────────────────────────────────────────────
func play_summon() -> void:
	_kill_current()
	_current_anim = "summon"
	var tp := _rest_pos(torso)
	if _effects: _effects.intensify()
	_spawn_summon_circle()
	SFXManager.play_boss_summon()
	if _tendrils:
		_tendrils.emerge(0.5)
		_tendrils.writhe()

	var t = create_tween()
	t.set_parallel()
	t.tween_property(torso, "position:y", tp.y - 45.0, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(shoulder_l, "rotation_degrees", -55.0, 0.4)
	t.tween_property(shoulder_r, "rotation_degrees", 55.0, 0.4)
	t.tween_property(upper_arm_l, "rotation_degrees", -20.0, 0.35)
	t.tween_property(upper_arm_r, "rotation_degrees", 20.0, 0.35)
	t.tween_property(sword_l, "rotation_degrees", -15.0, 0.3)
	t.tween_property(sword_r, "rotation_degrees", 15.0, 0.3)
	t.tween_property(sword_l, "rotation_degrees", -12.0, 0.35)
	t.tween_property(sword_r, "rotation_degrees", 12.0, 0.35)
	t.tween_property(wing_l, "rotation_degrees", -30.0, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(wing_r, "rotation_degrees", 30.0, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(head, "rotation_degrees", -12.0, 0.3)
	t.tween_property(leg_skirt, "rotation_degrees", -4.0, 0.5)
	t.tween_property(upper_leg_l, "rotation_degrees", 10.0, 0.4)
	t.tween_property(upper_leg_r, "rotation_degrees", -10.0, 0.4)
	t.tween_property(leg_left, "rotation_degrees", 12.0, 0.4)
	t.tween_property(leg_right, "rotation_degrees", -12.0, 0.4)
	await t.finished

	var channel = create_tween().set_loops(8)
	channel.tween_property(self, "position:x", position.x + 3, 0.03)
	channel.tween_property(self, "position:x", position.x - 3, 0.03)
	channel.tween_property(self, "position:x", position.x, 0.02)

	var glow = create_tween().set_loops(4)
	glow.tween_property(self, "modulate", Color(2.2, 1.8, 0.4, 1.0), 0.1)
	glow.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)

	var wing_channel = create_tween().set_loops(6)
	wing_channel.tween_property(wing_l, "rotation_degrees", -33.0, 0.06)
	wing_channel.tween_property(wing_l, "rotation_degrees", -27.0, 0.06)
	_active_tweens.append(wing_channel)

	var wing_channel_r = create_tween().set_loops(6)
	wing_channel_r.tween_property(wing_r, "rotation_degrees", 33.0, 0.06)
	wing_channel_r.tween_property(wing_r, "rotation_degrees", 27.0, 0.06)
	_active_tweens.append(wing_channel_r)

	await channel.finished

	var t2 = create_tween()
	t2.set_parallel()
	t2.tween_property(shoulder_l, "rotation_degrees", 20.0, 0.08)
	t2.tween_property(shoulder_r, "rotation_degrees", -20.0, 0.08)
	t2.tween_property(sword_l, "rotation_degrees", 18.0, 0.06)
	t2.tween_property(sword_r, "rotation_degrees", -18.0, 0.06)
	t2.tween_property(torso, "position:y", tp.y + 10.0, 0.12)
	t2.tween_property(head, "rotation_degrees", 8.0, 0.08)
	t2.tween_property(wing_l, "rotation_degrees", 5.0, 0.1)
	t2.tween_property(wing_r, "rotation_degrees", -5.0, 0.1)
	t2.tween_property(upper_leg_l, "rotation_degrees", -6.0, 0.1)
	t2.tween_property(upper_leg_r, "rotation_degrees", 6.0, 0.1)
	t2.tween_property(leg_left, "rotation_degrees", 5.0, 0.08)
	t2.tween_property(leg_right, "rotation_degrees", -5.0, 0.08)
	await t2.finished

	ScreenShake.shake_heavy()
	if _summon_circle: _summon_circle.pulse()
	await get_tree().create_timer(0.2).timeout
	_dismiss_summon_circle()
	if _tendrils: _tendrils.retract(0.3)
	animation_finished.emit("summon")
	play_idle()


# ── PHASE TRANSITION (boss-specific) ──────────────────────────────────────
func play_phase_transition() -> void:
	_kill_current()
	_current_anim = "phase_transition"
	if _effects: _effects.intensify()
	if _shader_ctrl: _shader_ctrl.flash_aberration(15.0, 0.4)
	ScreenShake.shake_heavy(25.0, 0.6)
	SFXManager.boss_phase_drop()
	SFXManager.play_boss_phase()

	var glitch = create_tween()
	for i in 6:
		var dir = 1.0 if i % 2 == 0 else -1.0
		glitch.tween_property(torso, "rotation_degrees", 12.0 * dir, 0.04)
		glitch.tween_property(head, "rotation_degrees", -18.0 * dir, 0.04)
		glitch.tween_property(wing_l, "rotation_degrees", -15.0 * dir, 0.04)
		glitch.tween_property(wing_r, "rotation_degrees", 15.0 * dir, 0.04)
		glitch.tween_property(sword_l, "rotation_degrees", 20.0 * dir, 0.04)
		glitch.tween_property(sword_r, "rotation_degrees", -20.0 * dir, 0.04)
		glitch.tween_property(upper_leg_l, "rotation_degrees", 10.0 * dir, 0.04)
		glitch.tween_property(upper_leg_r, "rotation_degrees", -10.0 * dir, 0.04)
		glitch.tween_property(self, "modulate", Color(2.5, 2.0, 0.3, 1.0) if i % 2 == 0 else Color(0.8, 0.3, 2.0, 1.0), 0.04)
	await glitch.finished

	var corrupt = create_tween()
	corrupt.set_parallel()
	corrupt.tween_property(wing_l, "rotation_degrees", -40.0, 0.08) \
		.set_trans(Tween.TRANS_BACK)
	corrupt.tween_property(wing_r, "rotation_degrees", 40.0, 0.08) \
		.set_trans(Tween.TRANS_BACK)
	corrupt.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1) \
		.set_trans(Tween.TRANS_BACK)
	corrupt.tween_property(self, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.05)
	corrupt.tween_property(shoulder_l, "rotation_degrees", -30.0, 0.08)
	corrupt.tween_property(shoulder_r, "rotation_degrees", 30.0, 0.08)
	await corrupt.finished

	await get_tree().create_timer(0.15).timeout

	var reform = create_tween()
	reform.set_parallel()
	reform.tween_property(self, "scale", Vector2(0.85, 0.85), 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	reform.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)
	reform.tween_property(torso, "rotation_degrees", 0.0, 0.3)
	reform.tween_property(head, "rotation_degrees", 0.0, 0.3)
	reform.tween_property(wing_l, "rotation_degrees", 0.0, 0.3)
	reform.tween_property(wing_r, "rotation_degrees", 0.0, 0.3)
	reform.tween_property(sword_l, "rotation_degrees", 0.0, 0.3)
	reform.tween_property(sword_r, "rotation_degrees", 0.0, 0.3)
	reform.tween_property(shoulder_l, "rotation_degrees", 0.0, 0.3)
	reform.tween_property(shoulder_r, "rotation_degrees", 0.0, 0.3)
	reform.tween_property(upper_leg_l, "rotation_degrees", 0.0, 0.3)
	reform.tween_property(upper_leg_r, "rotation_degrees", 0.0, 0.3)
	reform.tween_property(leg_left, "rotation_degrees", 0.0, 0.3)
	reform.tween_property(leg_right, "rotation_degrees", 0.0, 0.3)
	await reform.finished

	animation_finished.emit("phase_transition")
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
	t.tween_property(shoulder_l, "rotation_degrees", 0.0, duration)
	t.tween_property(shoulder_r, "rotation_degrees", 0.0, duration)
	t.tween_property(upper_arm_l, "rotation_degrees", 0.0, duration)
	t.tween_property(upper_arm_r, "rotation_degrees", 0.0, duration)
	t.tween_property(sword_l, "rotation_degrees", 0.0, duration)
	t.tween_property(sword_r, "rotation_degrees", 0.0, duration)
	t.tween_property(wing_l, "rotation_degrees", 0.0, duration)
	t.tween_property(wing_r, "rotation_degrees", 0.0, duration)
	t.tween_property(leg_skirt, "rotation_degrees", 0.0, duration)
	t.tween_property(upper_leg_l, "rotation_degrees", 0.0, duration)
	t.tween_property(upper_leg_r, "rotation_degrees", 0.0, duration)
	t.tween_property(leg_left, "rotation_degrees", 0.0, duration)
	t.tween_property(leg_right, "rotation_degrees", 0.0, duration)
	t.tween_property(wing_inner_l, "rotation_degrees", 0.0, duration)
	t.tween_property(wing_inner_r, "rotation_degrees", 0.0, duration)
	t.tween_property(cape, "rotation_degrees", 0.0, duration)
	t.tween_property(cape, "modulate:a", 1.0, duration)
	t.tween_property(self, "scale", Vector2(0.85, 0.85), duration)
	t.tween_property(self, "modulate", Color(1, 1, 1, 1), duration)


# ── VFX HELPERS ────────────────────────────────────────────────────────────
func _spawn_summon_circle() -> void:
	_dismiss_summon_circle()
	_summon_circle = Node2D.new()
	_summon_circle.set_script(SummoningCircleScene)
	_summon_circle.position = Vector2(0, 200)
	add_child(_summon_circle)
	_summon_circle.appear(0.3)


var _idle_hum_tween: Tween = null

func _start_idle_hum() -> void:
	_stop_idle_hum()
	_idle_hum_loop()

func _idle_hum_loop() -> void:
	if _current_anim != "idle" or not is_inside_tree():
		return
	SFXManager.play_boss_idle_hum()
	var delay = randf_range(4.0, 7.0)
	_idle_hum_tween = create_tween()
	_idle_hum_tween.tween_interval(delay)
	_idle_hum_tween.tween_callback(_idle_hum_loop)
	_active_tweens.append(_idle_hum_tween)

func _stop_idle_hum() -> void:
	if _idle_hum_tween and _idle_hum_tween.is_valid():
		_idle_hum_tween.kill()
		_idle_hum_tween = null

func _dismiss_summon_circle() -> void:
	if _summon_circle and is_instance_valid(_summon_circle):
		_summon_circle.disappear(0.3)
		_summon_circle = null
