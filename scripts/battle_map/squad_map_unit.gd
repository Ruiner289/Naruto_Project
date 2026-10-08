class_name SquadMapUnit
extends RefCounted

var id: String
var squad: SquadData
var coord: HexCoord
var enemy: bool
var acted: bool = false
var moved: bool = false
var attack_range: int = 1
var movement: int = PrototypeRules.MOVEMENT

func _init(p_id: String, p_squad: SquadData, p_coord: HexCoord, p_enemy: bool) -> void:
	id = p_id
	squad = p_squad
	coord = p_coord
	enemy = p_enemy

func can_act() -> bool:
	return not acted and PrototypeRules.hp_total(squad) > 0

func can_move() -> bool:
	return can_act() and not moved
