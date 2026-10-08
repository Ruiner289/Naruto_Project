class_name HexBoard
extends Control

signal hex_clicked(coord: Vector2i)
signal hex_hovered(coord: Vector2i)
signal hover_cleared
const ORIGIN := Vector2(55, 52)
var selected: SquadMapUnit
var search: Dictionary = {"costs": {}, "previous": {}}
var views: Dictionary = {}
var hovered: Vector2i = Vector2i(-100, -100)
var preview_path: Array[Vector2i] = []
var attack_tiles: Dictionary = {}
var cursor: HexCursor

func _ready() -> void:
	custom_minimum_size = Vector2(ORIGIN.x + (GameState.grid.width + 0.5) * sqrt(3.0) * PrototypeRules.HEX_RADIUS, ORIGIN.y + (GameState.grid.height - 1) * 1.5 * PrototypeRules.HEX_RADIUS + PrototypeRules.HEX_RADIUS + 15)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	rebuild_units()
	cursor = HexCursor.new()
	cursor.visible = false
	add_child(cursor)
	mouse_exited.connect(clear_hover)

func center(coord: Vector2i) -> Vector2:
	return ORIGIN + HexCoord.to_pixel(coord, PrototypeRules.HEX_RADIUS)

func polygon(coord: Vector2i, radius: float = PrototypeRules.HEX_RADIUS - 2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 30.0)
		points.append(center(coord) + Vector2(cos(angle), sin(angle)) * radius)
	return points

func rebuild_units() -> void:
	for child in get_children():
		if not child is SquadMapView:
			continue
		remove_child(child)
		child.queue_free()
	views.clear()
	for unit in GameState.units:
		if PrototypeRules.hp_total(unit.squad) <= 0:
			continue
		var view := SquadMapView.new(unit, GameState.formation.roster)
		view.position = center(unit.coord.vector())
		view.selected = unit == selected
		add_child(view)
		views[unit.id] = view
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		update_hover(event.position)
		var coord := hovered
		if not GameState.grid.tiles.has(coord):
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			hex_clicked.emit(coord)
			accept_event()

func update_hover(local_point: Vector2) -> void:
	var coord := HexCoord.from_pixel(local_point - ORIGIN, PrototypeRules.HEX_RADIUS)
	if not GameState.grid.tiles.has(coord):
		clear_hover()
		return
	if coord != hovered:
		hovered = coord
		hex_hovered.emit(coord)
	if is_instance_valid(cursor):
		cursor.position = center(coord)
		cursor.visible = true
	queue_redraw()

func clear_hover() -> void:
	preview_path.clear()
	if is_instance_valid(cursor):
		cursor.visible = false
	if hovered != Vector2i(-100, -100):
		hovered = Vector2i(-100, -100)
		hover_cleared.emit()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.17, 0.13))
	# Environment is visual only: no tile/occupancy/path mutation.
	for coord in GameState.grid.tiles:
		draw_texture_rect(EnvironmentArt.tile_texture(GameState.grid, coord), Rect2(center(coord) - Vector2(32, 37), Vector2(64, 74)), false)
		var line := polygon(coord, 35)
		line.append(line[0])
		draw_polyline(line, Color(0.23, 0.26, 0.18, 0.7), 1)
	for coord in GameState.grid.tiles:
		var prop: String = EnvironmentArt.prop_for(GameState.grid, coord)
		if not prop.is_empty():
			var dimensions := Vector2(40, 55) if prop.begins_with("tree") or prop == "dead_tree" else Vector2(48, 26)
			draw_texture_rect(EnvironmentArt.texture(prop), Rect2(center(coord) - Vector2(dimensions.x / 2, dimensions.y - 18), dimensions), false)
	for point in GameState.control_points:
		if not GameState.grid.tiles.has(point.hex_coord):
			continue
		var building: String = "outpost" if point.owner == ControlPointData.Owner.NEUTRAL else ("village_house" if point.owner == ControlPointData.Owner.PLAYER else "village_shop")
		draw_texture_rect(EnvironmentArt.texture(building), Rect2(center(point.hex_coord) - Vector2(30, 19), Vector2(60, 32)), false)
	# Range tint stays above scenery and below units/cursor/menu.
	for coord in GameState.grid.tiles:
		var overlay := Color.TRANSPARENT
		if attack_tiles.has(coord):
			overlay = Color(0.86, 0.15, 0.18, 0.46)
		if search.costs.has(coord):
			overlay = Color(0.08, 0.53, 0.8, 0.47)
		if selected != null and selected.coord.vector() == coord:
			overlay = Color(1.0, 0.74, 0.16, 0.48)
		if overlay.a > 0:
			draw_colored_polygon(polygon(coord, 35), overlay)
			var border := polygon(coord, 35)
			border.append(border[0])
			draw_polyline(border, Color(overlay, 0.85), 1.5)
		if search.costs.has(coord) and search.get("zoc", {}).has(coord):
			var border := polygon(coord, 35)
			border.append(border[0])
			draw_polyline(border, Color(1, 0.58, 0.2), 2)
	for point in GameState.control_points:
		var at := center(point.hex_coord)
		var color: Color = [Color(0.3, 0.65, 1), Color(1, 0.3, 0.35), Color(0.7, 0.7, 0.75)][point.owner]
		draw_line(at + Vector2(-8, -18), at + Vector2(-8, 10), color, 3)
		draw_colored_polygon(PackedVector2Array([at + Vector2(-8, -18), at + Vector2(12, -12), at + Vector2(-8, -6)]), color)
		draw_string(ThemeDB.fallback_font, at + Vector2(-26, 25), point.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)
	if preview_path.size() > 1:
		var line := PackedVector2Array()
		for coord in preview_path:
			line.append(center(coord))
			draw_circle(center(coord), 5, Color(1, 0.85, 0.35))
			var costs: Dictionary = search.get("traversal_costs", search.costs)
			if costs.has(coord):
				draw_string(ThemeDB.fallback_font, center(coord) + Vector2(7, -9), str(costs[coord]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.9, 0.4))
		draw_polyline(line, Color(1, 0.85, 0.35), 3, true)
		draw_arc(center(preview_path.back()), 12, 0, TAU, 24, Color(1, 0.9, 0.5), 3)
