extends SceneTree
var failures := 0
func check(ok: bool, note: String) -> void:
	if not ok:
		failures += 1
		push_error(note)
func _initialize() -> void:
	call_deferred("run")
func click(point: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
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
	var map: Control = load("res://scenes/battle_map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	await process_frame
	await click(Vector2(1270, 710), MOUSE_BUTTON_RIGHT)
	check(map.context_menu.visible and map.get_global_rect().encloses(map.context_menu.get_global_rect()), "Idle right click opens clamped menu at screen edge")
	check(not map.context_end_button.disabled, "Context end turn is available")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://context_menu_preview.png")
	await click(map.context_menu.get_node("UnitList").get_global_rect().get_center())
	check(map.unit_list != null and not map.context_menu.visible and map.end_button.disabled, "Unit list opens and blocks turn changes")
	var entries: Array[Button] = []
	for button in map.unit_list.find_children("*", "Button", true, false):
		if button.name == state.units[2].id:
			entries.append(button)
	check(entries.size() == 1, "List contains live enemy squad")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://context_unit_list_preview.png")
	await click(entries[0].get_global_rect().get_center())
	check(map.unit_list == null and map.inspector != null and map.selected == state.units[2], "List entry inspects the original enemy formation")
	await click(Vector2(800, 500), MOUSE_BUTTON_RIGHT)
	check(map.inspector == null and map.selected != null, "Right click closes inspection first")
	await click(Vector2(800, 500), MOUSE_BUTTON_RIGHT)
	check(map.selected == null and not map.context_menu.visible, "Selected-unit cancel keeps its existing priority")
	await click(Vector2(30, 35), MOUSE_BUTTON_RIGHT)
	check(map.context_menu.visible, "Idle right click also works over the toolbar")
	await click(map.context_end_button.get_global_rect().get_center())
	check(not state.turn_manager.is_player_turn() and not map.context_menu.visible and state.units[0].acted, "Context turn button ends player turn and commits remaining waits")
	await click(Vector2(500, 400), MOUSE_BUTTON_RIGHT)
	check(not map.context_menu.visible, "Enemy turn blocks context commands")
	state.turn_manager.current_side = TurnManager.TurnSide.PLAYER
	for unit in state.units:
		unit.acted = false
	map.refresh()
	await click(map.end_button.get_global_rect().get_center())
	check(not state.turn_manager.is_player_turn(), "Visible toolbar end button receives real mouse input above full-screen map")
	print("Battlefield context commands: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
