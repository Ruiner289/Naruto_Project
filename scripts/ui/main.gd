extends Control

signal map_requested

const RosterButton = preload("res://scripts/ui/roster_button.gd")
var manager := FormationManager.new()
var selected_id: String = "kakashi"
var board: FormationBoard
var info: Label
var selection: Label
var status: Label
var list: VBoxContainer
var name_input: LineEdit

func _ready() -> void:
	manager = GameState.formation
	selected_id = manager.squad.leader_id
	# Windows' Korean system font is used when available; no copyrighted graphics are bundled.
	var korean_font := SystemFont.new()
	korean_font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "sans-serif"])
	var ui_theme := Theme.new()
	ui_theme.default_font = korean_font
	ui_theme.default_font_size = 16
	theme = ui_theme
	ThemeDB.fallback_font = korean_font
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)
	var title := Label.new()
	title.text = "닌자 부대 편성  /  첫 시제품"
	title.add_theme_font_size_override("font_size", 28)
	var header := HBoxContainer.new()
	root.add_child(header)
	header.add_child(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_button(header, "헥스 전장으로", func(): PrototypeRules.ensure_hp(manager.squad, manager.roster); map_requested.emit())
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	root.add_child(columns)
	var roster_column := VBoxContainer.new()
	roster_column.custom_minimum_size.x = 250
	columns.add_child(roster_column)
	add_label(roster_column, "캐릭터 목록 · 클릭 / 드래그")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_column.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var center := VBoxContainer.new()
	columns.add_child(center)
	add_label(center, "후열 → 중열 → 전열 → 적")
	board = FormationBoard.new()
	board.manager = manager
	center.add_child(board)
	board.slot_clicked.connect(func(slot: FormationSlot): show_result(manager.place(selected_id, slot), "배치했습니다."))
	board.member_selected.connect(select_ninja)
	board.remove_requested.connect(func(id: String): show_result(manager.remove(id), "제거했습니다."))
	board.cancel_requested.connect(cancel_selection)
	board.ninja_dropped.connect(func(id: String, slot: FormationSlot): selected_id = id; show_result(manager.place(id, slot), "배치했습니다."))
	add_label(center, "큰 타일 9개 + 경계의 작은 점 6개\n반칸도 같은 크기 · 같은 열에서는 카드 영역이 겹칠 수 있습니다.")
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size.x = 300
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)
	add_label(right, "현재 부대")
	name_input = LineEdit.new()
	name_input.text = manager.squad.squad_name
	name_input.text_changed.connect(func(value: String): manager.squad.squad_name = value; refresh())
	right.add_child(name_input)
	info = add_label(right, "")
	selection = add_label(right, "")
	add_button(right, "선택한 멤버를 부대장으로", func(): show_result(manager.set_leader(selected_id), "부대장을 변경했습니다."))
	add_button(right, "기존 부대장과 교체", func(): show_result(manager.replace_leader(selected_id), "기존 부대장을 제외하고 교체했습니다."))
	add_label(right, "교체: 기존 부대장은 부대에서 제외됩니다.\n새 부대장이 미편성이면 기존 위치를 사용합니다.")
	add_button(right, "선택한 캐릭터 제거", func(): show_result(manager.remove(selected_id), "제거했습니다."))
	add_button(right, "JSON 저장", func(): show_result(manager.save_json(), "user://squad.json에 저장했습니다."))
	add_button(right, "JSON 불러오기", func(): show_result(manager.load_json(), "불러왔습니다."); name_input.text = manager.squad.squad_name)
	add_label(right, "조작\n좌클릭: 선택 → 빈 후보에 배치\n우클릭 / Esc: 선택·드래그 취소\n제거: 오른쪽 제거 버튼\n반칸 후보: 타일 경계의 점")
	status = add_label(root, "캐릭터를 선택하고 진형의 빈 위치를 클릭하세요.")
	status.custom_minimum_size.y = 48
	manager.changed.connect(refresh)
	manager.changed.connect(func(): PrototypeRules.ensure_hp(manager.squad, manager.roster))
	refresh()

func add_label(parent: Node, value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func add_button(parent: Node, value: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = value
	button.pressed.connect(callback)
	parent.add_child(button)

func select_ninja(id: String) -> void:
	selected_id = id
	refresh()

func cancel_selection() -> void:
	if get_viewport().gui_is_dragging():
		get_viewport().gui_cancel_drag()
	selected_id = ""
	status.text = "선택을 취소했습니다. 캐릭터를 다시 선택하세요."
	refresh()

func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT) or event.is_action_pressed("ui_cancel"):
		cancel_selection()
		get_viewport().set_input_as_handled()

func show_result(error: String, success: String) -> void:
	status.text = success if error.is_empty() else error
	status.modulate = Color(0.65, 0.95, 0.78) if error.is_empty() else Color(1, 0.68, 0.56)
	refresh()

func refresh() -> void:
	if info == null:
		return
	var leader: NinjaData = manager.roster[manager.squad.leader_id]
	info.text = "부대장: %s\n계급: %s\n편성 인원: %d / 9" % [leader.display_name, NinjaRank.label(leader.rank), manager.squad.positions.size()]
	if manager.roster.has(selected_id):
		var ninja: NinjaData = manager.roster[selected_id]
		selection.text = "선택: %s · %s" % [ninja.display_name, NinjaRank.label(ninja.rank)]
	else:
		selection.text = "선택 없음 · 좌클릭으로 선택"
	if manager.squad.positions.has(selected_id):
		var slot: FormationSlot = manager.squad.positions[selected_id]
		selection.text += "\n논리 좌표: column=%d, row_offset=%.1f" % [slot.column, slot.row_offset]
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for id in manager.roster:
		var member: NinjaData = manager.roster[id]
		if member.battlefield_only:
			continue
		var button := RosterButton.new()
		button.ninja_id = id
		button.text = "%s  ·  %s%s" % [member.display_name, NinjaRank.label(member.rank), "  ✓" if manager.squad.positions.has(id) else ""]
		var profile_id := member.sprite_profile_id if not member.sprite_profile_id.is_empty() else member.id
		var profile := SpriteLibrary.profile(profile_id)
		if not profile.is_empty():
			var texture: Texture2D = profile.sprite_frames.get_frame_texture("idle", 0)
			var portrait := AtlasTexture.new()
			portrait.atlas = texture
			portrait.region = texture.get_image().get_used_rect()
			button.icon = portrait
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 30)
			button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.toggle_mode = true
		button.button_pressed = id == selected_id
		button.custom_minimum_size.y = 40
		button.pressed.connect(select_ninja.bind(id))
		list.add_child(button)
	board.selected_id = selected_id
	board.queue_redraw()
