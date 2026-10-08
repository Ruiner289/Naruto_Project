extends SceneTree
var failures := 0
func check(ok: bool, note: String) -> void:
	if not ok:
		failures += 1
		push_error(note)
func _initialize() -> void:
	call_deferred("run")
func snap(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://" + name)
func tap(map: Control, coord: Vector2i) -> void:
	if root.get_node("GameState").unit_at(coord) == null and map.selected != null and map.selected.can_move() and not map.choosing_attack and map.preview == null:
		map.move_selected()
	if map.action_menu.visible:
		map.action_menu.hide() # This helper targets a hex, not a command button.
	map.focus_hex(coord)
	await process_frame
	var point: Vector2 = map.board.get_global_transform() * map.board.center(coord)
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
	var map: Control = load("res://scenes/battle_map.tscn").instantiate()
	root.add_child(map)
	map.set_fit_view(false)
	await process_frame
	await process_frame
	map.set_process(false)
	var area: Rect2 = map.map_scroll.get_global_rect()
	map.map_scroll.scroll_horizontal = 100
	map.map_scroll.scroll_vertical = 100
	await process_frame
	map.pointer = area.position + Vector2(area.size.x - 2, area.size.y / 2)
	map._process(0.1)
	await process_frame
	check(map.map_scroll.scroll_horizontal == 148, "Cursor right edge scrolls")
	var old_hover: Vector2i = map.board.hovered
	map._process(0.3)
	await process_frame
	map._process(0.0)
	check(map.board.hovered != old_hover, "Stationary cursor tracks tiles after pan")
	map.pointer = area.position + Vector2(2, area.size.y / 2)
	map._process(0.1)
	check(map.map_scroll.scroll_horizontal == 244, "Cursor left edge scrolls")
	map.pointer = area.position + Vector2(area.size.x / 2, area.size.y - 2)
	map._process(0.1)
	check(map.map_scroll.scroll_vertical == 148, "Cursor bottom edge scrolls")
	map.pointer = area.position + Vector2(area.size.x / 2, 2)
	map._process(0.1)
	check(map.map_scroll.scroll_vertical == 100, "Cursor top edge scrolls")
	map.map_scroll.scroll_horizontal = 0
	map.pointer = area.position + Vector2(2, area.size.y / 2)
	map._process(1.0)
	check(map.map_scroll.scroll_horizontal == 0, "Camera clamps at west boundary")
	map.pointer = area.position + Vector2(area.size.x - 2, area.size.y / 2)
	map._process(100.0)
	await process_frame
	var east_limit: int = map.map_scroll.scroll_horizontal
	map._process(1.0)
	check(map.map_scroll.scroll_horizontal == east_limit, "Camera clamps at east boundary")
	map.map_scroll.scroll_horizontal = 244
	state.turn_manager.current_side = TurnManager.TurnSide.ENEMY
	map._process(1.0)
	check(map.map_scroll.scroll_horizontal == 244, "Enemy turn pauses cursor pan")
	state.turn_manager.current_side = TurnManager.TurnSide.PLAYER
	map.pointer = Vector2(1250, 400)
	map._process(1.0)
	check(map.map_scroll.scroll_vertical == 100 and not map.board.cursor.visible, "Sidebar cursor does not pan/highlight")
	map.pointer = area.get_center()
	var wheel := InputEventMouseButton.new()
	wheel.position = map.pointer
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	root.push_input(wheel, true)
	await process_frame
	check(map.map_scroll.scroll_vertical == 100, "Wheel does not pan")
	var ally: SquadMapUnit = state.units[0]
	await tap(map, ally.coord.vector())
	map._process(0.0)
	check(map.selected == ally and map.action_menu.visible and map.board.cursor.z_index == 40, "Ally selected with cursor above units")
	await snap("preview_cursor_hex.png")
	map.info_selected()
	check(map.inspector != null and map.inspector.formation.read_only and not map.inspector.formation.mirror_display, "Friendly Info button opens read-only formation")
	var before := JSON.stringify(ally.squad.to_dict())
	check(map.inspector.formation._get_drag_data(Vector2.ZERO) == null, "Inspector cannot drag")
	map.inspector.formation._drop_data(Vector2.ZERO, {"ninja_id": "naruto"})
	check(JSON.stringify(ally.squad.to_dict()) == before, "Inspector cannot edit")
	await snap("preview_ally_formation.png")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.position = Vector2(640, 360)
	right.pressed = true
	root.push_input(right, true)
	check(map.inspector == null and map.selected == ally, "Cancel closes formation and retains selection")
	var enemy: SquadMapUnit = state.units[2]
	enemy.acted = true
	before = JSON.stringify(enemy.squad.to_dict())
	var position := enemy.coord.vector()
	await tap(map, position)
	check(map.selected == enemy and map.preview == null and map.board.search.costs.size() > 1 and not map.board.attack_tiles.is_empty(), "Enemy first click shows full threat despite acted status")
	await snap("preview_enemy_ranges.png")
	map.info_selected()
	check(map.inspector != null and map.inspector.formation.snapshot_squad == enemy.squad and map.inspector.formation.mirror_display, "Enemy Info button inspects original formation with visual mirror")
	var scroll_before := Vector2i(map.map_scroll.scroll_horizontal, map.map_scroll.scroll_vertical)
	map.pointer = area.position + Vector2(2, 2)
	map._process(1.0)
	check(Vector2i(map.map_scroll.scroll_horizontal, map.map_scroll.scroll_vertical) == scroll_before, "Modal pauses cursor camera")
	await snap("preview_enemy_formation.png")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	check(map.inspector == null and map.selected == enemy, "Escape closes inspector")
	map.cancel_interaction()
	check(map.selected == null and map.command_unit == null, "Next cancel clears selection")
	check(enemy.coord.vector() == position and enemy.acted and JSON.stringify(enemy.squad.to_dict()) == before and state.battle == null, "Inspection never changes position/HP/actions/battle")
	print("Cursor and inspection: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)



