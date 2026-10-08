class_name FormationBoard
extends Control

signal slot_clicked(slot: FormationSlot)
signal member_selected(id: String)
signal remove_requested(id: String)
signal cancel_requested
signal ninja_dropped(id: String, slot: FormationSlot)
var manager: FormationManager
var selected_id: String = ""
var hovered: FormationSlot
var read_only: bool = false
var snapshot_squad: SquadData
var snapshot_roster: Dictionary = {}
var mirror_display: bool = false
var member_views: Dictionary = {}
const TILE := Vector2(150, 120)
const ORIGIN := Vector2(30, 50)

func _ready() -> void:
	custom_minimum_size = Vector2(510, 460)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func(): hovered = null; queue_redraw())
	sync_member_views()

func _process(_delta: float) -> void:
	sync_member_views()

func sync_member_views() -> void:
	var squad: SquadData = snapshot_squad if snapshot_squad != null else (manager.squad if manager != null else null)
	var roster: Dictionary = snapshot_roster if snapshot_squad != null else (manager.roster if manager != null else {})
	if squad == null:
		return
	var visible_ids: Dictionary = {}
	for id in squad.positions:
		if read_only and squad.current_hp.get(id, 0) <= 0:
			continue
		var ninja: NinjaData = roster[id]
		var profile_id := ninja.sprite_profile_id if not ninja.sprite_profile_id.is_empty() else ninja.id
		if SpriteLibrary.profile(profile_id).is_empty():
			continue
		visible_ids[id] = true
		if not member_views.has(id):
			var view := CharacterBattleView.new(ninja, squad)
			view.show_status = false
			view.presentation_scale = 0.8
			view.faces_right = not mirror_display
			view.displayed_hp = int(squad.current_hp.get(id, ninja.test_stats().hp)) if read_only else int(ninja.test_stats().hp)
			add_child(view)
			member_views[id] = view
		var view: CharacterBattleView = member_views[id]
		var rect := slot_rect(squad.positions[id]).grow(-10)
		view.position = rect.position + Vector2(rect.size.x / 2.0 - CharacterBattleView.GROUND.x, -6)
		view.home = view.position
		view.z_index = 0 # Keep sprites inside the modal/editor canvas layer.
		view.displayed_hp = int(squad.current_hp.get(id, ninja.test_stats().hp)) if read_only else int(ninja.test_stats().hp)
		view.faces_right = not mirror_display
		view.play_state("idle")
	for id in member_views.keys():
		if not visible_ids.has(id):
			remove_child(member_views[id])
			member_views[id].queue_free()
			member_views.erase(id)

	var depth_order: Array = member_views.keys()
	depth_order.sort_custom(func(a, b): return squad.positions[a].row_offset < squad.positions[b].row_offset)
	for id in depth_order:
		move_child(member_views[id], -1)

func slot_rect(slot: FormationSlot) -> Rect2:
	var column: int = 2 - slot.column if mirror_display else slot.column
	return Rect2(ORIGIN + Vector2(column * TILE.x, slot.row_offset * TILE.y), TILE)

func slot_at(point: Vector2) -> FormationSlot:
	var relative := point - ORIGIN
	if relative.x < 0 or relative.x >= TILE.x * 3 or relative.y < 0 or relative.y >= TILE.y * 3:
		return null
	var offset := clampf(roundf((relative.y / TILE.y - 0.5) * 2.0) / 2.0, 0.0, 2.0)
	return FormationSlot.new(int(relative.x / TILE.x), offset)

func _gui_input(event: InputEvent) -> void:
	if read_only:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel_requested.emit()
		accept_event()
		return
	if event is InputEventMouseMotion:
		hovered = slot_at(event.position)
		queue_redraw()
	if event is InputEventMouseButton and event.pressed:
		var slot := slot_at(event.position)
		if slot == null:
			return
		var id := manager.squad.occupant(slot)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if id != "":
				member_selected.emit(id)
			else:
				slot_clicked.emit(slot)
		accept_event()

func _get_drag_data(at_position: Vector2) -> Variant:
	if read_only:
		return null
	var slot := slot_at(at_position)
	if slot == null:
		return null
	var id := manager.squad.occupant(slot)
	if id == "":
		return null
	var preview := Label.new()
	preview.text = manager.roster[id].display_name
	set_drag_preview(preview)
	member_selected.emit(id)
	return {"ninja_id": id}

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return not read_only and data is Dictionary and data.has("ninja_id") and slot_at(at_position) != null

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if read_only:
		return
	ninja_dropped.emit(data.ninja_id, slot_at(at_position))

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for col in 3:
		draw_string(font, ORIGIN + Vector2((2 - col if mirror_display else col) * TILE.x + 55, -18), ["후열", "중열", "전열"][col], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
		for row in 3:
			var rect := slot_rect(FormationSlot.new(col, float(row)))
			draw_rect(rect.grow(-3), Color(0.09, 0.14, 0.22), true)
			draw_rect(rect.grow(-3), Color(0.35, 0.46, 0.60), false, 2)
		for half in [0.5, 1.5]:
			var center := slot_rect(FormationSlot.new(col, half)).get_center()
			draw_circle(center, 5, Color(0.55, 0.72, 0.88, 0.5))
	var squad: SquadData = snapshot_squad if snapshot_squad != null else (manager.squad if manager != null else null)
	var roster: Dictionary = snapshot_roster if snapshot_squad != null else (manager.roster if manager != null else {})
	if squad == null:
		return
	for id in squad.positions:
		if read_only and squad.current_hp.get(id, 0) <= 0:
			continue
		var slot: FormationSlot = squad.positions[id]
		var ninja: NinjaData = roster[id]
		var rect := slot_rect(slot).grow(-10)
		# Every card has the same dimensions, including half-row placements.
		# Outlines keep overlapping full-size regions visible; labels use their own upper band.
		var fill := ninja.color
		fill.a = 0.22
		draw_rect(rect, fill)
		draw_rect(rect, ninja.color, false, 2)
		var title: String = ninja.display_name + (" ★" if id == squad.leader_id else "")
		if member_views.has(id):
			draw_string(font, rect.position + Vector2(0, 91), title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 14, Color.WHITE)
			if read_only:
				draw_string(font, rect.position + Vector2(0, 107), "HP %d/%d · %s" % [squad.current_hp.get(id, 0), ninja.test_stats().hp, NinjaData.class_label(ninja.class_type)], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 10, Color(0.75, 0.85, 0.95))
		else:
			# Unmapped characters retain their readable card fallback.
			draw_string(font, rect.position + Vector2(8, 24), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		if id == selected_id:
			draw_rect(rect.grow(2), Color(1, 0.84, 0.36), false, 3)
	if hovered != null:
		var rect := slot_rect(hovered).grow(-5)
		draw_rect(rect, Color(0.7, 0.85, 1, 0.1))
		draw_rect(rect, Color(0.75, 0.89, 1), false, 2)
		draw_string(font, Vector2(30, 443), "후보 좌표: 열 %d / 높이 %.1f" % [hovered.column, hovered.row_offset], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.7, 0.85, 1))
