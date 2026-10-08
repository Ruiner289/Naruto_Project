class_name BattleStage
extends Control

var context: BattleContext
var roster: Dictionary
var views: Dictionary = {}
const PITCH := Vector2(76, 32)
const ALLY_ORIGIN := Vector2(210, 246)
const ENEMY_ORIGIN := Vector2(660, 246)

func _ready() -> void:
	custom_minimum_size = Vector2(1100, 450)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	resized.connect(layout_views)
	for side in 2:
		var squad: SquadData = context.attacker if side == 0 else context.defender
		for id in squad.positions:
			if squad.current_hp.get(id, 0) <= 0:
				continue # Earlier casualties stay hidden; new casualties keep this encounter's view.
			var view := CharacterBattleView.new(roster[id], squad)
			view.compact_status = true
			view.position = position_for(squad.positions[id], side)
			view.z_index = int(squad.positions[id].row_offset * 10)
			view.home_z_index = view.z_index
			view.home = view.position
			view.faces_right = is_left(side)
			view.displayed_hp = squad.current_hp[id]
			add_child(view)
			views[key(side, id)] = view

static func key(side: int, id: String) -> String:
	return "%d:%s" % [side, id]

func position_for(slot: FormationSlot, side: int) -> Vector2:
	var left := is_left(side)
	var origin := ALLY_ORIGIN if left else ENEMY_ORIGIN
	var display_column: int = slot.column if left else 2 - slot.column
	return origin + Vector2(maxf(0, size.x - 1100) / 2 + display_column * PITCH.x + (slot.row_offset - 1.0) * (10 if left else -10), maxf(0, size.y - 450) * 2.0 / 3.0 + slot.row_offset * PITCH.y)

func layout_views() -> void:
	if context == null:
		return
	for side in 2:
		var squad: SquadData = context.attacker if side == 0 else context.defender
		for id in squad.positions:
			var view: CharacterBattleView = views.get(key(side, id))
			if view == null:
				continue
			view.home = position_for(squad.positions[id], side)
			if view.visual_state == "idle":
				view.position = view.home

func is_left(side: int) -> bool:
	var unit := context.attacker_unit if side == 0 else context.defender_unit
	return not unit.enemy

func refresh_hp() -> void:
	for view in views.values():
		view.displayed_hp = view.squad.current_hp[view.ninja.id]
		view.sync_sprite()
		view.queue_redraw()

func _draw() -> void:
	if context != null:
		draw_texture_rect(EnvironmentArt.backdrop(context, get_node("/root/GameState").grid), Rect2(Vector2.ZERO, Vector2(maxf(1100, size.x), maxf(450, size.y))), false)
		draw_rect(Rect2(Vector2.ZERO, Vector2(maxf(1100, size.x), maxf(450, size.y))), Color(0.02, 0.045, 0.045, 0.34))
		draw_rect(Rect2(Vector2.ZERO, Vector2(maxf(1100, size.x), 66)), Color(0.025, 0.04, 0.045, 0.76))
	var font := ThemeDB.fallback_font
	for side in 2:
		var squad: SquadData = context.attacker if side == 0 else context.defender
		var unit: SquadMapUnit = context.attacker_unit if side == 0 else context.defender_unit
		var at := Vector2((190 if is_left(side) else 740) + maxf(0, size.x - 1100) / 2, 34)
		draw_string(font, at, ("공격측 · " if side == 0 else "방어측 · ") + squad.squad_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(1, 0.5, 0.5) if unit.enemy else Color(0.5, 0.78, 1))
