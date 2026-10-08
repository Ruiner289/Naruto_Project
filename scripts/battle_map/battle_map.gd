extends Control

signal formation_requested
var board: HexBoard
var selected: SquadMapUnit
var busy: bool = false
var info: Label
var coordinate_label: Label
var status: Label
var turn_label: Label
var end_button: Button
var formation_button: Button
var wait_button: Button
var preview: BattlePreview
var pending_attacker: SquadMapUnit
var pending_defender: SquadMapUnit
var map_scroll: ScrollContainer
var command_unit: SquadMapUnit
var inspector: SquadInspector
var attack_button: Button
var action_menu: Panel
var action_title: Label
var menu_requested: bool = false
var choosing_attack: bool = false
var choosing_move: bool = false
var move_button: Button
var info_button: Button
var board_container: Control
var details_drawer: PanelContainer
var fit_button: Button
var fit_view: bool = true
var board_zoom: float = 1.0
var context_menu: Panel
var context_end_button: Button
var unit_list: PanelContainer
var pointer := Vector2(-1000, -1000)
var pan_fraction := Vector2.ZERO
const COMMAND_WIDTH: float = 180.0
const COMMAND_HEIGHT: float = 38.0
const MENU_WIDTH: float = 200.0
const EDGE_MARGIN: float = 28.0
const EDGE_SPEED: float = 480.0

func _ready() -> void:
	var box := Control.new()
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var toolbar := HBoxContainer.new()
	box.add_child(toolbar)
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toolbar.offset_left = 20
	toolbar.offset_right = -20
	toolbar.offset_top = 15
	toolbar.offset_bottom = 55
	toolbar.z_index = 60
	toolbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header := ColorRect.new()
	header.color = Color(0.025, 0.04, 0.055, 0.88)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom = 65
	header.z_index = 59
	box.add_child(header)
	turn_label = UIHelpers.label(toolbar, "", 24)
	turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fit_button = UIHelpers.button(toolbar, "확대 보기", func(): set_fit_view(not fit_view))
	UIHelpers.button(toolbar, "도움말", func(): details_drawer.visible = not details_drawer.visible)
	UIHelpers.button(toolbar, "전체화면 F11", GameState.toggle_fullscreen)
	formation_button = UIHelpers.button(toolbar, "주력 부대 편성", func(): formation_requested.emit())
	end_button = UIHelpers.button(toolbar, "턴 종료", request_end_turn)
	var row := Control.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_scroll = ScrollContainer.new()
	map_scroll.custom_minimum_size = Vector2(0, 480)
	map_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	row.add_child(map_scroll)
	map_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_container = Control.new()
	map_scroll.add_child(board_container)
	board = HexBoard.new()
	board_container.add_child(board)
	map_scroll.resized.connect(func(): call_deferred("update_view"))
	fit_view = GameState.map_fit_view
	call_deferred("update_view")
	call_deferred("restore_scroll")
	details_drawer = PanelContainer.new()
	details_drawer.name = "DetailsDrawer"
	details_drawer.z_index = 45
	details_drawer.size = Vector2(340, 520)
	add_child(details_drawer)
	details_drawer.hide()
	var panel_scroll := ScrollContainer.new()
	panel_scroll.custom_minimum_size.x = 310
	panel_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details_drawer.add_child(panel_scroll)
	var panel := VBoxContainer.new()
	panel.custom_minimum_size.x = 310
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 8)
	panel_scroll.add_child(panel)
	UIHelpers.button(panel, "도움말 닫기", func(): details_drawer.hide())
	UIHelpers.label(panel, "선택 부대", 22)
	info = UIHelpers.label(panel, "아군 부대를 클릭하세요.")
	coordinate_label = UIHelpers.label(panel, "헥스 좌표: —")
	UIHelpers.label(panel, "부대 클릭 → 이동 / 공격 / 정보 / 대기\n행동 메뉴 공격 → 적 선택 → 공격 확인\n부대 선택: 청록 이동 / 빨강 예상 공격\n공격 선택: 현재 위치의 빨강 대상\n화면 가장자리 커서: 전장 이동 · 휠 이동 없음\nWASD/방향키도 가능 · 우클릭/Esc 취소\n이동 후 공격/대기 전 우클릭: 출발 위치 복귀\n아군 통과 가능 · 주황 ZOC 진입 시 이동 끝", 14)
	UIHelpers.button(panel, "행동 메뉴 열기 (Space)", show_action_menu)
	UIHelpers.label(panel, "지형: 평지·도로 1 / 숲 2 / 늪·산 3\n물·×장애물: 통행 불가\n깃발: 파랑 아군 / 빨강 적 / 회색 중립\n거점은 위치 표시용입니다.", 14)
	UIHelpers.label(panel, "개발 디버그", 18)
	UIHelpers.button(panel, "[디버그] 모든 부대 회복", func(): if not busy and GameState.turn_manager.is_player_turn() and preview == null and inspector == null: GameState.heal_all(); refresh())
	status = UIHelpers.label(box, GameState.startup_message)
	status.custom_minimum_size.y = 30
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	status.offset_left = 20
	status.offset_right = -20
	status.offset_top = -36
	status.offset_bottom = -6
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.clip_text = true
	status.z_index = 60
	var status_style := StyleBoxFlat.new()
	status_style.bg_color = Color(0.025, 0.04, 0.055, 0.9)
	status_style.content_margin_left = 8
	status.add_theme_stylebox_override("normal", status_style)
	board.hex_clicked.connect(on_hex_clicked)
	board.hex_hovered.connect(on_hex_hovered)
	board.hover_cleared.connect(func(): coordinate_label.text = "커서를 전장 타일에 올리세요.")
	# Input picking follows child order, not z_index: toolbar must follow the full-screen board.
	box.move_child(toolbar, box.get_child_count() - 1)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_context_menu()
	build_action_menu()
	GameState.map_changed.connect(refresh)
	refresh()

