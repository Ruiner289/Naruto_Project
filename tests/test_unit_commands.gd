extends SceneTree
var failures := 0
func check(ok: bool, note: String) -> void:
	if not ok:
		failures += 1
		push_error(note)
func _initialize() -> void:
	call_deferred("run")
func tap(point: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = button
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame
func command(button: Button) -> void:
	await process_frame
	await tap(button.get_global_rect().get_center())
func hex(map: Control, coord: Vector2i) -> void:
	await tap(map.board.get_global_transform() * map.board.center(coord))
func screenshot(path: String) -> void:
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://" + path)
func run() -> void:
	root.size = Vector2i(1280, 720)
	var state: Node = root.get_node("GameState")
	state.grid = HexGrid.new(20, 14)
	state.units.resize(4)
	var ally: SquadMapUnit = state.units[0]
	var enemy: SquadMapUnit = state.units[2]
	var origin := Vector2i(2, 2)
	var goal := Vector2i(2, 3)
	ally.coord = HexCoord.from_vector(origin)
	enemy.coord = HexCoord.new(3, 2)
	state.units[1].coord = HexCoord.new(1, 6)
	state.units[3].coord = HexCoord.new(10, 2)
	var hp := ally.squad.current_hp.duplicate()
	var map: Control = load("res://scenes/battle_map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	await process_frame
	map.set_process(false)
	await hex(map, origin)
	check(map.action_menu.visible and map.move_button.visible and map.attack_button.visible and map.info_button.visible and map.wait_button.visible, "First unit click opens Move/Attack/Info/Wait")
	check(map.board.search.costs.size() > 1 and not map.board.attack_tiles.is_empty(), "Selection shows move and potential attack overlays")
	await hex(map, origin)
	check(map.inspector == null and map.action_menu.visible, "Repeated unit click keeps command menu, never opens inspection")
	map.on_hex_clicked(goal)
	check(ally.coord.vector() == origin and not map.busy and not ally.moved, "Vacant tile cannot move unit before Move command")
	await screenshot("unit_commands_menu.png")
	await command(map.info_button)
	check(map.inspector != null and not map.action_menu.visible, "Info button alone opens formation")
	await tap(Vector2(1200, 650), MOUSE_BUTTON_RIGHT)
	check(map.inspector == null and map.selected == ally and map.action_menu.visible, "Right click closes information and restores commands")
	await command(map.attack_button)
	check(map.choosing_attack and map.board.attack_tiles.size() == 1 and map.board.attack_tiles.has(enemy.coord.vector()), "Standing Attack colors only current legal target")
	await screenshot("unit_commands_attack.png")
	await hex(map, enemy.coord.vector())
	check(map.preview != null and map.inspector == null and map.selected == ally, "Standing target click opens attack preview, not enemy information")
	await tap(Vector2(1200, 650), MOUSE_BUTTON_RIGHT)
	check(map.preview == null and map.action_menu.visible and ally.coord.vector() == origin and not ally.acted, "Preview cancellation preserves standing action")
	await command(map.attack_button)
	await hex(map, enemy.coord.vector())
	map.confirm_attack()
	check(state.battle != null and ally.acted and ally.coord.vector() == origin and state.battle.attacker_origin.vector() == origin, "Confirmed stationary attack preserves attacking tile")
	check(ally.squad.current_hp == hp and state.pending_move_unit == null, "Attack entry neither edits HP nor invents pending movement")
	state.battle = null
	ally.acted = false
	map.refresh()
	map.show_action_menu()
	await command(map.move_button)
	check(map.choosing_move and not map.action_menu.visible and map.board.search.costs.has(goal) and map.board.attack_tiles.is_empty(), "Move command alone exposes movement range")
	await tap(Vector2(1200, 650), MOUSE_BUTTON_RIGHT)
	check(not map.choosing_move and map.action_menu.visible and ally.coord.vector() == origin, "Move target cancellation returns to commands")
	await command(map.move_button)
	await hex(map, goal)
	while map.busy:
		await process_frame
	await process_frame
	check(ally.coord.vector() == goal and state.pending_move_unit == ally and map.action_menu.visible, "Movement ends in provisional command menu")
	check(map.move_button.disabled and map.board.attack_tiles.is_empty(), "Moved unit cannot move again and has no attack overlay")
	await command(map.info_button)
	check(map.inspector != null and state.pending_move_unit == ally, "Information preserves provisional movement")
	await tap(Vector2(1200, 650), MOUSE_BUTTON_RIGHT)
	check(ally.coord.vector() == goal and map.action_menu.visible, "First cancel only closes information")
	await tap(Vector2(1200, 650), MOUSE_BUTTON_RIGHT)
	check(ally.coord.vector() == origin and ally.can_move() and map.action_menu.visible, "Next cancel undoes movement and restores commands")
	await command(map.wait_button)
	check(ally.acted and not ally.moved and ally.coord.vector() == origin and not map.action_menu.visible, "Standing Wait ends action without moving")
	await tap(Vector2(1200, 650), MOUSE_BUTTON_RIGHT)
	check(ally.acted and ally.coord.vector() == origin, "Completed Wait cannot be undone")
	await hex(map, origin)
	check(map.action_menu.visible and map.move_button.disabled and map.wait_button.disabled and map.info_button.visible, "Acted unit still offers information, with actions disabled")
	ally.acted = false
	map.refresh()
	await command(map.move_button)
	await hex(map, goal)
	while map.busy:
		await process_frame
	await command(map.wait_button)
	check(ally.acted and ally.coord.vector() == goal and state.pending_move_unit == null, "Moved Wait commits destination")
	map.cancel_interaction()
	await hex(map, enemy.coord.vector())
	check(map.action_menu.visible and map.info_button.visible and not map.move_button.visible and not map.attack_button.visible and not map.wait_button.visible, "Enemy menu offers information without allied actions")
	await command(map.info_button)
	check(map.inspector != null and map.selected == enemy, "Enemy information opens from Info command")
	map.cancel_interaction()
	state.turn_manager.current_side = TurnManager.TurnSide.ENEMY
	map.refresh()
	map.on_hex_clicked(ally.coord.vector())
	check(not map.action_menu.visible and map.selected == enemy, "Enemy turn blocks player command selection")
	print("Explicit unit commands: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
