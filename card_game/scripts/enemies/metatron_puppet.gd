extends Node2D
## Metatron puppet controller — South Park-style cutout animation
## Drives all poses via tween-based bone rotations on the sprite hierarchy.

@onready var torso: Sprite2D = $Torso
@onready var head: Sprite2D = $Torso/Neck/Head
@onready var hood: Sprite2D = $Torso/Neck/Head/Hood
@onready var neck: Sprite2D = $Torso/Neck
@onready var shoulder_l: Sprite2D = $Torso/ShoulderLeft
@onready var shoulder_r: Sprite2D = $Torso/ShoulderRight
@onready var upper_arm_l: Sprite2D = $Torso/ShoulderLeft/UpperArmLeft
@onready var upper_arm_r: Sprite2D = $Torso/ShoulderRight/UpperArmRight
@onready var lower_arm_l: Sprite2D = $Torso/ShoulderLeft/UpperArmLeft/LowerArmLeft
@onready var lower_arm_r: Sprite2D = $Torso/ShoulderRight/UpperArmRight/LowerArmRight
@onready var claw_l: Sprite2D = $Torso/ShoulderLeft/UpperArmLeft/LowerArmLeft/ClawLeft
@onready var claw_r: Sprite2D = $Torso/ShoulderRight/UpperArmRight/LowerArmRight/ClawRight
@onready var robe_l: Sprite2D = $RobeLeft
@onready var robe_r: Sprite2D = $RobeRight
# Back arms (second pair)
@onready var back_shoulder_l: Sprite2D = $Torso/BackShoulderLeft
@onready var back_shoulder_r: Sprite2D = $Torso/BackShoulderRight
@onready var back_upper_arm_l: Sprite2D = $Torso/BackShoulderLeft/BackUpperArmLeft
@onready var back_upper_arm_r: Sprite2D = $Torso/BackShoulderRight/BackUpperArmRight
@onready var back_lower_arm_l: Sprite2D = $Torso/BackShoulderLeft/BackUpperArmLeft/BackLowerArmLeft
@onready var back_lower_arm_r: Sprite2D = $Torso/BackShoulderRight/BackUpperArmRight/BackLowerArmRight
@onready var back_claw_l: Sprite2D = $Torso/BackShoulderLeft/BackUpperArmLeft/BackLowerArmLeft/BackClawLeft
@onready var back_claw_r: Sprite2D = $Torso/BackShoulderRight/BackUpperArmRight/BackLowerArmRight/BackClawRight

var _idle_tween: Tween = null
var _current_anim: String = ""
var _active_tweens: Array[Tween] = []
var _rest_positions: Dictionary = {}  # Node -> Vector2

# VFX systems
var _effects: Node2D = null          # metatron_effects.gd (eye glow + wisps)
var _shader_ctrl: Node = null        # shader_controller.gd (dissolve + aberration)
var _afterimage: Node2D = null       # afterimage.gd (ghost trails)
var _tendrils: Node2D = null         # dark_tendrils.gd (summon tendrils)
var _summon_circle: Node2D = null    # active summoning circle instance

signal animation_finished(anim_name: String)

const SummoningCircleScene = preload("res://scripts/effects/summoning_circle.gd")
const AfterimageScene = preload("res://scripts/effects/afterimage.gd")
const DarkTendrilsScene = preload("res://scripts/effects/dark_tendrils.gd")
const MetatronEffectsScene = preload("res://scripts/enemies/metatron_effects.gd")
const ShaderControllerScene = preload("res://scripts/effects/shader_controller.gd")

## Debug keys (remove for production):
## 1=idle  2=attack  3=hit  4=stagger  5=telegraph
## 6=cast  7=death   8=buff  9=taunt  0=summon  -=phase

func _ready() -> void:
	_capture_rest_positions()
	_setup_effects()
	play_idle()


func _capture_rest_positions() -> void:
	var nodes: Array = [torso, head, hood, neck, shoulder_l, shoulder_r,
		upper_arm_l, upper_arm_r, lower_arm_l, lower_arm_r, claw_l, claw_r,
		robe_l, robe_r, back_shoulder_l, back_shoulder_r,
		back_upper_arm_l, back_upper_arm_r, back_lower_arm_l, back_lower_arm_r,
		back_claw_l, back_claw_r]
	for node in nodes:
		if node:
			_rest_positions[node] = node.position


