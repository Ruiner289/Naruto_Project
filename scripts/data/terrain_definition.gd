class_name TerrainDefinition
extends RefCounted

enum Type { PLAIN, ROAD, FOREST, SWAMP, MOUNTAIN, WATER, BLOCKED }
# All terrain balance and drawing data live here.
const DEFINITIONS := {
	Type.PLAIN: {"name": "평지", "cost": 1, "passable": true, "color": Color(0.19, 0.27, 0.22), "symbol": "·"},
	Type.ROAD: {"name": "도로", "cost": 1, "passable": true, "color": Color(0.40, 0.35, 0.26), "symbol": "="},
	Type.FOREST: {"name": "숲", "cost": 2, "passable": true, "color": Color(0.10, 0.32, 0.19), "symbol": "♠"},
	Type.SWAMP: {"name": "늪", "cost": 3, "passable": true, "color": Color(0.29, 0.29, 0.14), "symbol": "~"},
	Type.MOUNTAIN: {"name": "산", "cost": 3, "passable": true, "color": Color(0.34, 0.29, 0.37), "symbol": "▲"},
	Type.WATER: {"name": "물", "cost": 0, "passable": false, "color": Color(0.10, 0.25, 0.43), "symbol": "≈"},
	Type.BLOCKED: {"name": "장애물", "cost": 0, "passable": false, "color": Color(0.14, 0.14, 0.17), "symbol": "×"}
}

static func get_definition(type: int) -> Dictionary:
	return DEFINITIONS[type]
