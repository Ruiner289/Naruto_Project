class_name TurnManager
extends RefCounted

enum TurnSide { PLAYER, ENEMY }
var current_side: TurnSide = TurnSide.PLAYER
var turn_number: int = 1

func is_player_turn() -> bool:
	return current_side == TurnSide.PLAYER

func available_units(units: Array[SquadMapUnit]) -> Array[SquadMapUnit]:
	var result: Array[SquadMapUnit] = []
	for unit in units:
		if unit.enemy == (current_side == TurnSide.ENEMY) and unit.can_act():
			result.append(unit)
	return result

func end_player(units: Array[SquadMapUnit]) -> void:
	if not is_player_turn():
		return
	for unit in units:
		if not unit.enemy:
			unit.acted = true
	current_side = TurnSide.ENEMY
	reset_side(units, true)

func end_enemy(units: Array[SquadMapUnit]) -> void:
	if is_player_turn():
		return
	current_side = TurnSide.PLAYER
	turn_number += 1
	reset_side(units, false)

func reset_side(units: Array[SquadMapUnit], enemy: bool) -> void:
	for unit in units:
		if unit.enemy == enemy:
			unit.acted = false
			unit.moved = false
