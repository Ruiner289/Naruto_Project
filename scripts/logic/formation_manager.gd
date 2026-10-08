class_name FormationManager
extends RefCounted

signal changed
const MAX_MEMBERS := 9
var roster: Dictionary
var squad: SquadData

func _init() -> void:
	roster = TestRoster.create()
	squad = SquadData.new()
	squad.leader_id = "kakashi"
	squad.positions["kakashi"] = FormationSlot.new(2, 0.0)

func place(id: String, slot: FormationSlot) -> String:
	if not roster.has(id) or not slot.is_valid():
		return "유효하지 않은 캐릭터 또는 좌표입니다."
	if not NinjaRank.can_command(roster[squad.leader_id].rank, roster[id].rank):
		return "현재 부대장은 이 계급을 지휘할 수 없습니다."
	var occupant := squad.occupant(slot)
	if occupant != "" and occupant != id:
		return "이미 점유된 위치입니다. 빈 위치를 선택하세요."
	if not squad.positions.has(id) and squad.positions.size() >= MAX_MEMBERS:
		return "최대 9명까지 편성할 수 있습니다."
	squad.positions[id] = slot
	changed.emit()
	return ""

func remove(id: String) -> String:
	if id == squad.leader_id:
		return "부대장은 제거할 수 없습니다. 다른 편성 멤버를 부대장으로 지정하세요."
	if not squad.positions.has(id):
		return "편성되지 않은 캐릭터입니다."
	squad.positions.erase(id)
	changed.emit()
	return ""

func set_leader(id: String) -> String:
	if not roster.has(id) or not NinjaRank.can_lead(roster[id].rank):
		return "하급닌자는 부대장이 될 수 없습니다."
	if not squad.positions.has(id):
		return "먼저 캐릭터를 진형에 배치하세요."
	for member in squad.positions:
		if not NinjaRank.can_command(roster[id].rank, roster[member].rank):
			return "상급닌자가 편성되어 있습니다. 먼저 기존 상급닌자 부대장을 다른 상급닌자로 변경하고, 지휘할 수 없는 멤버를 제거하세요."
	squad.leader_id = id
	changed.emit()
	return ""

# Atomic replacement allows promotion/demotion without ever leaving the squad leaderless.
func replace_leader(id: String) -> String:
	if not roster.has(id) or not NinjaRank.can_lead(roster[id].rank):
		return "하급닌자는 부대장이 될 수 없습니다."
	var old: String = squad.leader_id
	for member in squad.positions:
		if member != old and not NinjaRank.can_command(roster[id].rank, roster[member].rank):
			return "새 부대장이 지휘할 수 없는 멤버를 먼저 제거하세요."
	var old_slot: FormationSlot = squad.positions[old]
	squad.positions.erase(old)
	if not squad.positions.has(id):
		squad.positions[id] = old_slot
	squad.leader_id = id
	changed.emit()
	return ""

func save_json(path: String = "user://squad.json") -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "저장 파일을 열 수 없습니다."
	file.store_string(JSON.stringify(squad.to_dict(), "\t"))
	return ""

func load_json(path: String = "user://squad.json") -> String:
	if not FileAccess.file_exists(path):
		return "저장 파일이 없습니다."
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not raw is Dictionary or raw.get("version") != 1 or not raw.get("members") is Array:
		return "저장 형식이 올바르지 않습니다."
	var candidate := SquadData.new()
	if not raw.get("leader_id") is String or not raw.get("squad_name") is String:
		return "부대 정보가 올바르지 않습니다."
	candidate.leader_id = raw.leader_id
	candidate.squad_name = raw.squad_name
	if not roster.has(candidate.leader_id) or not NinjaRank.can_lead(roster[candidate.leader_id].rank):
		return "부대장 정보가 올바르지 않습니다."
	for entry in raw.members:
		if not entry is Dictionary or not entry.get("position") is Dictionary:
			return "위치 정보가 올바르지 않습니다."
		var id: Variant = entry.get("ninja_id")
		var p: Dictionary = entry.position
		if not id is String or not roster.has(id) or candidate.positions.has(id):
			return "멤버 정보가 올바르지 않습니다."
		if not (p.get("column") is int or p.get("column") is float) or not (p.get("row_offset") is int or p.get("row_offset") is float):
			return "좌표 형식이 올바르지 않습니다."
		if float(p.column) != floorf(float(p.column)):
			return "열 좌표는 정수여야 합니다."
		var slot := FormationSlot.new(int(p.column), float(p.row_offset))
		if not slot.is_valid() or candidate.occupant(slot) != "" or not NinjaRank.can_command(roster[candidate.leader_id].rank, roster[id].rank):
			return "배치 또는 계급 규칙에 맞지 않는 저장입니다."
		candidate.positions[id] = slot
	if candidate.positions.size() > MAX_MEMBERS or not candidate.positions.has(candidate.leader_id):
		return "인원 또는 부대장 규칙이 올바르지 않습니다."
	var hp_data: Variant = raw.get("current_hp", {})
	if not hp_data is Dictionary:
		return "HP 저장 형식이 올바르지 않습니다."
	for id in candidate.positions:
		if hp_data.has(id):
			var value: Variant = hp_data[id]
			if not (value is int or value is float) or float(value) != floorf(float(value)) or value < 0 or value > roster[id].test_stats().hp:
				return "HP 값이 올바르지 않습니다."
			candidate.current_hp[id] = int(value)
	# Preserve identity: map units and BattleContext may already reference this object.
	squad.squad_name = candidate.squad_name
	squad.leader_id = candidate.leader_id
	squad.positions = candidate.positions
	squad.current_hp = candidate.current_hp
	changed.emit()
	return ""
