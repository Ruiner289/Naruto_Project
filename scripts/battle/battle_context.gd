class_name BattleContext
extends RefCounted

var attacker: SquadData
var defender: SquadData
var hex: HexCoord
var attacker_unit: SquadMapUnit
var defender_unit: SquadMapUnit
var attacker_origin: HexCoord
var winner: int = -1 # 0 attacker victory, 1 defender victory, 2 encounter over, both survived

func _init(attack_unit: SquadMapUnit, defend_unit: SquadMapUnit) -> void:
	attacker_unit = attack_unit
	defender_unit = defend_unit
	attacker = attack_unit.squad
	defender = defend_unit.squad
	attacker_origin = HexCoord.from_vector(attack_unit.coord.vector())
	hex = HexCoord.from_vector(defend_unit.coord.vector())
