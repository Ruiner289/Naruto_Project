extends SceneTree

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var m := FormationManager.new()
	check(m.squad.positions.size() == 1, "Initial leader")
	check(not m.set_leader("naruto").is_empty(), "Genin cannot lead")
	check(m.place("naruto", FormationSlot.new(0, 0.5)).is_empty(), "Half slot")
	check(m.place("naruto", FormationSlot.new(0, 1.5)).is_empty(), "Move")
	check(m.squad.positions.size() == 2, "Move does not duplicate")
	check(not m.place("sakura", FormationSlot.new(0, 1.5)).is_empty(), "Occupied rejection")
	check(not m.remove("kakashi").is_empty(), "Leader must remain")
	check(m.replace_leader("shikamaru").is_empty(), "Demotion through atomic replacement")
	check(not m.place("yamato", FormationSlot.new(0, 0)).is_empty(), "Rank restriction")
	check(m.replace_leader("kakashi").is_empty(), "Promotion")
	var row: int = 0
	for id in m.roster:
		if m.squad.positions.has(id):
			continue
		while m.squad.occupant(FormationSlot.new(row / 5, float(row % 5) / 2.0)) != "":
			row += 1
		var error := m.place(id, FormationSlot.new(row / 5, float(row % 5) / 2.0))
		if m.squad.positions.size() < 9:
			check(error.is_empty(), "Add within limit")
		row += 1
	check(m.squad.positions.size() == 9, "Capacity")
	check(not m.place("shino", FormationSlot.new(2, 2)).is_empty(), "Capacity rejection")
	check(not m.place("naruto", FormationSlot.new(0, 0.25)).is_empty(), "Invalid offset")
	check(m.save_json("user://test_squad.json").is_empty(), "Save")
	var before := JSON.stringify(m.squad.to_dict())
	check(m.load_json("user://test_squad.json").is_empty(), "Load")
	check(JSON.stringify(m.squad.to_dict()) == before, "Round trip coordinates")
	var f := FileAccess.open("user://test_invalid.json", FileAccess.WRITE)
	f.store_string('{"version":1,"leader_id":"naruto","squad_name":"bad","members":[]}')
	f.close()
	check(not m.load_json("user://test_invalid.json").is_empty(), "Invalid save rejected")
	check(JSON.stringify(m.squad.to_dict()) == before, "Invalid load atomic")
	for col in 3:
		for half in 5:
			check(FormationSlot.new(col, float(half) / 2.0).is_valid(), "15 valid coordinates")
	print("Formation tests: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
