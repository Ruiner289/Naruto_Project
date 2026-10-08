class_name SquadInspector
extends Control

signal closed
var unit: SquadMapUnit
var roster: Dictionary
var formation: FormationBoard
var close_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 580
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.11, 0.17)
	style.border_color = Color(1, 0.4, 0.45) if unit.enemy else Color(0.4, 0.7, 1)
	style.set_border_width_all(2)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	UIHelpers.label(box, ("적" if unit.enemy else "아군") + " 진형 확인 · " + unit.squad.squad_name, 23)
	UIHelpers.label(box, "%s · 부대장 %s · %d명 · HP %d" % [unit.id, roster[unit.squad.leader_id].display_name, PrototypeRules.living_count(unit.squad), PrototypeRules.hp_total(unit.squad)], 15)
	formation = FormationBoard.new()
	formation.read_only = true
	formation.snapshot_squad = unit.squad
	formation.snapshot_roster = roster
	formation.mirror_display = unit.enemy
	box.add_child(formation)
	UIHelpers.label(box, "확인용입니다. 배치·HP·행동 상태를 변경하지 않습니다.", 14)
	close_button = UIHelpers.button(box, "닫기 · 우클릭 / Esc", func(): closed.emit())

