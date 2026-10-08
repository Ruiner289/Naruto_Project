extends SceneTree

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var grid := HexGrid.new()
	check(grid.tiles.size() == PrototypeRules.MAP_COLUMNS * PrototypeRules.MAP_ROWS, "Map bounds")
	for coord in grid.tiles:
		check(HexCoord.from_pixel(HexCoord.to_pixel(coord, PrototypeRules.HEX_RADIUS), PrototypeRules.HEX_RADIUS) == coord, "Axial pixel round trip")
	var start := HexCoord.from_offset(2, 3).vector()
	var goal := HexCoord.from_offset(6, 3).vector()
	var search := grid.reachable(start, PrototypeRules.MOVEMENT, {}, {goal: true})
	var route := grid.path(start, goal, search)
	check(route.size() == 5, "Movement budget includes contact cell")
	for i in range(1, route.size()):
		check(HexCoord.distance(route[i - 1], route[i]) == 1, "Adjacent path steps")
	var blocker: Vector2i = route[1]
	var blocked_search := grid.reachable(start, 6, {blocker: true}, {})
	var detour := grid.path(start, goal, blocked_search)
	check(not detour.has(blocker), "Allied blockers excluded")
	check(not detour.is_empty(), "Detour exists")
	var corridor := HexGrid.new(1, 1)
	corridor.tiles = {Vector2i(0, 0): 1, Vector2i(1, 0): 1, Vector2i(2, 0): 1}
	var contact := corridor.reachable(Vector2i.ZERO, 4, {}, {Vector2i(1, 0): true})
	check(contact.costs.has(Vector2i(1, 0)), "Enemy contact reachable")
	check(not contact.costs.has(Vector2i(2, 0)), "Enemy not traversed")
	corridor.tiles[Vector2i(1, 0)] = 4
	var weighted := corridor.reachable(Vector2i.ZERO, 4, {}, {})
	check(weighted.costs[Vector2i(1, 0)] == 4 and not weighted.costs.has(Vector2i(2, 0)), "Terrain cost budget")
	var manager := FormationManager.new()
	manager.place("naruto", FormationSlot.new(2, 0.5))
	PrototypeRules.ensure_hp(manager.squad, manager.roster)
	var enemy := SquadData.new()
	enemy.leader_id = "asuma"
	enemy.positions = {"asuma": FormationSlot.new(0, 0), "kiba": FormationSlot.new(2, 1.5), "shino": FormationSlot.new(1, 1)}
	PrototypeRules.ensure_hp(enemy, manager.roster)
	var attacker := SquadMapUnit.new("a", manager.squad, HexCoord.new(), false)
	var defender := SquadMapUnit.new("d", enemy, HexCoord.new(1, 0), true)
	var context := BattleContext.new(attacker, defender)
	var resolver := BattleResolver.new(context, manager.roster)
	check(context.attacker == manager.squad and context.defender == enemy, "No copied squad objects")
	check(resolver.choose_target(1, FormationSlot.new(0, 0.5)) == "kiba", "Front column priority")
	enemy.current_hp["kiba"] = 0
	check(resolver.choose_target(1, FormationSlot.new()) == "shino", "Incapacitated excluded, middle next")
	var event := resolver.next_action()
	check(event.side == 0 and event.actor == "kakashi" and event.phase == 4, "Initiator attacks before defender, even when defender has Gunpowder")
	check(not event.is_empty() and enemy.current_hp[event.target] < manager.roster[event.target].test_stats().hp, "Damage mutates original defender SquadData")
	var count: int = 1
	while not resolver.next_action().is_empty() and count < 2000:
		count += 1
	check(resolver.winner >= 0 and count < 2000, "Combat terminates")
	check(PrototypeRules.hp_total(manager.squad) < 130, "Survivor HP not reset")
	var identity: SquadData = manager.squad
	check(manager.save_json("user://tactics_save.json").is_empty(), "HP save")
	var before := JSON.stringify(manager.squad.to_dict())
	check(manager.load_json("user://tactics_save.json").is_empty(), "HP load")
	check(manager.squad == identity, "Load preserves object identity")
	check(JSON.stringify(manager.squad.to_dict()) == before, "HP round trip")
	print("Tactics tests: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