func refresh() -> void:
	if selected != null and (not GameState.units.has(selected) or PrototypeRules.hp_total(selected.squad) <= 0):
		selected = null
	if command_unit != null and (not GameState.units.has(command_unit) or PrototypeRules.hp_total(command_unit.squad) <= 0):
		command_unit = null
	turn_label.text = "%d×%d 전장 · 턴 %d · %s" % [GameState.grid.width, GameState.grid.height, GameState.turn, "아군 PLAYER" if GameState.turn_manager.is_player_turn() else "적 ENEMY"]
	end_button.disabled = busy or preview != null or inspector != null or unit_list != null or not GameState.can_end_turn()
	context_end_button.disabled = end_button.disabled
	if not GameState.turn_manager.is_player_turn():
		context_menu.hide()
	formation_button.disabled = busy or preview != null or inspector != null or unit_list != null or GameState.pending_move_unit != null or GameState.combat_started or not GameState.turn_manager.is_player_turn()
	wait_button.disabled = busy or preview != null or inspector != null or selected == null or selected.enemy or not GameState.can_unit_act(selected) or not GameState.turn_manager.is_player_turn()
	attack_button.disabled = current_attack_targets().is_empty()
	board.selected = selected
	board.search = {"costs": {}, "previous": {}}
	board.attack_tiles = {}
	if selected != null and GameState.turn_manager.is_player_turn():
		if selected.enemy:
			board.search = GameState.search_for(selected, false, true)
			board.attack_tiles = GameState.attack_area(selected, board.search, true)
		elif GameState.can_unit_act(selected) and selected.can_move():
			board.search = GameState.search_for(selected)
			if not choosing_move:
				board.attack_tiles = GameState.attack_area(selected, board.search)
	if choosing_attack and selected != null:
		board.search = {"costs": {}, "previous": {}}
		board.preview_path.clear()
		board.attack_tiles.clear()
		for target in current_attack_targets():
			board.attack_tiles[target.coord.vector()] = true
	board.rebuild_units()
	refresh_action_menu()
	if selected == null:
		info.text = "아군 부대를 좌클릭하세요."
	if selected != null:
		var squad := selected.squad
		info.text = "%s [%s / %s]\n부대장: %s · %d명 · HP %d\nq=%d / r=%d · 이동력 %d · 공격 %d\n행동: %s" % [squad.squad_name, selected.id, "적" if selected.enemy else "아군", GameState.formation.roster[squad.leader_id].display_name, PrototypeRules.living_count(squad), PrototypeRules.hp_total(squad), selected.coord.q, selected.coord.r, selected.movement, selected.attack_range, "전투불능" if PrototypeRules.hp_total(squad) == 0 else ("완료" if selected.acted else ("이동 후보 · 공격/대기/우클릭 취소" if selected.moved else "이동/공격/대기 가능"))]
		if selected.enemy and GameState.turn_manager.is_player_turn():
			info.text += "\n적 범위: 다음 행동의 전체 이동력 기준 (확인용)"
		if command_unit != null and selected.enemy:
			info.text += "\n공격 부대: " + command_unit.squad.squad_name

