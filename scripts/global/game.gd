extends Control

var active_screen: Control
var transitioning: bool = false
var curtain: ColorRect

func _ready() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = ThemeDB.fallback_font
	ui_theme.default_font_size = 16
	theme = ui_theme
	GameState.battle_requested.connect(show_battle)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	curtain = ColorRect.new()
	curtain.color = Color(0.02, 0.03, 0.05)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	curtain.visible = false
	layer.add_child(curtain)
	var screen := set_screen("res://scenes/battle_map.tscn")
	screen.formation_requested.connect(show_formation)
	GameState.enemy_controller.resume(screen)

func set_screen(path: String) -> Control:
	if active_screen != null:
		remove_child(active_screen)
		active_screen.queue_free()
	active_screen = load(path).instantiate()
	add_child(active_screen)
	return active_screen

func show_map() -> void:
	change_screen("res://scenes/battle_map.tscn")

func show_formation() -> void:
	change_screen("res://scenes/main.tscn")

func show_battle() -> void:
	change_screen("res://scenes/battle.tscn")

func change_screen(path: String) -> void:
	if transitioning:
		return
	transitioning = true
	active_screen.set_process_input(false)
	curtain.modulate.a = 0.0
	curtain.visible = true
	var fade_out := create_tween()
	fade_out.tween_property(curtain, "modulate:a", 1.0, PrototypeRules.TRANSITION_SECONDS)
	await fade_out.finished
	var screen := set_screen(path)
	screen.set_process_input(false)
	if path.ends_with("battle_map.tscn"):
		screen.formation_requested.connect(show_formation)
	elif path.ends_with("main.tscn"):
		screen.map_requested.connect(show_map)
	else:
		screen.return_requested.connect(show_map)
	var fade_in := create_tween()
	fade_in.tween_property(curtain, "modulate:a", 0.0, PrototypeRules.TRANSITION_SECONDS)
	await fade_in.finished
	curtain.visible = false
	screen.set_process_input(true)
	transitioning = false
	if path.ends_with("battle_map.tscn"):
		GameState.enemy_controller.resume(screen)

func _input(event: InputEvent) -> void:
	if transitioning and (event is InputEventMouseButton or event is InputEventKey):
		get_viewport().set_input_as_handled()
