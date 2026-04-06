class_name PlayerPuppet
extends PuppetBase
## Player-side character puppet for combat.
## Loads body parts from res://assets/characters/{character_id}/parts/
## Standard parts: head, torso, arm_left, arm_right, leg_left, leg_right, weapon, effect_layer
## Parts are optional — missing textures are silently skipped.

# Character identity
var character_id: String = ""
var character_color: Color = Color.WHITE

# Body part sprites — created in code, positioned per character config
var torso: Sprite2D
var head: Sprite2D
var arm_l: Sprite2D
var arm_r: Sprite2D
var leg_l: Sprite2D
var leg_r: Sprite2D
var weapon: Sprite2D
var back_layer: Sprite2D  # Cape, wings, aura, etc.

# Pivot points for arm rotation
var shoulder_l_pivot: Node2D
var shoulder_r_pivot: Node2D

# Effect layer
var aura_particles: GPUParticles2D
var cast_particles: GPUParticles2D

# Layout config per character (positions relative to torso center)
# Override with CHARACTER_CONFIGS[id] or load from file
const DEFAULT_LAYOUT = {
	"torso":    Vector2(0, 0),
	"head":     Vector2(0, -90),
	"arm_l":    Vector2(-45, -50),
	"arm_r":    Vector2(45, -50),
	"leg_l":    Vector2(-20, 70),
	"leg_r":    Vector2(20, 70),
	"weapon":   Vector2(55, -30),
	"back":     Vector2(0, -40),
}

# Per-character layout overrides and personality
const CHARACTER_CONFIGS = {
	"netrunner": {
		"layout": {
			"torso":  Vector2(0, 0),
			"head":   Vector2(0, -85),
			"arm_l":  Vector2(-42, -48),
			"arm_r":  Vector2(42, -48),
			"leg_l":  Vector2(-18, 68),
			"leg_r":  Vector2(18, 68),
			"weapon": Vector2(50, -20),  # data gauntlet
			"back":   Vector2(0, -35),   # hood/cloak
		},
		"idle_speed": 1.0,
		"idle_sway": 3.0,      # breathing amplitude
		"attack_style": "fast",  # quick jab
		"color": Color(0.3, 0.9, 1.0),
	},
	"sysadmin": {
		"layout": {
			"torso":  Vector2(0, 0),
			"head":   Vector2(0, -95),
			"arm_l":  Vector2(-50, -55),
			"arm_r":  Vector2(50, -55),
			"leg_l":  Vector2(-22, 75),
			"leg_r":  Vector2(22, 75),
			"weapon": Vector2(60, -40),  # shield module
			"back":   Vector2(0, -50),   # heavy armor plate
		},
		"idle_speed": 1.3,
		"idle_sway": 2.0,      # heavy, less movement
		"attack_style": "heavy",
		"color": Color(0.2, 0.7, 0.3),
	},
	"cryptomancer": {
		"layout": {
			"torso":  Vector2(0, 0),
			"head":   Vector2(0, -88),
			"arm_l":  Vector2(-40, -45),
			"arm_r":  Vector2(40, -45),
			"leg_l":  Vector2(-16, 65),
			"leg_r":  Vector2(16, 65),
			"weapon": Vector2(45, -60),  # floating cipher
			"back":   Vector2(0, -42),   # rune circles
		},
		"idle_speed": 0.9,
		"idle_sway": 4.0,      # floaty, mystical
		"attack_style": "cast",
		"color": Color(0.8, 0.4, 1.0),
	},
	"white_hat": {
		"layout": {
			"torso":  Vector2(0, 0),
			"head":   Vector2(0, -90),
			"arm_l":  Vector2(-44, -50),
			"arm_r":  Vector2(44, -50),
			"leg_l":  Vector2(-18, 70),
			"leg_r":  Vector2(18, 70),
			"weapon": Vector2(52, -35),  # HUD ring tool
			"back":   Vector2(0, -45),   # coat
		},
		"idle_speed": 1.1,
		"idle_sway": 2.5,
		"attack_style": "precise",
		"color": Color(1.0, 0.95, 0.8),
	},
	"technomancer": {
		"layout": {
			"torso":  Vector2(0, 0),
			"head":   Vector2(0, -86),
			"arm_l":  Vector2(-43, -47),
			"arm_r":  Vector2(43, -47),
			"leg_l":  Vector2(-19, 67),
			"leg_r":  Vector2(19, 67),
			"weapon": Vector2(48, -55),  # daemon fragments orbit
			"back":   Vector2(0, -38),   # energy aura
		},
		"idle_speed": 0.85,
		"idle_sway": 5.0,      # chaotic energy, lots of movement
		"attack_style": "summon",
		"color": Color(0.9, 0.2, 0.8),
	},
}

