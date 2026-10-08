class_name SquadData
extends RefCounted

var squad_name: String = "나뭇잎 시험 부대"
var leader_id: String = ""
# ninja id -> FormationSlot. Battle code can query this without any UI node.
var positions: Dictionary = {}
# Runtime HP belongs to the squad, not NinjaData (shared character definitions).
var current_hp: Dictionary = {}

func occupant(slot: FormationSlot) -> String:
	for id in positions:
		if positions[id].key() == slot.key():
			return id
	return ""

func to_dict() -> Dictionary:
	var members: Array = []
	for id in positions:
		members.append({"ninja_id": id, "position": positions[id].to_dict()})
	var hp: Dictionary = {}
	for id in positions:
		if current_hp.has(id):
			hp[id] = current_hp[id]
	return {"version": 1, "squad_name": squad_name, "leader_id": leader_id, "members": members, "current_hp": hp}
