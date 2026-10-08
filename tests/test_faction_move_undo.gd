extends SceneTree
var failures := 0
func check(ok: bool, note: String) -> void:
	if not ok:
		failures += 1
		push_error(note)
func _initialize() -> void:
	call_deferred("run")
func cancel_input(escape: bool = false) -> void:
	if escape:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = true
		root.push_input(event, true)
	else:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = true
		event.position = Vector2(1200, 650)
		root.push_input(event, true)
	await process_frame
func run() -> void:
	root.size = Vector2i(1280, 720)
	var state: Node = root.get_node("GameState")
	state.grid = HexGrid.new(12, 8)
	state.units.resize(4)
	var ally: SquadMapUnit = state.units[0]
	var friend: SquadMapUnit = state.units[1]
	var enemy: SquadMapUnit = state.units[2]
	ally.coord = HexCoord.new(2, 2)
	friend.coord = HexCoord.new(1, 4)
	enemy.coord = HexCoord.new(4, 2)
	state.units[3].coord = HexCoord.new(8, 2)
	var origin := ally.coord.vector()
	var goal := Vector2i(3, 2)
	var hp := ally.squad.current_hp.duplicate()
	var map: Control = load("res://scenes/battle_map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	map.set_process(false)
	map.on_hex_clicked(origin)
	map.move_selected()
	map.on_hex_clicked(goal)
	check(map.busy, "Movement animation begins")
	map.cancel_interaction()
	check(map.busy, "Cancel does not interrupt an active movement tween")
	while map.busy:
		await process_frame
	check(ally.coord.vector() == goal and ally.moved and not ally.acted and state.pending_move_unit == ally, "Movement remains provisional until attack or wait")
	await cancel_input()
	check(ally.coord.vector() == origin and not ally.moved and not ally.acted and map.selected == ally and state.pending_move_unit == null, "Right-click restores origin, movement allowance and selected ally")
	check(ally.squad.current_hp == hp and state.unit_at(goal) == null and state.unit_at(origin) == ally, "Undo preserves HP and fixes map occupancy")
	check(map.board.views[ally.id].position == map.board.center(origin) and not map.move_button.disabled, "Undo updates visible marker and movement range")
	map.move_selected()
	map.on_hex_clicked(goal)
	while map.busy:
		await process_frame
	map.attack_selected()
	map.on_hex_clicked(enemy.coord.vector())
	check(map.preview != null, "Moved ally can preview adjacent attack")
	await cancel_input()
	check(map.preview == null and ally.coord.vector() == goal and state.pending_move_unit == ally, "First cancel closes attack preview, preserving pending move")
	await cancel_input(true)
	check(ally.coord.vector() == origin and ally.can_move(), "Escape then cancels the pending move")
	map.move_selected()
	map.on_hex_clicked(goal)
	while map.busy:
		await process_frame
	map.on_hex_clicked(friend.coord.vector())
	check(ally.coord.vector() == origin and ally.can_move() and map.selected == friend, "Selecting another ally cancels previous provisional move")
	map.on_hex_clicked(origin)
	map.move_selected()
	map.on_hex_clicked(goal)
	while map.busy:
		await process_frame
	map.wait_selected()
	await cancel_input()
	check(ally.coord.vector() == goal and ally.acted and state.pending_move_unit == null, "Wait commits move; cancel cannot undo completed action")
	ally.acted = false
	ally.moved = false
	ally.coord = HexCoord.from_vector(origin)
	map.on_hex_clicked(origin)
	map.move_selected()
	map.on_hex_clicked(goal)
	while map.busy:
		await process_frame
	map.attack_selected()
	map.on_hex_clicked(enemy.coord.vector())
	map.confirm_attack()
	while map.busy:
		await process_frame
	check(state.battle != null and ally.acted and state.pending_move_unit == null, "Confirmed attack commits pending movement")
	state.cancel_pending_move()
	check(ally.coord.vector() == goal, "Battle commitment never returns attacker to turn origin")
	state.battle = null
	ally.acted = false
	ally.moved = false
	ally.coord = HexCoord.from_vector(origin)
	map.selected = ally
	var final_route: Array[Vector2i] = [origin, goal]
	await map.move_unit(ally, final_route, null)
	state.end_turn()
	check(state.pending_move_unit == null and ally.coord.vector() == goal and ally.acted, "End turn commits pending move as wait")
	state.turn_manager.current_side = TurnManager.TurnSide.PLAYER
	map.hide()
	# Rendering follows faction; event keys and resolver sides follow initiator.
	var context := BattleContext.new(enemy, ally)
	var stage := BattleStage.new()
	stage.context = context
	stage.roster = state.formation.roster
	stage.position = Vector2(20, 80)
	root.add_child(stage)
	var title := Label.new()
	title.text = "적 선공 · 아군 왼쪽 / 적군 오른쪽"
	title.position = Vector2(20, 25)
	title.add_theme_font_size_override("font_size", 24)
	root.add_child(title)
	await process_frame
	var enemy_slot: FormationSlot = enemy.squad.positions[enemy.squad.leader_id]
	var ally_slot: FormationSlot = ally.squad.positions[ally.squad.leader_id]
	check(not stage.is_left(0) and stage.is_left(1), "Enemy initiator remains right; allied defender remains left")
	check(stage.position_for(enemy_slot, 0).x >= stage.ENEMY_ORIGIN.x and stage.position_for(ally_slot, 1).x < 500, "Cards use faction screen sides")
	var enemy_view: CharacterBattleView = stage.views[BattleStage.key(0, enemy.squad.leader_id)]
	var ally_view: CharacterBattleView = stage.views[BattleStage.key(1, ally.squad.leader_id)]
	var animator := BattleAnimator.new()
	animator.stage = stage
	root.add_child(animator)
	var event := {"side": 0, "actor": enemy.squad.leader_id, "target_side": 1, "target": ally.squad.leader_id, "hp": ally.squad.current_hp[ally.squad.leader_id], "damage": 0, "action_type": BattleAction.Type.MELEE}
	animator.present(event, 1.0)
	await animator.impact
	check(enemy_view.position.x > ally_view.home.x and enemy_view.position.distance_to(ally_view.home) < 125, "Enemy melee approaches allied card from right")
	await animator.presentation_finished
	check(enemy_view.position == enemy_view.home and ally_view.position == ally_view.home, "Mirrored melee returns cards to their own faction positions")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview_faction_battle.png")
	check(enemy.squad.positions[enemy.squad.leader_id] == enemy_slot and ally.squad.positions[ally.squad.leader_id] == ally_slot, "Display mirroring never changes formation data")
	print("Faction display and move undo: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
