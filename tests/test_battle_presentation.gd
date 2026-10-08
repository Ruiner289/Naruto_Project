extends SceneTree

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var roster := TestRoster.create()
	var attacker := SquadData.new()
	attacker.positions = {"kakashi": FormationSlot.new(2, 0.5), "shikamaru": FormationSlot.new(0, 1.5)}
	attacker.leader_id = "kakashi"
	var defender := SquadData.new()
	defender.positions = {"asuma": FormationSlot.new(2, 0.5)}
	defender.leader_id = "asuma"
	PrototypeRules.ensure_hp(attacker, roster)
	PrototypeRules.ensure_hp(defender, roster)
	var context := BattleContext.new(SquadMapUnit.new("a", attacker, HexCoord.new(), false), SquadMapUnit.new("d", defender, HexCoord.new(1, 0), true))
	var stage := BattleStage.new()
	stage.context = context
	stage.roster = roster
	root.add_child(stage)
	var animator := BattleAnimator.new()
	animator.stage = stage
	root.add_child(animator)
	await process_frame
	var melee: CharacterBattleView = stage.views[BattleStage.key(0, "kakashi")]
	var ranged: CharacterBattleView = stage.views[BattleStage.key(0, "shikamaru")]
	var target: CharacterBattleView = stage.views[BattleStage.key(1, "asuma")]
	defender.current_hp.asuma = 64
	var event := {"side": 0, "actor": "kakashi", "target": "asuma", "damage": 16, "hp": 64, "action_type": BattleAction.Type.MELEE}
	animator.present(event, 1.0)
	await animator.impact
	check(melee.position.distance_to(target.home) < 125, "Melee reaches enemy instead of short nudge")
	check(target.displayed_hp == 64 and target.hit_flash and target.damage_text == "-16", "HP revealed with impact feedback")
	await animator.presentation_finished
	check(melee.position == melee.home and target.position == target.home, "Melee and shake restore original positions")
	check(not target.hit_flash and target.damage_text.is_empty(), "Impact feedback cleared")
	defender.current_hp.asuma = 49
	event = {"side": 0, "actor": "shikamaru", "target": "asuma", "damage": 15, "hp": 49, "action_type": BattleAction.Type.RANGED}
	animator.present(event, 1.0)
	var deadline := Time.get_ticks_msec() + 2000
	while animator.projectile == null and Time.get_ticks_msec() < deadline:
		await process_frame
	check(animator.projectile != null and is_instance_valid(animator.projectile), "Ranged projectile exists in flight")
	check(ranged.position == ranged.home, "Ranged stays in formation")
	await animator.presentation_finished
	check(animator.projectile == null and target.displayed_hp == 49, "Projectile cleanup and persistent impact HP")
	check(animator.melee_count == 1 and animator.ranged_count == 1, "Separated animation branches")
	check(defender.current_hp.asuma == 49, "Animator never recalculates damage")
	check(attacker.positions.kakashi.row_offset == 0.5 and defender.positions.asuma.column == 2, "Animation never alters FormationSlot")
	attacker.current_hp.kakashi = 70
	event = {"side": 0, "actor": "shikamaru", "target_side": 0, "target": "kakashi", "kind": BattleAction.Kind.HEAL, "heal": 20, "damage": 0, "hp": 70, "action_type": BattleAction.Type.MELEE}
	animator.present(event, 1.0)
	await animator.impact
	check(melee.displayed_hp == 70 and melee.heal_flash and melee.damage_text == "+20", "Healer displays same-side HP increase at impact")
	check(ranged.position == ranged.home, "Healer stays at own formation position")
	await animator.presentation_finished
	check(attacker.current_hp.kakashi == 70 and not melee.heal_flash, "Healing presentation does not recompute or duplicate heal")
	check(animator.melee_count == 1 and animator.ranged_count == 1, "Healing is separate from attack presentation")
	print("Battle presentation tests: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