func has_enemy() -> bool:
	for unit in GameState.units:
		if unit.enemy:
			return true
	return false

func on_hex_clicked(coord: Vector2i) -> void:
	if context_menu.visible:
		context_menu.hide()
		return
	if busy or preview != null or inspector != null or unit_list != null or not GameState.turn_manager.is_player_turn():
		return
	var occupant := GameState.unit_at(coord)
	if choosing_attack:
		if occupant != null and current_attack_targets().has(occupant):
			choosing_attack = false
			open_preview(selected, occupant)
		else:
			status.text = "현재 위치에서 공격 가능한 적을 클릭하세요. 우클릭으로 행동 메뉴에 돌아갑니다."
		return
	if choosing_move:
		if occupant == selected:
			show_action_menu()
			return
		if occupant != null:
			status.text = "빈 이동 가능 타일을 선택하세요. 우클릭은 행동 메뉴로 돌아갑니다."
			return
	elif occupant != null:
		if not occupant.enemy and GameState.pending_move_unit != null and occupant != GameState.pending_move_unit:
			GameState.cancel_pending_move()
		selected = occupant
		command_unit = occupant if not occupant.enemy else null
		show_action_menu()
		return
	else:
		status.text = "부대를 클릭하고 이동 버튼을 선택하세요."
		return
	if selected == null or selected.enemy or not selected.can_act():
		return
	var search := GameState.search_for(selected)
	if not selected.can_move():
		status.text = "이미 이동했습니다. 현재 위치에서 공격하거나 대기하세요."
		return
	if not search.costs.has(coord):
		status.text = "이동 범위 밖이거나 다른 부대가 경로를 막고 있습니다."
		return
	var route := GameState.grid.path(selected.coord.vector(), coord, search)
	if route.size() < 2:
		return
	move_unit(selected, route, null)

func wait_selected() -> void:
	if busy or preview != null or inspector != null or not GameState.turn_manager.is_player_turn() or selected == null or selected.enemy or not selected.can_act():
		return
	menu_requested = false
	choosing_attack = false
	choosing_move = false
	GameState.commit_pending_move()
	selected.acted = true
	board.preview_path.clear()
	status.text = "대기 완료. 다른 아군 부대를 선택하세요."
	refresh()

func on_hex_hovered(coord: Vector2i) -> void:
	var terrain: Dictionary = GameState.grid.terrain_info(coord)
	coordinate_label.text = "%s · q=%d / r=%d\n%s" % [terrain.name, coord.x, coord.y, "이동 비용 %d · 통행 가능" % terrain.cost if terrain.passable else "통행 불가"]
	board.preview_path.clear()
	if GameState.turn_manager.is_player_turn() and selected != null and (selected.enemy or (choosing_move and selected.can_move())) and not busy and preview == null and inspector == null and not choosing_attack:
		var search := GameState.search_for(selected, false, selected.enemy)
		board.preview_path = GameState.grid.path(selected.coord.vector(), coord, search)
		if board.preview_path.size() > 1:
			coordinate_label.text += "\n경로 비용: %d / %d" % [search.costs[coord], selected.movement]
	board.queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		pointer = event.position
	if event is InputEventMouseButton and unit_list != null and unit_list.get_global_rect().has_point(event.position) and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT] and map_scroll.get_global_rect().has_point(event.position):
		get_viewport().set_input_as_handled()
		return
	if not GameState.turn_manager.is_player_turn() and event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		show_action_menu()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if not busy and preview == null and inspector == null and unit_list == null and not details_drawer.visible and selected == null and GameState.pending_move_unit == null and not context_menu.visible:
			open_context_menu(event.position)
		else:
			cancel_interaction()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		cancel_interaction()
		get_viewport().set_input_as_handled()
	elif busy and event is InputEventMouseButton:
		get_viewport().set_input_as_handled()

