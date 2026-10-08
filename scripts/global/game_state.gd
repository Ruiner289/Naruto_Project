extends Node

signal battle_requested
signal map_changed
var formation := FormationManager.new()
var grid := BattlefieldSetup.create_grid()
var control_points: Array[ControlPointData] = BattlefieldSetup.control_points()
var turn_manager := TurnManager.new()
var enemy_controller: EnemyTurnController
var map_fit_view: bool = true
var map_scroll := Vector2i.ZERO
var units: Array[SquadMapUnit] = []
var battle: BattleContext
var pending_move_unit: SquadMapUnit
var pending_move_origin: HexCoord

var turn: int:
	get:
		return turn_manager.turn_number
var combat_started: bool = false
var startup_message: String = ""

func begin_pending_move(unit: SquadMapUnit) -> void:
	if unit.enemy or not turn_manager.is_player_turn():
		return
	if pending_move_unit != null:
		cancel_pending_move()
	pending_move_unit = unit
	pending_move_origin = HexCoord.from_vector(unit.coord.vector())

func commit_pending_move() -> void:
	pending_move_unit = null
	pending_move_origin = null

func cancel_pending_move() -> SquadMapUnit:
	var unit := pending_move_unit
	if unit != null and units.has(unit) and unit.can_act() and turn_manager.is_player_turn() and battle == null:
		unit.coord = HexCoord.from_vector(pending_move_origin.vector())
		unit.moved = false
	commit_pending_move()
	return unit

func _ready() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "sans-serif"])
	ThemeDB.fallback_font = font
	startup_message = SpriteDeployment.prepare(formation)
	PrototypeRules.ensure_hp(formation.squad, formation.roster)
	units.append(SquadMapUnit.new("player", formation.squad, HexCoord.from_offset(2, 2), false))
	var slots := [Vector2(2, 0), Vector2(2, 2), Vector2(1, 0.5), Vector2(0, 1.5)]
	units.append(SquadMapUnit.new("ally2", make_squad("아스마반", ["asuma", "choji", "shikamaru", "ino"], slots), HexCoord.from_offset(3, 6), false))
	units.append(SquadMapUnit.new("enemy1", GenericFactory.make_squad(formation.roster, "enemy1", ["big_sound", "claw", "dart", "pole"], "적 선봉"), HexCoord.from_offset(16, 2), true))
	units.append(SquadMapUnit.new("enemy2", GenericFactory.make_squad(formation.roster, "enemy2", ["pole", "flail", "scythe", "dart"], "적 예비"), HexCoord.from_offset(16, 6), true))
	# Four squads per faction; keep the formation-owned primary squad object.
	units.append(SquadMapUnit.new("ally3", make_squad("쿠레나이반", ["kurenai", "kiba", "hinata", "shino"], slots), HexCoord.from_offset(2, 4), false))
	units.append(SquadMapUnit.new("enemy3", GenericFactory.make_squad(formation.roster, "enemy3", ["big_sound", "dart", "claw", "scythe"], "적 제3부대"), HexCoord.from_offset(16, 4), true))
	units.append(SquadMapUnit.new("ally4", make_squad("가이반", ["guy", "lee", "neji", "tenten"], slots), HexCoord.from_offset(3, 10), false))
	units.append(SquadMapUnit.new("enemy4", GenericFactory.make_squad(formation.roster, "enemy4", ["pole", "flail", "scythe", "dart"], "적 제4부대"), HexCoord.from_offset(17, 10), true))
	enemy_controller = EnemyTurnController.new()
	enemy_controller.state = self
	add_child(enemy_controller)

func make_squad(title: String, ids: Array, slots: Array) -> SquadData:
	var squad := SquadData.new()
	squad.squad_name = title
	squad.leader_id = ids[0]
	for i in ids.size():
		squad.positions[ids[i]] = FormationSlot.new(int(slots[i].x), slots[i].y)
	PrototypeRules.ensure_hp(squad, formation.roster)
	return squad

func unit_at(coord: Vector2i) -> SquadMapUnit:
	for unit in units:
		if unit.coord.vector() == coord and PrototypeRules.hp_total(unit.squad) > 0:
			return unit
	return null

