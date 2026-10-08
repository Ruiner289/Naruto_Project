extends SceneTree

func _initialize() -> void:
	var roster := TestRoster.create()
	var a := SquadData.new()
	a.positions.kakashi = FormationSlot.new(2, 0.5)
	a.current_hp.kakashi = 80
	var d := SquadData.new()
	d.positions.asuma = FormationSlot.new(2, 1.5)
	d.current_hp.asuma = 80
	var attacker := SquadMapUnit.new("a", a, HexCoord.new(), false)
	var defender := SquadMapUnit.new("d", d, HexCoord.new(1, 0), true)
	var battle := BattleResolver.new(BattleContext.new(attacker, defender), roster)
	var count := 0
	while not battle.next_action().is_empty():
		count += 1
	assert(count == 2 and battle.winner == 2)
	var hp: int = a.current_hp.kakashi
	var again := BattleResolver.new(BattleContext.new(attacker, defender), roster)
	assert(a.current_hp.kakashi == hp and not again.next_action().is_empty())
	assert(a.positions.kakashi.row_offset == 0.5)
	print("Engagement tests: PASS (single six-phase exchange, persistent HP)")
	quit(0)