func cancel_interaction() -> void:
	if context_menu.visible:
		context_menu.hide()
		return
	if unit_list != null:
		close_unit_list()
		return
	if details_drawer.visible:
		details_drawer.hide()
		return
	if not GameState.turn_manager.is_player_turn():
		return
	if busy:
		status.text = "이동 연출 중입니다. 완료 후 우클릭으로 이동을 취소할 수 있습니다."
		return
	if choosing_move:
		choosing_move = false
		menu_requested = true
		board.preview_path.clear()
		status.text = "이동 위치 선택을 취소했습니다. 행동을 다시 선택하세요."
		refresh()
		return
	if choosing_attack:
		choosing_attack = false
		menu_requested = true
		status.text = "공격 대상 선택을 취소했습니다. 행동을 다시 선택하세요."
		refresh()
		return
	if inspector != null:
		close_inspector()
		return
	if preview != null:
		remove_child(preview)
		preview.queue_free()
		preview = null
		pending_attacker = null
		pending_defender = null
		menu_requested = true
		status.text = "전투 진입을 취소했습니다. 부대 선택은 유지됩니다."
	elif GameState.pending_move_unit != null:
		menu_requested = false
		selected = GameState.cancel_pending_move()
		menu_requested = true
		command_unit = selected
		status.text = "이동을 취소하고 출발 위치로 돌아왔습니다. 다시 이동할 수 있습니다."
	else:
		menu_requested = false
		selected = null
		command_unit = null
		status.text = "선택을 취소했습니다. 아군 부대를 좌클릭하세요."
	board.preview_path.clear()
	refresh()

func current_attack_targets() -> Array[SquadMapUnit]:
	var targets: Array[SquadMapUnit] = []
	if selected == null or selected.enemy or not GameState.turn_manager.is_player_turn() or not GameState.can_unit_act(selected):
		return targets
	for unit in GameState.units:
		if unit.enemy != selected.enemy and PrototypeRules.hp_total(unit.squad) > 0 and HexCoord.distance(selected.coord.vector(), unit.coord.vector()) <= selected.attack_range and not GameState.attack_route(selected, unit).is_empty():
			targets.append(unit)
	return targets

func attack_selected() -> void:
	if busy or preview != null or inspector != null or current_attack_targets().is_empty():
		return
	choosing_move = false
	choosing_attack = true
	menu_requested = true
	status.text = "공격할 적을 좌클릭하세요. 우클릭/Esc는 행동 메뉴로 돌아갑니다."
	refresh()

func build_action_menu() -> void:
	action_menu = Panel.new()
	action_menu.name = "UnitActionMenu"
	action_menu.custom_minimum_size.x = MENU_WIDTH
	action_menu.z_index = 50
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.11, 0.98)
	style.border_color = Color(0.84, 0.68, 0.31)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	action_menu.add_theme_stylebox_override("panel", style)
	var commands := Control.new()
	commands.name = "Commands"
	commands.position = Vector2(10, 8)
	commands.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_menu.add_child(commands)
	action_title = UIHelpers.label(commands, "행동 선택", 16)
	action_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	action_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	action_title.clip_text = true
	action_title.size = Vector2(COMMAND_WIDTH, 24)
	move_button = UIHelpers.button(commands, "이동", move_selected)
	attack_button = UIHelpers.button(commands, "공격", attack_selected)
	info_button = UIHelpers.button(commands, "정보", info_selected)
	wait_button = UIHelpers.button(commands, "대기", wait_selected)
	var cancel_button := UIHelpers.button(commands, "취소", cancel_interaction)
	cancel_button.name = "CancelMove"
	for button in [move_button, attack_button, info_button, wait_button, cancel_button]:
		button.custom_minimum_size = Vector2(COMMAND_WIDTH, COMMAND_HEIGHT)
		button.size = Vector2(COMMAND_WIDTH, COMMAND_HEIGHT)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(action_menu)
	action_menu.hide()

func move_selected() -> void:
	if busy or preview != null or inspector != null or selected == null or selected.enemy or not GameState.can_unit_act(selected) or not selected.can_move():
		return
	choosing_move = true
	choosing_attack = false
	menu_requested = false
	status.text = "이동할 빈 타일을 선택하세요. 우클릭/Esc는 행동 메뉴로 돌아갑니다."
	refresh()

func info_selected() -> void:
	if busy or preview != null or inspector != null or selected == null or not GameState.turn_manager.is_player_turn():
		return
	choosing_move = false
	choosing_attack = false
	menu_requested = true
	open_inspector(selected)

