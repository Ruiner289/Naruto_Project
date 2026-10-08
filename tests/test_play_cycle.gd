extends SceneTree

var failures: int = 0
var screenshots: bool = false
var captured_melee: bool = false
var captured_ranged: bool = false

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func snapshot(filename: String) -> void:
	if screenshots:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://" + filename)

func capture_impact(type: int) -> void:
	if type == BattleAction.Type.MELEE and not captured_melee:
		captured_melee = true
		await snapshot("preview_melee_hit.png")
	elif type == BattleAction.Type.RANGED and not captured_ranged:
		captured_ranged = true
		await snapshot("preview_ranged_hit.png")

func wait_transition(app: Control) -> void:
	var deadline: int = Time.get_ticks_msec() + 5000
	while app.transitioning and Time.get_ticks_msec() < deadline:
		await create_timer(0.01).timeout
	check(not app.transitioning, "Scene fade completes")
	await process_frame

func click_hex(map: Control, coord: Vector2i) -> void:
	if root.get_node("GameState").unit_at(coord) == null and map.selected != null and map.selected.can_move() and not map.choosing_attack and map.preview == null:
		map.move_selected()
	if map.action_menu.visible:
		map.action_menu.hide() # This helper targets a hex, not a command button.
	var location: Vector2 = map.board.get_global_transform() * map.board.center(coord)
	var motion := InputEventMouseMotion.new()
	motion.position = location
	root.push_input(motion, true)
	var press := InputEventMouseButton.new()
	press.position = location
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	var release := InputEventMouseButton.new()
	release.position = location
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	root.push_input(release, true)
	await process_frame

func wait_move(map: Control) -> void:
	var deadline: int = Time.get_ticks_msec() + 15000
	while is_instance_valid(map) and map.busy and Time.get_ticks_msec() < deadline:
		await create_timer(0.01).timeout
	check(not is_instance_valid(map) or not map.busy, "Movement animation finishes")

func finish_battle(scene: Control) -> void:
	if OS.get_cmdline_user_args().has("--normal-speed"):
		scene.speed = 2.0
	else:
		scene.skip = true
	var deadline: int = Time.get_ticks_msec() + 60000
	while not scene.finished and Time.get_ticks_msec() < deadline:
		await create_timer(0.01).timeout
	check(scene.finished, "Battle scene reaches result")

