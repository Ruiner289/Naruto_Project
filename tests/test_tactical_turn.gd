extends SceneTree

var failures: int = 0
var screenshots: bool = false
var battle_count: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func snapshot(name: String) -> void:
	if screenshots:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://" + name)

func click(map: Control, coord: Vector2i) -> void:
	if root.get_node("GameState").unit_at(coord) == null and map.selected != null and map.selected.can_move() and not map.choosing_attack and map.preview == null:
		map.move_selected()
	if map.action_menu.visible:
		map.action_menu.hide() # This helper targets a hex, not a command button.
	map.focus_hex(coord)
	await process_frame
	var at: Vector2 = map.board.get_global_transform() * map.board.center(coord)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame

func run() -> void:
	root.size = Vector2i(1280, 720)
	screenshots = DisplayServer.get_name() != "headless"
	var state: Node = root.get_node("GameState")
	var original_grid: HexGrid = state.grid
	var original_points: Array[ControlPointData] = state.control_points
	var terrain_ids: Dictionary = {}
	for coord in state.grid.tiles:
		terrain_ids[coord] = state.grid.tiles[coord].terrain
	var primary: SquadMapUnit = state.units[0]
	var support: SquadMapUnit = state.units[1]
	var enemy1: SquadMapUnit = state.units[2]
	var enemy2: SquadMapUnit = state.units[3]
	var dead_enemy: SquadMapUnit = state.units.back()
	check(state.units.size() == 8, "TEST17 eight simultaneously registered original squads")
	check(primary.squad == state.formation.squad, "Original formation-owned primary squad reused")
	var app: Control = load("res://scenes/game.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	var map: Control = app.active_screen
	map.set_fit_view(false)
	await click(map, primary.coord.vector())
	check(map.selected == primary and not map.end_button.disabled, "TEST1 player selects/moves, early turn end available")
	await snapshot("preview_tactical_west.png")
	map.focus_hex(state.control_points[1].hex_coord)
	await process_frame
	await snapshot("preview_tactical_center.png")
	for point in state.control_points:
		check(map.board.center(point.hex_coord) == map.board.ORIGIN + HexCoord.to_pixel(point.hex_coord, PrototypeRules.HEX_RADIUS), "TEST18 point derives position from real hex")
	check(original_points[0].owner == ControlPointData.Owner.PLAYER and original_points[1].owner == ControlPointData.Owner.NEUTRAL and original_points[2].owner == ControlPointData.Owner.ENEMY, "TEST19 distinct point owners")
	map.move_selected()
	var camera_before: int = map.map_scroll.scroll_horizontal
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	await create_timer(0.15).timeout
	key.pressed = false
	Input.parse_input_event(key)
	check(map.map_scroll.scroll_horizontal > camera_before, "TEST16 real D key pans the large battlefield")
	map.focus_hex(state.control_points[2].hex_coord)
	await process_frame
	await snapshot("preview_tactical_east.png")
	var destination := primary.coord.vector() + Vector2i(1, 0)
	map.cancel_interaction()
	await click(map, primary.coord.vector())
	await click(map, destination)
	var deadline: int = Time.get_ticks_msec() + 5000
	while map.busy and Time.get_ticks_msec() < deadline:
		await create_timer(0.01).timeout
	check(primary.coord.vector() == destination and primary.moved and primary.can_act(), "Player actual movement preserves attack option")
	# Arrange two genuine enemy attacks in this turn. The rest must follow terrain paths.
	enemy1.coord = HexCoord.from_offset(5, 2)
	enemy2.coord = HexCoord.from_offset(5, 6)
	for id in primary.squad.positions:
		primary.squad.current_hp[id] = 0
	primary.squad.current_hp[primary.squad.leader_id] = 1
	for id in dead_enemy.squad.positions:
		dead_enemy.squad.current_hp[id] = 0
	map.refresh()
	state.end_turn()
	check(not state.turn_manager.is_player_turn() and state.turn == 1, "TEST2 manual end enters Enemy Turn1 immediately")
	state.end_turn()
	check(state.turn == 1, "Repeated end-turn does not skip enemy side")
	await process_frame
	check(map.end_button.disabled, "Enemy turn end button locked")
	var selected_before: SquadMapUnit = map.selected
	await click(map, support.coord.vector())
	check(map.selected == selected_before, "Player left-click selection locked during enemy movement")
	var support_acted_before: bool = support.acted
	map.wait_selected()
	check(support.acted == support_acted_before, "Player wait cannot change friendly action during enemy turn")
	var observed_positions: Dictionary = {}
	for unit in state.units:
		observed_positions[unit.id] = unit.coord.vector()
	var first_enemy_origin: Vector2i = enemy1.coord.vector()
	var first_enemy_attack_origin := Vector2i(-100, -100)
	var saved_hp: int = -1
	var seen_scenes: Dictionary = {}
	deadline = Time.get_ticks_msec() + 90000
	while not state.turn_manager.is_player_turn() and Time.get_ticks_msec() < deadline:
		for unit in state.units:
			if observed_positions.has(unit.id):
				check(HexCoord.distance(observed_positions[unit.id], unit.coord.vector()) <= 1, "TEST4 no teleport between observed hex steps")
			observed_positions[unit.id] = unit.coord.vector()
		if not app.transitioning and app.active_screen.name == "BattleScene":
			var scene: Control = app.active_screen
			var identity := scene.get_instance_id()
			if not seen_scenes.has(identity):
				seen_scenes[identity] = true
				battle_count += 1
				check(state.battle.attacker_unit.enemy and not state.battle.defender_unit.enemy, "TEST5/6 enemy Attacker and player Defender in actual BattleScene")
				if OS.get_cmdline_user_args().has("--normal-speed"):
					scene.speed = 2.0
				else:
					scene.skip = true
				if battle_count == 1:
					first_enemy_attack_origin = state.battle.attacker_origin.vector()
					await snapshot("preview_enemy_battle.png")
			if scene.finished:
				check(not state.turn_manager.is_player_turn() and state.turn == 1, "TEST7 battle completion does not reset enemy turn")
				check(state.grid == original_grid and state.control_points == original_points, "TEST20 terrain and point objects survive battle scene")
				if battle_count == 1:
					check(scene.resolver.winner == 0, "Enemy victory applies same resolver winner semantics")
					await snapshot("preview_enemy_result.png")
				if battle_count == 2:
					saved_hp = PrototypeRules.hp_total(support.squad)
				scene.return_button.pressed.emit()
		await create_timer(0.01).timeout
	check(state.turn_manager.is_player_turn() and state.turn == 2, "TEST9 all living enemies finish then Player Turn2")
	check(battle_count >= 2, "TEST8 remaining enemy acts and attacks after first battle return")
	check(not state.units.has(primary) and enemy1.coord.vector() == first_enemy_attack_origin and state.unit_at(destination) == null, "Enemy victory removes defender and keeps attacker on approach tile")
	check(first_enemy_origin != enemy1.coord.vector() and enemy1.coord.vector() != destination, "AI approaches before attack without occupying defeated defender tile")
	var history: Array[String] = state.enemy_controller.action_history
	check(history == ["enemy1", "enemy2", "enemy3"], "Persistent deterministic cursor, every living enemy exactly once, dead enemy excluded")
	check(saved_hp > 0 and PrototypeRules.hp_total(support.squad) == saved_hp, "Player HP persists through enemy scene return")
	for coord in terrain_ids:
		check(state.grid.tiles[coord].terrain == terrain_ids[coord], "No terrain reset or mutation")
	for unit in state.units:
		check(state.grid.is_passable(unit.coord.vector()), "Every actual AI destination remains passable")
		if not unit.enemy:
			check(not unit.acted and not unit.moved, "Player side action status reset at turn start")
	map = app.active_screen
	for unit in state.units:
		if PrototypeRules.hp_total(unit.squad) <= 0:
			check(not map.board.views.has(unit.id), "No incapacitated map marker")
			continue
		check(map.board.views[unit.id].position == map.board.center(unit.coord.vector()), "Offscreen and onscreen unit nodes use persistent coordinates")
	await snapshot("preview_player_turn2.png")
	# Separate display fixture after the complete turn cycle: demonstrate forest cost labels.
	var forest_unit: SquadMapUnit = null
	for unit in state.units:
		if unit.id == "ally3":
			forest_unit = unit
	forest_unit.coord = HexCoord.from_offset(7, 5)
	map.refresh()
	await click(map, forest_unit.coord.vector())
	map.move_selected()
	var forest_goal := HexCoord.from_offset(9, 5).vector()
	var hover := InputEventMouseMotion.new()
	hover.position = map.board.get_global_transform() * map.board.center(forest_goal)
	root.push_input(hover, true)
	await process_frame
	check(map.board.preview_path.size() == 3 and map.board.search.costs[forest_goal] == 4, "Forest preview labels and actual movement budget agree (0,2,4)")
	await snapshot("preview_terrain_path.png")
	print("Tactical turn cycle: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures; ", battle_count, " enemy battles)")
	quit(failures)



