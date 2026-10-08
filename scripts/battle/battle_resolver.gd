class_name BattleResolver
extends RefCounted

var context: BattleContext
var roster: Dictionary
var round_number: int = 1
var phase: int = 0
var phase_history: Array[int] = []
var acting_side: int = 0
var wave_history: Array[Dictionary] = []
var wave_cursor: int = 0
var reservations: Array[BattleAction] = []
var winner: int = -1

func _init(p_context: BattleContext, p_roster: Dictionary) -> void:
	context = p_context
	roster = p_roster
	PrototypeRules.ensure_hp(context.attacker, roster)
	PrototypeRules.ensure_hp(context.defender, roster)

func squad_for(side: int) -> SquadData:
	return context.attacker if side == 0 else context.defender

func alive(side: int) -> Array[String]:
	var result: Array[String] = []
	for id in squad_for(side).positions:
		if int(squad_for(side).current_hp[id]) > 0:
			result.append(id)
	return result

func resolve_winner() -> int:
	if alive(0).is_empty():
		return 1
	if alive(1).is_empty():
		return 0
	return -1

func choose_target(side: int, actor_slot: FormationSlot) -> String:
	return TargetSelector.choose(squad_for(side), actor_slot, alive(side))

func reserve_phase(class_type: int) -> void:
	# Reserve targets within this side/class wave before changing HP.
	var side := acting_side
	var members := alive(side)
	members.sort_custom(func(a: String, b: String) -> bool:
		var first: FormationSlot = squad_for(side).positions[a]
		var second: FormationSlot = squad_for(side).positions[b]
		if first.column != second.column:
			return first.column > second.column
		return first.row_offset < second.row_offset if first.row_offset != second.row_offset else a < b)
	for id in members:
		var ninja: NinjaData = roster[id]
		if ninja.class_type != class_type:
			continue
		var action := BattleAction.new()
		action.side = side
		action.actor = id
		action.phase = phase
		action.presentation_type = ninja.prototype_action_type
		if class_type == NinjaData.ClassType.HEALER:
			action.kind = BattleAction.Kind.HEAL
			action.target_side = side
			action.target = TargetSelector.choose_heal(squad_for(side), roster)
			action.value = maxi(0, ninja.heal_power)
		else:
			action.target_side = 1 - side
			action.target = choose_target(1 - side, squad_for(side).positions[id])
			action.value = maxi(0, int(ninja.test_stats().attack))
		if not action.target.is_empty():
			reservations.append(action)

# One exchange: attacker attacks, defender attacks, attacker heals, defender heals.
func next_action() -> Dictionary:
	if winner >= 0:
		return {}
	while true:
		winner = resolve_winner()
		if winner >= 0:
			context.winner = winner
			reservations.clear()
			return {}
		if reservations.is_empty():
			var attack_phases := NinjaData.phase_order().size() - 1
			if wave_cursor >= (attack_phases + 1) * 2:
				winner = 2
				context.winner = winner
				return {}
			if wave_cursor < attack_phases * 2:
				acting_side = 0 if wave_cursor < attack_phases else 1
				phase = wave_cursor % attack_phases + 1
			else:
				acting_side = wave_cursor - attack_phases * 2
				phase = attack_phases + 1
			wave_cursor += 1
			phase_history.append(phase)
			wave_history.append({"side": acting_side, "phase": phase})
			reserve_phase(NinjaData.phase_order()[phase - 1])
			continue
		var action: BattleAction = reservations.pop_front()
		if int(squad_for(action.side).current_hp[action.actor]) <= 0:
			continue # A dead actor's reservation is cancelled.
		var victim := squad_for(action.target_side)
		if action.kind == BattleAction.Kind.ATTACK and int(victim.current_hp[action.target]) <= 0:
			# A previous action may have defeated the reserved target.
			action.target = choose_target(action.target_side, squad_for(action.side).positions[action.actor])
			if action.target.is_empty():
				continue
		var before: int = victim.current_hp[action.target]
		var maximum: int = roster[action.target].test_stats().hp
		if action.kind == BattleAction.Kind.HEAL:
			if before <= 0:
				continue # No revival.
			victim.current_hp[action.target] = mini(maximum, before + action.value)
		else:
			victim.current_hp[action.target] = maxi(0, before - action.value)
		return {"side": action.side, "actor": action.actor, "target_side": action.target_side, "target": action.target, "kind": action.kind, "value": action.value, "damage": action.value if action.kind == BattleAction.Kind.ATTACK else 0, "heal": int(victim.current_hp[action.target]) - before if action.kind == BattleAction.Kind.HEAL else 0, "hp": victim.current_hp[action.target], "max_hp": maximum, "phase": action.phase, "round": 1, "action_type": action.presentation_type, "actions_left": 0}
	return {}