func _rest_pos(node: Node2D) -> Vector2:
	var pos: Vector2 = _rest_positions.get(node, node.position)
	return pos


func _setup_effects() -> void:
	# Eye glow + dark wisps
	_effects = Node2D.new()
	_effects.set_script(MetatronEffectsScene)
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

	# Dark tendrils — at robe/waist area
	_tendrils = Node2D.new()
	_tendrils.set_script(DarkTendrilsScene)
	_tendrils.position = Vector2(0, 100)  # below torso, at robe area
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
	_idle_tween = create_tween().set_loops()

	# Gentle float up and down
	var tp := _rest_pos(torso)
	_idle_tween.tween_property(torso, "position:y", tp.y - 6.0, 1.4) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_property(torso, "position:y", tp.y + 6.0, 1.4) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# Arms sway — left
	var arm_tween_l = create_tween().set_loops()
	arm_tween_l.tween_property(shoulder_l, "rotation_degrees", -5.0, 1.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	arm_tween_l.tween_property(shoulder_l, "rotation_degrees", 5.0, 1.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(arm_tween_l)

	# Arms sway — right
	var arm_tween_r = create_tween().set_loops()
	arm_tween_r.tween_property(shoulder_r, "rotation_degrees", 5.0, 2.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	arm_tween_r.tween_property(shoulder_r, "rotation_degrees", -5.0, 2.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(arm_tween_r)

	# Head slight tilt
	var head_tween = create_tween().set_loops()
	head_tween.tween_property(head, "rotation_degrees", -3.0, 2.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	head_tween.tween_property(head, "rotation_degrees", 3.0, 2.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(head_tween)

	# Robe sway
	var robe_tween = create_tween().set_loops()
	robe_tween.tween_property(robe_l, "rotation_degrees", -2.0, 2.2) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	robe_tween.tween_property(robe_l, "rotation_degrees", 2.0, 2.2) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(robe_tween)

	var robe_tween_r = create_tween().set_loops()
	robe_tween_r.tween_property(robe_r, "rotation_degrees", 2.0, 2.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	robe_tween_r.tween_property(robe_r, "rotation_degrees", -2.0, 2.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(robe_tween_r)

	# Claws flex
	var claw_tween = create_tween().set_loops()
	claw_tween.tween_property(claw_l, "rotation_degrees", -8.0, 1.2) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	claw_tween.tween_property(claw_l, "rotation_degrees", 8.0, 1.2) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(claw_tween)

	var claw_tween_r = create_tween().set_loops()
	claw_tween_r.tween_property(claw_r, "rotation_degrees", 8.0, 1.3) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	claw_tween_r.tween_property(claw_r, "rotation_degrees", -8.0, 1.3) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(claw_tween_r)

	# Back arms — twitchy, erratic, reaching movements (their own mind)
	# Left back arm: slow reaching upward then snapping back down
	var back_arm_l = create_tween().set_loops()
	back_arm_l.tween_property(back_shoulder_l, "rotation_degrees", -18.0, 3.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	back_arm_l.tween_property(back_shoulder_l, "rotation_degrees", -22.0, 0.08) \
		.set_trans(Tween.TRANS_BACK)  # twitch!
	back_arm_l.tween_property(back_shoulder_l, "rotation_degrees", -15.0, 0.12)
	back_arm_l.tween_interval(0.6)  # pause — hold the pose
	back_arm_l.tween_property(back_shoulder_l, "rotation_degrees", 5.0, 0.4) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	back_arm_l.tween_property(back_shoulder_l, "rotation_degrees", 0.0, 1.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(back_arm_l)

	# Right back arm: totally different rhythm — slow grasping
	var back_arm_r = create_tween().set_loops()
	back_arm_r.tween_property(back_shoulder_r, "rotation_degrees", 12.0, 2.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	back_arm_r.tween_interval(1.2)  # long creepy pause
	back_arm_r.tween_property(back_shoulder_r, "rotation_degrees", 16.0, 0.06) \
		.set_trans(Tween.TRANS_BACK)  # sudden jolt
	back_arm_r.tween_property(back_shoulder_r, "rotation_degrees", -5.0, 0.8) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	back_arm_r.tween_property(back_shoulder_r, "rotation_degrees", 0.0, 2.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(back_arm_r)

	# Back lower arms — twitchy elbow bends, like fingers tapping
	var back_elbow_l = create_tween().set_loops()
	back_elbow_l.tween_property(back_lower_arm_l, "rotation_degrees", -6.0, 0.7) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	back_elbow_l.tween_property(back_lower_arm_l, "rotation_degrees", 4.0, 0.3) \
		.set_trans(Tween.TRANS_BACK)
	back_elbow_l.tween_property(back_lower_arm_l, "rotation_degrees", -3.0, 0.5)
	back_elbow_l.tween_property(back_lower_arm_l, "rotation_degrees", 8.0, 0.15)  # snap
	back_elbow_l.tween_property(back_lower_arm_l, "rotation_degrees", 0.0, 1.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(back_elbow_l)

	var back_elbow_r = create_tween().set_loops()
	back_elbow_r.tween_interval(0.8)  # start offset from left
	back_elbow_r.tween_property(back_lower_arm_r, "rotation_degrees", 5.0, 0.6)
	back_elbow_r.tween_property(back_lower_arm_r, "rotation_degrees", -7.0, 0.12) \
		.set_trans(Tween.TRANS_BACK)
	back_elbow_r.tween_property(back_lower_arm_r, "rotation_degrees", 3.0, 0.4)
	back_elbow_r.tween_property(back_lower_arm_r, "rotation_degrees", 0.0, 1.3) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(back_elbow_r)

	# Back claws — spidery flexing, fast little grabs
	var back_claw_tw_l = create_tween().set_loops()
	back_claw_tw_l.tween_property(back_claw_l, "rotation_degrees", -15.0, 0.2)
	back_claw_tw_l.tween_property(back_claw_l, "rotation_degrees", 5.0, 0.1)
	back_claw_tw_l.tween_property(back_claw_l, "rotation_degrees", -10.0, 0.15)
	back_claw_tw_l.tween_property(back_claw_l, "rotation_degrees", 0.0, 0.8) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	back_claw_tw_l.tween_interval(1.5)  # rest, then grab again
	_active_tweens.append(back_claw_tw_l)

	var back_claw_tw_r = create_tween().set_loops()
	back_claw_tw_r.tween_interval(0.7)  # offset start
	back_claw_tw_r.tween_property(back_claw_r, "rotation_degrees", 12.0, 0.15)
	back_claw_tw_r.tween_property(back_claw_r, "rotation_degrees", -8.0, 0.1)
	back_claw_tw_r.tween_property(back_claw_r, "rotation_degrees", 15.0, 0.2)
	back_claw_tw_r.tween_property(back_claw_r, "rotation_degrees", 0.0, 1.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	back_claw_tw_r.tween_interval(2.0)  # different rest period
	_active_tweens.append(back_claw_tw_r)


# ── ATTACK ─────────────────────────────────────────────────────────────────
func play_attack() -> void:
	_kill_current()
	_current_anim = "attack"
	if _effects: _effects.intensify()
	if _afterimage: _afterimage.spawn_afterimage(self, 3, 0.06)
	SFXManager.play_boss_attack_telegraph()

	# Telegraph: lean back — front arms wind up, back arms reach UP and out
	var t1 = create_tween()
	t1.set_parallel()
	t1.tween_property(torso, "rotation_degrees", -8.0, 0.2)
	t1.tween_property(shoulder_l, "rotation_degrees", -30.0, 0.2)
	t1.tween_property(shoulder_r, "rotation_degrees", 30.0, 0.2)
	# Back arms do the OPPOSITE — reaching skyward while front coils
	t1.tween_property(back_shoulder_l, "rotation_degrees", -40.0, 0.18) \
		.set_trans(Tween.TRANS_BACK)
	t1.tween_property(back_shoulder_r, "rotation_degrees", 40.0, 0.18) \
		.set_trans(Tween.TRANS_BACK)
	t1.tween_property(back_lower_arm_l, "rotation_degrees", -15.0, 0.2)
	t1.tween_property(back_lower_arm_r, "rotation_degrees", 15.0, 0.2)
	t1.tween_property(head, "rotation_degrees", -5.0, 0.15)
	await t1.finished

	# Strike: front arms slam, back arms CLENCH inward (grabbing motion)
	var t2 = create_tween()
	t2.set_parallel()
	t2.tween_property(torso, "rotation_degrees", 10.0, 0.1).set_trans(Tween.TRANS_BACK)
	var tp := _rest_pos(torso)
	t2.tween_property(torso, "position:y", tp.y - 20.0, 0.1)
	t2.tween_property(shoulder_l, "rotation_degrees", 25.0, 0.1)
	t2.tween_property(shoulder_r, "rotation_degrees", -25.0, 0.1)
	# Back arms slam inward — crossing over the body
	t2.tween_property(back_shoulder_l, "rotation_degrees", 35.0, 0.08)
	t2.tween_property(back_shoulder_r, "rotation_degrees", -35.0, 0.08)
	t2.tween_property(back_lower_arm_l, "rotation_degrees", 25.0, 0.06)
	t2.tween_property(back_lower_arm_r, "rotation_degrees", -25.0, 0.06)
	t2.tween_property(lower_arm_l, "rotation_degrees", 15.0, 0.08)
	t2.tween_property(lower_arm_r, "rotation_degrees", -15.0, 0.08)
	t2.tween_property(claw_l, "rotation_degrees", 20.0, 0.08)
	t2.tween_property(claw_r, "rotation_degrees", -20.0, 0.08)
	t2.tween_property(back_claw_l, "rotation_degrees", 30.0, 0.06)
	t2.tween_property(back_claw_r, "rotation_degrees", -30.0, 0.06)
	t2.tween_property(head, "rotation_degrees", 8.0, 0.08)
	await t2.finished

	# Hold for impact — SCREEN SHAKE + aberration flash + SOUND
	ScreenShake.shake_heavy()
	if _shader_ctrl: _shader_ctrl.flash_aberration(10.0, 0.15)
	SFXManager.play_boss_attack_impact()
	await get_tree().create_timer(0.15).timeout

	# Return to idle
	_reset_pose(0.4)
	await get_tree().create_timer(0.45).timeout
	animation_finished.emit("attack")
	play_idle()


# ── HIT / DAMAGE ───────────────────────────────────────────────────────────
func play_hit() -> void:
	_kill_current()
	_current_anim = "hit"
	ScreenShake.shake_light()
	if _shader_ctrl: _shader_ctrl.flash_aberration(6.0, 0.1)
	SFXManager.play_boss_hit()

	# Flash white
	modulate = Color(3.0, 3.0, 3.0, 1.0)

	# Recoil back
	var tp := _rest_pos(torso)
	var t = create_tween()
	t.set_parallel()
	t.tween_property(torso, "rotation_degrees", -12.0, 0.06)
	t.tween_property(torso, "position:x", tp.x + 15.0, 0.06)
	t.tween_property(head, "rotation_degrees", -10.0, 0.05)
	t.tween_property(shoulder_l, "rotation_degrees", 15.0, 0.06)
	t.tween_property(shoulder_r, "rotation_degrees", -10.0, 0.06)
	await t.finished

	# Flash back to normal
	modulate = Color(1.0, 1.0, 1.0, 1.0)

	# Snap back
	var t2 = create_tween()
	t2.set_parallel()
	t2.tween_property(torso, "rotation_degrees", 5.0, 0.05)
	t2.tween_property(torso, "position:x", tp.x - 8.0, 0.05)
	await t2.finished

	var t3 = create_tween()
	t3.set_parallel()
	t3.tween_property(torso, "rotation_degrees", 0.0, 0.15)
	t3.tween_property(torso, "position:x", tp.x, 0.15)
	t3.tween_property(head, "rotation_degrees", 0.0, 0.15)
	t3.tween_property(shoulder_l, "rotation_degrees", 0.0, 0.15)
	t3.tween_property(shoulder_r, "rotation_degrees", 0.0, 0.15)
	await t3.finished

	animation_finished.emit("hit")
	play_idle()


# ── TELEGRAPH (intent preview) ─────────────────────────────────────────────
func play_telegraph() -> void:
	_kill_current()
	_current_anim = "telegraph"
	SFXManager.play_boss_telegraph()

	# Menacing pose: all arms spread wide, head tilted
	var t = create_tween()
	t.set_parallel()
	t.tween_property(shoulder_l, "rotation_degrees", -20.0, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(shoulder_r, "rotation_degrees", 20.0, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(back_shoulder_l, "rotation_degrees", -35.0, 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(back_shoulder_r, "rotation_degrees", 35.0, 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(lower_arm_l, "rotation_degrees", -10.0, 0.3)
	t.tween_property(lower_arm_r, "rotation_degrees", 10.0, 0.3)
	t.tween_property(head, "rotation_degrees", -5.0, 0.2)
	var tp := _rest_pos(torso)
	t.tween_property(torso, "position:y", tp.y - 10.0, 0.3)
	await t.finished

	# Hold the menacing pose with subtle pulse
	var pulse = create_tween().set_loops(3)
	pulse.tween_property(self, "scale", Vector2(0.87, 0.87), 0.3) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(self, "scale", Vector2(0.85, 0.85), 0.3) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await pulse.finished

	animation_finished.emit("telegraph")
	play_idle()


# ── CAST / SKILL ───────────────────────────────────────────────────────────
func play_cast() -> void:
	_kill_current()
	_current_anim = "cast"
	if _effects: _effects.intensify()
	_spawn_summon_circle()
	SFXManager.play_boss_cast()

	# Front arms raise to channel — back arms splay out rigid, trembling
	var t = create_tween()
	t.set_parallel()
	t.tween_property(shoulder_l, "rotation_degrees", -35.0, 0.25)
	t.tween_property(shoulder_r, "rotation_degrees", 35.0, 0.25)
	t.tween_property(upper_arm_l, "rotation_degrees", -15.0, 0.25)
	t.tween_property(upper_arm_r, "rotation_degrees", 15.0, 0.25)
	# Back arms go rigid and wide — different pose entirely
	t.tween_property(back_shoulder_l, "rotation_degrees", -15.0, 0.2)
	t.tween_property(back_shoulder_r, "rotation_degrees", 15.0, 0.2)
	t.tween_property(back_lower_arm_l, "rotation_degrees", -20.0, 0.2)
	t.tween_property(back_lower_arm_r, "rotation_degrees", 20.0, 0.2)
	t.tween_property(head, "rotation_degrees", -12.0, 0.2)
	var tp := _rest_pos(torso)
	t.tween_property(torso, "position:y", tp.y - 15.0, 0.3)
	await t.finished

	# Back arms VIBRATE while front holds the channel pose
	var tremble = create_tween().set_loops(6)
	tremble.tween_property(back_shoulder_l, "rotation_degrees", -18.0, 0.04)
	tremble.tween_property(back_shoulder_l, "rotation_degrees", -12.0, 0.04)
	var tremble_r = create_tween().set_loops(6)
	tremble_r.tween_property(back_shoulder_r, "rotation_degrees", 18.0, 0.04)
	tremble_r.tween_property(back_shoulder_r, "rotation_degrees", 12.0, 0.04)

	# Energy pulse — scale burst
	var pulse = create_tween()
	pulse.tween_property(self, "scale", Vector2(0.92, 0.92), 0.08)
	pulse.tween_property(self, "scale", Vector2(0.85, 0.85), 0.15)
	await pulse.finished

	# Front arms slam down, back arms snap to sides
	var t2 = create_tween()
	t2.set_parallel()
	t2.tween_property(shoulder_l, "rotation_degrees", 20.0, 0.1)
	t2.tween_property(shoulder_r, "rotation_degrees", -20.0, 0.1)
	t2.tween_property(back_shoulder_l, "rotation_degrees", 10.0, 0.06)
	t2.tween_property(back_shoulder_r, "rotation_degrees", -10.0, 0.06)
	t2.tween_property(back_lower_arm_l, "rotation_degrees", 15.0, 0.08)
	t2.tween_property(back_lower_arm_r, "rotation_degrees", -15.0, 0.08)
	t2.tween_property(head, "rotation_degrees", 8.0, 0.08)
	t2.tween_property(torso, "position:y", tp.y + 10.0, 0.1)
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
	if _effects: _effects.dim()
	ScreenShake.shake_heavy()
	if _shader_ctrl: _shader_ctrl.play_dissolve(1.5)
	SFXManager.play_boss_death()

	# All four arms go limp
	var t = create_tween()
	t.set_parallel()
	t.tween_property(shoulder_l, "rotation_degrees", 30.0, 0.3)
	t.tween_property(shoulder_r, "rotation_degrees", -30.0, 0.3)
	t.tween_property(back_shoulder_l, "rotation_degrees", 35.0, 0.35)
	t.tween_property(back_shoulder_r, "rotation_degrees", -35.0, 0.35)
	t.tween_property(lower_arm_l, "rotation_degrees", 20.0, 0.3)
	t.tween_property(lower_arm_r, "rotation_degrees", -20.0, 0.3)
	t.tween_property(back_lower_arm_l, "rotation_degrees", 25.0, 0.35)
	t.tween_property(back_lower_arm_r, "rotation_degrees", -25.0, 0.35)
	t.tween_property(head, "rotation_degrees", 25.0, 0.4)
	var tp := _rest_pos(torso)
	t.tween_property(torso, "position:y", tp.y + 50.0, 0.5)
	t.tween_property(robe_l, "rotation_degrees", -10.0, 0.4)
	t.tween_property(robe_r, "rotation_degrees", 10.0, 0.4)
	await t.finished

	# Collapse and fade
	var t2 = create_tween()
	t2.set_parallel()
	t2.tween_property(self, "scale", Vector2(1.0, 0.3), 0.4) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	t2.tween_property(self, "modulate:a", 0.0, 0.6)
	t2.tween_property(torso, "position:y", tp.y + 100.0, 0.4)
	await t2.finished

	animation_finished.emit("death")


# ── BUFF ───────────────────────────────────────────────────────────────────
func play_buff() -> void:
	_kill_current()
	_current_anim = "buff"
	if _effects: _effects.intensify()
	SFXManager.play_boss_buff()

	# Rise up with arms spread — powering up
	var t = create_tween()
	t.set_parallel()
	var tp := _rest_pos(torso)
	t.tween_property(torso, "position:y", tp.y - 25.0, 0.4)
	t.tween_property(shoulder_l, "rotation_degrees", -25.0, 0.3)
	t.tween_property(shoulder_r, "rotation_degrees", 25.0, 0.3)
	t.tween_property(head, "rotation_degrees", -8.0, 0.3)
	await t.finished

	# Pulsing glow effect
	var glow = create_tween().set_loops(2)
	glow.tween_property(self, "modulate", Color(1.5, 1.2, 0.8, 1.0), 0.2)
	glow.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)
	await glow.finished

	animation_finished.emit("buff")
	play_idle()


# ── TAUNT ──────────────────────────────────────────────────────────────────
func play_taunt() -> void:
	_kill_current()
	_current_anim = "taunt"
	SFXManager.play_boss_taunt()

	# Lean forward menacingly, claws spread wide
	var t = create_tween()
	t.set_parallel()
	var tp := _rest_pos(torso)
	t.tween_property(torso, "rotation_degrees", 8.0, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(torso, "position:y", tp.y + 10.0, 0.3)
	t.tween_property(shoulder_l, "rotation_degrees", -40.0, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(shoulder_r, "rotation_degrees", 40.0, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(lower_arm_l, "rotation_degrees", -20.0, 0.2)
	t.tween_property(lower_arm_r, "rotation_degrees", 20.0, 0.2)
	t.tween_property(claw_l, "rotation_degrees", -25.0, 0.15)
	t.tween_property(claw_r, "rotation_degrees", 25.0, 0.15)
	t.tween_property(head, "rotation_degrees", 10.0, 0.2)
	await t.finished

	# Shake head side to side — "tsk tsk"
	var shake = create_tween()
	for i in 3:
		shake.tween_property(head, "rotation_degrees", -8.0, 0.08)
		shake.tween_property(head, "rotation_degrees", 12.0, 0.08)
	shake.tween_property(head, "rotation_degrees", 0.0, 0.1)
	await shake.finished

	await get_tree().create_timer(0.3).timeout
	animation_finished.emit("taunt")
	play_idle()


# ── SUMMON ─────────────────────────────────────────────────────────────────
func play_summon() -> void:
	_kill_current()
	_current_anim = "summon"
	if _effects: _effects.intensify()
	_spawn_summon_circle()
	SFXManager.play_boss_summon()
	if _tendrils:
		_tendrils.emerge(0.5)
		_tendrils.writhe()

	# Rise — front arms go up, back arms do a "come hither" beckoning
	var t = create_tween()
	t.set_parallel()
	var tp := _rest_pos(torso)
	t.tween_property(torso, "position:y", tp.y - 40.0, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(shoulder_l, "rotation_degrees", -50.0, 0.4)
	t.tween_property(shoulder_r, "rotation_degrees", 50.0, 0.4)
	t.tween_property(upper_arm_l, "rotation_degrees", -20.0, 0.35)
	t.tween_property(upper_arm_r, "rotation_degrees", 20.0, 0.35)
	t.tween_property(lower_arm_l, "rotation_degrees", -15.0, 0.3)
	t.tween_property(lower_arm_r, "rotation_degrees", 15.0, 0.3)
	# Back arms reach FORWARD — beckoning something from below
	t.tween_property(back_shoulder_l, "rotation_degrees", 15.0, 0.35)
	t.tween_property(back_shoulder_r, "rotation_degrees", -15.0, 0.35)
	t.tween_property(back_lower_arm_l, "rotation_degrees", 20.0, 0.3)
	t.tween_property(back_lower_arm_r, "rotation_degrees", -20.0, 0.3)
	t.tween_property(head, "rotation_degrees", -15.0, 0.3)
	t.tween_property(robe_l, "rotation_degrees", -8.0, 0.5)
	t.tween_property(robe_r, "rotation_degrees", 8.0, 0.5)
	await t.finished

	# Back claws do rapid beckoning curls while shaking happens
	var beckon = create_tween().set_loops(4)
	beckon.tween_property(back_claw_l, "rotation_degrees", 20.0, 0.08)
	beckon.tween_property(back_claw_l, "rotation_degrees", -5.0, 0.12)
	var beckon_r = create_tween().set_loops(4)
	beckon_r.tween_property(back_claw_r, "rotation_degrees", -20.0, 0.1)
	beckon_r.tween_property(back_claw_r, "rotation_degrees", 5.0, 0.1)

	# Violent shaking while channeling — screen-shake style
	var channel = create_tween().set_loops(8)
	channel.tween_property(self, "position:x", position.x + 3, 0.03)
	channel.tween_property(self, "position:x", position.x - 3, 0.03)
	channel.tween_property(self, "position:x", position.x, 0.02)

	# Simultaneous glow pulses
	var glow = create_tween().set_loops(4)
	glow.tween_property(self, "modulate", Color(1.8, 0.6, 0.6, 1.0), 0.1)
	glow.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)
	await channel.finished

	# Slam arms down — the summon completes
	var t2 = create_tween()
	t2.set_parallel()
	t2.tween_property(shoulder_l, "rotation_degrees", 15.0, 0.08)
	t2.tween_property(shoulder_r, "rotation_degrees", -15.0, 0.08)
	t2.tween_property(torso, "position:y", tp.y + 5.0, 0.12)
	t2.tween_property(head, "rotation_degrees", 8.0, 0.08)
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
	SFXManager.boss_phase_drop()  # pitch drops each phase — gets deeper and scarier
	SFXManager.play_boss_phase()

	# Seizure / glitch — rapidly alternate properties
	var glitch = create_tween()
	for i in 6:
		var dir = 1.0 if i % 2 == 0 else -1.0
		glitch.tween_property(torso, "rotation_degrees", 15.0 * dir, 0.04)
		glitch.tween_property(head, "rotation_degrees", -20.0 * dir, 0.04)
		glitch.tween_property(self, "modulate", Color(2.0, 0.3, 0.3, 1.0) if i % 2 == 0 else Color(0.3, 0.3, 2.0, 1.0), 0.04)
	await glitch.finished

	# Explode outward
	var explode = create_tween()
	explode.set_parallel()
	explode.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1) \
		.set_trans(Tween.TRANS_BACK)
	explode.tween_property(self, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.05)
	await explode.finished

	# Hold white flash
	await get_tree().create_timer(0.15).timeout

	# Snap back — new form
	var reform = create_tween()
	reform.set_parallel()
	reform.tween_property(self, "scale", Vector2(0.85, 0.85), 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	reform.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)
	reform.tween_property(torso, "rotation_degrees", 0.0, 0.3)
	reform.tween_property(head, "rotation_degrees", 0.0, 0.3)
	await reform.finished

	animation_finished.emit("phase_transition")
	play_idle()


# ── STAGGER (heavy hit) ───────────────────────────────────────────────────
func play_stagger() -> void:
	_kill_current()
	_current_anim = "stagger"
	ScreenShake.shake(15.0, 0.4)
	if _shader_ctrl: _shader_ctrl.flash_aberration(12.0, 0.2)
	SFXManager.play_boss_stagger()

	# Big recoil + flash
	modulate = Color(4.0, 2.0, 2.0, 1.0)
	var tp := _rest_pos(torso)
	var t = create_tween()
	t.set_parallel()
	t.tween_property(torso, "rotation_degrees", -20.0, 0.05)
	t.tween_property(torso, "position", tp + Vector2(25, 30), 0.05)
	t.tween_property(head, "rotation_degrees", -25.0, 0.04)
	t.tween_property(shoulder_l, "rotation_degrees", 25.0, 0.05)
	t.tween_property(shoulder_r, "rotation_degrees", -20.0, 0.05)
	t.tween_property(lower_arm_l, "rotation_degrees", 15.0, 0.04)
	t.tween_property(lower_arm_r, "rotation_degrees", -12.0, 0.04)
	await t.finished

	modulate = Color(1.0, 1.0, 1.0, 1.0)

	# Wobble back — like barely keeping balance
	for i in 3:
		var wobble = create_tween()
		var intensity = 1.0 - (i * 0.3)
		wobble.set_parallel()
		wobble.tween_property(torso, "rotation_degrees", 8.0 * intensity, 0.12)
		wobble.tween_property(torso, "position:x", tp.x - 10.0 * intensity, 0.12)
		wobble.tween_property(head, "rotation_degrees", 10.0 * intensity, 0.1)
		await wobble.finished

		var wobble2 = create_tween()
		wobble2.set_parallel()
		wobble2.tween_property(torso, "rotation_degrees", -5.0 * intensity, 0.12)
		wobble2.tween_property(torso, "position:x", tp.x + 5.0 * intensity, 0.12)
		wobble2.tween_property(head, "rotation_degrees", -6.0 * intensity, 0.1)
		await wobble2.finished

	_reset_pose(0.3)
	await get_tree().create_timer(0.35).timeout
	animation_finished.emit("stagger")
	play_idle()


# ── UTILITY ────────────────────────────────────────────────────────────────
func _kill_current() -> void:
	_current_anim = ""
	# Kill all tracked tweens
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
	t.tween_property(hood, "rotation_degrees", 0.0, duration)
	t.tween_property(neck, "rotation_degrees", 0.0, duration)
	t.tween_property(shoulder_l, "rotation_degrees", 0.0, duration)
	t.tween_property(shoulder_r, "rotation_degrees", 0.0, duration)
	t.tween_property(upper_arm_l, "rotation_degrees", 0.0, duration)
	t.tween_property(upper_arm_r, "rotation_degrees", 0.0, duration)
	t.tween_property(lower_arm_l, "rotation_degrees", 0.0, duration)
	t.tween_property(lower_arm_r, "rotation_degrees", 0.0, duration)
	t.tween_property(claw_l, "rotation_degrees", 0.0, duration)
	t.tween_property(claw_r, "rotation_degrees", 0.0, duration)
	t.tween_property(robe_l, "rotation_degrees", 0.0, duration)
	t.tween_property(robe_r, "rotation_degrees", 0.0, duration)
	t.tween_property(back_shoulder_l, "rotation_degrees", 0.0, duration)
	t.tween_property(back_shoulder_r, "rotation_degrees", 0.0, duration)
	t.tween_property(back_upper_arm_l, "rotation_degrees", 0.0, duration)
	t.tween_property(back_upper_arm_r, "rotation_degrees", 0.0, duration)
	t.tween_property(back_lower_arm_l, "rotation_degrees", 0.0, duration)
	t.tween_property(back_lower_arm_r, "rotation_degrees", 0.0, duration)
	t.tween_property(back_claw_l, "rotation_degrees", 0.0, duration)
	t.tween_property(back_claw_r, "rotation_degrees", 0.0, duration)
	t.tween_property(self, "scale", Vector2(0.85, 0.85), duration)
	t.tween_property(self, "modulate", Color(1, 1, 1, 1), duration)


# ── VFX HELPERS ────────────────────────────────────────────────────────────
func _spawn_summon_circle() -> void:
	_dismiss_summon_circle()
	_summon_circle = Node2D.new()
	_summon_circle.set_script(SummoningCircleScene)
	_summon_circle.position = Vector2(0, 200)  # at feet
	add_child(_summon_circle)
	_summon_circle.appear(0.3)


var _idle_hum_tween: Tween = null

func _start_idle_hum() -> void:
	_stop_idle_hum()
	# Play a quiet hum every 4-6 seconds during idle
	_idle_hum_loop()

func _idle_hum_loop() -> void:
	if _current_anim != "idle" or not is_inside_tree():
		return
	SFXManager.play_boss_idle_hum()
	# Random interval for next hum
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