func show_action_menu() -> void:
	if busy or preview != null or inspector != null or selected == null or not GameState.turn_manager.is_player_turn():
		return
	menu_requested = true
	choosing_attack = false
	choosing_move = false
	board.preview_path.clear()
	status.text = "이동·공격·정보·대기 중 행동을 선택하세요." if not selected.enemy else "정보 버튼으로 적 진형을 확인하세요."
	refresh()

func refresh_action_menu() -> void:
	var eligible := selected != null and GameState.units.has(selected) and GameState.turn_manager.is_player_turn()
	if not eligible:
		menu_requested = false
		choosing_attack = false
		choosing_move = false
	action_menu.visible = eligible and not busy and preview == null and inspector == null and not choosing_attack and not choosing_move and menu_requested
	var friendly := eligible and not selected.enemy
	move_button.visible = friendly
	move_button.disabled = not friendly or not GameState.can_unit_act(selected) or not selected.can_move()
	wait_button.visible = friendly
	attack_button.visible = friendly and not current_attack_targets().is_empty()
	info_button.disabled = not eligible
	action_title.text = selected.squad.squad_name if eligible else "행동 선택"
	# Resolve geometry immediately, before the first visible frame. No deferred container sorting.
	var next_y: float = 30.0
	for button in [move_button, attack_button, info_button, wait_button, action_menu.get_node("Commands/CancelMove")]:
		if button.visible:
			button.position = Vector2(0, next_y)
			button.size = Vector2(COMMAND_WIDTH, COMMAND_HEIGHT)
			next_y += COMMAND_HEIGHT + 6.0
	action_menu.size = Vector2(MENU_WIDTH, next_y + 12.0)
	action_menu.get_node("Commands").size = Vector2(COMMAND_WIDTH, next_y)
	if action_menu.visible:
		position_action_menu()

func position_action_menu() -> void:
	if selected == null:
		return
	var area := map_scroll.get_global_rect()
	area.position.y += 66
	area.size.y -= 110
	var anchor := board.get_global_transform() * board.center(selected.coord.vector())
	var extent := action_menu.size
	var destination := anchor + Vector2(48, -extent.y / 2)
	if destination.x + extent.x > area.end.x - 8:
		destination.x = anchor.x - extent.x - 48
	destination.x = clampf(destination.x, area.position.x + 8, maxf(area.position.x + 8, area.end.x - extent.x - 8))
	destination.y = clampf(destination.y, area.position.y + 8, maxf(area.position.y + 8, area.end.y - extent.y - 8))
	action_menu.position = (get_global_transform().affine_inverse() * destination).round()

func open_inspector(unit: SquadMapUnit) -> void:
	inspector = SquadInspector.new()
	inspector.unit = unit
	inspector.roster = GameState.formation.roster
	inspector.closed.connect(close_inspector)
	add_child(inspector)
	board.clear_hover()
	refresh()

func close_inspector() -> void:
	if inspector == null:
		return
	remove_child(inspector)
	inspector.queue_free()
	inspector = null
	status.text = "진형 확인을 닫았습니다. 부대 선택과 범위는 유지됩니다."
	refresh()

func open_preview(attacker: SquadMapUnit, defender: SquadMapUnit) -> void:
	pending_attacker = attacker
	pending_defender = defender
	preview = BattlePreview.new()
	preview.attacker = attacker
	preview.defender = defender
	preview.roster = GameState.formation.roster
	preview.confirmed.connect(confirm_attack)
	preview.cancelled.connect(cancel_interaction)
	add_child(preview)
	board.preview_path.clear()
	refresh()

func confirm_attack() -> void:
	if preview == null or busy or pending_attacker == null or pending_defender == null:
		return
	var attacker := pending_attacker
	var defender := pending_defender
	var route := GameState.attack_route(attacker, defender)
	if not attacker.can_act() or not GameState.units.has(defender) or route.is_empty():
		cancel_interaction()
		status.text = "상태가 변경되어 공격할 수 없습니다."
		return
	remove_child(preview)
	preview.queue_free()
	preview = null
	pending_attacker = null
	pending_defender = null
	move_unit(attacker, route, defender)

