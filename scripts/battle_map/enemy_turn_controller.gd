class_name EnemyTurnController
extends Node

var state: Node
var map: Control
var queue: Array[SquadMapUnit] = []
var cursor: int = 0
var running: bool = false
var action_history: Array[String] = []

func begin() -> void:
	queue.clear()
	cursor = 0
	action_history.clear()
	for unit in state.units:
		if unit.enemy and unit.can_act():
			queue.append(unit)
	queue.sort_custom(func(a: SquadMapUnit, b: SquadMapUnit) -> bool: return a.id < b.id)
	resume(map)

func resume(active_map: Control) -> void:
	map = active_map
	if state.turn_manager.is_player_turn() or state.battle != null or running or not is_instance_valid(map):
		return
	call_deferred("advance")

func advance() -> void:
	if running or state.turn_manager.is_player_turn() or state.battle != null or not is_instance_valid(map):
		return
	running = true
	while cursor < queue.size():
		var unit: SquadMapUnit = queue[cursor]
		cursor += 1 # Persistent cursor is committed before a possible scene change.
		if not state.units.has(unit) or not unit.can_act():
			continue
		var plan := EnemySquadAI.plan(state, unit)
		action_history.append(unit.id)
		print("[ENEMY TURN %d] %s 목표=%s 목적지=%s 총 경로 비용=%d" % [state.turn, unit.id, plan.goal.id if plan.goal != null else "없음", str(plan.route.back()), plan.cost])
		map.selected = unit
		map.focus_unit(unit)
		map.status.text = "적 턴: %s 행동 중" % unit.squad.squad_name
		map.refresh()
		await map.move_unit(unit, plan.route, plan.target)
		if state.battle != null:
			running = false
			return # A fresh map resumes this controller after battle/fade.
		# Recheck after movement using the shared current-position attack rule.
		for target in state.units:
			if target.enemy != unit.enemy and not state.attack_route(unit, target).is_empty():
				state.request_battle(unit, target)
				if state.battle != null:
					running = false
					return
		unit.acted = true
		map.refresh()
		await get_tree().create_timer(0.12).timeout
	running = false
	state.turn_manager.end_enemy(state.units)
	map.selected = null
	state.map_changed.emit()
	map.status.text = "아군 턴 시작. 부대를 선택하세요."
	map.refresh()
