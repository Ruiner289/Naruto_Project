extends SceneTree

var failures := 0
const NEW_IDS := ["shikamaru", "ino", "choji", "kiba", "shino", "hinata"]
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func capture(path: String) -> void:
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(path)
func run() -> void:
	root.size = Vector2i(1280, 720)
	var preview: Control = load("res://scenes/sprite_preview.tscn").instantiate()
	root.add_child(preview)
	preview.setup_battle(false, true)
	await process_frame
	for id in NEW_IDS:
		var view: CharacterBattleView = preview.stage.views[BattleStage.key(0, id)]
		check(view.sprite != null, "Actual sprite: " + id)
		for action in ["idle", "move", "attack", "hit", "ko"]:
			view.play_state(action)
			check(view.visual_state == action and view.sprite.sprite_frames.get_frame_count(action) > 0, "Verified state: " + id + " " + action)
		view.play_state("idle")
	await capture("res://sprite_extended_idle.png")
	var actions: Dictionary = {}
	while true:
		var event: Dictionary = preview.resolver.next_action()
		if event.is_empty():
			break
		var actor: CharacterBattleView = preview.stage.views[BattleStage.key(event.side, event.actor)]
		var target: CharacterBattleView = preview.stage.views[BattleStage.key(event.target_side, event.target)]
		var old_hp := target.displayed_hp
		preview.animator.present(event, 4.0)
		check(target.displayed_hp == old_hp, "Extended HP waits for impact")
		await preview.animator.impact
		check(target.displayed_hp == event.hp, "Extended HP revealed at impact")
		if event.side == 0:
			actions[event.actor] = true
			if event.actor == "choji":
				await capture("res://sprite_extended_melee.png")
		await preview.animator.presentation_finished
		check(actor.position == actor.home and actor.faces_right == preview.stage.is_left(event.side), "Extended actor returns home and restores facing")
	for id in NEW_IDS:
		check(actions.has(id), "Each added character acts in the real exchange: " + id)
	# KO uses the final flat frame and survives the animator's return to idle.
	for id in NEW_IDS:
		var view: CharacterBattleView = preview.stage.views[BattleStage.key(0, id)]
		view.displayed_hp = 0
		view.play_state("ko", 10.0)
	await create_timer(0.2).timeout
	for id in NEW_IDS:
		var view: CharacterBattleView = preview.stage.views[BattleStage.key(0, id)]
		check(view.visual_state == "ko" and not view.sprite.is_playing(), "KO holds: " + id)
	await capture("res://sprite_extended_ko.png")
	# The authored support squads now expose all six additional sprites in game.
	var state: Node = root.get_node("GameState")
	var deployed: Dictionary = {}
	for unit in state.units:
		for id in unit.squad.positions:
			deployed[id] = true
	for id in NEW_IDS:
		check(deployed.has(id), "Added character deployed in support squads: " + id)
	preview.queue_free()
	await process_frame
	print("Extended sprites: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