func run() -> void:
	root.size = Vector2i(1280, 720)
	screenshots = DisplayServer.get_name() != "headless"
	var state: Node = root.get_node("GameState")
	# This is the legacy player/formation regression fixture; the authored battlefield
	# and actual enemy-turn continuation are covered by test_tactical_turn.gd.
	state.grid = HexGrid.new(12, 8)
	state.units.resize(4)
	state.units[0].coord = HexCoord.from_offset(2, 3)
	state.units[1].coord = HexCoord.from_offset(2, 5)
	state.units[2].coord = HexCoord.from_offset(6, 3)
	state.units[3].coord = HexCoord.from_offset(8, 5)
	# Test isolated startup save or load fixture without touching the user's real save.
	var load_error: String = state.formation.load_json("res://tests/fixtures/existing_formation.json")
	check(load_error.is_empty(), "Existing v1 user save loads")
	PrototypeRules.ensure_hp(state.formation.squad, state.formation.roster)
	var primary: SquadMapUnit = state.units[0]
	check(primary.squad == state.formation.squad, "Existing save preserves map/formation identity")
	check(primary.squad.positions.size() == 4 and primary.squad.positions.yamato.row_offset == 1.0, "Existing user's four members and positions preserved")
	var app: Control = load("res://scenes/game.tscn").instantiate()
	root.add_child(app)
	await process_frame
	check(app.active_screen.name == "BattleMap", "Starts on battlefield")
	app.active_screen.formation_button.pressed.emit()
	await wait_transition(app)
	var formation_screen: Control = app.active_screen
	check(formation_screen.manager.squad == primary.squad, "Formation uses same squad")
	formation_screen.select_ninja("choji")
	formation_screen.board.slot_clicked.emit(FormationSlot.new(2, 1.5))
	check(primary.squad.positions.choji.row_offset == 1.5, "Half offset edited in existing UI")
	formation_screen.map_requested.emit()
	await wait_transition(app)
	var map: Control = app.active_screen
	await click_hex(map, primary.coord.vector())
	check(map.selected == primary and map.action_menu.visible, "Real viewport input selects and highlights")
	check(not map.board.attack_tiles.is_empty() and map.board.search.costs.size() > 1, "Ally selection shows potential move and attack ranges")
	var free_cell: Vector2i = primary.coord.vector() + Vector2i(1, 0)
	var hover := InputEventMouseMotion.new()
	hover.position = map.board.get_global_transform() * map.board.center(free_cell + Vector2i(1, 0))
	root.push_input(hover, true)
	await process_frame
	await snapshot("preview_battle_map.png")
	await click_hex(map, free_cell)
	await wait_move(map)
	check(primary.coord.vector() == free_cell and primary.moved and not primary.acted, "Move first, attack/wait later")
	check(map.board.search.costs.is_empty() and map.board.attack_tiles.is_empty(), "After moving attack colors remain hidden")
	map.wait_button.pressed.emit()
	var support: SquadMapUnit = state.units[1]
	await click_hex(map, support.coord.vector())
	check(map.selected == support, "Other allied squad selection")
	await click_hex(map, support.coord.vector() + Vector2i(1, 0))
	await wait_move(map)
	map.wait_button.pressed.emit()
	check(state.can_end_turn(), "End turn enabled after all actions")
	map.end_button.pressed.emit()
	state.turn_manager.end_enemy(state.units)
	map.refresh()
	check(state.turn == 2 and not primary.acted, "Turn reset without enemy AI")
	await click_hex(map, primary.coord.vector())
	var enemy: SquadMapUnit = state.units[2]
	var target_coord: Vector2i = enemy.coord.vector()
	var turn_origin: Vector2i = primary.coord.vector()
	var attack_origin: Vector2i = target_coord - Vector2i(1, 0)
	await click_hex(map, attack_origin)
	await wait_move(map)
	check(primary.coord.vector() == attack_origin and primary.can_act(), "Moved squad may attack from chosen position")
	map.attack_button.pressed.emit()
	await click_hex(map, target_coord)
	check(map.preview != null and state.battle == null and not primary.acted, "Preview before commitment")
	map.preview.cancel_button.pressed.emit()
	check(primary.coord.vector() == attack_origin and primary.moved and not primary.acted, "Cancelling attack after move retains destination")
	map.attack_button.pressed.emit()
	await click_hex(map, target_coord)
	await snapshot("preview_contact.png")
	map.preview.start_button.pressed.emit()
	await wait_move(map)
	await wait_transition(app)
	var battle_screen: Control = app.active_screen
	check(battle_screen.name == "BattleScene", "Contact changes scene")
	check(state.battle.attacker == primary.squad and state.battle.defender == enemy.squad, "Context uses original objects")
	var half_slot: FormationSlot = primary.squad.positions.choji
	var ally_view: CharacterBattleView = battle_screen.stage.views[BattleStage.key(0, "choji")]
	check(ally_view.home == battle_screen.stage.position_for(half_slot, 0), "Half position carried into battle")
	var enemy_slot: FormationSlot = enemy.squad.positions[enemy.squad.leader_id]
	var before_column: int = enemy_slot.column
	var enemy_view: CharacterBattleView = battle_screen.stage.views[BattleStage.key(1, enemy.squad.leader_id)]
	check(enemy_view.home == battle_screen.stage.position_for(enemy_slot, 1), "Enemy rendering mirrored")
	check(enemy_slot.column == before_column, "Mirroring does not modify formation")
	battle_screen.animator.impact.connect(capture_impact)
	await snapshot("preview_auto_battle.png")
	# Let one normal animated action visibly land before asking for instant resolution.
	await create_timer(PrototypeRules.ACTION_SECONDS * 0.4).timeout
	await snapshot("preview_battle_hit.png")
	await finish_battle(battle_screen)
	if OS.get_cmdline_user_args().has("--normal-speed"):
		check(battle_screen.animator.melee_count > 0 and battle_screen.animator.ranged_count > 0, "Both action styles animated")
	check(battle_screen.resolver.winner == 2, "Finite encounter ends with both squads alive")
	var hp_after: int = PrototypeRules.hp_total(primary.squad)
	check(hp_after > 0 and hp_after < 275, "Winner injured, HP retained")
	await snapshot("preview_battle_result.png")
	battle_screen.return_button.pressed.emit()
	await wait_transition(app)
	map = app.active_screen
	check(map.name == "BattleMap" and state.battle == null, "Result returns to map")
	check(state.units.has(enemy) and primary.coord.vector() == attack_origin and primary.coord.vector() != turn_origin and primary.acted, "Survived exchange keeps moved position, never turn start")
	check(primary.squad == state.formation.squad and PrototypeRules.hp_total(primary.squad) == hp_after, "HP/identity preserved after return")
	await click_hex(map, primary.coord.vector())
	map.attack_button.pressed.emit()
	await click_hex(map, target_coord)
	check(map.preview == null, "Same-turn second attack blocked")
	# Each later turn grants a new finite encounter, retaining enemy and friendly HP.
	var encounters: int = 1
	while state.units.has(enemy) and encounters < 6:
		await click_hex(map, support.coord.vector())
		map.wait_button.pressed.emit()
		check(state.can_end_turn(), "Turn ends after remaining ally action")
		map.end_button.pressed.emit()
		state.turn_manager.end_enemy(state.units)
		map.refresh()
		check(primary.can_act(), "Next turn permits reengagement")
		var enemy_hp: int = PrototypeRules.hp_total(enemy.squad)
		await click_hex(map, primary.coord.vector())
		map.attack_button.pressed.emit()
		await click_hex(map, target_coord)
		check(map.preview != null, "Next-turn reengagement preview")
		map.preview.start_button.pressed.emit()
		await wait_move(map)
		await wait_transition(app)
		var next_battle: Control = app.active_screen
		check(PrototypeRules.hp_total(enemy.squad) <= enemy_hp, "Enemy HP never reset at reengagement")
		await finish_battle(next_battle)
		encounters += 1
		next_battle.return_button.pressed.emit()
		await wait_transition(app)
		map = app.active_screen
	check(not state.units.has(enemy) and primary.coord.vector() == attack_origin and state.unit_at(target_coord) == null and primary.acted, "Annihilation removes enemy, leaves its tile empty, keeps attacker on attack tile with action spent")
	check(encounters > 1, "Combat spans multiple map turns")
	# Defeat branch: a 1-HP attacker remains on its original cell and cannot act.
	var surviving_enemy: SquadMapUnit = state.units.back()
	for id in support.squad.positions:
		support.squad.current_hp[id] = 0
	support.squad.current_hp[support.squad.leader_id] = 1
	var original: Vector2i = support.coord.vector()
	# Arrange a reachable opponent, then use the real map input/contact path for defeat too.
	surviving_enemy.coord = HexCoord.from_vector(original + Vector2i(3, 0))
	support.acted = false
	support.moved = false
	map.refresh()
	await click_hex(map, original)
	var defeat_origin: Vector2i = original + Vector2i(2, 0)
	await click_hex(map, defeat_origin)
	await wait_move(map)
	map.attack_button.pressed.emit()
	await click_hex(map, surviving_enemy.coord.vector())
	check(map.preview != null, "Defeat scenario preview")
	map.preview.start_button.pressed.emit()
	await wait_move(map)
	await wait_transition(app)
	var defeat_screen: Control = app.active_screen
	await finish_battle(defeat_screen)
	check(defeat_screen.resolver.winner == 1, "Defeat branch")
	defeat_screen.return_button.pressed.emit()
	await wait_transition(app)
	check(support.coord.vector() == defeat_origin and not state.units.has(support) and state.unit_at(defeat_origin) == null, "Defeated attacker removed and its attack tile freed")
	check(PrototypeRules.hp_total(support.squad) == 0 and not support.can_act(), "Defeated HP stays zero and action disabled")
	state.heal_all()
	check(PrototypeRules.hp_total(support.squad) == 0 and not state.units.has(support), "Debug recovery does not resurrect removed units")
	print("Play cycle: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)




