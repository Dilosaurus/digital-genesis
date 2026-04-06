## 3D player character puppet for combat.
## Loads a rigged GLB model based on character_id and plays animations
## from the shared KayKit Rig_Medium animation packs.
extends PuppetBase3D
class_name PlayerPuppet3D

## Character ID → GLB model path mapping
const CHARACTER_MODELS: Dictionary = {
	# Adventurers pack (originals)
	"knight":           "res://assets/models/characters/Knight.glb",
	"barbarian":        "res://assets/models/characters/Barbarian.glb",
	"mage":             "res://assets/models/characters/Mage.glb",
	"ranger":           "res://assets/models/characters/Ranger.glb",
	"rogue":            "res://assets/models/characters/Rogue.glb",
	"rogue_hooded":     "res://assets/models/characters/Rogue_Hooded.glb",
	# Skeleton pack
	"skeleton_warrior": "res://assets/models/characters/Skeleton_Warrior.glb",
	"skeleton_mage":    "res://assets/models/characters/Skeleton_Mage.glb",
	"skeleton_rogue":   "res://assets/models/characters/Skeleton_Rogue.glb",
	"skeleton_minion":  "res://assets/models/characters/Skeleton_Minion.glb",
	# Characters pack 4
	"paladin":          "res://assets/models/characters/Paladin_with_Helmet.glb",
	"orc":              "res://assets/models/characters/OrcRaider.glb",
	"werewolf":         "res://assets/models/characters/Werewolf_Wolf.glb",
	# Characters pack 5
	"black_knight":     "res://assets/models/characters/BlackKnight.glb",
	"witch":            "res://assets/models/characters/Witch.glb",
	"vampire":          "res://assets/models/characters/Vampire.glb",
	"combat_mech":      "res://assets/models/characters/CombatMech.glb",
	"frost_golem":      "res://assets/models/characters/FrostGolem.glb",
	"tiefling":         "res://assets/models/characters/Tiefling.glb",
	"clanker":          "res://assets/models/characters/Clanker.glb",
	# Player character → model mapping
	"netrunner":        "res://assets/models/characters/Rogue_Hooded.glb",
	"sysadmin":         "res://assets/models/characters/Knight.glb",
	"cryptomancer":     "res://assets/models/characters/Witch.glb",
	"white_hat":        "res://assets/models/characters/Paladin_with_Helmet.glb",
	"technomancer":     "res://assets/models/characters/CombatMech.glb",
}

## Shared animation packs (applied to all characters with same rig)
const ANIMATION_PACKS := [
	"res://assets/models/animations/Rig_Medium_General.glb",
	"res://assets/models/animations/Rig_Medium_MovementBasic.glb",
	"res://assets/models/animations/Rig_Medium_CombatMelee.glb",
	"res://assets/models/animations/Rig_Medium_CombatRanged.glb",
	"res://assets/models/animations/Rig_Medium_Special.glb",
]

## Character ID → weapon model path
const CHARACTER_WEAPONS: Dictionary = {
	"knight":     "res://assets/models/weapons/sword_1handed.gltf",
	"sysadmin":   "res://assets/models/weapons/sword_1handed.gltf",
	"barbarian":  "res://assets/models/weapons/axe_1handed.gltf",
	"mage":       "res://assets/models/weapons/staff.gltf",
	"ranger":     "res://assets/models/weapons/dagger.gltf",
	"rogue":      "res://assets/models/weapons/dagger.gltf",
	"rogue_hooded": "res://assets/models/weapons/dagger.gltf",
	"netrunner":  "res://assets/models/weapons/dagger.gltf",
	"cryptomancer": "res://assets/models/weapons/wand.gltf",
	"white_hat":  "res://assets/models/weapons/sword_1handed.gltf",
	"technomancer": "res://assets/models/weapons/staff.gltf",
}

## Bone name for right hand weapon slot (from KayKit rig)
const WEAPON_BONE := "handslot.r"

## Character tint colors (preserving the existing color identity)
const CHARACTER_COLORS: Dictionary = {
	"netrunner":    Color(0.3, 0.9, 1.0),      # Cyan
	"sysadmin":     Color(0.2, 0.72, 0.35),     # Green
	"cryptomancer": Color(0.8, 0.4, 1.0),       # Purple
	"white_hat":    Color(1.0, 0.95, 0.8),       # Pale gold
	"technomancer": Color(0.9, 0.2, 0.8),       # Magenta
	"knight":       Color(0.8, 0.8, 0.85),       # Silver
	"barbarian":    Color(0.85, 0.6, 0.4),       # Bronze
	"mage":         Color(0.5, 0.5, 1.0),        # Blue
	"ranger":       Color(0.4, 0.7, 0.3),        # Forest green
	"rogue":        Color(0.6, 0.6, 0.6),         # Dark gray
	"seraph":       Color(1.0, 0.9, 0.6),         # Golden divine glow
}

