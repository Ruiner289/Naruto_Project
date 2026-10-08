extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for id in SpriteLibrary.IDS:
		var ninja := NinjaData.new(id, id, 0)
		var squad := SquadData.new()
		squad.current_hp[id] = 50
		var view := CharacterBattleView.new(ninja, squad)
		root.add_child(view)
		var sprite := view.sprite
		var profile := view.sprite_profile
		var n: int = profile.animations.idle.frames.size()
		var order: Array = profile.animations.idle.playback_order
		check(order.size() == maxi(1, n * 2 - 2), "Idle cycle uses intermediate return poses: " + id)
		for i in order.size():
			check(absi(int(order[i]) - int(order[(i + 1) % order.size()])) <= 1, "No end-to-start idle snap: " + id)
		sprite.set_frame_and_progress(1, 0.73)
		view.play_state("idle", 4.0)
		check(sprite.frame == 1 and is_equal_approx(sprite.frame_progress, 0.73), "Same idle request preserves phase: " + id)
		check(sprite.speed_scale == 1.0, "Breathing remains calm at accelerated combat speed: " + id)
		view.play_state("move")
		sprite.set_frame_and_progress(1, 0.42)
		view.faces_right = not view.faces_right
		view.play_state("move", 2.0)
		check(sprite.frame == 1 and is_equal_approx(sprite.frame_progress, 0.42), "Facing/speed change does not restart stride: " + id)
		view.play_state("attack", 20.0)
		while sprite.is_playing():
			await process_frame
		view.play_state("idle")
		check(sprite.frame == 1 and is_equal_approx(sprite.frame_progress, 0.73), "Idle resumes prior breathing phase after action: " + id)
		view.play_state("hit", 20.0, true)
		await create_timer(0.06).timeout
		check(view.visual_state == "idle", "Surviving hit flows back to idle without waiting for actor return: " + id)
		view.displayed_hp = 0
		view.play_state("ko", 30.0, true)
		await create_timer(0.08).timeout
		check(view.visual_state == "ko" and not sprite.is_playing(), "KO holds final pose: " + id)
		for state in ["idle", "move"]:
			var min_y := INF
			var max_y := -INF
			for f in profile.animations[state].frames:
				var c: Array = f.registered_body_core
				check(absf(float(c[0]) - 120.0) <= 0.51, "Torso stays on formation centre: " + id + " " + state)
				min_y = minf(min_y, c[1])
				max_y = maxf(max_y, c[1])
			check(max_y - min_y <= 1.01, "Torso height stays stable through stride: " + id + " " + state)
		var height: float = 54.0 if id == "generic_pole" else 0.0
		if id != "generic_pole":
			for f in profile.animations.idle.frames:
				height = maxf(height, f.bbox[3] - f.bbox[1])
		check(height * profile.scale <= 96.1, "Standing bodies fit the same formation height: " + id)
		view.queue_free()
		await process_frame
	print("Sprite flow and alignment: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
