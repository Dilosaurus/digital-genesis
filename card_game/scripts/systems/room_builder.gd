class_name RoomBuilder
extends RefCounted
## Procedurally assembles 3D dungeon rooms from KayKit tiles.
## Usage: var room_node := RoomBuilder.build_room("fight")
## Returns a Node3D containing the assembled room scene.

# -----------------------------------------------------------------------
# Tile base path
# -----------------------------------------------------------------------
const TILE_BASE := "res://downloaded-packs/dungeon/Assets/gltf/"

# -----------------------------------------------------------------------
# Verified tile names (matched against actual files in gltf/ directory)
# -----------------------------------------------------------------------
const FLOORS := [
	"floor_tile_large",
	"floor_tile_small",
	"floor_dirt_large",
	"floor_wood_large",
]
const WALLS := [
	"wall",
	"wall_half",
	"wall_corner",
	"wall_broken",
	"wall_cracked",
	"wall_arched",
]
const WALL_DOORWAYS := [
	"wall_doorway",
	"wall_doorway_sides",
]
const COLUMNS := ["column"]
const PILLARS := ["pillar", "pillar_decorated"]
const TORCHES := ["torch_mounted", "torch_lit"]
const BARRELS := ["barrel_large", "barrel_small", "barrel_large_decorated"]
const CHESTS := ["chest", "chest_gold"]
const BANNERS := ["banner_red", "banner_blue", "banner_green", "banner_brown"]
const BANNERS_SHIELD := ["banner_shield_red", "banner_shield_blue", "banner_shield_gold"]
const BEDS := ["bed_decorated", "bed_floor"]
const SHELVES := ["shelf_large", "shelf_small", "shelf_small_candles", "shelves"]
const TABLES := ["table_medium", "table_small", "table_medium_tablecloth"]
const CHAIRS := ["chair", "stool"]
const CANDLES := ["candle_lit", "candle_triple", "candle_thin_lit"]
const TRUNKS := ["trunk_large_A", "trunk_medium_A", "trunk_small_A"]
const SWORDS := ["sword_shield", "sword_shield_gold", "sword_shield_broken"]

# -----------------------------------------------------------------------
# Tile size constants (KayKit dungeon tiles are roughly 2x2 world units)
# -----------------------------------------------------------------------
const TILE_SIZE := 2.0

# -----------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------

## Build a 3D room scene for a given map-node type.
## Returns a new Node3D containing the assembled room.
static func build_room(node_type: String) -> Node3D:
	var root := Node3D.new()
	root.name = "DungeonRoom"

	match node_type:
		"fight":
			_build_combat_room(root, "basic")
		"elite":
			_build_combat_room(root, "elite")
		"boss":
			_build_boss_arena(root)
		"rest":
			_build_rest_chamber(root)
		"shop":
			_build_shop_hall(root)
		"event":
			_build_event_room(root)
		_:
			_build_combat_room(root, "basic")

	_add_lighting(root, node_type)
	return root

# -----------------------------------------------------------------------
# Room builders
# -----------------------------------------------------------------------

static func _build_combat_room(root: Node3D, tier: String) -> void:
	# Floor: 3x3 grid of large tiles
	_place_floor_grid(root, 3, 3, "floor_tile_large")

	# Walls on three sides (left, right, back) -- front stays open
	_place_wall_line(root, Vector3(-3.0 * TILE_SIZE, 0, 0), Vector3.FORWARD, 3)
	_place_wall_line(root, Vector3( 3.0 * TILE_SIZE, 0, 0), Vector3.FORWARD, 3)
	_place_wall_line(root, Vector3(0, 0, -3.0 * TILE_SIZE), Vector3.RIGHT, 3)

	# Columns at back corners
	_place_tile(root, "column", Vector3(-3.0 * TILE_SIZE, 0, -3.0 * TILE_SIZE))
	_place_tile(root, "column", Vector3( 3.0 * TILE_SIZE, 0, -3.0 * TILE_SIZE))

	# Wall-mounted torches on back wall
	_place_tile(root, "torch_mounted", Vector3(-2.0 * TILE_SIZE, 1.5, -2.9 * TILE_SIZE))
	_place_tile(root, "torch_mounted", Vector3( 2.0 * TILE_SIZE, 1.5, -2.9 * TILE_SIZE))

	# Elite tier: add menacing banners and extra pillars
	if tier == "elite":
		_place_tile(root, "banner_shield_red", Vector3(-2.5 * TILE_SIZE, 0, -2.8 * TILE_SIZE))
		_place_tile(root, "banner_shield_red", Vector3( 2.5 * TILE_SIZE, 0, -2.8 * TILE_SIZE))
		_place_tile(root, "pillar", Vector3(-1.5 * TILE_SIZE, 0, -2.8 * TILE_SIZE))
		_place_tile(root, "pillar", Vector3( 1.5 * TILE_SIZE, 0, -2.8 * TILE_SIZE))


