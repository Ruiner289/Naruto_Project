class_name FormationSlot
extends RefCounted

var column: int
var row_offset: float

func _init(p_column: int = 0, p_row_offset: float = 0.0) -> void:
	column = p_column
	row_offset = p_row_offset

func is_valid() -> bool:
	return column >= 0 and column < 3 and row_offset >= 0.0 and row_offset <= 2.0 and is_equal_approx(row_offset * 2.0, roundf(row_offset * 2.0))

func key() -> String:
	return "%d:%d" % [column, roundi(row_offset * 2.0)]

func to_dict() -> Dictionary:
	return {"column": column, "row_offset": row_offset}
