class_name BattlePreview
extends Control

signal confirmed
signal cancelled
var attacker: SquadMapUnit
var defender: SquadMapUnit
var roster: Dictionary
var start_button: Button
var cancel_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.18)
	style.border_color = Color(0.45, 0.65, 0.85)
	style.set_border_width_all(2)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	panel.add_child(box)
	UIHelpers.label(box, "전투 진입 확인", 26)
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 24)
	box.add_child(sides)
	for unit in [attacker, defender]:
		var info := UIHelpers.label(sides, summary(unit), 18)
		info.custom_minimum_size.x = 260
		info.modulate = Color(0.55, 0.8, 1) if unit == attacker else Color(1, 0.6, 0.6)
	UIHelpers.label(box, "전투 시작 → 병종별 6단계의 1차 공방 → 종료\n양측 생존 시 HP와 공격 위치를 유지하고 다음 턴에 다시 싸웁니다.\n이동 후 취소해도 이동한 위치는 유지됩니다. 공격 대신 대기할 수 있습니다.")
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	start_button = UIHelpers.button(buttons, "전투 시작", func(): confirmed.emit())
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_button = UIHelpers.button(buttons, "취소 · 우클릭 / Esc", func(): cancelled.emit())
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func summary(unit: SquadMapUnit) -> String:
	var living: int = 0
	for id in unit.squad.positions:
		if unit.squad.current_hp.get(id, 0) > 0:
			living += 1
	return "%s\n부대장: %s\n인원: %d명 / 전투 가능: %d명\nHP 합계: %d\n위치: q=%d / r=%d" % [unit.squad.squad_name, roster[unit.squad.leader_id].display_name, unit.squad.positions.size(), living, PrototypeRules.hp_total(unit.squad), unit.coord.q, unit.coord.r]
