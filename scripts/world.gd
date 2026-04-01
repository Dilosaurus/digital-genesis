extends Node2D

# Tile indices in the packed tilemap (12 columns, 0-indexed)
# Row, Col -> tile coords in atlas
const GRASS_1 := Vector2i(0, 0)
const GRASS_2 := Vector2i(1, 0)
const FLOWERS := Vector2i(2, 0)
const DIRT := Vector2i(0, 1)
const DIRT_2 := Vector2i(1, 1)
const PATH_EDGE := Vector2i(2, 1)
const TREE_ORANGE_TOP := Vector2i(3, 0)
const TREE_GREEN_TOP := Vector2i(4, 0)
const TREE_ROUND := Vector2i(5, 0)
const TREE_DARK := Vector2i(6, 0)
const TREE_TALL := Vector2i(7, 0)
const TREE_TRUNK_GREEN := Vector2i(4, 1)
const TREE_TRUNK_FRUIT := Vector2i(5, 1)
const TREE_AUTUMN_TOP := Vector2i(9, 0)
const TREE_AUTUMN_TRUNK := Vector2i(9, 1)
const ROCK := Vector2i(3, 1)
const FENCE_H := Vector2i(6, 1)
const FENCE_V := Vector2i(7, 1)
const WATER := Vector2i(8, 0)
const WATER_2 := Vector2i(8, 1)
const MUSHROOM := Vector2i(3, 2)

const MAP_WIDTH := 40
const MAP_HEIGHT := 30

var tilemap_layer: TileMapLayer
var tree_layer: TileMapLayer

func _ready() -> void:
	_setup_tileset()
	_generate_map()

func _setup_tileset() -> void:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(16, 16)

	var source := TileSetAtlasSource.new()
	source.texture = preload("res://assets/kenney_tiny_town/Tilemap/tilemap_packed.png")
	source.texture_region_size = Vector2i(16, 16)
	source.separation = Vector2i(0, 0)

	# Create all tile entries in the atlas
	for y in range(11):
		for x in range(12):
			var coords = Vector2i(x, y)
			source.create_tile(coords)

	tileset.add_source(source, 0)

	# Add physics layer for collisions (trees, water, rocks)
	tileset.add_physics_layer()

	# Set collision on tree/obstacle tiles
	var obstacle_tiles = [
		TREE_GREEN_TOP, TREE_ORANGE_TOP, TREE_ROUND, TREE_DARK, TREE_TALL,
		TREE_TRUNK_GREEN, TREE_TRUNK_FRUIT, TREE_AUTUMN_TOP, TREE_AUTUMN_TRUNK,
		ROCK, WATER, WATER_2
	]
	for tile_coord in obstacle_tiles:
		var tile_data = source.get_tile_data(tile_coord, 0)
		if tile_data:
			var polygon = PackedVector2Array([
				Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
			])
			tile_data.add_collision_polygon(0)
			tile_data.set_collision_polygon_points(0, 0, polygon)

	# Ground layer
	tilemap_layer = TileMapLayer.new()
	tilemap_layer.name = "Ground"
	tilemap_layer.tile_set = tileset
	add_child(tilemap_layer)

	# Object layer (trees, rocks — rendered on top, has collision)
	tree_layer = TileMapLayer.new()
	tree_layer.name = "Objects"
	tree_layer.tile_set = tileset
	tree_layer.y_sort_enabled = true
	add_child(tree_layer)

	# Move player to be a sibling so y-sort works
	# Player is added in main.tscn, we just need the layers set up

func _generate_map() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42  # Deterministic for now

	# Step 1: Fill ground with grass
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var grass_tile: Vector2i
			var roll = rng.randf()
			if roll < 0.7:
				grass_tile = GRASS_1
			elif roll < 0.9:
				grass_tile = GRASS_2
			else:
				grass_tile = FLOWERS
			tilemap_layer.set_cell(Vector2i(x, y), 0, grass_tile)

	# Step 2: Create a dirt path through the middle
	# Horizontal path
	for x in range(MAP_WIDTH):
		var path_y = 14
		for dy in range(-1, 2):
			var tile = DIRT if rng.randf() > 0.3 else DIRT_2
			tilemap_layer.set_cell(Vector2i(x, path_y + dy), 0, tile)

	# Vertical path crossing
	for y in range(MAP_HEIGHT):
		var path_x = 20
		for dx in range(-1, 2):
			var tile = DIRT if rng.randf() > 0.3 else DIRT_2
			tilemap_layer.set_cell(Vector2i(path_x + dx, y), 0, tile)

	# Step 3: Add a pond (water area)
	var pond_x = 8
	var pond_y = 8
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			if abs(dx) == 2 and abs(dy) == 2:
				continue  # Round the corners
			var wx = pond_x + dx
			var wy = pond_y + dy
			tilemap_layer.set_cell(Vector2i(wx, wy), 0, WATER)
			tree_layer.set_cell(Vector2i(wx, wy), 0, WATER)

	# Step 4: Scatter trees around the map
	var tree_tops = [TREE_GREEN_TOP, TREE_ORANGE_TOP, TREE_ROUND, TREE_DARK]
	for i in range(40):
		var tx = rng.randi_range(1, MAP_WIDTH - 2)
		var ty = rng.randi_range(1, MAP_HEIGHT - 2)

		# Don't place on paths or water
		if _is_on_path(tx, ty) or _is_on_water(tx, ty, pond_x, pond_y):
			continue
		# Don't place near player spawn (20, 14)
		if abs(tx - 20) < 3 and abs(ty - 14) < 3:
			continue

		var tree_tile = tree_tops[rng.randi_range(0, tree_tops.size() - 1)]
		tree_layer.set_cell(Vector2i(tx, ty), 0, tree_tile)

	# Step 5: Add some rocks
	for i in range(10):
		var rx = rng.randi_range(1, MAP_WIDTH - 2)
		var ry = rng.randi_range(1, MAP_HEIGHT - 2)
		if _is_on_path(rx, ry) or _is_on_water(rx, ry, pond_x, pond_y):
			continue
		if abs(rx - 20) < 3 and abs(ry - 14) < 3:
			continue
		tree_layer.set_cell(Vector2i(rx, ry), 0, ROCK)

	# Step 6: Border the map with trees (natural boundary)
	for x in range(MAP_WIDTH):
		tree_layer.set_cell(Vector2i(x, 0), 0, TREE_GREEN_TOP)
		tree_layer.set_cell(Vector2i(x, MAP_HEIGHT - 1), 0, TREE_GREEN_TOP)
	for y in range(MAP_HEIGHT):
		tree_layer.set_cell(Vector2i(0, y), 0, TREE_GREEN_TOP)
		tree_layer.set_cell(Vector2i(MAP_WIDTH - 1, y), 0, TREE_GREEN_TOP)

func _is_on_path(x: int, y: int) -> bool:
	return (abs(y - 14) <= 1) or (abs(x - 20) <= 1)

func _is_on_water(x: int, y: int, pond_x: int, pond_y: int) -> bool:
	return abs(x - pond_x) <= 2 and abs(y - pond_y) <= 2