## Per-model transform overrides for non-KayKit models (FAB, Mixamo, etc.)
## Fixes coordinate system differences (Z-up → Y-up) and scale mismatches.
const MODEL_TRANSFORMS: Dictionary = {
	"seraph": {
		"scale": Vector3(1.0, 1.0, 1.0),
		"rotation": Vector3(0.0, 0.0, 0.0),
		"offset": Vector3(0.0, 0.0, 0.0),
	},
}

var _character_id: String = ""


func setup_character(character_id: String) -> void:
	_character_id = character_id

	# Get model path
	var model_path: String = CHARACTER_MODELS.get(character_id, "")
	if model_path == "":
		push_warning("PlayerPuppet3D: Unknown character '%s', defaulting to Knight" % character_id)
		model_path = CHARACTER_MODELS["knight"]

	# Load model
	var model_scene := load(model_path) as PackedScene
	if not model_scene:
		push_error("PlayerPuppet3D: Failed to load model at '%s'" % model_path)
		return

	load_model(model_scene)

	# Apply per-model transform fixes via a WRAPPER node so we don't
	# break the skeleton bind poses inside _model_root.
	if _model_root and MODEL_TRANSFORMS.has(character_id):
		var xform: Dictionary = MODEL_TRANSFORMS[character_id]
		var wrapper := Node3D.new()
		wrapper.name = "ModelWrapper"
		wrapper.scale = xform.get("scale", Vector3.ONE)
		wrapper.rotation_degrees = xform.get("rotation", Vector3.ZERO)
		wrapper.position = xform.get("offset", Vector3.ZERO)
		# Re-parent: model out of puppet → into wrapper → wrapper into puppet
		_model_root.get_parent().remove_child(_model_root)
		wrapper.add_child(_model_root)
		add_child(wrapper)

	# Only load KayKit shared animation packs for KayKit-rigged models.
	# Non-KayKit models (e.g. Seraph) use their own embedded anims or procedural motion.
	var is_kaykit := not model_path.begins_with("res://assets/models/enemies/")
	if is_kaykit:
		for anim_path in ANIMATION_PACKS:
			var anim_scene := load(anim_path) as PackedScene
			if anim_scene:
				load_animations(anim_scene)

		# Attach weapon to hand (only KayKit models have the weapon bone)
		_attach_weapon(character_id)

	# Apply character color tint if defined
	var tint: Color = CHARACTER_COLORS.get(character_id, Color.WHITE)
	if tint != Color.WHITE:
		_apply_color_tint(tint)

	# Start idle
	play_idle()


func _attach_weapon(character_id: String) -> void:
	var weapon_path: String = CHARACTER_WEAPONS.get(character_id, "")
	if weapon_path == "" or not ResourceLoader.exists(weapon_path):
		return

	# Find the skeleton in the model
	var skeleton = _find_skeleton_node(_model_root)
	if not skeleton:
		print("PlayerPuppet3D: No skeleton found — can't attach weapon")
		return

	# Find the weapon bone index
	var bone_idx = skeleton.find_bone(WEAPON_BONE)
	if bone_idx == -1:
		print("PlayerPuppet3D: Bone '%s' not found in skeleton" % WEAPON_BONE)
		return

	# Create BoneAttachment3D
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = WEAPON_BONE
	attachment.bone_idx = bone_idx
	skeleton.add_child(attachment)

	# Load and attach weapon model
	var weapon_scene = load(weapon_path)
	if weapon_scene:
		var weapon_instance = weapon_scene.instantiate()
		attachment.add_child(weapon_instance)
		print("PlayerPuppet3D: Attached weapon '%s' to %s" % [weapon_path.get_file(), WEAPON_BONE])


func _find_skeleton_node(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result = _find_skeleton_node(child)
		if result:
			return result
	return null


func _apply_color_tint(tint: Color) -> void:
	## Apply a subtle color tint to the character model.
	## Blends with the existing texture rather than replacing it.
	for node in _mesh_instances:
		var mesh := node as MeshInstance3D
		if not mesh:
			continue
		for s in range(mesh.get_surface_override_material_count()):
			var base_mat = mesh.get_active_material(s)
			if base_mat is StandardMaterial3D:
				var mat := base_mat.duplicate() as StandardMaterial3D
				# Blend tint with existing albedo
				mat.albedo_color = mat.albedo_color * tint
				mesh.set_surface_override_material(s, mat)
