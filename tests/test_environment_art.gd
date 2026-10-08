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
	var before: Dictionary = {}
	for coord in state.grid.tiles:
		before[coord] = [state.grid.movement_cost(coord), state.grid.is_passable(coord)]
	for terrain in 7:
		for variant in 3:
			var tex := EnvironmentArt.texture("hex_%s_%d" % [EnvironmentArt.TERRAIN_IDS[terrain], variant])
			check(tex != null and tex.get_size() == Vector2(64, 74), "Every terrain variant has a hex sprite")
			var im := tex.get_image()
			check(im.get_pixel(0, 0).a == 0 and im.get_pixel(32, 37).a == 1, "Hex corners are transparent and terrain centre is opaque")
	for id in ["tree_oak", "tree_pine", "bush", "rock", "dead_tree", "fallen_log", "village_house", "village_shop", "outpost", "stall"]:
		check(EnvironmentArt.texture(id) != null, "Extracted prop loads: " + id)
	var map: Control = load("res://scenes/battle_map.tscn").instantiate()
	root.add_child(map)
	map.set_fit_view(false)
	await process_frame
	await process_frame
	map.set_process(false)
	await screenshot("environment_map_west.png")
	map.map_scroll.scroll_horizontal = 410
	map.map_scroll.scroll_vertical = 160
	await screenshot("environment_map_center.png")
	map.map_scroll.scroll_horizontal = 900
	map.map_scroll.scroll_vertical = 250
	await screenshot("environment_map_east.png")
	map.on_hex_clicked(state.units[2].coord.vector())
	await screenshot("environment_map_ranges.png")
	for coord in state.grid.tiles:
		check(before[coord] == [state.grid.movement_cost(coord), state.grid.is_passable(coord)], "Artwork leaves terrain rules intact")
	map.hide()
	var context := BattleContext.new(state.units[0], state.units[2])
	var stage := BattleStage.new()
	stage.context = context
	stage.roster = state.formation.roster
	stage.position = Vector2(60, 90)
	root.add_child(stage)
	await process_frame
	check(stage.views.size() == 8 and stage.is_left(0) and not stage.is_left(1), "Background preserves character views and faction placement")
	await screenshot("environment_battle_village.png")
	var original := context.defender_unit.coord
	context.defender_unit.coord = HexCoord.from_offset(8, 5)
	stage.queue_redraw()
	await screenshot("environment_battle_forest.png")
	check(EnvironmentArt.backdrop(context, state.grid) == EnvironmentArt.texture("battle_forest"), "Forest encounter chooses forest scenery")
	context.defender_unit.coord = HexCoord.from_offset(14, 8)
	stage.queue_redraw()
	await screenshot("environment_battle_bridge.png")
	check(EnvironmentArt.backdrop(context, state.grid) == EnvironmentArt.texture("battle_bridge"), "Waterside encounter chooses bridge scenery")
	context.defender_unit.coord = original
	print("Environment artwork: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