# Part names in render order (back to front)
const PART_ORDER = ["back", "leg_l", "leg_r", "torso", "arm_l", "arm_r", "head", "weapon"]


var _is_fullbody_mode := false
var fullbody_sprite: Sprite2D

func setup_character(id: String) -> void:
	character_id = id
	var config = CHARACTER_CONFIGS.get(id, {})
	character_color = config.get("color", Color.WHITE)

	# Check for fullbody sprite first (simpler mode)
	var fullbody_path := "res://assets/characters/%s/fullbody.png" % id
	if ResourceLoader.exists(fullbody_path):
		_setup_fullbody(fullbody_path)
		return

	var layout = config.get("layout", DEFAULT_LAYOUT)
	_build_skeleton(layout)
	_load_textures()
	_setup_particles()
	_all_bones = _get_bones()
	_capture_rest_state()
	play_idle()


func _setup_fullbody(tex_path: String) -> void:
	_is_fullbody_mode = true
	fullbody_sprite = Sprite2D.new()
	fullbody_sprite.name = "FullBody"
	fullbody_sprite.texture = load(tex_path)
	# Anchor at bottom-center so animations pivot naturally
	fullbody_sprite.offset.y = -fullbody_sprite.texture.get_height() / 2.0
	add_child(fullbody_sprite)

	# Simple particles
	_setup_particles()
	_all_bones = [fullbody_sprite]
	_capture_rest_state()
	play_idle()


func _build_skeleton(layout: Dictionary) -> void:
	# Back layer (behind everything)
	back_layer = _make_part("BackLayer", layout.get("back", DEFAULT_LAYOUT["back"]), -3)

	# Legs
	leg_l = _make_part("LegLeft", layout.get("leg_l", DEFAULT_LAYOUT["leg_l"]), -1)
	leg_r = _make_part("LegRight", layout.get("leg_r", DEFAULT_LAYOUT["leg_r"]), -1)

	# Torso (most things parent to this)
	torso = _make_part("Torso", layout.get("torso", DEFAULT_LAYOUT["torso"]), 0)

	# Shoulder pivots for arm rotation
	shoulder_l_pivot = Node2D.new()
	shoulder_l_pivot.name = "ShoulderLPivot"
	shoulder_l_pivot.position = layout.get("arm_l", DEFAULT_LAYOUT["arm_l"])
	torso.add_child(shoulder_l_pivot)

	shoulder_r_pivot = Node2D.new()
	shoulder_r_pivot.name = "ShoulderRPivot"
	shoulder_r_pivot.position = layout.get("arm_r", DEFAULT_LAYOUT["arm_r"])
	torso.add_child(shoulder_r_pivot)

	# Arms (parented to shoulder pivots)
	arm_l = Sprite2D.new()
	arm_l.name = "ArmLeft"
	arm_l.offset = Vector2(0, 30)  # pivot at shoulder
	shoulder_l_pivot.add_child(arm_l)

	arm_r = Sprite2D.new()
	arm_r.name = "ArmRight"
	arm_r.offset = Vector2(0, 30)
	shoulder_r_pivot.add_child(arm_r)

	# Head
	head = _make_part("Head", layout.get("head", DEFAULT_LAYOUT["head"]), 2)

	# Weapon / held item (highest z)
	weapon = _make_part("Weapon", layout.get("weapon", DEFAULT_LAYOUT["weapon"]), 3)


