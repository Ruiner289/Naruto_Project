class_name HexGrid
extends RefCounted

# Axial coordinates own tile/terrain data; numeric tiles remain supported by tests.
var tiles: Dictionary = {}
var width: int
var height: int

func _init(columns: int = PrototypeRules.MAP_COLUMNS, rows: int = PrototypeRules.MAP_ROWS) -> void:
	width = columns
	height = rows
	for row in rows:
		for col in columns:
			var coord := HexCoord.from_offset(col, row).vector()
			tiles[coord] = HexTileData.new(coord)

func movement_cost(at: Vector2i) -> int:
	if not tiles.has(at):
		return 0
	if tiles[at] is HexTileData:
		return TerrainDefinition.get_definition(tiles[at].terrain).cost
	return int(tiles[at])

func is_passable(at: Vector2i) -> bool:
	if not tiles.has(at):
		return false
	if tiles[at] is HexTileData:
		return TerrainDefinition.get_definition(tiles[at].terrain).passable
	return int(tiles[at]) > 0

func full_search_budget() -> int:
	var total: int = 0
	for coord in tiles:
		if is_passable(coord):
			total += movement_cost(coord)
	return total

func terrain_info(at: Vector2i) -> Dictionary:
	if tiles.has(at) and tiles[at] is HexTileData:
		return TerrainDefinition.get_definition(tiles[at].terrain)
	return TerrainDefinition.get_definition(TerrainDefinition.Type.PLAIN)

# Dijkstra. Enemy cells are reachable terminal nodes, never traversal cells.
func reachable(start: Vector2i, budget: int, blocked: Dictionary, enemies: Dictionary, zoc: Dictionary = {}) -> Dictionary:
	if not is_passable(start):
		return {"costs": {}, "previous": {}}
	var costs: Dictionary = {start: 0}
	var previous: Dictionary = {}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var best: int = 0
		for i in frontier.size():
			if costs[frontier[i]] < costs[frontier[best]]:
				best = i
		var current: Vector2i = frontier[best]
		frontier.remove_at(best)
		if current != start and (enemies.has(current) or zoc.has(current)):
			continue
		for direction in HexCoord.DIRECTIONS:
			var next: Vector2i = current + direction
			if not is_passable(next) or blocked.has(next):
				continue
			var cost: int = int(costs[current]) + movement_cost(next)
			if cost <= budget and (not costs.has(next) or cost < costs[next]):
				costs[next] = cost
				previous[next] = current
				if not frontier.has(next):
					frontier.append(next)
	return {"costs": costs, "previous": previous}

func path(start: Vector2i, target: Vector2i, search: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not search.costs.has(target):
		return result
	var current: Vector2i = target
	while current != start:
		result.push_front(current)
		current = search.previous[current]
	result.push_front(start)
	return result
