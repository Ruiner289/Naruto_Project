class_name NinjaRank
extends RefCounted

enum Value { GENIN, CHUNIN, JONIN }

static func label(rank: int) -> String:
	return ["하급닌자", "중급닌자", "상급닌자"][rank]

static func can_lead(rank: int) -> bool:
	return rank >= Value.CHUNIN

static func can_command(leader_rank: int, member_rank: int) -> bool:
	return can_lead(leader_rank) and member_rank <= leader_rank
