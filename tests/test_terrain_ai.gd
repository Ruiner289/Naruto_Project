extends SceneTree

var failures: int = 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func custom_grid(columns: int, rows: int) -> HexGrid:
	var grid := HexGrid.new(columns, rows)
	grid.tiles.clear()
	for x in columns:
		for y in rows:
			var cell := Vector2i(x, y)
			grid.tiles[cell] = HexTileData.new(cell)
	return grid

func run() -> void:
	var state: Node = root.get_node("GameState")
	check(state.grid.width == 20 and state.grid.height == 14 and state.grid.tiles.size() == 280, "Authored 20x14 battlefield")
	var counts: Dictionary = {}
	for tile in state.grid.tiles.values():
		counts[tile.terrain] = counts.get(tile.terrain, 0) + 1
	check(counts.size() == 7, "All seven authored terrains exist")
	var side_counts := [0, 0]
	for unit in state.units:
		side_counts[1 if unit.enemy else 0] += 1
		check(state.grid.is_passable(unit.coord.vector()), "All eight starting cells passable")
	check(side_counts == [4, 4], "Four squads per side")
	check(state.control_points.size() == 3, "Three persistent control points")
	for point in state.control_points:
		check(state.grid.is_passable(point.hex_coord), "Control point is on valid traversable hex")

	var line := custom_grid(3, 1)
	line.tiles[Vector2i(1, 0)].terrain = TerrainDefinition.Type.FOREST
	line.tiles[Vector2i(2, 0)].terrain = TerrainDefinition.Type.SWAMP
	var search := line.reachable(Vector2i.ZERO, 4, {}, {})
	check(search.costs[Vector2i(1, 0)] == 2 and not search.costs.has(Vector2i(2, 0)), "TEST10/11 forest2 plus swamp3 exceeds budget4")
	search = line.reachable(Vector2i.ZERO, 5, {}, {})
	check(search.costs[Vector2i(2, 0)] == 5, "Movement consumes terrain cost, not hex count")
	line.tiles[Vector2i(1, 0)].terrain = TerrainDefinition.Type.WATER
	check(not line.reachable(Vector2i.ZERO, 100, {}, {}).costs.has(Vector2i(2, 0)), "TEST12 impassable water stops traversal")
	line.tiles[Vector2i(1, 0)].terrain = TerrainDefinition.Type.BLOCKED
	check(not line.is_passable(Vector2i(1, 0)), "Blocked is impassable")

	var grid := custom_grid(5, 3)
	grid.tiles[Vector2i(2, 0)].terrain = TerrainDefinition.Type.BLOCKED
	grid.tiles[Vector2i(2, 1)].terrain = TerrainDefinition.Type.WATER
	search = grid.reachable(Vector2i.ZERO, 30, {}, {})
	var route := grid.path(Vector2i.ZERO, Vector2i(4, 0), search)
	check(not route.is_empty() and route.has(Vector2i(2, 2)), "TEST14 detour around wall through southern opening")
	for tile in route:
		check(grid.is_passable(tile), "Path never includes obstacle")
	grid = custom_grid(5, 3)
	for x in range(1, 4):
		grid.tiles[Vector2i(x, 0)].terrain = TerrainDefinition.Type.SWAMP
	search = grid.reachable(Vector2i.ZERO, 30, {}, {})
	route = grid.path(Vector2i.ZERO, Vector2i(4, 0), search)
	check(search.costs[Vector2i(4, 0)] < 10 and route.size() > 5, "TEST15 cheaper longer road/plain route instead of expensive direct swamp")

	var old_grid: HexGrid = state.grid
	var old_units: Array[SquadMapUnit] = state.units
	state.grid = grid
	var enemy := SquadMapUnit.new("ai", state.make_squad("AI", ["asuma"], [Vector2(2, 0)]), HexCoord.new(), true)
	var target := SquadMapUnit.new("target", state.make_squad("目标", ["kakashi"], [Vector2(2, 0)]), HexCoord.new(4, 0), false)
	var test_units: Array[SquadMapUnit] = [enemy, target]
	state.units = test_units
	var plan := EnemySquadAI.plan(state, enemy)
	check(plan.goal == target and not plan.route.is_empty(), "AI uses reachable path-cost target")
	var spent := 0
	for i in range(1, plan.route.size()):
		spent += grid.movement_cost(plan.route[i])
		check(grid.is_passable(plan.route[i]) and state.unit_at(plan.route[i]) == null, "TEST13 AI shares obstacles and occupancy")
	check(spent <= enemy.movement, "AI prefix respects terrain budget")
	var adjacent := SquadMapUnit.new("adjacent", state.make_squad("인접 목표", ["kiba"], [Vector2(2, 0)]), HexCoord.new(0, 1), false)
	state.units.append(adjacent)
	plan = EnemySquadAI.plan(state, enemy)
	check(plan.goal == adjacent and plan.route.size() == 1 and plan.target == adjacent, "AI prioritizes immediate attack over further movement")
	state.units.erase(adjacent)
	# Seal the closer target's entire attack perimeter; AI must choose the other reachable target.
	grid = custom_grid(6, 4)
	state.grid = grid
	target.coord = HexCoord.new(4, 0)
	for direction in HexCoord.DIRECTIONS:
		var cell := target.coord.vector() + direction
		if grid.tiles.has(cell):
			grid.tiles[cell].terrain = TerrainDefinition.Type.BLOCKED
	var alternative := SquadMapUnit.new("other", state.make_squad("다른 목표", ["naruto"], [Vector2(2, 0)]), HexCoord.new(4, 3), false)
	state.units.append(alternative)
	plan = EnemySquadAI.plan(state, enemy)
	check(plan.goal == alternative, "Unreachable target is ignored, reachable alternative chosen")
	state.units.erase(alternative)
	plan = EnemySquadAI.plan(state, enemy)
	check(plan.goal == null and plan.route.size() == 1, "No accessible targets means wait")
	state.grid = old_grid
	state.units = old_units
	print("Terrain and AI tests: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
