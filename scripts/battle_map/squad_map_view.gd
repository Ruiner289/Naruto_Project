class_name SquadMapView
extends Control

var unit: SquadMapUnit
var roster: Dictionary
var selected: bool = false

func _init(p_unit: SquadMapUnit, p_roster: Dictionary) -> void:
	unit = p_unit
	roster = p_roster
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var color := Color(1, 0.34, 0.36) if unit.enemy else Color(0.35, 0.72, 1)
	if PrototypeRules.hp_total(unit.squad) == 0:
		color = Color(0.45, 0.45, 0.48)
	elif unit.acted:
		color = color.darkened(0.55)
	draw_circle(Vector2.ZERO, 25, color.darkened(0.65))
	draw_arc(Vector2.ZERO, 25, 0, TAU, 32, color, 3)
	if selected:
		draw_arc(Vector2.ZERO, 30, 0, TAU, 32, Color(1, 0.88, 0.35), 3)
	var font := ThemeDB.fallback_font
	var title: String = unit.squad.squad_name
	var leader: String = roster[unit.squad.leader_id].display_name
	draw_string(font, Vector2(-font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x / 2, -6), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	draw_string(font, Vector2(-font.get_string_size(leader, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x / 2, 13), leader, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	if unit.acted:
		draw_string(font, Vector2(15, -20), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 0.9, 0.4))
