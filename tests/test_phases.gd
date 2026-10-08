extends SceneTree

var failures: int = 0
var roster: Dictionary = {}

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func member(squad: SquadData, id: String, type: int, hp: int = 100, maximum: int = 100, attack: int = 30, heal: int = 80, column: int = 2) -> void:
	var ninja := NinjaData.new(id, id)
	ninja.class_type = type
	ninja.prototype_stats = {"hp": maximum, "attack": attack}
	ninja.heal_power = heal
	roster[id] = ninja
	squad.positions[id] = FormationSlot.new(column, float(squad.positions.size()) * 0.5)
	squad.current_hp[id] = hp
	if squad.leader_id.is_empty():
		squad.leader_id = id

func resolver(a: SquadData, d: SquadData) -> BattleResolver:
	return BattleResolver.new(BattleContext.new(SquadMapUnit.new("a", a, HexCoord.new(), false), SquadMapUnit.new("d", d, HexCoord.new(1, 0), true)), roster)

func drain(battle: BattleResolver) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in 100:
		var event := battle.next_action()
		if event.is_empty():
			return events
		events.append(event)
	check(false, "Exchange must terminate in bounded actions")
	return events

func _initialize() -> void:
	var a := SquadData.new()
	var d := SquadData.new()
	for type in NinjaData.phase_order():
		member(a, "p%d" % type, type, 50 if type == NinjaData.ClassType.HEAVY_MELEE else 100)
	member(d, "enemy", NinjaData.ClassType.HEAVY_MELEE, 10000, 10000, 0)
	var battle := resolver(a, d)
	var events := drain(battle)
	var phases: Array[int] = []
	for event in events:
		if event.side == 0:
			phases.append(event.phase)
		print(BattleLogger.format_event(event, roster))
	check(phases == [1, 2, 3, 4, 5, 6], "TEST1 six ordered class phases including healer")
	check(battle.winner == 2 and battle.next_action().is_empty(), "Single exchange, no repeat rounds")
	check(events[5].side == 1 and events[5].kind == BattleAction.Kind.ATTACK, "Defender attacks before attacker heals")
	check(events.back().side == 0 and events.back().kind == BattleAction.Kind.HEAL, "Attacker heals after both sides attack")
	check(battle.wave_history.size() == 12, "Six waves per side, no extra exchange")

	# A later attacker class must precede an earlier defender class.
	a = SquadData.new()
	d = SquadData.new()
	member(a, "heavyA", NinjaData.ClassType.HEAVY_MELEE, 1000, 1000, 10)
	member(a, "rangedA", NinjaData.ClassType.RANGED, 1000, 1000, 10)
	member(d, "gunDfast", NinjaData.ClassType.GUNPOWDER, 1000, 1000, 10)
	member(d, "rangedD", NinjaData.ClassType.RANGED, 1000, 1000, 10)
	battle = resolver(a, d)
	events = drain(battle)
	check(events.size() == 4 and events[0].actor == "rangedA" and events[1].actor == "heavyA" and events[2].actor == "gunDfast" and events[3].actor == "rangedD", "Whole attacker initiative overrides defender class priority")
	# The enemy can be the initiator: initiative follows context, not faction.
	var enemy_attack := BattleContext.new(SquadMapUnit.new("enemy", a, HexCoord.new(), true), SquadMapUnit.new("ally", d, HexCoord.new(1, 0), false))
	events = drain(BattleResolver.new(enemy_attack, roster))
	check(events[0].side == 0 and events[1].side == 0 and events[2].side == 1, "Enemy-initiated battle uses the same initiative rule")

	# Defender healing chooses targets after damage from the attacker turn.
	a = SquadData.new()
	d = SquadData.new()
	member(a, "shooter", NinjaData.ClassType.RANGED, 1000, 1000, 30)
	member(d, "guard", NinjaData.ClassType.HEAVY_MELEE, 100, 100, 0)
	member(d, "medic", NinjaData.ClassType.HEALER, 100, 100, 0, 20, 0)
	events = drain(resolver(a, d))
	check(events.size() == 3 and events[2].kind == BattleAction.Kind.HEAL and events[2].target == "guard" and d.current_hp.guard == 90, "Defender heal observes damage from attacker waves")

	# Both healers must observe the completed exchange, including counter damage.
	a = SquadData.new()
	d = SquadData.new()
	member(a, "fighterA", NinjaData.ClassType.HEAVY_MELEE, 100, 100, 30)
	member(a, "healerA", NinjaData.ClassType.HEALER, 100, 100, 0, 20, 0)
	member(d, "fighterD", NinjaData.ClassType.HEAVY_MELEE, 100, 100, 40)
	member(d, "healerD", NinjaData.ClassType.HEALER, 100, 100, 0, 15, 0)
	events = drain(resolver(a, d))
	check(events.size() == 4 and events[0].actor == "fighterA" and events[1].actor == "fighterD" and events[2].actor == "healerA" and events[3].actor == "healerD", "Both attacks precede attacker heal then defender heal")
	check(a.current_hp.fighterA == 80 and d.current_hp.fighterD == 85, "Healthy attacker at battle start is healed after receiving counter damage")

	a = SquadData.new()
	d = SquadData.new()
	member(a, "archer1", NinjaData.ClassType.RANGED)
	member(a, "archer2", NinjaData.ClassType.RANGED)
	member(d, "front", NinjaData.ClassType.LIGHT_MELEE, 20, 100, 0)
	member(d, "rear", NinjaData.ClassType.LIGHT_MELEE, 100, 100, 0, 0, 0)
	member(d, "dead", NinjaData.ClassType.GUNPOWDER, 0)
	battle = resolver(a, d)
	var first := battle.next_action()
	var second := battle.next_action()
	check(first.target == "front" and second.target == "rear" and second.hp == 70, "TEST2 defeated reserved target replaced with living target")
	check(d.current_hp.rear == 70 and second.damage == 30, "Retarget uses normal damage without carrying over excess damage")
	check(first.target != "dead", "TEST8 dead target excluded at phase start")
	check(d.current_hp.front == 0, "TEST10 damage mutates original SquadData")
	# Repeat with the enemy as initiator; every attack sees a living target.
	a.current_hp.archer1 = 100
	a.current_hp.archer2 = 100
	d.current_hp.front = 20
	d.current_hp.rear = 100
	var retarget_context := BattleContext.new(SquadMapUnit.new("e", a, HexCoord.new(), true), SquadMapUnit.new("p", d, HexCoord.new(1, 0), false))
	battle = BattleResolver.new(retarget_context, roster)
	var living_attack_count := 0
	while battle.winner < 0:
		var hp_before_action := [a.current_hp.duplicate(), d.current_hp.duplicate()]
		var event := battle.next_action()
		if event.is_empty():
			break
		if event.kind == BattleAction.Kind.ATTACK:
			check(int(hp_before_action[event.target_side][event.target]) > 0, "Every executed attack targets a living character, including enemy-initiated battle")
			living_attack_count += 1
	check(living_attack_count == 3, "Defeated defender never retaliates; remaining defender does")

	# A healer killed during attacks cannot act or revive in the final heal phase.
	a = SquadData.new()
	d = SquadData.new()
	member(a, "killer", NinjaData.ClassType.GUNPOWDER, 100, 100, 30)
	member(a, "medicA", NinjaData.ClassType.HEALER, 100, 100, 0, 20, 0)
	member(d, "fallenMedic", NinjaData.ClassType.HEALER, 10, 100, 0, 100)
	member(d, "survivingGuard", NinjaData.ClassType.HEAVY_MELEE, 100, 100, 10, 0, 0)
	events = drain(resolver(a, d))
	for event in events:
		check(event.actor != "fallenMedic", "Healer killed before heal stage cannot act")
	check(d.current_hp.fallenMedic == 0, "Final healing stage cannot revive defeated characters")

	a = SquadData.new()
	d = SquadData.new()
	member(a, "gunA", NinjaData.ClassType.GUNPOWDER)
	member(d, "gunD", NinjaData.ClassType.GUNPOWDER, 20)
	member(d, "survivor", NinjaData.ClassType.HEAVY_MELEE, 100, 100, 0, 0, 0)
	battle = resolver(a, d)
	events = drain(battle)
	var dead_acted := false
	for event in events:
		dead_acted = dead_acted or event.actor == "gunD"
	check(not dead_acted and a.current_hp.gunA == 100, "TEST3 actor killed before execution cancels reservation")

	a = SquadData.new()
	d = SquadData.new()
	member(a, "gun", NinjaData.ClassType.GUNPOWDER)
	member(a, "late", NinjaData.ClassType.HEAVY_MELEE)
	member(d, "sole", NinjaData.ClassType.HEAVY_MELEE, 1)
	battle = resolver(a, d)
	events = drain(battle)
	check(events.size() == 1 and battle.phase_history == [1] and battle.winner == 0, "TEST4 annihilation stops remaining actions and phases")

	a = SquadData.new()
	d = SquadData.new()
	member(a, "patient30", NinjaData.ClassType.HEAVY_MELEE, 30, 100, 0)
	member(a, "patient40", NinjaData.ClassType.HEAVY_MELEE, 20, 50, 0)
	member(a, "healer1", NinjaData.ClassType.HEALER)
	member(a, "healer2", NinjaData.ClassType.HEALER)
	member(a, "dead_patient", NinjaData.ClassType.HEAVY_MELEE, 0)
	member(d, "healthy_enemy", NinjaData.ClassType.HEAVY_MELEE, 1000, 1000, 0)
	check(TargetSelector.choose_heal(a, roster) == "patient30", "TEST5 lowest HP ratio, not absolute HP")
	battle = resolver(a, d)
	events = drain(battle)
	var heals: Array[Dictionary] = []
	for event in events:
		if event.kind == BattleAction.Kind.HEAL:
			heals.append(event)
	check(heals.size() == 2 and heals[0].target == "patient30" and heals[1].target == "patient30", "TEST6 both healers reserve same injured ally")
	check(a.current_hp.patient30 == 100 and heals[1].heal == 0, "TEST7 capped healing with no retarget after first heal")
	check(a.current_hp.dead_patient == 0, "TEST9 no dead heal target or revival")
	check(a.current_hp.patient40 == 20 and a.current_hp.patient30 == heals[1].hp, "TEST10 healing persisted in original squad")
	check(battle.context.attacker == a, "No duplicated HP or squad model")
	for id in a.positions:
		if a.current_hp[id] > 0:
			a.current_hp[id] = roster[id].test_stats().hp
	check(TargetSelector.choose_heal(a, roster).is_empty(), "No healing action when all survivors full")
	var again := resolver(a, d)
	var hp_before: int = a.current_hp.patient30
	drain(again)
	check(a.current_hp.patient30 == hp_before, "New exchange does not reset HP")
	print("Phase tests: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
