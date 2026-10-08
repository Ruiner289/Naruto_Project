extends SceneTree

var failures: int = 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state: Node = root.get_node("GameState")
	var app: Control = load("res://scenes/game.tscn").instantiate()
	root.add_child(app)
	await process_frame
	for cycle in 2:
		state.end_turn()
		var deadline: int = Time.get_ticks_msec() + 60000
		while not state.turn_manager.is_player_turn() and Time.get_ticks_msec() < deadline:
			if not app.transitioning and app.active_screen.name == "BattleScene":
				var scene: Control = app.active_screen
				scene.skip = true
				if scene.finished:
					scene.return_button.pressed.emit()
			await create_timer(0.01).timeout
		check(state.turn_manager.is_player_turn() and state.turn == cycle + 2, "Authored default board completes successive enemy turns")
		check(state.enemy_controller.action_history == ["enemy1", "enemy2", "enemy3", "enemy4"], "All four default living enemies act once on each turn")
		var occupied: Dictionary = {}
		for unit in state.units:
			check(not occupied.has(unit.coord.vector()), "No overlapping squads after real AI movement")
			occupied[unit.coord.vector()] = true
			check(state.grid.is_passable(unit.coord.vector()), "Default AI destinations passable")
	print("Default battlefield turns: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
