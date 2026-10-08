class_name GenericFactory
extends RefCounted

const TYPES := ["big_sound", "dart", "claw", "pole", "flail", "scythe"]
const NAMES := ["소리 중갑병", "다트병", "발톱병", "봉술병", "철구병", "낫병"]

static func make_squad(roster: Dictionary, prefix: String, types: Array, title: String = "범용 부대") -> SquadData:
	var squad := SquadData.new()
	squad.squad_name = title
	for i in types.size():
		var kind: String = types[i]
		var id := "%s_%s_%d" % [prefix, kind, i]
		var definition := NinjaData.new(id, NAMES[TYPES.find(kind)], 0, Color(0.85, 0.52, 0.4))
		definition.battlefield_only = true
		definition.sprite_profile_id = "generic_" + kind
		definition.class_type = NinjaData.ClassType.RANGED if kind == "dart" else (NinjaData.ClassType.HEAVY_MELEE if kind in ["big_sound", "flail"] else NinjaData.ClassType.LIGHT_MELEE)
		definition.prototype_action_type = BattleAction.Type.RANGED if kind == "dart" else BattleAction.Type.MELEE
		definition.prototype_stats = PrototypeRules.stats(0)
		roster[id] = definition
		squad.positions[id] = FormationSlot.new(2 - int(i / 3.0), float(i % 3))
		if i == 0:
			squad.leader_id = id
	PrototypeRules.ensure_hp(squad, roster)
	return squad
