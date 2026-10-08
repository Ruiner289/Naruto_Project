class_name TestRoster
extends RefCounted

static func create() -> Dictionary:
	var result: Dictionary = {}
	var names := ["카카시", "야마토", "아스마", "시카마루", "이노", "쵸지", "나루토", "사스케", "사쿠라", "키바", "히나타", "시노"]
	var ids := ["kakashi", "yamato", "asuma", "shikamaru", "ino", "choji", "naruto", "sasuke", "sakura", "kiba", "hinata", "shino"]
	for i in names.size():
		var rank: int = 2 if i < 3 else (1 if i < 6 else 0)
		result[ids[i]] = NinjaData.new(ids[i], names[i], rank, Color.from_hsv(float(i) / 12.0, 0.48, 0.85))
		result[ids[i]].prototype_stats = PrototypeRules.stats(rank)
		# Temporary class assignments, unrelated to final Naruto skills.
		var classes := [NinjaData.ClassType.LIGHT_MELEE, NinjaData.ClassType.HEAVY_MELEE, NinjaData.ClassType.HEAVY_MELEE, NinjaData.ClassType.MAGIC, NinjaData.ClassType.HEALER, NinjaData.ClassType.HEAVY_MELEE, NinjaData.ClassType.LIGHT_MELEE, NinjaData.ClassType.MAGIC, NinjaData.ClassType.HEALER, NinjaData.ClassType.LIGHT_MELEE, NinjaData.ClassType.RANGED, NinjaData.ClassType.GUNPOWDER]
		result[ids[i]].class_type = classes[i]
		if result[ids[i]].class_type in [NinjaData.ClassType.GUNPOWDER, NinjaData.ClassType.MAGIC, NinjaData.ClassType.RANGED]:
			result[ids[i]].prototype_action_type = BattleAction.Type.RANGED
	# Provisional melee fixture for the newly supplied outfit; no character skill system.
	result["kurenai"] = NinjaData.new("kurenai", "쿠레나이", 2, Color(0.7, 0.25, 0.4))
	result["kurenai"].prototype_stats = PrototypeRules.stats(2)
	# Temporary prototype classes; character-specific skills are not implemented.
	for entry in [["guy", "가이", 2], ["lee", "리", 0], ["neji", "네지", 0], ["tenten", "텐텐", 0]]:
		var id: String = entry[0]
		result[id] = NinjaData.new(id, entry[1], entry[2], Color(0.35, 0.7, 0.45))
		result[id].prototype_stats = PrototypeRules.stats(entry[2])
		if id == "tenten":
			result[id].class_type = NinjaData.ClassType.RANGED
			result[id].prototype_action_type = BattleAction.Type.RANGED
	return result
