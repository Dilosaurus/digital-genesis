extends Node2D
## Azrael puppet controller — Angel of Oblivion (skeletal reaper with wings, keys, dark robes)
## Drives all poses via tween-based bone rotations on the sprite hierarchy.

@onready var torso: Sprite2D = $Torso
@onready var skull_hood: Sprite2D = $Torso/SkullHood
@onready var sleeve_l: Sprite2D = $Torso/SleeveLeft
@onready var sleeve_r: Sprite2D = $Torso/SleeveRight
@onready var arm_l: Sprite2D = $Torso/SleeveLeft/ArmLeft
@onready var hand_keys: Sprite2D = $Torso/SleeveRight/HandKeys
@onready var wing_l: Sprite2D = $WingLeft
@onready var wing_r: Sprite2D = $WingRight
@onready var leg_l: Sprite2D = $LegLeft
@onready var leg_r: Sprite2D = $LegRight

var _idle_tween: Tween = null
var _current_anim: String = ""
var _active_tweens: Array[Tween] = []

# Rest positions — captured from editor layout on _ready
var _rest_positions: Dictionary = {}  # Node -> Vector2

# VFX systems
var _effects: Node2D = null          # azrael_effects.gd (soul wisps + eye glow)
var _shader_ctrl: Node = null        # shader_controller.gd (dissolve + aberration)
var _afterimage: Node2D = null       # afterimage.gd (ghost trails)
var _tendrils: Node2D = null         # dark_tendrils.gd (summon tendrils)
var _summon_circle: Node2D = null    # active summoning circle instance

signal animation_finished(anim_name: String)

const SummoningCircleScene = preload("res://scripts/effects/summoning_circle.gd")
const AfterimageScene = preload("res://scripts/effects/afterimage.gd")
const DarkTendrilsScene = preload("res://scripts/effects/dark_tendrils.gd")
const AzraelEffectsScene = preload("res://scripts/enemies/azrael_effects.gd")
const ShaderControllerScene = preload("res://scripts/effects/shader_controller.gd")

## Debug keys (remove for production):
## 1=idle  2=attack  3=hit  4=stagger  5=telegraph
## 6=cast  7=death   8=buff  9=taunt  0=summon  -=phase


func _ready() -> void:
	_capture_rest_positions()
	_setup_effects()
	play_idle()


func _capture_rest_positions() -> void:
	for node in [torso, skull_hood, sleeve_l, sleeve_r, arm_l, hand_keys, wing_l, wing_r, leg_l, leg_r]:
		_rest_positions[node] = node.position


func _rest_pos(node: Node2D) -> Vector2:
	var pos: Vector2 = _rest_positions.get(node, node.position)
	return pos


