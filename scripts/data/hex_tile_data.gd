class_name HexTileData
extends RefCounted

var coord: Vector2i
var terrain: TerrainDefinition.Type

func _init(p_coord: Vector2i, p_terrain: TerrainDefinition.Type = TerrainDefinition.Type.PLAIN) -> void:
	coord = p_coord
	terrain = p_terrain
