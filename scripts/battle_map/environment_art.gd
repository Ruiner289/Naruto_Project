class_name EnvironmentArt
extends RefCounted

const TERRAIN_IDS := ["plain", "road", "forest", "swamp", "mountain", "water", "blocked"]
static var cache: Dictionary = {}

static func texture(id: String) -> Texture2D:
	if not cache.has(id):
		cache[id] = load("res://assets/environment/" + id + ".png")
	return cache[id]

static func terrain_type(grid: HexGrid, coord: Vector2i) -> int:
	var tile = grid.tiles.get(coord)
	return tile.terrain if tile is HexTileData else TerrainDefinition.Type.PLAIN

static func tile_texture(grid: HexGrid, coord: Vector2i) -> Texture2D:
	var variant := posmod(coord.x * 13 + coord.y * 7, 3)
	return texture("hex_%s_%d" % [TERRAIN_IDS[terrain_type(grid, coord)], variant])

static func prop_for(grid: HexGrid, coord: Vector2i) -> String:
	var variant := posmod(coord.x * 13 + coord.y * 7, 3)
	match terrain_type(grid, coord):
		TerrainDefinition.Type.FOREST:
			return ["tree_oak", "tree_pine", "bush"][variant]
		TerrainDefinition.Type.SWAMP:
			return "dead_tree" if variant == 0 else "bush"
		TerrainDefinition.Type.MOUNTAIN:
			return "rock"
		TerrainDefinition.Type.BLOCKED:
			return "fallen_log"
	return ""

static func backdrop(context: BattleContext, grid: HexGrid) -> Texture2D:
	var terrain := terrain_type(grid, context.defender_unit.coord.vector())
	if terrain in [TerrainDefinition.Type.WATER, TerrainDefinition.Type.SWAMP]:
		return texture("battle_bridge")
	if terrain in [TerrainDefinition.Type.ROAD, TerrainDefinition.Type.PLAIN]:
		return texture("battle_village")
	return texture("battle_forest")
