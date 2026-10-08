class_name NinjaData
extends Resource

enum ClassType { GUNPOWDER, MAGIC, RANGED, LIGHT_MELEE, HEAVY_MELEE, HEALER }
@export var class_type: ClassType = ClassType.LIGHT_MELEE
@export var heal_power: int = 20

@export var id: String
@export var sprite_profile_id: String = ""
@export var battlefield_only: bool = false
@export var display_name: String
@export var rank: int
@export var color: Color
# Provisional prototype data, separate from final character abilities.
@export var prototype_stats: Dictionary = {}
@export var prototype_action_type: int = BattleAction.Type.MELEE
# Legacy resource field; the six-phase exchange now reserves one action per member.
@export_range(1, 4) var prototype_actions_per_engagement: int = 1

func _init(p_id: String = "", p_name: String = "", p_rank: int = 0, p_color: Color = Color.WHITE) -> void:
	id = p_id
	display_name = p_name
	rank = p_rank
	color = p_color

func test_stats() -> Dictionary:
	return prototype_stats if not prototype_stats.is_empty() else PrototypeRules.stats(rank)

static func phase_order() -> Array[int]:
	return [ClassType.GUNPOWDER, ClassType.MAGIC, ClassType.RANGED, ClassType.LIGHT_MELEE, ClassType.HEAVY_MELEE, ClassType.HEALER]

static func get_phase_priority(value: int) -> int:
	return phase_order().find(value) + 1

static func class_label(value: int) -> String:
	return ["Gunpowder", "Magic", "Ranged", "LightMelee", "HeavyMelee", "Healer"][get_phase_priority(value) - 1]
