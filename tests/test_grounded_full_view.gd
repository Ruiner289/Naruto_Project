extends SceneTree
var failures := 0
func check(ok: bool, note: String) -> void:
	if not ok:
		failures += 1
		push_error(note)
func _initialize() -> void:
	call_deferred("run")
func screenshot(path: String) -> void:
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://" + path)
func run() -> void:
	root.size = Vector2i(1280, 720)
	var state: Node = root.get_node("GameState")
	var map: Control = load("res://scenes/battle_map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	await process_frame
	map.update_view()
	check(map.fit_view and not map.details_drawer.visible, "Default view uses whole battlefield with folded information")
	check(map.map_scroll.size.x > 1200, "Battlefield spans available screen width")
	var area: Rect2 = map.map_scroll.get_global_rect()
	for coord in state.grid.tiles:
		check(area.has_point(map.board.get_global_transform() * map.board.center(coord)), "Every tile centre is visible in fit view")
	await screenshot("grounded_full_map.png")
	var target: SquadMapUnit = state.units[7]
	var point: Vector2 = map.board.get_global_transform() * map.board.center(target.coord.vector())
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame
	check(map.selected == target and map.action_menu.visible, "Scaled edge tile selection opens the correct unit menu")
	check(area.encloses(map.action_menu.get_global_rect()), "Menu remains inside the full map viewport")
	map.cancel_interaction()
	map.set_fit_view(false)
	check(map.board_zoom > 1.0, "Detail view retains camera navigation")
	map.set_fit_view(true)
	map.hide()
	var context := BattleContext.new(state.units[1], state.units[2])
	var formation_before := JSON.stringify(context.attacker.to_dict())
	var stage := BattleStage.new()
	stage.context = context
	stage.roster = state.formation.roster
	stage.position = Vector2(20, 60)
	stage.size = Vector2(1240, 590)
	root.add_child(stage)
	await process_frame
	stage.layout_views()
	var floor_y: float = stage.size.y * 2.0 / 3.0
	for view: CharacterBattleView in stage.views.values():
		var foot: Vector2 = view.home + CharacterBattleView.GROUND
		check(foot.y > floor_y and foot.y < stage.size.y - 20, "Every character's ground pivot lies on the foreground floor")
		check(view.compact_status, "Packed sprites use compact health bars")
	check(stage.PITCH.y < 40 and stage.PITCH.x < 80, "Formation uses close ground spacing")
	check(JSON.stringify(context.attacker.to_dict()) == formation_before, "Ground presentation preserves combat formation data")
	await screenshot("grounded_battle_pack.png")
	if DisplayServer.get_name() != "headless":
		var original_mode := DisplayServer.window_get_mode()
		for attempt in 2:
			for pressed in [true, false]:
				var key := InputEventKey.new()
				key.keycode = KEY_F11
				key.pressed = pressed
				root.push_input(key, true)
			await process_frame
			await process_frame
			check(DisplayServer.window_get_mode() == (DisplayServer.WINDOW_MODE_FULLSCREEN if attempt == 0 else original_mode), "F11 toggles fullscreen and returns to the original window mode")
	print("Grounded battle and full map: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