func can_unit_act(unit: SquadMapUnit) -> bool:
	return battle == null and units.has(unit) and unit.can_act() and unit.enemy == (not turn_manager.is_player_turn())

func search_for(unit: SquadMapUnit, full_map: bool = false, inspection: bool = false) -> Dictionary:
	var blocked: Dictionary = {}
	var friendly: Dictionary = {}
	var zoc: Dictionary = {}
	for other in units:
		if other == unit or PrototypeRules.hp_total(other.squad) <= 0:
			continue
		if other.enemy == unit.enemy:
			friendly[other.coord.vector()] = true
		else:
			blocked[other.coord.vector()] = true
			for direction in HexCoord.DIRECTIONS:
				zoc[other.coord.vector() + direction] = true
	var budget: int = grid.full_search_budget() if full_map else (unit.movement if can_unit_act(unit) and unit.can_move() else 0)
	if inspection and PrototypeRules.hp_total(unit.squad) > 0:
		budget = unit.movement
	var search := grid.reachable(unit.coord.vector(), budget, blocked, {}, zoc)
	# Friendly tiles are traversal nodes, never destinations or attack positions.
	search["traversal_costs"] = search.costs.duplicate()
	search["zoc"] = zoc
	for tile in friendly:
		search.costs.erase(tile)
	return search

func attack_area(unit: SquadMapUnit, search: Dictionary, inspection: bool = false) -> Dictionary:
	var result: Dictionary = {}
	if (not inspection and not can_unit_act(unit)) or PrototypeRules.hp_total(unit.squad) <= 0:
		return result
	for destination in search.costs:
		for tile in grid.tiles:
			if grid.is_passable(tile) and tile != destination and HexCoord.distance(destination, tile) <= unit.attack_range:
				result[tile] = true
	return result

func attack_route(unit: SquadMapUnit, defender: SquadMapUnit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not can_unit_act(unit) or defender.enemy == unit.enemy or not units.has(defender) or PrototypeRules.hp_total(defender.squad) <= 0:
		return result
	var search := search_for(unit)
	return route_to_attack(unit, defender, search)

func route_to_attack(unit: SquadMapUnit, defender: SquadMapUnit, search: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var candidates: Array[Vector2i] = []
	for tile in search.costs:
		if HexCoord.distance(tile, defender.coord.vector()) <= unit.attack_range:
			candidates.append(tile)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if search.costs[a] != search.costs[b]:
			return search.costs[a] < search.costs[b]
		return a.x < b.x if a.x != b.x else a.y < b.y)
	if not candidates.is_empty():
		result = grid.path(unit.coord.vector(), candidates[0], search)
	return result

func request_battle(attacker: SquadMapUnit, defender: SquadMapUnit, origin: HexCoord = null) -> void:
	if attack_route(attacker, defender).size() != 1:
		return
	battle = BattleContext.new(attacker, defender)
	commit_pending_move()
	if origin != null:
		battle.attacker_origin = origin
	attacker.acted = true
	combat_started = true
	battle_requested.emit()

func apply_battle_result() -> void:
	if battle == null:
		return
	# Every outcome keeps the tile from which the attack was launched, after approach.
	# Victory removes the defender without granting an additional move into its tile.
	battle.attacker_unit.coord = HexCoord.from_vector(battle.attacker_origin.vector())
	for unit in [battle.attacker_unit, battle.defender_unit]:
		if PrototypeRules.hp_total(unit.squad) <= 0:
			units.erase(unit)
	battle = null
	map_changed.emit()

func can_end_turn() -> bool:
	var active_map: Control = enemy_controller.map
	return battle == null and turn_manager.is_player_turn() and not enemy_controller.running and (not is_instance_valid(active_map) or (not active_map.busy and active_map.preview == null and active_map.inspector == null))

func end_turn() -> void:
	if not can_end_turn():
		return
	commit_pending_move()
	turn_manager.end_player(units)
	map_changed.emit()
	enemy_controller.begin()

func heal_all() -> void:
	for unit in units:
		for id in unit.squad.positions:
			unit.squad.current_hp[id] = formation.roster[id].test_stats().hp
	map_changed.emit()


func toggle_fullscreen() -> void:
	var current := DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if current == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
