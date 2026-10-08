extends SceneTree
var failures := 0
func check(ok: bool, note: String) -> void:
	if not ok:
		failures += 1
		push_error(note)
func _initialize() -> void:
	call_deferred("run")
func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame
func run() -> void:
	root.size = Vector2i(1280, 720)
	var state: Node = root.get_node("GameState")
	state.grid = HexGrid.new(20, 14)
	state.units.resize(4)
	var ally: SquadMapUnit = state.units[0]
	var enemy: SquadMapUnit = state.units[2]
	var origin := Vector2i(2, 2)
	var goal := Vector2i(3, 2)
	ally.coord = HexCoord.from_vector(origin)
	enemy.coord = HexCoord.new(4, 2)
	state.units[1].coord = HexCoord.new(1, 5)
	state.units[3].coord = HexCoord.new(10, 2)
	var map: Control = load("res://scenes/battle_map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	map.on_hex_clicked(origin)
	check(map.action_menu.visible and map.move_button.visible and map.info_button.visible and map.wait_button.visible, "Unit selection opens explicit commands")
	map.move_selected()
	map.on_hex_clicked(goal)
	check(not map.action_menu.visible, "Menu hidden during tween")
	while map.busy:
		await process_frame
	await process_frame
	check(map.board.attack_tiles.is_empty(), "Move does not color attack tiles before command")
	check(map.action_menu.visible and map.attack_button.visible, "Move opens local menu with adjacent attack")
	check(map.map_scroll.get_global_rect().encloses(map.action_menu.get_global_rect()), "Menu stays inside map viewport")
	var scroll := Vector2i(map.map_scroll.scroll_horizontal, map.map_scroll.scroll_vertical)
	map.pointer = map.map_scroll.get_global_rect().end - Vector2(1, 1)
	map._process(0.5)
	check(scroll == Vector2i(map.map_scroll.scroll_horizontal, map.map_scroll.scroll_vertical), "Local menu freezes edge pan")
	await click(map.attack_button)
	check(map.choosing_attack and not map.action_menu.visible and map.selected == ally and map.preview == null, "Attack button enters target selection without click leaking")
	check(map.board.attack_tiles.size() == 1 and map.board.attack_tiles.has(enemy.coord.vector()) and map.board.search.costs.is_empty(), "Attack command colors only legal targets, without movement overlay")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://attack_target_preview.png")
	map.on_hex_clicked(state.units[3].coord.vector())
	check(map.selected == ally and map.preview == null and map.choosing_attack, "Out of range target does not inspect or attack")
	map.cancel_interaction()
	check(map.board.attack_tiles.is_empty(), "Cancelling target selection clears attack colors")
	check(map.action_menu.visible and ally.coord.vector() == goal and not map.choosing_attack, "Target cancel returns to menu without undo")
	await click(map.attack_button)
	map.on_hex_clicked(enemy.coord.vector())
	check(map.preview != null and not map.action_menu.visible, "Legal target opens preview")
	map.cancel_interaction()
	check(map.preview == null and map.action_menu.visible and ally.coord.vector() == goal, "Preview cancel restores local menu")
	await click(map.action_menu.get_node("Commands/CancelMove"))
	check(ally.coord.vector() == origin and ally.can_move() and map.action_menu.visible, "Menu cancel restores origin and movement")
	enemy.coord = HexCoord.new(8, 2)
	map.move_selected()
	map.on_hex_clicked(goal)
	while map.busy:
		await process_frame
	await process_frame
	check(map.action_menu.visible and not map.attack_button.visible, "No adjacent enemy means no Attack button")
	await click(map.wait_button)
	check(ally.acted and ally.coord.vector() == goal and state.pending_move_unit == null and not map.action_menu.visible, "Wait commits movement and closes menu")
	map.cancel_interaction()
	check(ally.coord.vector() == goal and ally.acted, "Completed wait cannot be undone")
	ally.acted = false
	ally.moved = false
	map.move_selected()
	map.on_hex_clicked(goal)
	map.show_action_menu()
	check(map.action_menu.visible and not map.attack_button.visible, "Standing unit can open menu; reachable distant enemies do not add Attack")
	await click(map.wait_button)
	check(ally.acted, "Standing unit can wait")
	ally.acted = false
	map.cancel_interaction()
	map.on_hex_clicked(enemy.coord.vector())
	check(map.action_menu.visible and map.info_button.visible and not map.move_button.visible and not map.wait_button.visible and map.selected == enemy, "Enemy inspection never shows command menu")
	map.move_selected()
	map.on_hex_clicked(goal)
	map.show_action_menu()
	map.map_scroll.scroll_horizontal = 430
	map.map_scroll.scroll_vertical = 210
	map.position_action_menu()
	check(map.map_scroll.get_global_rect().encloses(map.action_menu.get_global_rect()), "Offscreen anchor menu clamps inside viewport")
	if not DisplayServer.get_name() == "headless":
		map.map_scroll.scroll_horizontal = 0
		map.map_scroll.scroll_vertical = 0
		ally.coord = HexCoord.from_vector(origin)
		enemy.coord = HexCoord.new(4, 2)
		map.menu_requested = false
		map.refresh()
		map.selected = ally
		map.move_selected()
		map.on_hex_clicked(goal)
		while map.busy:
			await process_frame
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://action_menu_preview.png")
	print("Context action menu: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
