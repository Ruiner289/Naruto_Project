class_name BattleAction
extends RefCounted

# Presentation categories only; these are not Naruto skills/classes.
enum Type { MELEE, RANGED, HEAL }
enum Kind { ATTACK, HEAL }

# Targets are reserved at phase start, before any HP changes.
var side: int
var actor: String
var target_side: int
var target: String
var kind: Kind = Kind.ATTACK
var value: int
var phase: int
var presentation_type: int

static func label(type: int) -> String:
	return "원거리 테스트" if type == Type.RANGED else "근접 테스트"
