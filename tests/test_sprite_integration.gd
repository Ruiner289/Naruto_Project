extends SceneTree

var failures := 0
func check(ok: bool, note: String) -> void:
	if not ok:
		failures += 1
		push_error(note)
func _initialize() -> void:
	call_deferred("run")
func capture(path: String) -> void:
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(path)
func run() -> void:
	root.size = Vector2i(1280, 720)
	var fallback_data := NinjaData.new("unmapped_test", "미적용 테스트", 0)
	var fallback_squad := SquadData.new()
	fallback_squad.current_hp.unmapped_test = 50
	var fallback := CharacterBattleView.new(fallback_data, fallback_squad)
	root.add_child(fallback)
	check(fallback.sprite == null and fallback.hp_value() == 50, "Missing profile safely retains legacy token")
	fallback.queue_free()
	for id in SpriteLibrary.IDS:
		var profile := SpriteLibrary.profile(id)
		check(not profile.is_empty(), "Reviewed profile loads: " + id)
		check(profile.sprite_frames == SpriteLibrary.profile(id).sprite_frames, "Frames cached: " + id)
		for state in ["idle", "move", "attack", "hit", "ko"]:
			check(profile.sprite_frames.get_frame_count(state) == profile.animations[state].get("playback_order", profile.animations[state].frames).size(), id + " " + state + " frame count")
			check(profile.sprite_frames.get_animation_loop(state) == (state in ["idle", "move"]), "Only idle/move loop")
	var preview: Control = load("res://scenes/sprite_preview.tscn").instantiate()
	root.add_child(preview)
	await process_frame
	for generic_only in [false, true]:
		preview.setup_battle(generic_only)
		await process_frame
		var stage: BattleStage = preview.stage
		var animator: BattleAnimator = preview.animator
		var resolver: BattleResolver = preview.resolver
		for key in stage.views:
			var view: CharacterBattleView = stage.views[key]
			check(view.sprite != null, "All test participants have actual sprites")
			check(view.faces_right == stage.is_left(int(key.split(":")[0])), "Faction facing")
			check(view.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Nearest filter")
		await capture("res://sprite_preview_%s.png" % ("B" if generic_only else "A"))
		if generic_only:
			var first: CharacterBattleView = stage.views["0:preview_a_dart_0"]
			var second: CharacterBattleView = stage.views["0:preview_a_dart_1"]
			check(first.ninja.id != second.ninja.id and first.sprite != second.sprite and first.sprite.sprite_frames == second.sprite.sprite_frames, "Duplicate template: unique IDs and sprite nodes; shared cached resource")
			first.play_state("attack")
			check(second.visual_state == "idle", "Animation state remains independent")
			first.play_state("idle")
		var count := 0
		while true:
			var event := resolver.next_action()
			if event.is_empty():
				break
			var actor: CharacterBattleView = stage.views[BattleStage.key(event.side, event.actor)]
			var target: CharacterBattleView = stage.views[BattleStage.key(event.target_side, event.target)]
			var before := target.displayed_hp
			animator.present(event, 4.0)
			check(target.displayed_hp == before, "HP remains unrevealed before animation impact")
			await animator.impact
			check(target.displayed_hp == event.hp and target.hit_flash, "HP and hit feedback synchronized with impact")
			if event.hp <= 0:
				check(target.visual_state == "ko", "Death plays KO")
			if count == 0 and not generic_only:
				await capture("res://sprite_preview_impact.png")
			await animator.presentation_finished
			check(actor.position == actor.home and target.position == target.home, "Attack and hit return to visual home")
			check(actor.visual_state == "idle" or actor.hp_value() <= 0, "Actor resumes idle")
			count += 1
		check(count > 4 and animator.impact_count == count, "Complete multi-member animated exchange")
		print("Sprite scenario ", "B" if generic_only else "A", ": ", count, " events")
	# Force a casualty through the real animator, then create the next battle's stage.
	preview.setup_battle(false)
	await process_frame
	var target_id: String = preview.stage.context.defender.leader_id
	var target: CharacterBattleView = preview.stage.views[BattleStage.key(1, target_id)]
	preview.stage.context.defender.current_hp[target_id] = 0
	var ko_event := {"side": 0, "actor": "naruto", "target_side": 1, "target": target_id, "kind": BattleAction.Kind.ATTACK, "action_type": BattleAction.Type.MELEE, "hp": 0, "damage": 50}
	await preview.animator.present(ko_event, 4.0)
	await create_timer(0.3).timeout
	check(target.visual_state == "ko" and not target.sprite.is_playing(), "KO holds its final frame without idle revival")
	var next_stage := BattleStage.new()
	next_stage.context = preview.stage.context
	next_stage.roster = preview.stage.roster
	root.add_child(next_stage)
	check(not next_stage.views.has(BattleStage.key(1, target_id)), "Earlier casualties absent from next battle")
	next_stage.queue_free()
	# Verify the production BattleScene layout and automatic playback too.
	preview.setup_battle(false)
	preview.hide()
	var state: Node = root.get_node("GameState")
	var saved_context: BattleContext = state.battle
	state.battle = preview.stage.context
	var original_roster: Dictionary = state.formation.roster
	state.formation.roster = preview.stage.roster
	var battle_screen: Control = load("res://scenes/battle.tscn").instantiate()
	root.add_child(battle_screen)
	battle_screen.speed = 4.0
	await battle_screen.animator.impact
	await capture("res://sprite_battle_ingame.png")
	while not battle_screen.finished:
		await process_frame
	check(battle_screen.return_button.global_position.y + battle_screen.return_button.size.y <= 720, "Production battle return button fits viewport")
	check(battle_screen.animator.impact_count > 4, "Production BattleScene plays actual sprites")
	state.battle = saved_context
	state.formation.roster = original_roster
	battle_screen.queue_free()
	preview.queue_free()
	await process_frame
	print("Sprite integration: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