func move_unit(moving: SquadMapUnit, route: Array[Vector2i], occupant: SquadMapUnit) -> void:
	if occupant != null:
		GameState.commit_pending_move()
	elif route.size() > 1:
		GameState.begin_pending_move(moving)
	busy = true
	choosing_move = false
	choosing_attack = false
	action_menu.hide()
	end_button.disabled = true
	formation_button.disabled = true
	status.text = "경로를 따라 이동 중…"
	board.preview_path.clear()
	# Attack routes already terminate at a vacant hex in attack range.
	var steps: int = route.size() - 1
	for i in range(1, steps + 1):
		var view: SquadMapView = board.views[moving.id]
		var tween := create_tween()
		tween.tween_property(view, "position", board.center(route[i]), PrototypeRules.MOVE_STEP_SECONDS)
		await tween.finished
		moving.coord = HexCoord.from_vector(route[i])
	if steps > 0:
		moving.moved = true
	busy = false
	if occupant != null:
		GameState.request_battle(moving, occupant)
		return
	menu_requested = true
	status.text = "이동 후보. 공격/대기로 확정하거나 우클릭/Esc로 이동을 취소하세요."
	refresh()

func set_fit_view(enabled: bool) -> void:
	fit_view = enabled
	GameState.map_fit_view = enabled
	update_view()

func update_view() -> void:
	if board == null or map_scroll.size.x <= 0:
		return
	var logical: Vector2 = board.custom_minimum_size
	var usable := Vector2(map_scroll.size.x, maxf(1, map_scroll.size.y - 92))
	board_zoom = minf(usable.x / logical.x, usable.y / logical.y) if fit_view else 1.25
	board.scale = Vector2.ONE * board_zoom
	board.size = logical
	board_container.custom_minimum_size = logical * board_zoom
	board_container.size = map_scroll.size.max(board_container.custom_minimum_size)
	board.position = (usable - logical * board_zoom) / 2 + Vector2(0, 66) if fit_view else Vector2.ZERO
	if fit_view:
		map_scroll.scroll_horizontal = 0
		map_scroll.scroll_vertical = 0
	fit_button.text = "확대 보기" if fit_view else "전체 전장"
	if action_menu != null and action_menu.visible:
		position_action_menu()

func restore_scroll() -> void:
	if fit_view:
		return
	map_scroll.scroll_horizontal = GameState.map_scroll.x
	map_scroll.scroll_vertical = GameState.map_scroll.y

func _exit_tree() -> void:
	GameState.map_scroll = Vector2i(map_scroll.scroll_horizontal, map_scroll.scroll_vertical)

func focus_unit(unit: SquadMapUnit) -> void:
	focus_hex(unit.coord.vector())

func focus_hex(coord: Vector2i) -> void:
	if fit_view:
		return
	var point := board.center(coord) * board_zoom
	map_scroll.scroll_horizontal = maxi(0, int(point.x - map_scroll.size.x / 2))
	map_scroll.scroll_vertical = maxi(0, int(point.y - map_scroll.size.y / 2))

func _process(delta: float) -> void:
	if context_menu.visible or unit_list != null:
		board.clear_hover()
		pan_fraction = Vector2.ZERO
		return
	if details_drawer.visible:
		details_drawer.global_position = map_scroll.get_global_rect().position + Vector2(maxf(0, map_scroll.size.x - 350), 66)
		board.clear_hover()
		pan_fraction = Vector2.ZERO
		return
	if action_menu.visible:
		position_action_menu()
		board.clear_hover()
		pan_fraction = Vector2.ZERO
		return
	if preview != null or inspector != null:
		board.clear_hover()
		pan_fraction = Vector2.ZERO
		return
	var direction := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		direction.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		direction.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		direction.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		direction.y += 1
	if fit_view:
		direction = Vector2.ZERO
	var velocity := direction * 600
	var area := map_scroll.get_global_rect()
	if not fit_view and direction == Vector2.ZERO and not busy and GameState.turn_manager.is_player_turn() and area.has_point(pointer):
		var local := pointer - area.position
		if local.x < EDGE_MARGIN:
			direction.x = -1
		elif local.x > area.size.x - EDGE_MARGIN:
			direction.x = 1
		if local.y < EDGE_MARGIN:
			direction.y = -1
		elif local.y > area.size.y - EDGE_MARGIN:
			direction.y = 1
		velocity = direction.normalized() * EDGE_SPEED
	pan_fraction += velocity * delta
	var pixels := Vector2i(int(pan_fraction.x), int(pan_fraction.y))
	pan_fraction -= Vector2(pixels)
	map_scroll.scroll_horizontal += pixels.x
	map_scroll.scroll_vertical += pixels.y
	if area.has_point(pointer) and not busy:
		board.update_hover(board.get_global_transform().affine_inverse() * pointer)
	else:
		board.clear_hover()