func _setup_effects() -> void:
	# Soul wisps + eye glow
	_effects = Node2D.new()
	_effects.set_script(AzraelEffectsScene)
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

	# Dark tendrils — at robe/feet area
	_tendrils = Node2D.new()
	_tendrils.set_script(DarkTendrilsScene)
	_tendrils.position = Vector2(0, 120)
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

	# Gentle float up/down
	_idle_tween.tween_property(torso, "position:y", tp.y - 8.0, 1.3) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_property(torso, "position:y", tp.y + 8.0, 1.3) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# Torso micro-jitter — skeletal looseness
	var jitter = create_tween().set_loops()
	jitter.tween_property(torso, "rotation_degrees", 1.5, 0.15)
	jitter.tween_property(torso, "rotation_degrees", -1.0, 0.12)
	jitter.tween_property(torso, "rotation_degrees", 0.5, 0.18)
	jitter.tween_property(torso, "rotation_degrees", -0.8, 0.1)
	jitter.tween_interval(randf_range(0.8, 1.5))
	_active_tweens.append(jitter)

	# Wings: slow asymmetric flap
	var wing_tween_l = create_tween().set_loops()
	wing_tween_l.tween_property(wing_l, "rotation_degrees", -8.0, 1.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	wing_tween_l.tween_property(wing_l, "rotation_degrees", 8.0, 1.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(wing_tween_l)

	var wing_tween_r = create_tween().set_loops()
	wing_tween_r.tween_property(wing_r, "rotation_degrees", 8.0, 1.75) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	wing_tween_r.tween_property(wing_r, "rotation_degrees", -8.0, 1.75) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(wing_tween_r)

	# Hand keys: pendulum sway
	var keys_tween = create_tween().set_loops()
	keys_tween.tween_property(hand_keys, "rotation_degrees", 5.0, 2.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	keys_tween.tween_property(hand_keys, "rotation_degrees", -5.0, 2.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(keys_tween)

	# Skull: occasional sudden twitch
	var skull_twitch = create_tween().set_loops()
	skull_twitch.tween_interval(2.5)
	skull_twitch.tween_property(skull_hood, "rotation_degrees", -12.0, 0.04) \
		.set_trans(Tween.TRANS_BACK)
	skull_twitch.tween_property(skull_hood, "rotation_degrees", 0.0, 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	skull_twitch.tween_interval(3.2)
	skull_twitch.tween_property(skull_hood, "rotation_degrees", 8.0, 0.04) \
		.set_trans(Tween.TRANS_BACK)
	skull_twitch.tween_property(skull_hood, "rotation_degrees", -3.0, 0.06)
	skull_twitch.tween_property(skull_hood, "rotation_degrees", 0.0, 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	skull_twitch.tween_interval(2.0)
	_active_tweens.append(skull_twitch)

	# Legs: slight skeletal sway
	var leg_l_tween = create_tween().set_loops()
	leg_l_tween.tween_property(leg_l, "rotation_degrees", -2.0, 2.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	leg_l_tween.tween_property(leg_l, "rotation_degrees", 2.0, 2.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(leg_l_tween)

	var leg_r_tween = create_tween().set_loops()
	leg_r_tween.tween_property(leg_r, "rotation_degrees", 2.0, 2.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	leg_r_tween.tween_property(leg_r, "rotation_degrees", -2.0, 2.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(leg_r_tween)

	# Left sleeve: gentle dangle sway
	var sleeve_l_tween = create_tween().set_loops()
	sleeve_l_tween.tween_property(sleeve_l, "rotation_degrees", -4.0, 1.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	sleeve_l_tween.tween_property(sleeve_l, "rotation_degrees", 4.0, 1.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(sleeve_l_tween)

	# Left arm: limp sway under sleeve
	var arm_l_tween = create_tween().set_loops()
	arm_l_tween.tween_property(arm_l, "rotation_degrees", -3.0, 1.4) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	arm_l_tween.tween_property(arm_l, "rotation_degrees", 3.0, 1.4) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(arm_l_tween)

	# Right sleeve: slow drift (key arm hangs heavy)
	var sleeve_r_tween = create_tween().set_loops()
	sleeve_r_tween.tween_property(sleeve_r, "rotation_degrees", 3.0, 2.2) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	sleeve_r_tween.tween_property(sleeve_r, "rotation_degrees", -3.0, 2.2) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tweens.append(sleeve_r_tween)


# ── ATTACK (KEY STRIKE) ──────────────────────────────────────────────────
func play_attack() -> void:
	_kill_current()
	_current_anim = "attack"
	var tp := _rest_pos(torso)
	if _effects: _effects.intensify()
	if _afterimage: _afterimage.spawn_afterimage(self, 3, 0.06)
	SFXManager.play_boss_attack_telegraph()

	# Telegraph: torso rotates back, right sleeve pulls back, keys tilt, wings fold
	var t1 = create_tween()
	t1.set_parallel()
	t1.tween_property(torso, "rotation_degrees", -10.0, 0.2)
	t1.tween_property(sleeve_r, "rotation_degrees", -35.0, 0.2)
	t1.tween_property(hand_keys, "rotation_degrees", 12.0, 0.18)
	t1.tween_property(wing_l, "rotation_degrees", -15.0, 0.2)
	t1.tween_property(wing_r, "rotation_degrees", 15.0, 0.2)
	t1.tween_property(skull_hood, "rotation_degrees", -5.0, 0.15)
	t1.tween_property(sleeve_l, "rotation_degrees", 10.0, 0.2)
	await t1.finished

	# Strike: torso snaps forward, sleeve_r sweeps, wings flare
	var t2 = create_tween()
	t2.set_parallel()
	t2.tween_property(torso, "rotation_degrees", 12.0, 0.08).set_trans(Tween.TRANS_BACK)
	t2.tween_property(torso, "position:y", tp.y - 15.0, 0.08)
	t2.tween_property(sleeve_r, "rotation_degrees", 45.0, 0.08)
	t2.tween_property(hand_keys, "rotation_degrees", -8.0, 0.06)
	t2.tween_property(wing_l, "rotation_degrees", 25.0, 0.1) \
		.set_trans(Tween.TRANS_BACK)
	t2.tween_property(wing_r, "rotation_degrees", -25.0, 0.1) \
		.set_trans(Tween.TRANS_BACK)
	t2.tween_property(skull_hood, "rotation_degrees", 8.0, 0.06)
	t2.tween_property(sleeve_l, "rotation_degrees", -15.0, 0.08)
	t2.tween_property(arm_l, "rotation_degrees", 10.0, 0.07)
	await t2.finished

	# Impact
	ScreenShake.shake_heavy()
	if _shader_ctrl: _shader_ctrl.flash_aberration(10.0, 0.15)
	SFXManager.play_boss_attack_impact()
	await get_tree().create_timer(0.15).timeout

	# Recovery to idle
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

	# Flash white
	modulate = Color(3.0, 3.0, 3.0, 1.0)

	# Recoil back
	var t = create_tween()
	t.set_parallel()
	t.tween_property(torso, "rotation_degrees", -12.0, 0.06)
	t.tween_property(torso, "position:x", tp.x + 15.0, 0.06)
	t.tween_property(skull_hood, "rotation_degrees", -10.0, 0.05)
	t.tween_property(sleeve_l, "rotation_degrees", 15.0, 0.06)
	t.tween_property(sleeve_r, "rotation_degrees", -10.0, 0.06)
	t.tween_property(wing_l, "rotation_degrees", 12.0, 0.06)
	t.tween_property(wing_r, "rotation_degrees", -12.0, 0.06)
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
	t3.tween_property(skull_hood, "rotation_degrees", 0.0, 0.15)
	t3.tween_property(sleeve_l, "rotation_degrees", 0.0, 0.15)
	t3.tween_property(sleeve_r, "rotation_degrees", 0.0, 0.15)
	t3.tween_property(wing_l, "rotation_degrees", 0.0, 0.15)
	t3.tween_property(wing_r, "rotation_degrees", 0.0, 0.15)
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

	# Big recoil + flash
	modulate = Color(4.0, 2.0, 2.0, 1.0)
	var t = create_tween()
	t.set_parallel()
	t.tween_property(torso, "rotation_degrees", -20.0, 0.05)
	t.tween_property(torso, "position", tp + Vector2(25, 30), 0.05)
	t.tween_property(skull_hood, "rotation_degrees", -25.0, 0.04)
	t.tween_property(sleeve_l, "rotation_degrees", 25.0, 0.05)
	t.tween_property(sleeve_r, "rotation_degrees", -20.0, 0.05)
	t.tween_property(arm_l, "rotation_degrees", 15.0, 0.04)
	t.tween_property(hand_keys, "rotation_degrees", -12.0, 0.04)
	t.tween_property(wing_l, "rotation_degrees", 20.0, 0.05)
	t.tween_property(wing_r, "rotation_degrees", -18.0, 0.05)
	await t.finished

	modulate = Color(1.0, 1.0, 1.0, 1.0)

	# Wobble back — barely keeping balance
	for i in 3:
		var wobble = create_tween()
		var intensity = 1.0 - (i * 0.3)
		wobble.set_parallel()
		wobble.tween_property(torso, "rotation_degrees", 8.0 * intensity, 0.12)
		wobble.tween_property(torso, "position:x", tp.x - 10.0 * intensity, 0.12)
		wobble.tween_property(skull_hood, "rotation_degrees", 10.0 * intensity, 0.1)
		await wobble.finished

		var wobble2 = create_tween()
		wobble2.set_parallel()
		wobble2.tween_property(torso, "rotation_degrees", -5.0 * intensity, 0.12)
		wobble2.tween_property(torso, "position:x", tp.x + 5.0 * intensity, 0.12)
		wobble2.tween_property(skull_hood, "rotation_degrees", -6.0 * intensity, 0.1)
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

	# Wings spread wide, skull tilts, menacing pose
	var t = create_tween()
	t.set_parallel()
	t.tween_property(wing_l, "rotation_degrees", -30.0, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(wing_r, "rotation_degrees", 30.0, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(sleeve_l, "rotation_degrees", -15.0, 0.25)
	t.tween_property(sleeve_r, "rotation_degrees", 15.0, 0.25)
	t.tween_property(hand_keys, "rotation_degrees", 8.0, 0.25)
	t.tween_property(skull_hood, "rotation_degrees", -8.0, 0.2)
	t.tween_property(torso, "position:y", tp.y - 15.0, 0.3)
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
	var tp := _rest_pos(torso)
	if _effects: _effects.intensify()
	_spawn_summon_circle()
	SFXManager.play_boss_cast()

	# Arms raise to channel, wings flutter up
	var t = create_tween()
	t.set_parallel()
	t.tween_property(sleeve_l, "rotation_degrees", -40.0, 0.25)
	t.tween_property(sleeve_r, "rotation_degrees", 40.0, 0.25)
	t.tween_property(arm_l, "rotation_degrees", -10.0, 0.2)
	t.tween_property(hand_keys, "rotation_degrees", -5.0, 0.2)
	t.tween_property(wing_l, "rotation_degrees", -20.0, 0.3)
	t.tween_property(wing_r, "rotation_degrees", 20.0, 0.3)
	t.tween_property(skull_hood, "rotation_degrees", -12.0, 0.2)
	t.tween_property(torso, "position:y", tp.y - 20.0, 0.3)
	await t.finished

	# Wings flutter rapidly while channeling
	var flutter_l = create_tween().set_loops(6)
	flutter_l.tween_property(wing_l, "rotation_degrees", -25.0, 0.04)
	flutter_l.tween_property(wing_l, "rotation_degrees", -15.0, 0.04)
	var flutter_r = create_tween().set_loops(6)
	flutter_r.tween_property(wing_r, "rotation_degrees", 25.0, 0.04)
	flutter_r.tween_property(wing_r, "rotation_degrees", 15.0, 0.04)

	# Energy pulse — scale burst
	var pulse = create_tween()
	pulse.tween_property(self, "scale", Vector2(0.92, 0.92), 0.08)
	pulse.tween_property(self, "scale", Vector2(0.85, 0.85), 0.15)
	await pulse.finished

	# Arms slam down — cast completes
	var t2 = create_tween()
	t2.set_parallel()
	t2.tween_property(sleeve_l, "rotation_degrees", 20.0, 0.1)
	t2.tween_property(sleeve_r, "rotation_degrees", -20.0, 0.1)
	t2.tween_property(arm_l, "rotation_degrees", 12.0, 0.08)
	t2.tween_property(hand_keys, "rotation_degrees", -12.0, 0.08)
	t2.tween_property(skull_hood, "rotation_degrees", 8.0, 0.08)
	t2.tween_property(torso, "position:y", tp.y + 10.0, 0.1)
	t2.tween_property(wing_l, "rotation_degrees", 5.0, 0.1)
	t2.tween_property(wing_r, "rotation_degrees", -5.0, 0.1)
	await t2.finished

	ScreenShake.shake()
	if _summon_circle: _summon_circle.pulse()
	await get_tree().create_timer(0.2).timeout
	_dismiss_summon_circle()
	animation_finished.emit("cast")
	play_idle()


# ── DEATH (BONE SCATTER) ──────────────────────────────────────────────────
func play_death() -> void:
	_kill_current()
	_current_anim = "death"
	var tp := _rest_pos(torso)
	var llp := _rest_pos(leg_l)
	var lrp := _rest_pos(leg_r)
	var hkp := _rest_pos(hand_keys)
	var shp := _rest_pos(skull_hood)
	if _effects: _effects.dim()
	ScreenShake.shake_heavy()
	if _shader_ctrl: _shader_ctrl.play_dissolve(1.8)
	SFXManager.play_boss_death()

	# Phase 1: torso scatters outward
	var t_core = create_tween()
	t_core.set_parallel()
	t_core.tween_property(torso, "position", tp + Vector2(randf_range(-40, 40), randf_range(-60, -20)), 0.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t_core.tween_property(torso, "rotation_degrees", randf_range(-45, 45), 0.6)
	t_core.tween_property(leg_l, "position", llp + Vector2(randf_range(-40, -10), randf_range(30, 80)), 0.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t_core.tween_property(leg_l, "rotation_degrees", randf_range(-40, 40), 0.6)
	t_core.tween_property(leg_r, "position", lrp + Vector2(randf_range(10, 40), randf_range(30, 80)), 0.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t_core.tween_property(leg_r, "rotation_degrees", randf_range(-40, 40), 0.6)

	# Phase 2: limbs scatter
	await get_tree().create_timer(0.1).timeout
	var t_limbs = create_tween()
	t_limbs.set_parallel()
	t_limbs.tween_property(sleeve_l, "rotation_degrees", randf_range(-80, -40), 0.5)
	t_limbs.tween_property(sleeve_r, "rotation_degrees", randf_range(40, 80), 0.5)
	t_limbs.tween_property(arm_l, "rotation_degrees", randf_range(-70, -30), 0.5)
	t_limbs.tween_property(hand_keys, "rotation_degrees", randf_range(-90, 90), 0.5)
	t_limbs.tween_property(hand_keys, "position", hkp + Vector2(randf_range(40, 100), randf_range(20, 80)), 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Wings crumple — scale to 0
	t_limbs.tween_property(wing_l, "scale", Vector2(0.0, 0.0), 0.5) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t_limbs.tween_property(wing_r, "scale", Vector2(0.0, 0.0), 0.5) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t_limbs.tween_property(wing_l, "rotation_degrees", randf_range(-60, -30), 0.5)
	t_limbs.tween_property(wing_r, "rotation_degrees", randf_range(30, 60), 0.5)

	# Phase 3: skull launches last
	await get_tree().create_timer(0.1).timeout
	var t_skull = create_tween()
	t_skull.set_parallel()
	t_skull.tween_property(skull_hood, "rotation_degrees", randf_range(-90, 90), 0.4) \
		.set_trans(Tween.TRANS_BACK)
	t_skull.tween_property(skull_hood, "position", shp + Vector2(randf_range(-50, 50), randf_range(-80, -30)), 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Final fade
	await get_tree().create_timer(0.4).timeout
	var t_fade = create_tween()
	t_fade.set_parallel()
	t_fade.tween_property(self, "modulate:a", 0.0, 0.8)
	t_fade.tween_property(self, "scale", Vector2(0.6, 0.6), 0.8) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await t_fade.finished

	animation_finished.emit("death")


# ── BUFF ───────────────────────────────────────────────────────────────────
func play_buff() -> void:
	_kill_current()
	_current_anim = "buff"
	var tp := _rest_pos(torso)
	if _effects: _effects.intensify()
	SFXManager.play_boss_buff()

	# Rise up with wings spread wide — powering up
	var t = create_tween()
	t.set_parallel()
	t.tween_property(torso, "position:y", tp.y - 30.0, 0.4)
	t.tween_property(wing_l, "rotation_degrees", -35.0, 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(wing_r, "rotation_degrees", 35.0, 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(sleeve_l, "rotation_degrees", -20.0, 0.3)
	t.tween_property(sleeve_r, "rotation_degrees", 20.0, 0.3)
	t.tween_property(skull_hood, "rotation_degrees", -8.0, 0.3)
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
	var tp := _rest_pos(torso)
	SFXManager.play_boss_taunt()

	# Lean forward, keys raised menacingly, skull tilts
	var t = create_tween()
	t.set_parallel()
	t.tween_property(torso, "rotation_degrees", 10.0, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(torso, "position:y", tp.y + 5.0, 0.3)
	t.tween_property(sleeve_r, "rotation_degrees", -30.0, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(hand_keys, "rotation_degrees", 15.0, 0.2)
	t.tween_property(sleeve_l, "rotation_degrees", 8.0, 0.25)
	t.tween_property(arm_l, "rotation_degrees", 5.0, 0.2)
	t.tween_property(skull_hood, "rotation_degrees", 12.0, 0.2)
	t.tween_property(wing_l, "rotation_degrees", -10.0, 0.3)
	t.tween_property(wing_r, "rotation_degrees", 10.0, 0.3)
	await t.finished

	# Skull tilts side to side — menacing "I see you"
	var tilt = create_tween()
	for i in 3:
		tilt.tween_property(skull_hood, "rotation_degrees", -8.0, 0.1)
		tilt.tween_property(skull_hood, "rotation_degrees", 14.0, 0.1)
	tilt.tween_property(skull_hood, "rotation_degrees", 0.0, 0.12)
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

	# Rise high — arms spread wide, wings fully extended
	var t = create_tween()
	t.set_parallel()
	t.tween_property(torso, "position:y", tp.y - 45.0, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(sleeve_l, "rotation_degrees", -50.0, 0.4)
	t.tween_property(sleeve_r, "rotation_degrees", 50.0, 0.4)
	t.tween_property(arm_l, "rotation_degrees", -15.0, 0.3)
	t.tween_property(hand_keys, "rotation_degrees", -10.0, 0.3)
	t.tween_property(wing_l, "rotation_degrees", -40.0, 0.45) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(wing_r, "rotation_degrees", 40.0, 0.45) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(skull_hood, "rotation_degrees", -15.0, 0.3)
	await t.finished

	# Beckoning motion — arms curl inward repeatedly
	var beckon_l = create_tween().set_loops(4)
	beckon_l.tween_property(arm_l, "rotation_degrees", -25.0, 0.1)
	beckon_l.tween_property(arm_l, "rotation_degrees", -10.0, 0.15)
	var beckon_r = create_tween().set_loops(4)
	beckon_r.tween_property(hand_keys, "rotation_degrees", 25.0, 0.12)
	beckon_r.tween_property(hand_keys, "rotation_degrees", 10.0, 0.13)

	# Violent channeling shake
	var channel = create_tween().set_loops(8)
	channel.tween_property(self, "position:x", position.x + 3, 0.03)
	channel.tween_property(self, "position:x", position.x - 3, 0.03)
	channel.tween_property(self, "position:x", position.x, 0.02)

	# Dark glow pulses
	var glow = create_tween().set_loops(4)
	glow.tween_property(self, "modulate", Color(1.8, 0.5, 0.8, 1.0), 0.1)
	glow.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)
	await channel.finished

	# Slam down — summon completes
	var t2 = create_tween()
	t2.set_parallel()
	t2.tween_property(sleeve_l, "rotation_degrees", 15.0, 0.08)
	t2.tween_property(sleeve_r, "rotation_degrees", -15.0, 0.08)
	t2.tween_property(arm_l, "rotation_degrees", 10.0, 0.06)
	t2.tween_property(hand_keys, "rotation_degrees", -10.0, 0.06)
	t2.tween_property(torso, "position:y", tp.y + 10.0, 0.12)
	t2.tween_property(skull_hood, "rotation_degrees", 8.0, 0.08)
	t2.tween_property(wing_l, "rotation_degrees", 5.0, 0.1)
	t2.tween_property(wing_r, "rotation_degrees", -5.0, 0.1)
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

	# Seizure / glitch — rapidly alternate properties
	var glitch = create_tween()
	for i in 6:
		var dir = 1.0 if i % 2 == 0 else -1.0
		glitch.tween_property(torso, "rotation_degrees", 15.0 * dir, 0.04)
		glitch.tween_property(skull_hood, "rotation_degrees", -20.0 * dir, 0.04)
		glitch.tween_property(wing_l, "rotation_degrees", 25.0 * dir, 0.04)
		glitch.tween_property(wing_r, "rotation_degrees", -25.0 * dir, 0.04)
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

	# Snap back — reformed
	var reform = create_tween()
	reform.set_parallel()
	reform.tween_property(self, "scale", Vector2(0.85, 0.85), 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	reform.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)
	reform.tween_property(torso, "rotation_degrees", 0.0, 0.3)
	reform.tween_property(skull_hood, "rotation_degrees", 0.0, 0.3)
	reform.tween_property(wing_l, "rotation_degrees", 0.0, 0.3)
	reform.tween_property(wing_r, "rotation_degrees", 0.0, 0.3)
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
	t.tween_property(skull_hood, "rotation_degrees", 0.0, duration)
	t.tween_property(skull_hood, "position", _rest_pos(skull_hood), duration)
	t.tween_property(sleeve_l, "rotation_degrees", 0.0, duration)
	t.tween_property(sleeve_r, "rotation_degrees", 0.0, duration)
	t.tween_property(arm_l, "rotation_degrees", 0.0, duration)
	t.tween_property(hand_keys, "rotation_degrees", 0.0, duration)
	t.tween_property(hand_keys, "position", _rest_pos(hand_keys), duration)
	t.tween_property(wing_l, "rotation_degrees", 0.0, duration)
	t.tween_property(wing_r, "rotation_degrees", 0.0, duration)
	t.tween_property(wing_l, "scale", Vector2(1.0, 1.0), duration)
	t.tween_property(wing_r, "scale", Vector2(1.0, 1.0), duration)
	t.tween_property(leg_l, "rotation_degrees", 0.0, duration)
	t.tween_property(leg_l, "position", _rest_pos(leg_l), duration)
	t.tween_property(leg_r, "rotation_degrees", 0.0, duration)
	t.tween_property(leg_r, "position", _rest_pos(leg_r), duration)
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
