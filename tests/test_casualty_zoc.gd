extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func line_grid() -> HexGrid:
	var grid := HexGrid.new(9, 3)
	grid.tiles.clear()
	for x in 9:
		grid.tiles[Vector2i(x, 1)] = HexTileData.new(Vector2i(x, 1))
	return grid
func make_unit(state: Node, name: String, x: int, enemy: bool) -> SquadMapUnit:
	return SquadMapUnit.new(name, state.make_squad(name, ["kakashi"], [Vector2(2, 0)]), HexCoord.new(x, 1), enemy)
func snap(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://" + name)
func run() -> void:
	root.size = Vector2i(1280, 720)
	var state: Node = root.get_node("GameState")
	state.grid = line_grid()
	var ally := make_unit(state, "ally", 0, false)
	var friend := make_unit(state, "friend", 1, false)
	var enemy := make_unit(state, "enemy", 4, true)
	state.units.assign([ally, friend, enemy])
	var search: Dictionary = state.search_for(ally)
	check(not search.costs.has(friend.coord.vector()) and search.traversal_costs.has(friend.coord.vector()), "Friendly tile is transit only")
	check(search.costs.has(Vector2i(2, 1)) and search.costs.has(Vector2i(3, 1)), "Movement passes friend and reaches hostile perimeter")
	check(not search.costs.has(Vector2i(4, 1)) and not search.costs.has(Vector2i(5, 1)), "Enemy blocks tile and ZOC prevents crossing")
	var route: Array[Vector2i] = state.grid.path(ally.coord.vector(), Vector2i(3, 1), search)
	check(route == [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)], "Path keeps friendly transit with terrain costs")
	friend.coord = HexCoord.new(3, 1)
	search = state.search_for(ally)
	check(not search.costs.has(friend.coord.vector()) and not search.costs.has(Vector2i(5, 1)), "Friendly tile in hostile ZOC cannot be traversed beyond")
	friend.coord = HexCoord.new(1, 1)
	ally.coord = HexCoord.new(3, 1)
	search = state.search_for(ally)
	check(search.costs.has(Vector2i(0, 1)), "Unit starting in ZOC can leave")
	ally.coord = HexCoord.new(0, 1)
	var map: Control = load("res://scenes/battle_map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	map.set_process(false)
	map.selected = ally
	map.refresh()
	await snap("preview_zoc_movement.png")
	await map.move_unit(ally, route, null)
	check(ally.coord.vector() == Vector2i(3, 1) and friend.coord.vector() == Vector2i(1, 1) and ally.moved and not ally.acted, "Actual movement passes friend and stops at ZOC with attack available")
	state.turn_manager.current_side = TurnManager.TurnSide.ENEMY
	enemy.coord = HexCoord.new(0, 1)
	friend.enemy = true
	friend.coord = HexCoord.new(3, 1)
	ally.coord = HexCoord.new(7, 1)
	enemy.movement = 3
	var plan := EnemySquadAI.plan(state, enemy)
	check(plan.route == [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)], "AI avoids ending on friend at budget boundary")
	enemy.movement = 6
	plan = EnemySquadAI.plan(state, enemy)
	check(plan.route.has(friend.coord.vector()) and plan.route.back() == Vector2i(6, 1) and plan.target == ally, "Enemy passes own side and stops at opposing ZOC")
	var dead_squad: SquadData = state.make_squad("casualty", ["kakashi", "naruto"], [Vector2(2, 0), Vector2(1, 0.5)])
	dead_squad.current_hp.kakashi = 0
	var partial := SquadMapUnit.new("partial", dead_squad, HexCoord.new(2, 1), false)
	var context := BattleContext.new(partial, enemy)
	var stage := BattleStage.new()
	stage.context = context
	stage.roster = state.formation.roster
	root.add_child(stage)
	check(not stage.views.has("0:kakashi") and stage.views.has("0:naruto"), "Prior casualty hidden; surviving member present")
	dead_squad.current_hp.naruto = 0
	stage.refresh_hp()
	check(stage.views.has("0:naruto") and stage.views["0:naruto"].displayed_hp == 0, "New casualty displayed only in current encounter")
	map.visible = false
	await snap("preview_current_casualty.png")
	root.remove_child(stage)
	stage.queue_free()
	stage = BattleStage.new()
	stage.context = context
	stage.roster = state.formation.roster
	root.add_child(stage)
	check(not stage.views.has("0:naruto"), "Next encounter hides previous casualty")
	root.remove_child(stage)
	stage.queue_free()
	state.units.assign([partial, enemy])
	state.battle = context
	state.battle.winner = 1
	var attack_tile := partial.coord.vector()
	state.apply_battle_result()
	check(not state.units.has(partial) and state.unit_at(attack_tile) == null, "Defeated friendly attacker removed and tile freed")
	state.turn_manager.current_side = TurnManager.TurnSide.PLAYER
	var living := make_unit(state, "living", 0, false)
	state.units.assign([living, enemy])
	state.battle = BattleContext.new(living, enemy)
	enemy.squad.current_hp.kakashi = 0
	state.battle.winner = 0
	state.apply_battle_result()
	check(not state.units.has(enemy) and living.coord.vector() == Vector2i(0, 1), "Defeated enemy removed; winner holds attack position")
	search = state.search_for(living)
	check(search.costs.has(Vector2i(4, 1)) and search.zoc.is_empty(), "Removed hostile leaves no occupancy or ZOC")
	print("Casualties, friendly passage and ZOC: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)

