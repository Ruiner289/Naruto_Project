class_name BattleLogger
extends RefCounted

static func phase_label(phase: int) -> String:
	return "PHASE %d - %s" % [phase, NinjaData.class_label(NinjaData.phase_order()[phase - 1])]

static func format_event(event: Dictionary, roster: Dictionary) -> String:
	var actor_side := "공격측" if event.side == 0 else "방어측"
	var target_side := "공격측" if event.target_side == 0 else "방어측"
	var verb := "치료" if event.kind == BattleAction.Kind.HEAL else "공격"
	var amount_label := "회복" if event.kind == BattleAction.Kind.HEAL else "피해"
	var amount: int = event.heal if event.kind == BattleAction.Kind.HEAL else event.damage
	return "[%s] %s %s → %s %s %s / %s %d / HP %d/%d" % [phase_label(event.phase), actor_side, roster[event.actor].display_name, target_side, roster[event.target].display_name, verb, amount_label, amount, event.hp, event.max_hp]
