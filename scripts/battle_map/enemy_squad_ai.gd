class_name EnemySquadAI
extends RefCounted

# Pure planning; uses the exact same grid, costs, blockers and attack-position search.
static func plan(state: Node, unit: SquadMapUnit) -> Dictionary:
	var search: Dictionary = state.search_for(unit, true)
	var options: Array[Dictionary] = []
	for target in state.units:
		if target.enemy == unit.enemy or PrototypeRules.hp_total(target.squad) <= 0:
			continue
		var route: Array[Vector2i] = state.route_to_attack(unit, target, search)
		if route.is_empty():
			continue
		var cost: int = search.costs[route.back()]
		options.append({"target": target, "route": route, "cost": cost, "priority": 0 if route.size() == 1 else (1 if cost <= unit.movement else 2)})
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.priority != b.priority:
			return a.priority < b.priority
		return a.cost < b.cost if a.cost != b.cost else a.target.id < b.target.id)
	if options.is_empty():
		var wait_route: Array[Vector2i] = [unit.coord.vector()]
		return {"route": wait_route, "target": null, "goal": null, "cost": 0}
	var chosen: Dictionary = options[0]
	var prefix: Array[Vector2i] = []
	for tile in chosen.route:
		if int(search.traversal_costs[tile]) > unit.movement:
			break
		prefix.append(tile)
	# The budget may end in a friendly tile; stop at the last vacant destination.
	while prefix.size() > 1 and not search.costs.has(prefix.back()):
		prefix.pop_back()
	return {"route": prefix, "target": chosen.target if prefix.back() == chosen.route.back() else null, "goal": chosen.target, "cost": chosen.cost}