func _make_part(part_name: String, pos: Vector2, z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = part_name
	sprite.position = pos
	sprite.z_index = z
	add_child(sprite)
	return sprite


func _load_textures() -> void:
	var base_path := "res://assets/characters/%s/parts/" % character_id
	var parts: Dictionary = {
		"torso": torso,
		"head": head,
		"arm_left": arm_l,
		"arm_right": arm_r,
		"leg_left": leg_l,
		"leg_right": leg_r,
		"weapon": weapon,
		"back": back_layer,
	}
	for part_name in parts:
		var sprite: Sprite2D = parts[part_name]
		var tex_path: String = base_path + str(part_name) + ".png"
		if ResourceLoader.exists(tex_path):
			sprite.texture = load(tex_path)
		else:
			# No texture — create a placeholder colored shape
			_apply_placeholder(sprite, part_name)


func _apply_placeholder(sprite: Sprite2D, part_name: String) -> void:
	# Procedural placeholder until art is generated
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var col: Color = character_color
	var size := Vector2i(64, 64)

	match part_name:
		"torso":
			size = Vector2i(60, 80)
			col = col.darkened(0.2)
		"head":
			size = Vector2i(48, 52)
		"arm_left", "arm_right":
			size = Vector2i(24, 60)
			col = col.darkened(0.1)
		"leg_left", "leg_right":
			size = Vector2i(28, 70)
			col = col.darkened(0.3)
		"weapon":
			size = Vector2i(20, 50)
			col = col.lightened(0.3)
		"back":
			size = Vector2i(80, 90)
			col = col.darkened(0.4)
			col.a = 0.5

	img = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(col)
	# Round corners slightly
	for x in range(size.x):
		for y in range(size.y):
			var dx: int = mini(x, size.x - 1 - x)
			var dy: int = mini(y, size.y - 1 - y)
			if dx + dy < 4:
				img.set_pixel(x, y, Color.TRANSPARENT)

	sprite.texture = ImageTexture.create_from_image(img)


func _setup_particles() -> void:
	# Ambient aura particles
	aura_particles = GPUParticles2D.new()
	aura_particles.name = "AuraParticles"
	aura_particles.amount = 12
	aura_particles.lifetime = 2.0
	aura_particles.emitting = false
	aura_particles.z_index = -2

	var aura_mat := ParticleProcessMaterial.new()
	aura_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	aura_mat.emission_sphere_radius = 40.0
	aura_mat.direction = Vector3(0, -1, 0)
	aura_mat.initial_velocity_min = 10.0
	aura_mat.initial_velocity_max = 25.0
	aura_mat.gravity = Vector3.ZERO
	aura_mat.scale_min = 2.0
	aura_mat.scale_max = 5.0
	aura_mat.color = Color(character_color, 0.4)
	aura_particles.process_material = aura_mat
	add_child(aura_particles)

	# Cast burst particles
	cast_particles = GPUParticles2D.new()
	cast_particles.name = "CastParticles"
	cast_particles.amount = 20
	cast_particles.lifetime = 0.6
	cast_particles.one_shot = true
	cast_particles.emitting = false
	cast_particles.z_index = 4

	var cast_mat := ParticleProcessMaterial.new()
	cast_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	cast_mat.emission_sphere_radius = 15.0
	cast_mat.direction = Vector3(0, -1, 0)
	cast_mat.spread = 180.0
	cast_mat.initial_velocity_min = 50.0
	cast_mat.initial_velocity_max = 120.0
	cast_mat.gravity = Vector3(0, 50, 0)
	cast_mat.scale_min = 3.0
	cast_mat.scale_max = 6.0
	cast_mat.color = Color(character_color, 0.8)
	cast_particles.process_material = cast_mat
	add_child(cast_particles)


func _get_bones() -> Array[Node2D]:
	var bones: Array[Node2D] = []
	for node in [torso, head, arm_l, arm_r, leg_l, leg_r, weapon, back_layer, shoulder_l_pivot, shoulder_r_pivot]:
		if node:
			bones.append(node)
	return bones


# ── IDLE ──────────────────────────────────────────────────────────────────

func _idle_loop() -> void:
	if _current_anim != "idle" or not is_inside_tree():
		return

	if _is_fullbody_mode:
		_idle_loop_fullbody()
		return

	var config = CHARACTER_CONFIGS.get(character_id, {})
	var speed: float = config.get("idle_speed", 1.0)
	var sway: float = config.get("idle_sway", 3.0)
	var tp: Vector2 = _rest_pos(torso)

	# Breathing — torso bob
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(torso, "position:y", tp.y - sway, 1.2 * speed) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_property(torso, "position:y", tp.y + sway * 0.5, 1.2 * speed) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# Head subtle tilt
	var head_tw := create_tween().set_loops()
	head_tw.tween_property(head, "rotation_degrees", -1.5, 2.5 * speed) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	head_tw.tween_property(head, "rotation_degrees", 1.5, 2.5 * speed) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_track(head_tw)

	# Arm sway
	var arm_tw := create_tween().set_loops()
	arm_tw.set_parallel()
	arm_tw.tween_property(shoulder_l_pivot, "rotation_degrees", -2.0, 2.0 * speed) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	arm_tw.tween_property(shoulder_r_pivot, "rotation_degrees", 2.0, 2.0 * speed) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	arm_tw.chain()
	arm_tw.set_parallel()
	arm_tw.tween_property(shoulder_l_pivot, "rotation_degrees", 2.0, 2.0 * speed) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	arm_tw.tween_property(shoulder_r_pivot, "rotation_degrees", -2.0, 2.0 * speed) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_track(arm_tw)

	# Weapon float (if present)
	if weapon and weapon.texture:
		var wtw := create_tween().set_loops()
		var wp: Vector2 = _rest_pos(weapon)
		wtw.tween_property(weapon, "position:y", wp.y - 4.0, 1.8 * speed) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		wtw.tween_property(weapon, "position:y", wp.y + 4.0, 1.8 * speed) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_track(wtw)

	# Back layer sway (cape/aura)
	if back_layer and back_layer.texture:
		var btw := create_tween().set_loops()
		btw.tween_property(back_layer, "rotation_degrees", -1.5, 3.0 * speed) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		btw.tween_property(back_layer, "rotation_degrees", 1.5, 3.0 * speed) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_track(btw)

	# Aura particles on during idle
	aura_particles.emitting = true


func _idle_loop_fullbody() -> void:
	var rp: Vector2 = _rest_pos(fullbody_sprite)
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(fullbody_sprite, "position:y", rp.y - 3.0, 1.3) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_property(fullbody_sprite, "position:y", rp.y + 1.5, 1.3) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	var rot_tw := create_tween().set_loops()
	rot_tw.tween_property(fullbody_sprite, "rotation_degrees", -0.8, 2.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	rot_tw.tween_property(fullbody_sprite, "rotation_degrees", 0.8, 2.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_track(rot_tw)
	aura_particles.emitting = true


func _attack_fullbody() -> void:
	var tw := create_tween()
	# Lunge forward
	tw.tween_property(fullbody_sprite, "position:x", _rest_pos(fullbody_sprite).x + 40.0, 0.12) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(fullbody_sprite, "scale", Vector2(1.1, 0.95), 0.08)
	# Return
	tw.tween_property(fullbody_sprite, "position:x", _rest_pos(fullbody_sprite).x, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(fullbody_sprite, "scale", Vector2.ONE, 0.15)
	tw.tween_callback(play_idle)
	tw.tween_callback(_emit_finished.bind("attack"))
	_track(tw)


# ── ATTACK ────────────────────────────────────────────────────────────────

func play_attack() -> void:
	_kill_current()
	_current_anim = "attack"
	aura_particles.emitting = false

	if _is_fullbody_mode:
		_attack_fullbody()
		return

	var config = CHARACTER_CONFIGS.get(character_id, {})
	var style: String = config.get("attack_style", "fast")

	match style:
		"fast":   _attack_fast()
		"heavy":  _attack_heavy()
		"cast":   _attack_cast()
		"precise": _attack_precise()
		"summon": _attack_summon()
		_:        _attack_fast()


func _attack_fast() -> void:
	# Quick jab — arm swing + lunge
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(shoulder_r_pivot, "rotation_degrees", -45.0, 0.12) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(torso, "position:x", _rest_pos(torso).x + 25.0, 0.12) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(head, "rotation_degrees", 5.0, 0.1)
	tw.chain()
	tw.set_parallel()
	tw.tween_property(shoulder_r_pivot, "rotation_degrees", 0.0, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(torso, "position:x", _rest_pos(torso).x, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(head, "rotation_degrees", 0.0, 0.2)
	tw.chain().tween_callback(play_idle)
	tw.chain().tween_callback(_emit_finished.bind("attack"))
	_track(tw)


func _attack_heavy() -> void:
	# Wind up + slam — both arms raise then smash down
	var tw := create_tween()
	# Wind up
	tw.set_parallel()
	tw.tween_property(shoulder_l_pivot, "rotation_degrees", -30.0, 0.25)
	tw.tween_property(shoulder_r_pivot, "rotation_degrees", 30.0, 0.25)
	tw.tween_property(torso, "position:y", _rest_pos(torso).y - 10.0, 0.25)
	tw.chain()
	# Slam
	tw.set_parallel()
	tw.tween_property(shoulder_l_pivot, "rotation_degrees", 15.0, 0.1) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(shoulder_r_pivot, "rotation_degrees", -15.0, 0.1) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(torso, "position:y", _rest_pos(torso).y + 8.0, 0.1)
	tw.chain()
	tw.tween_interval(0.15)
	tw.tween_callback(play_idle)
	tw.tween_callback(_emit_finished.bind("attack"))
	_track(tw)


func _attack_cast() -> void:
	# Raise arms, burst of energy
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(shoulder_l_pivot, "rotation_degrees", -60.0, 0.2)
	tw.tween_property(shoulder_r_pivot, "rotation_degrees", 60.0, 0.2)
	tw.tween_property(torso, "position:y", _rest_pos(torso).y - 8.0, 0.2)
	tw.chain()
	tw.tween_callback(func(): cast_particles.emitting = true)
	tw.tween_interval(0.3)
	tw.set_parallel()
	tw.tween_property(shoulder_l_pivot, "rotation_degrees", 0.0, 0.3)
	tw.tween_property(shoulder_r_pivot, "rotation_degrees", 0.0, 0.3)
	tw.tween_property(torso, "position:y", _rest_pos(torso).y, 0.3)
	tw.chain().tween_callback(play_idle)
	tw.chain().tween_callback(_emit_finished.bind("attack"))
	_track(tw)


func _attack_precise() -> void:
	# Single precise strike — one arm extends with snap
	var tw := create_tween()
	tw.tween_property(shoulder_r_pivot, "rotation_degrees", -70.0, 0.08) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(torso, "rotation_degrees", 3.0, 0.08)
	tw.tween_interval(0.1)
	tw.tween_property(shoulder_r_pivot, "rotation_degrees", 0.0, 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(torso, "rotation_degrees", 0.0, 0.3)
	tw.tween_callback(play_idle)
	tw.tween_callback(_emit_finished.bind("attack"))
	_track(tw)


func _attack_summon() -> void:
	# Arms wide + energy burst, chaotic
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(shoulder_l_pivot, "rotation_degrees", -80.0, 0.15)
	tw.tween_property(shoulder_r_pivot, "rotation_degrees", 80.0, 0.15)
	tw.tween_property(head, "rotation_degrees", -5.0, 0.1)
	tw.tween_property(torso, "position:y", _rest_pos(torso).y - 12.0, 0.15)
	tw.chain()
	tw.tween_callback(func():
		cast_particles.emitting = true
		_shake(6.0, 0.2)
	)
	tw.tween_interval(0.35)
	tw.set_parallel()
	tw.tween_property(shoulder_l_pivot, "rotation_degrees", 0.0, 0.3)
	tw.tween_property(shoulder_r_pivot, "rotation_degrees", 0.0, 0.3)
	tw.tween_property(head, "rotation_degrees", 0.0, 0.25)
	tw.tween_property(torso, "position:y", _rest_pos(torso).y, 0.3)
	tw.chain().tween_callback(play_idle)
	tw.chain().tween_callback(_emit_finished.bind("attack"))
	_track(tw)


# ── CAST (Skill cards) ───────────────────────────────────────────────────

func play_cast() -> void:
	_kill_current()
	_current_anim = "cast"
	if _is_fullbody_mode:
		# Glow + particles burst
		cast_particles.emitting = true
		var tw := create_tween()
		tw.tween_property(self, "modulate", Color(1.5, 1.3, 1.8, 1.0), 0.2)
		tw.tween_property(fullbody_sprite, "scale", Vector2(1.05, 1.05), 0.2)
		tw.tween_property(self, "modulate", Color.WHITE, 0.3)
		tw.tween_property(fullbody_sprite, "scale", Vector2.ONE, 0.2)
		tw.tween_callback(play_idle)
		tw.tween_callback(_emit_finished.bind("cast"))
		_track(tw)
		return
	_attack_cast()


# ── BLOCK ─────────────────────────────────────────────────────────────────

func play_block() -> void:
	_kill_current()
	_current_anim = "block"

	if _is_fullbody_mode:
		_flash_white(0.1)
		var tw := create_tween()
		tw.tween_property(fullbody_sprite, "scale", Vector2(0.95, 1.05), 0.08)
		tw.tween_property(fullbody_sprite, "scale", Vector2.ONE, 0.2)
		tw.tween_callback(play_idle)
		tw.tween_callback(_emit_finished.bind("block"))
		_track(tw)
		return

	var tw := create_tween()
	# Arms cross defensively
	tw.set_parallel()
	tw.tween_property(shoulder_l_pivot, "rotation_degrees", 20.0, 0.1)
	tw.tween_property(shoulder_r_pivot, "rotation_degrees", -20.0, 0.1)
	tw.tween_property(torso, "position:y", _rest_pos(torso).y + 5.0, 0.1)
	tw.chain()
	_flash_white(0.1)
	tw.tween_interval(0.3)
	tw.tween_callback(play_idle)
	tw.tween_callback(_emit_finished.bind("block"))
	_track(tw)


# ── BUFF ──────────────────────────────────────────────────────────────────

func play_buff() -> void:
	_kill_current()
	_current_anim = "buff"

	aura_particles.emitting = true
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(self, "modulate", Color(1.4, 1.2, 1.0, 1.0), 0.3)
	tw.tween_property(torso, "position:y", _rest_pos(torso).y - 6.0, 0.3)
	tw.chain()
	tw.set_parallel()
	tw.tween_property(self, "modulate", Color.WHITE, 0.4)
	tw.tween_property(torso, "position:y", _rest_pos(torso).y, 0.4)
	tw.chain().tween_callback(play_idle)
	tw.chain().tween_callback(_emit_finished.bind("buff"))
	_track(tw)


# ── DEATH ─────────────────────────────────────────────────────────────────

func play_death() -> void:
	_kill_current()
	_current_anim = "death"
	aura_particles.emitting = false

	# Stagger back, collapse, fade
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(torso, "rotation_degrees", -8.0, 0.3)
	tw.tween_property(head, "rotation_degrees", -15.0, 0.3)
	tw.tween_property(shoulder_l_pivot, "rotation_degrees", 20.0, 0.3)
	tw.tween_property(shoulder_r_pivot, "rotation_degrees", -10.0, 0.3)
	tw.tween_property(self, "position:y", position.y + 20.0, 0.5)
	tw.chain()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(_emit_finished.bind("death"))
	_track(tw)
