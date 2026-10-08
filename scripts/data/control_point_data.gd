class_name ControlPointData
extends RefCounted

enum Owner { PLAYER, ENEMY, NEUTRAL }
enum PointType { BASE, OUTPOST, VILLAGE, FORT }
var id: String
var display_name: String
var hex_coord: Vector2i
var point_type: PointType
var owner: Owner

func _init(p_id: String, title: String, coord: Vector2i, type: PointType, p_owner: Owner) -> void:
	id = p_id
	display_name = title
	hex_coord = coord
	point_type = type
	owner = p_owner
