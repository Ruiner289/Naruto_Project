extends SceneTree

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var state: Node = root.get_node("GameState")
	check(state.units.size() == 8, "Four squads per faction deployed")
	for unit in state.units:
		check(unit.squad.positions.size() == 4, "Sprite formation member count")
		for id in unit.squad.positions:
			var ninja: NinjaData = state.formation.roster[id]
			var profile: String = ninja.sprite_profile_id if not ninja.sprite_profile_id.is_empty() else id
			check(not SpriteLibrary.profile(profile).is_empty(), "Every deployed member has a verified sprite: " + id)
	var teams := {"player": ["kakashi", "naruto", "sasuke", "sakura"], "ally2": ["asuma", "shikamaru", "ino", "choji"], "ally3": ["kurenai", "kiba", "hinata", "shino"], "ally4": ["guy", "lee", "neji", "tenten"]}
	var ally_count := 0
	var enemy_count := 0
	var occupied: Dictionary = {}
	for unit in state.units:
		check(not occupied.has(unit.coord.vector()) and state.grid.is_passable(unit.coord.vector()), "Unique passable default spawn")
		occupied[unit.coord.vector()] = true
		if unit.enemy:
			enemy_count += 1
		else:
			ally_count += 1
			check(unit.squad.leader_id == teams[unit.id][0], "Canonical team leader")
			for member in teams[unit.id]:
				check(unit.squad.positions.has(member), "Canonical member: " + member)
	check(ally_count == 4 and enemy_count == 4, "Exactly four allies and four enemies")
	# A real old save is preserved byte for byte before the requested replacement.
	var manager := FormationManager.new()
	manager.load_json("res://tests/fixtures/existing_formation.json")
	var identity := manager.squad
	var prefix := "user://deployment_test_" + str(Time.get_ticks_usec())
	var save_path := prefix + ".json"
	var marker_path := prefix + ".done"
	manager.save_json(save_path)
	var original := FileAccess.get_file_as_bytes(save_path)
	var message := SpriteDeployment.prepare(manager, save_path, marker_path)
	check(message.contains("재배치") and manager.squad == identity, "Deployment updates existing squad object")
	check(manager.squad.positions.keys() == ["kakashi", "naruto", "sasuke", "sakura"], "Primary sprite-only roster")
	var backups := 0
	for name in DirAccess.get_files_at("user://"):
		if name.begins_with(prefix.get_file() + "_before_sprite_deployment_"):
			backups += 1
			check(FileAccess.get_file_as_bytes("user://" + name) == original, "Old formation backup keeps exact bytes")
	check(backups == 1 and FileAccess.file_exists(marker_path), "One backup and successful migration marker")
	# Subsequent runs preserve later edits and current HP instead of resetting them.
	manager.squad.current_hp.naruto = 33
	manager.squad.positions.naruto = FormationSlot.new(1, 1)
	manager.save_json(save_path)
	SpriteDeployment.prepare(manager, save_path, marker_path)
	check(manager.squad.current_hp.naruto == 33 and manager.squad.positions.naruto.column == 1, "Later player edits and HP survive restart")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280, 720)
		state.battle = BattleContext.new(state.units[0], state.units[2])
		var screen: Control = load("res://scenes/battle.tscn").instantiate()
		root.add_child(screen)
		screen.speed = 2.0
		for view in screen.stage.views.values():
			check(view.sprite != null, "Deployed production battle has no placeholder member")
		await screen.animator.impact
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://sprite_deployed_battle.png")
		while not screen.finished:
			await process_frame
		screen.queue_free()
		state.battle = null
	print("Sprite-only deployment: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)

