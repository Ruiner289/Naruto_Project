extends SceneTree

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func mouse(point: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
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

func run() -> void:
	root.size = Vector2i(1280, 720)
	var state: Node = root.get_node("GameState")
	# Compact plain-field fixture keeps earlier input regression deterministic.
	state.grid = HexGrid.new(12, 8)
	state.units.resize(4)
	state.units[0].coord = HexCoord.from_offset(2, 3)
	state.units[1].coord = HexCoord.from_offset(2, 5)
	state.units[2].coord = HexCoord.from_offset(6, 3)
	state.units[3].coord = HexCoord.from_offset(8, 5)
	var unit: SquadMapUnit = state.units[0]
	var formation_screen: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(formation_screen)
	await process_frame
	formation_screen.select_ninja(unit.squad.leader_id)
	var before := JSON.stringify(unit.squad.to_dict())
	await mouse(formation_screen.board.global_position + formation_screen.board.slot_rect(unit.squad.positions[unit.squad.leader_id]).get_center(), MOUSE_BUTTON_RIGHT)
	check(formation_screen.selected_id == "", "Formation right-click clears selection")
	check(JSON.stringify(unit.squad.to_dict()) == before, "Right-click never removes a member")
	formation_screen.select_ninja("naruto")
	var source: Control = formation_screen.list.get_children()[6]
	source.force_drag({"ninja_id": "naruto"}, Label.new())
	check(root.gui_is_dragging(), "GUI drag begun")
	await mouse(Vector2(1210, 680), MOUSE_BUTTON_RIGHT)
	check(not root.gui_is_dragging() and formation_screen.selected_id == "", "Right-click cancels drag outside board")
	check(JSON.stringify(unit.squad.to_dict()) == before, "Cancelled drag keeps formation")
	root.remove_child(formation_screen)
	formation_screen.queue_free()
	var map: Control = load("res://scenes/battle_map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	var point: Vector2 = map.board.get_global_transform() * map.board.center(unit.coord.vector())
	await mouse(point)
	check(map.selected == unit and map.action_menu.visible, "Left-click selects ally")
	map.move_selected()
	var goal: Vector2i = unit.coord.vector() + Vector2i(1, 0)
	var motion := InputEventMouseMotion.new()
	motion.position = map.board.get_global_transform() * map.board.center(goal)
	root.push_input(motion, true)
	await process_frame
	check(map.board.preview_path.size() == 2 and map.board.preview_path.back() == goal, "Hover previews actual path")
	await mouse(Vector2(1210, 650), MOUSE_BUTTON_RIGHT)
	check(map.action_menu.visible and not map.choosing_move, "Move cancellation returns to command menu")
	await mouse(Vector2(1210, 650), MOUSE_BUTTON_RIGHT)
	check(map.selected == null and map.board.preview_path.is_empty() and map.board.search.costs.is_empty(), "Map right-click clears selection/path/range anywhere")
	await mouse(point)
	var enemy: SquadMapUnit = state.units[2]
	enemy.coord = HexCoord.from_vector(unit.coord.vector() + Vector2i(-1, 0))
	map.refresh()
	map.show_action_menu()
	map.attack_selected()
	await mouse(map.board.get_global_transform() * map.board.center(enemy.coord.vector()))
	check(map.selected == unit and map.preview != null and map.inspector == null and state.battle == null, "Attack command then legal enemy opens preview")
	check(not unit.acted and JSON.stringify(unit.squad.to_dict()) == before, "Preview has no action or HP side effects")
	var original: Vector2i = unit.coord.vector()
	await mouse(Vector2(650, 350), MOUSE_BUTTON_RIGHT)
	check(map.preview == null and map.selected == unit and map.command_unit == unit and unit.coord.vector() == original and not unit.acted, "Right-click preview cancellation retains selected unit and original position")
	map.attack_selected()
	await mouse(map.board.get_global_transform() * map.board.center(enemy.coord.vector()))
	map.preview.cancel_button.pressed.emit()
	check(map.preview == null and not unit.acted, "Cancel button is equivalent")
	map.cancel_interaction()
	await mouse(point)
	map.move_selected()
	await mouse(map.board.get_global_transform() * map.board.center(goal))
	check(map.busy, "Move committed")
	await mouse(Vector2(1210, 650), MOUSE_BUTTON_RIGHT)
	check(map.busy and map.selected == unit, "Committed movement not interrupted")
	await mouse(map.board.get_global_transform() * map.board.center(state.units[1].coord.vector()))
	check(map.selected == unit and not state.units[1].acted, "Other ally click ignored during movement")
	var deadline: int = Time.get_ticks_msec() + 5000
	while map.busy and Time.get_ticks_msec() < deadline:
		await create_timer(0.01).timeout
	check(unit.coord.vector() == goal and unit.moved and not unit.acted, "Movement keeps attack/wait available")
	var final_coord: Vector2i = unit.coord.vector()
	await mouse(map.board.get_global_transform() * map.board.center(goal + Vector2i(1, 0)))
	check(unit.coord.vector() == final_coord and not map.busy, "Acted unit cannot move again")
	print("Interaction tests: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)



