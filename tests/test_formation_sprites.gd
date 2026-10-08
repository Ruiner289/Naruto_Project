extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func capture(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://" + name)
func run() -> void:
	var state: Node = root.get_node("GameState")
	var screen: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame
	check(screen.board.member_views.size() == 4, "Editor displays all four actual character sprites")
	for view in screen.board.member_views.values():
		check(view.z_index == 0 and view.sprite != null and view.squad == state.formation.squad and view.faces_right, "Editor reuses squad and right-facing sprites")
	await capture("formation_editor_sprites.png")
	for unit in [state.units[0], state.units[2]]:
		var hp_before: Dictionary = unit.squad.current_hp.duplicate()
		var positions_before: Dictionary = unit.squad.positions.duplicate()
		var inspector := SquadInspector.new()
		inspector.unit = unit
		inspector.roster = state.formation.roster
		root.add_child(inspector)
		await process_frame
		check(inspector.formation.member_views.size() == PrototypeRules.living_count(unit.squad), "Inspector displays all living members")
		for view in inspector.formation.member_views.values():
			check(view.sprite != null and view.faces_right == not unit.enemy and view.squad == unit.squad, "Faction-facing live sprite with shared squad")
		await capture("formation_enemy_sprites.png" if unit.enemy else "formation_ally_sprites.png")
		check(unit.squad.current_hp == hp_before and unit.squad.positions == positions_before, "Viewing formation never mutates HP or formation")
		inspector.queue_free()
		await process_frame
	var scythe := SpriteLibrary.profile("generic_scythe")
	check(not scythe.move_uses_stance and scythe.animations.move.frames.size() == 2, "Scythe uses actual arms-back run")
	check(int(scythe.animations.move.frames[0].source_rect[1]) == 159 and int(scythe.animations.hit.frames[0].source_rect[1]) == 218, "Run and hurt rows are separate and correct")
	screen.queue_free()
	await process_frame
	print("Formation sprites and scythe run: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