func build_context_menu() -> void:
	context_menu = Panel.new()
	context_menu.name = "BattlefieldMenu"
	context_menu.z_index = 80
	context_menu.size = Vector2(200, 222)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.11, 0.98)
	style.border_color = Color(0.84, 0.68, 0.31)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	context_menu.add_theme_stylebox_override("panel", style)
	add_child(context_menu)
	var heading := UIHelpers.label(context_menu, "전장 메뉴", 16)
	heading.position = Vector2(10, 8)
	heading.size = Vector2(180, 24)
	context_end_button = UIHelpers.button(context_menu, "턴 종료", request_end_turn)
	var list_button := UIHelpers.button(context_menu, "부대 보기", open_unit_list)
	list_button.name = "UnitList"
	var help_button := UIHelpers.button(context_menu, "도움말", func(): context_menu.hide(); details_drawer.show())
	help_button.name = "Help"
	var close_button := UIHelpers.button(context_menu, "닫기", func(): context_menu.hide())
	for i in 4:
		var button: Button = [context_end_button, list_button, help_button, close_button][i]
		button.position = Vector2(10, 34 + i * 44)
		button.size = Vector2(180, 38)
	context_menu.hide()

func open_context_menu(at: Vector2) -> void:
	if busy or preview != null or inspector != null or unit_list != null or not GameState.turn_manager.is_player_turn():
		return
	context_end_button.disabled = not GameState.can_end_turn()
	var bounds := get_global_rect()
	var destination := Vector2(clampf(at.x, bounds.position.x + 8, bounds.end.x - context_menu.size.x - 8), clampf(at.y, bounds.position.y + 8, bounds.end.y - context_menu.size.y - 8))
	context_menu.global_position = destination.round()
	context_menu.show()
	board.clear_hover()

func request_end_turn() -> void:
	if busy or preview != null or inspector != null or unit_list != null or not GameState.can_end_turn():
		return
	context_menu.hide()
	menu_requested = false
	choosing_attack = false
	choosing_move = false
	selected = null
	command_unit = null
	GameState.end_turn()
	refresh()

func open_unit_list() -> void:
	if busy or preview != null or inspector != null or unit_list != null or not GameState.turn_manager.is_player_turn():
		return
	context_menu.hide()
	unit_list = PanelContainer.new()
	unit_list.name = "UnitListPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.11, 0.98)
	style.border_color = Color(0.84, 0.68, 0.31)
	style.set_border_width_all(2)
	style.set_content_margin_all(16)
	unit_list.add_theme_stylebox_override("panel", style)
	unit_list.z_index = 90
	unit_list.position = (size - Vector2(500, 530)) / 2
	unit_list.size = Vector2(500, 530)
	add_child(unit_list)
	var content := VBoxContainer.new()
	unit_list.add_child(content)
	UIHelpers.label(content, "전장 부대 · 선택하면 진형 확인", 22)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for unit in GameState.units:
		if PrototypeRules.hp_total(unit.squad) <= 0:
			continue
		var button := UIHelpers.button(rows, "%s · %s · HP %d · %s" % ["적" if unit.enemy else "아군", unit.squad.squad_name, PrototypeRules.hp_total(unit.squad), "행동 완료" if unit.acted else "행동 전"], func(): inspect_list_unit(unit))
		button.name = unit.id
		button.custom_minimum_size.y = 42
	UIHelpers.button(content, "닫기 · 우클릭 / Esc", close_unit_list)
	refresh()

func close_unit_list() -> void:
	if unit_list != null:
		remove_child(unit_list)
		unit_list.queue_free()
		unit_list = null
	refresh()

func inspect_list_unit(unit: SquadMapUnit) -> void:
	close_unit_list()
	if not GameState.units.has(unit):
		return
	selected = unit
	command_unit = unit if not unit.enemy else null
	focus_unit(unit)
	show_action_menu()
	info_selected()