static func _build_boss_arena(root: Node3D) -> void:
	# Larger floor: 5x5 grid
	_place_floor_grid(root, 5, 5, "floor_tile_large")

	# Full three-sided wall enclosure
	_place_wall_line(root, Vector3(-5.0 * TILE_SIZE, 0, 0), Vector3.FORWARD, 5)
	_place_wall_line(root, Vector3( 5.0 * TILE_SIZE, 0, 0), Vector3.FORWARD, 5)
	_place_wall_line(root, Vector3(0, 0, -5.0 * TILE_SIZE), Vector3.RIGHT, 5)

	# Grand columns along the back wall
	for x in [-4, -2, 0, 2, 4]:
		_place_tile(root, "pillar_decorated", Vector3(x * TILE_SIZE, 0, -4.8 * TILE_SIZE))

	# Alternating banners between columns
	for x in [-3, -1, 1, 3]:
		_place_tile(root, "banner_red", Vector3(x * TILE_SIZE, 0, -4.7 * TILE_SIZE))

	# Torches flanking the arena
	for x in [-4, -2, 2, 4]:
		_place_tile(root, "torch_mounted", Vector3(x * TILE_SIZE, 1.5, -4.9 * TILE_SIZE))

	# Sword-and-shield decorations at the entrance
	_place_tile(root, "sword_shield_gold", Vector3(-4.5 * TILE_SIZE, 0, 0))
	_place_tile(root, "sword_shield_gold", Vector3( 4.5 * TILE_SIZE, 0, 0))


static func _build_rest_chamber(root: Node3D) -> void:
	# Warm wooden floor
	_place_floor_grid(root, 3, 3, "floor_wood_large")

	# Three walls
	_place_wall_line(root, Vector3(-3.0 * TILE_SIZE, 0, 0), Vector3.FORWARD, 3)
	_place_wall_line(root, Vector3( 3.0 * TILE_SIZE, 0, 0), Vector3.FORWARD, 3)
	_place_wall_line(root, Vector3(0, 0, -3.0 * TILE_SIZE), Vector3.RIGHT, 3)

	# Cozy furnishing
	_place_tile(root, "bed_decorated", Vector3(-2.0 * TILE_SIZE, 0, -2.0 * TILE_SIZE))
	_place_tile(root, "barrel_large", Vector3( 2.0 * TILE_SIZE, 0, -2.0 * TILE_SIZE))
	_place_tile(root, "chest", Vector3( 2.0 * TILE_SIZE, 0, -2.5 * TILE_SIZE))
	_place_tile(root, "candle_triple", Vector3(0, 0.8, -2.5 * TILE_SIZE))
	_place_tile(root, "shelf_small_candles", Vector3(-2.5 * TILE_SIZE, 1.2, -2.8 * TILE_SIZE))
	_place_tile(root, "stool", Vector3(-1.0 * TILE_SIZE, 0, -1.5 * TILE_SIZE))


static func _build_shop_hall(root: Node3D) -> void:
	# Wider layout for the merchant hall
	_place_floor_grid(root, 4, 3, "floor_tile_large")

	# Three walls
	_place_wall_line(root, Vector3(-4.0 * TILE_SIZE, 0, 0), Vector3.FORWARD, 3)
	_place_wall_line(root, Vector3( 4.0 * TILE_SIZE, 0, 0), Vector3.FORWARD, 3)
	_place_wall_line(root, Vector3(0, 0, -3.0 * TILE_SIZE), Vector3.RIGHT, 4)

	# Merchant wares along the back wall
	_place_tile(root, "shelves", Vector3(-2.0 * TILE_SIZE, 0, -2.8 * TILE_SIZE))
	_place_tile(root, "shelf_large", Vector3( 2.0 * TILE_SIZE, 0, -2.8 * TILE_SIZE))

	# Barrels and crates
	_place_tile(root, "barrel_large_decorated", Vector3(-3.0 * TILE_SIZE, 0, -2.5 * TILE_SIZE))
	_place_tile(root, "barrel_small", Vector3(-2.5 * TILE_SIZE, 0, -2.0 * TILE_SIZE))

	# Gold chest as centrepiece
	_place_tile(root, "chest_gold", Vector3(0, 0, -2.5 * TILE_SIZE))

	# Table with display items
	_place_tile(root, "table_medium_tablecloth", Vector3(0, 0, -1.0 * TILE_SIZE))

	# Candle ambience
	_place_tile(root, "candle_lit", Vector3(-1.0 * TILE_SIZE, 0.8, -2.5 * TILE_SIZE))
	_place_tile(root, "candle_lit", Vector3( 1.0 * TILE_SIZE, 0.8, -2.5 * TILE_SIZE))


