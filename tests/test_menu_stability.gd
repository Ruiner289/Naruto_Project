extends SceneTree
var failures := 0
func check(ok: bool, note: String) -> void:
	if not ok:
		failures += 1
		push_error(note)
func _initialize() -> void:
	call_deferred("run")
func stable(map: Control, note: String) -> void:
	await process_frame # Apply explicit ScrollContainer offset changes before measuring.
	map.position_action_menu()
	var initial: Rect2 = map.action_menu.get_global_rect()
	for i in 60:
		map.on_hex_hovered(Vector2i(1, 1))
		map._process(0.016)
		await process_frame
		check(map.action_menu.get_global_rect() == initial, note + " frame " + str(i))
	check(map.map_scroll.get_global_rect().encloses(initial), note + " is clamped inside viewport")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var state: Node = root.get_node("GameState")
	state.grid = HexGrid.new(20, 14)
	state.units.resize(4)
	var ally: SquadMapUnit = state.units[0]
	var enemy: SquadMapUnit = state.units[2]
	ally.coord = HexCoord.new(2, 2)
	enemy.coord = HexCoord.new(3, 2)
	state.units[1].coord = HexCoord.new(1, 6)
	state.units[3].coord = HexCoord.new(10, 2)
	var map: Control = load("res://scenes/battle_map.tscn").instantiate()
	root.add_child(map)
	map.set_fit_view(false)
	await process_frame
	await process_frame
	map.on_hex_clicked(ally.coord.vector())
	var width: float = map.action_menu.size.x
	for button in [map.move_button, map.attack_button, map.info_button, map.wait_button, map.action_menu.get_node("Commands/CancelMove")]:
		check(button.size == Vector2(180, 38), "First visible frame has uniform button geometry")
	check(map.board.search.costs == state.search_for(ally).costs and not map.board.attack_tiles.is_empty(), "Ally initial selection shows legal movement and potential attack")
	await stable(map, "Initial menu")
	map.map_scroll.scroll_horizontal = 800
	map.map_scroll.scroll_vertical = 350
	await process_frame
	await stable(map, "Offscreen left/top anchor")
	map.selected = state.units[3]
	var original_title: String = map.selected.squad.squad_name
	map.selected.squad.squad_name = "아주 긴 이름을 가진 부대 — 메뉴 너비가 늘어나면 안 됩니다"
	map.map_scroll.scroll_horizontal = 0
	map.map_scroll.scroll_vertical = 0
	map.show_action_menu()
	check(map.action_menu.size.x == width and map.info_button.size.x == 180, "Enemy and long title keep the same menu/button widths")
	await stable(map, "Offscreen right anchor")
	state.units[3].squad.squad_name = original_title
	map.selected = enemy
	map.show_action_menu()
	check(map.board.search.costs == state.search_for(enemy, false, true).costs and not map.board.attack_tiles.is_empty(), "Enemy initial selection uses the same range presentation")
	map.selected = ally
	map.show_action_menu()
	map.attack_selected()
	check(map.board.search.costs.is_empty() and map.board.attack_tiles.size() == 1 and map.board.attack_tiles.has(enemy.coord.vector()), "Attack command still displays only actual legal targets")
	map.cancel_interaction()
	check(map.board.search.costs.size() > 1 and not map.board.attack_tiles.is_empty(), "Cancelling standing attack restores potential range preview")
	map.move_selected()
	check(map.board.search.costs.size() > 1 and map.board.attack_tiles.is_empty(), "Move mode has movement overlay only")
	map.on_hex_clicked(Vector2i(2, 3))
	while map.busy:
		await process_frame
	check(map.action_menu.visible and map.board.search.costs.is_empty() and map.board.attack_tiles.is_empty(), "Moved menu preserves no automatic attack overlay")
	map.cancel_interaction()
	check(ally.can_move() and map.board.search.costs.size() > 1 and not map.board.attack_tiles.is_empty(), "Move undo restores initial potential ranges")
	map.selected = state.units[3]
	map.show_action_menu()
	await stable(map, "Repeated reopen")
	map.selected = ally
	map.show_action_menu()
	await stable(map, "Reopened ally")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://menu_stability_preview.png")
	print("Menu geometry and range consistency: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
