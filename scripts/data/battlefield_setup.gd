class_name BattlefieldSetup
extends RefCounted

static func create_grid() -> HexGrid:
	var grid := HexGrid.new()
	# Authored lanes: fast northern road, costly center, southern detour.
	for coord in grid.tiles:
		var column: int = coord.x + floori(float(coord.y) / 2.0)
		var row: int = coord.y
		var terrain := TerrainDefinition.Type.PLAIN
		if row == 2 or row == 11:
			terrain = TerrainDefinition.Type.ROAD
		if column >= 7 and column <= 12 and row >= 4 and row <= 8:
			terrain = TerrainDefinition.Type.FOREST
		if column >= 8 and column <= 11 and row >= 9 and row <= 10:
			terrain = TerrainDefinition.Type.SWAMP
		if column == 10 and row >= 3 and row <= 10:
			terrain = TerrainDefinition.Type.MOUNTAIN
		if column == 10 and row in [4, 5, 7, 8]:
			terrain = TerrainDefinition.Type.BLOCKED
		if column >= 13 and column <= 15 and row >= 8 and row <= 9:
			terrain = TerrainDefinition.Type.WATER
		if row == 6 and column >= 8 and column <= 12:
			terrain = TerrainDefinition.Type.ROAD
		grid.tiles[coord].terrain = terrain
	return grid

static func control_points() -> Array[ControlPointData]:
	return [ControlPointData.new("west", "아군 본진", HexCoord.from_offset(1, 7).vector(), ControlPointData.PointType.BASE, ControlPointData.Owner.PLAYER), ControlPointData.new("center", "중립 전초", HexCoord.from_offset(10, 6).vector(), ControlPointData.PointType.OUTPOST, ControlPointData.Owner.NEUTRAL), ControlPointData.new("east", "적 본진", HexCoord.from_offset(18, 7).vector(), ControlPointData.PointType.BASE, ControlPointData.Owner.ENEMY)]