static func _build_event_room(root: Node3D) -> void:
	# Dirt floor for a mysterious vibe
	_place_floor_grid(root, 3, 3, "floor_dirt_large")

	# Only a back wall -- feels open and ominous
	_place_wall_line(root, Vector3(0, 0, -3.0 * TILE_SIZE), Vector3.RIGHT, 3)

	# Flanking columns
	_place_tile(root, "column", Vector3(-2.5 * TILE_SIZE, 0, -2.5 * TILE_SIZE))
	_place_tile(root, "column", Vector3( 2.5 * TILE_SIZE, 0, -2.5 * TILE_SIZE))

	# Mysterious banner
	_place_tile(root, "banner_blue", Vector3(0, 0, -2.8 * TILE_SIZE))

	# Trunk with unknown contents
	_place_tile(root, "trunk_large_A", Vector3(0, 0, -1.5 * TILE_SIZE))

	# Scattered candles
	_place_tile(root, "candle_thin_lit", Vector3(-1.0 * TILE_SIZE, 0, -2.0 * TILE_SIZE))
	_place_tile(root, "candle_thin_lit", Vector3( 1.0 * TILE_SIZE, 0, -2.0 * TILE_SIZE))

# -----------------------------------------------------------------------
# Tile placement helpers
# -----------------------------------------------------------------------

## Lay a grid of floor tiles centred on the origin.
## half_w / half_h define extent in tile counts from centre.
static func _place_floor_grid(root: Node3D, half_w: int, half_h: int, tile_name: String = "floor_tile_large") -> void:
	for x in range(-half_w, half_w + 1):
		for z in range(-half_h, half_h + 1):
			_place_tile(root, tile_name, Vector3(x * TILE_SIZE, 0, z * TILE_SIZE))


## Place a line of wall segments.
## start: world position of the line centre.
## direction: unit vector along the line (e.g. Vector3.RIGHT or Vector3.FORWARD).
## count: number of tiles on each side of centre.
static func _place_wall_line(root: Node3D, start: Vector3, direction: Vector3, count: int) -> void:
	for i in range(-count, count + 1):
		var pos := start + direction * (i * TILE_SIZE)
		# Rotate wall to face inward depending on line orientation
		var rot_y := 0.0
		if direction == Vector3.RIGHT:
			rot_y = 0.0      # back wall faces +Z
		elif direction == Vector3.FORWARD:
			rot_y = 90.0     # side walls face inward
		_place_tile(root, "wall", pos, rot_y)


## Instantiate a single tile at the given position with optional Y-axis rotation.
static func _place_tile(root: Node3D, tile_name: String, pos: Vector3, rot_y: float = 0.0) -> void:
	var path := TILE_BASE + tile_name + ".gltf"
	var scene: Resource = load(path)
	if not scene:
		push_warning("RoomBuilder: tile not found: %s" % path)
		return
	if not scene is PackedScene:
		push_warning("RoomBuilder: unexpected resource type for %s (got %s)" % [path, scene.get_class()])
		return
	var instance: Node3D = (scene as PackedScene).instantiate()
	instance.position = pos
	if rot_y != 0.0:
		instance.rotation_degrees.y = rot_y
	root.add_child(instance)

# -----------------------------------------------------------------------
# Lighting
# -----------------------------------------------------------------------

## Add directional + ambient lighting tuned per room type.
static func _add_lighting(root: Node3D, node_type: String) -> void:
	# Primary directional light
	var dir_light := DirectionalLight3D.new()
	dir_light.name = "RoomDirLight"
	dir_light.rotation_degrees = Vector3(-45, -30, 0)
	dir_light.light_energy = 0.6
	dir_light.shadow_enabled = true

	match node_type:
		"boss":
			dir_light.light_color = Color(1.0, 0.3, 0.2)   # threatening red
			dir_light.light_energy = 0.8
		"elite":
			dir_light.light_color = Color(1.0, 0.6, 0.2)   # hot orange
			dir_light.light_energy = 0.7
		"rest":
			dir_light.light_color = Color(1.0, 0.85, 0.6)  # warm campfire
		"shop":
			dir_light.light_color = Color(0.9, 0.9, 0.7)   # neutral warm
		"event":
			dir_light.light_color = Color(0.5, 0.55, 0.85)  # eerie blue
		_:
			dir_light.light_color = Color(0.7, 0.75, 0.9)   # cool dungeon
	root.add_child(dir_light)

	# Ambient fill via WorldEnvironment
	var world_env := WorldEnvironment.new()
	world_env.name = "RoomWorldEnv"
	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.15, 0.12, 0.18)
	environment.ambient_light_energy = 0.4
	environment.tonemap_mode = Environment.TONE_MAP_FILMIC
	world_env.environment = environment
	root.add_child(world_env)
