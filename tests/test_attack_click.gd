extends SceneTree
var failures := 0
func check(ok: bool, note: String) -> void:
	if not ok:
		failures += 1
		push_error(note)
func _initialize() -> void:
	call_deferred("run")
func tap(map: Control, unit: SquadMapUnit) -> void:
	map.action_menu.hide()
	var point: Vector2 = map.board.get_global_transform() * map.board.center(unit.coord.vector())
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
	state.grid = HexGrid.new(12, 8)
	state.units.resize(4)
	var ally: SquadMapUnit = state.units[0]
	var enemy: SquadMapUnit = state.units[2]
	ally.coord = HexCoord.from_offset(2, 3)
	enemy.coord = HexCoord.from_offset(6, 3)
	state.units[1].coord = HexCoord.from_offset(2, 6)
	state.units[3].coord = HexCoord.from_offset(10, 6)
	var map: Control = load("res://scenes/battle_map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	map.set_process(false)
	await tap(map, enemy)
	check(map.selected == enemy and map.preview == null, "No ally selected: inspect enemy ranges")
	map.info_selected()
	check(map.inspector != null, "Enemy Info button opens formation")
	map.cancel_interaction()
	map.cancel_interaction()
	await tap(map, ally)
	var origin := ally.coord.vector()
	var hp := PrototypeRules.hp_total(ally.squad)
	await tap(map, enemy)
	check(map.selected == enemy and map.preview == null and state.battle == null, "Reachable enemy click is inspection, never automatic approach attack")
	check(not ally.acted and ally.coord.vector() == origin and PrototypeRules.hp_total(ally.squad) == hp, "Inspection preserves ally state")
	map.info_selected()
	check(map.inspector != null, "Enemy Info button opens formation without changing allied state")
	map.cancel_interaction()
	map.cancel_interaction()
	enemy.coord = HexCoord.from_vector(ally.coord.vector() + Vector2i(1, 0))
	ally.moved = true
	map.refresh()
	await tap(map, ally)
	check(map.board.attack_tiles.is_empty(), "Ally selection does not show attack colors")
	await tap(map, enemy)
	check(map.preview == null and map.selected == enemy, "Adjacent enemy click also requires explicit Attack command")
	await tap(map, ally)
	map.show_action_menu()
	map.attack_button.pressed.emit()
	check(map.choosing_attack and map.board.attack_tiles.has(enemy.coord.vector()), "Attack button starts target mode and colors legal enemy")
	await tap(map, enemy)
	check(map.preview != null and map.selected == ally, "Explicit Attack then enemy opens preview")
	map.cancel_interaction()
	check(map.preview == null and map.board.attack_tiles.is_empty() and map.action_menu.visible, "Preview cancel restores uncolored menu")
	ally.acted = true
	map.refresh()
	map.attack_selected()
	check(not map.choosing_attack, "Acted ally cannot enter target mode")
	await tap(map, enemy)
	check(map.selected == enemy and map.preview == null, "Acted ally enemy click remains inspection")
	print("Explicit attack command: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
