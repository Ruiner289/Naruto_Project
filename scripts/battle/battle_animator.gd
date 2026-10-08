class_name BattleAnimator
extends Node

# Owns presentation only. Damage is resolved earlier; views reveal it at impact.
signal impact(type: int)
signal presentation_finished
var stage: BattleStage
var current_type: int = -1
var impact_count: int = 0
var melee_count: int = 0
var ranged_count: int = 0
var projectile: Polygon2D

func present(event: Dictionary, speed: float) -> void:
	current_type = event.action_type
	var healing: bool = event.get("kind", BattleAction.Kind.ATTACK) == BattleAction.Kind.HEAL
	if healing:
		current_type = BattleAction.Type.HEAL
	var actor: CharacterBattleView = stage.views[BattleStage.key(event.side, event.actor)]
	var target: CharacterBattleView = stage.views[BattleStage.key(event.get("target_side", 1 - int(event.side)), event.target)]
	if actor.sprite != null:
		await present_sprite(event, speed, actor, target, healing)
		return
	var duration: float = PrototypeRules.ACTION_SECONDS / speed
	actor.z_index = 100
	actor.emphasized = true
	target.emphasized = true
	actor.action_marker = "치료" if healing else ("발사" if current_type == BattleAction.Type.RANGED else "돌진")
	actor.queue_redraw()
	target.queue_redraw()
	if healing:
		await get_tree().create_timer(duration * 0.38).timeout
	elif current_type == BattleAction.Type.RANGED:
		ranged_count += 1
		projectile = Polygon2D.new()
		var points := PackedVector2Array()
		for i in 12:
			points.append(Vector2(cos(TAU * i / 12.0), sin(TAU * i / 12.0)) * 7)
		projectile.polygon = points
		projectile.color = Color(1, 0.83, 0.33)
		projectile.z_index = 20
		projectile.position = actor.home + CharacterBattleView.CARD_SIZE / 2.0
		stage.add_child(projectile)
		var flight := create_tween()
		flight.tween_property(projectile, "position", target.home + CharacterBattleView.CARD_SIZE / 2.0, duration * 0.38)
		await flight.finished
		projectile.queue_free()
		projectile = null
	else:
		melee_count += 1
		var approach: Vector2 = target.home + Vector2(-CharacterBattleView.CARD_SIZE.x - 12 if stage.is_left(event.side) else CharacterBattleView.CARD_SIZE.x + 12, 0)
		var charge := create_tween()
		charge.tween_property(actor, "position", approach, duration * 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await charge.finished
	target.displayed_hp = event.hp
	target.damage_text = "+%d" % event.heal if healing else "-%d" % event.damage
	target.heal_flash = healing
	target.hit_flash = true
	if not healing:
		target.play_state("ko" if event.hp <= 0 else "hit", speed, true)
	target.queue_redraw()
	impact_count += 1
	impact.emit(current_type)
	var recoil := create_tween()
	recoil.tween_property(target, "position", target.home + Vector2(6, 0), duration * 0.06)
	recoil.tween_property(target, "position", target.home - Vector2(6, 0), duration * 0.06)
	recoil.tween_property(target, "position", target.home, duration * 0.06)
	await recoil.finished
	if current_type == BattleAction.Type.MELEE:
		var back := create_tween()
		back.tween_property(actor, "position", actor.home, duration * 0.28)
		await back.finished
	else:
		await get_tree().create_timer(duration * 0.28).timeout
	await get_tree().create_timer(duration * 0.16).timeout
	actor.position = actor.home
	target.position = target.home
	actor.z_index = actor.home_z_index
	actor.emphasized = false
	target.emphasized = false
	actor.action_marker = ""
	target.damage_text = ""
	target.hit_flash = false
	target.heal_flash = false
	actor.play_state("idle")
	target.play_state("idle")
	stage.refresh_hp()
	current_type = -1
	presentation_finished.emit()

func present_sprite(event: Dictionary, speed: float, actor: CharacterBattleView, target: CharacterBattleView, healing: bool) -> void:
	var ranged := current_type == BattleAction.Type.RANGED
	var profile: Dictionary = actor.sprite_profile
	actor.z_index = 1000
	actor.emphasized = true
	target.emphasized = true
	actor.queue_redraw()
	target.queue_redraw()
	if healing:
		actor.play_state("idle", speed)
		await get_tree().create_timer(0.25 / speed).timeout
	else:
		if not ranged:
			melee_count += 1
			actor.play_state("move", speed)
			var approach := target.home + Vector2(-108 if stage.is_left(event.side) else 108, 0)
			var charge := create_tween()
			charge.tween_property(actor, "position", approach, travel_seconds(actor, approach) / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await charge.finished
		else:
			ranged_count += 1
		actor.play_state(actor.attack_state(ranged), speed)
		await get_tree().create_timer(maxf(0.001, actor.impact_delay(ranged) / speed)).timeout
		if ranged:
			# Ordinary thrown weapon; no elemental skill or new damage rule.
			projectile = Polygon2D.new()
			projectile.polygon = PackedVector2Array([Vector2(-12, 0), Vector2(5, -3), Vector2(12, 0), Vector2(5, 3)])
			projectile.color = Color(0.75, 0.82, 0.92)
			projectile.z_index = 110
			projectile.position = actor.home + CharacterBattleView.GROUND - Vector2(0, 48)
			stage.add_child(projectile)
			var flight := create_tween()
			flight.tween_property(projectile, "position", target.home + CharacterBattleView.GROUND - Vector2(0, 48), 0.16 / speed)
			await flight.finished
			projectile.queue_free()
			projectile = null
	# The resolver already calculated this event. Only reveal its result here.
	target.displayed_hp = event.hp
	target.damage_text = "+%d" % event.heal if healing else "-%d" % event.damage
	target.hit_flash = true
	target.heal_flash = healing
	if not healing:
		target.play_state("ko" if event.hp <= 0 else "hit", speed, true)
	target.sync_sprite()
	target.queue_redraw()
	impact_count += 1
	impact.emit(current_type)
	if not healing:
		var recoil := create_tween()
		recoil.tween_property(target, "position", target.home + Vector2(5, 0), 0.06 / speed)
		recoil.tween_property(target, "position", target.home, 0.08 / speed)
		await recoil.finished
		# Wait for actual one-shot completion; estimated timers used to hold the
		# last pose twice and interrupt/rewind transitions at high battle speeds.
		while actor.sprite.is_playing() and actor.visual_state == actor.attack_state(ranged):
			await get_tree().process_frame
	else:
		await get_tree().create_timer(0.25 / speed).timeout
	if not healing and not ranged:
		actor.faces_right = not actor.faces_right
		actor.play_state("move", speed)
		var back := create_tween()
		back.tween_property(actor, "position", actor.home, travel_seconds(actor, actor.home) / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await back.finished
		actor.faces_right = not actor.faces_right
	actor.position = actor.home
	target.position = target.home
	actor.z_index = actor.home_z_index
	actor.emphasized = false
	target.emphasized = false
	target.damage_text = ""
	target.hit_flash = false
	target.heal_flash = false
	actor.play_state("idle", speed)
	if target.hp_value() > 0:
		target.play_state("idle", speed)
	stage.refresh_hp()
	current_type = -1
	presentation_finished.emit()

func travel_seconds(actor: CharacterBattleView, destination: Vector2) -> float:
	# Keep enough time for a readable stride, with gentle acceleration/deceleration.
	return clampf(actor.position.distance_to(destination) / 1050.0, 0.32, 0.65)
