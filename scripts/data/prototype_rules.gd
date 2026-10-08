class_name PrototypeRules
extends RefCounted

# Deliberately provisional. No final Naruto attributes or combat rules.
const MAP_COLUMNS: int = 20
const MAP_ROWS: int = 14
const MOVEMENT: int = 4
const HEX_RADIUS: float = 36.0
const MOVE_STEP_SECONDS: float = 0.14
const ACTION_SECONDS: float = 0.55
const TRANSITION_SECONDS: float = 0.12

static func stats(rank: int) -> Dictionary:
	return {"hp": 50 + rank * 15, "attack": 14 + rank * 4}

static func ensure_hp(squad: SquadData, roster: Dictionary) -> void:
	for id in squad.positions:
		if not squad.current_hp.has(id):
			squad.current_hp[id] = roster[id].test_stats().hp

static func hp_total(squad: SquadData) -> int:
	var total: int = 0
	for id in squad.positions:
		total += int(squad.current_hp.get(id, 0))
	return total

static func living_count(squad: SquadData) -> int:
	var total := 0
	for id in squad.positions:
		if squad.current_hp.get(id, 0) > 0:
			total += 1
	return total
