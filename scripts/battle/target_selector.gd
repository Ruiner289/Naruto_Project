class_name TargetSelector
extends RefCounted

# Provisional front -> middle -> rear, then closest row_offset. No protection formula.
static func choose(squad: SquadData, actor_slot: FormationSlot, living: Array[String]) -> String:
	var candidates: Array[String] = living.duplicate()
	candidates.sort_custom(func(a: String, b: String) -> bool:
		var first: FormationSlot = squad.positions[a]
		var second: FormationSlot = squad.positions[b]
		if first.column != second.column:
			return first.column > second.column
		var first_distance := absf(first.row_offset - actor_slot.row_offset)
		var second_distance := absf(second.row_offset - actor_slot.row_offset)
		return first_distance < second_distance if not is_equal_approx(first_distance, second_distance) else a < b)
	return "" if candidates.is_empty() else candidates[0]

static func choose_heal(squad: SquadData, roster: Dictionary) -> String:
	var candidates: Array[String] = []
	for id in squad.positions:
		if int(squad.current_hp[id]) > 0 and int(squad.current_hp[id]) < int(roster[id].test_stats().hp):
			candidates.append(id)
	candidates.sort_custom(func(a: String, b: String) -> bool:
		var left: int = int(squad.current_hp[a]) * int(roster[b].test_stats().hp)
		var right: int = int(squad.current_hp[b]) * int(roster[a].test_stats().hp)
		return left < right if left != right else a < b)
	return "" if candidates.is_empty() else candidates[0]
