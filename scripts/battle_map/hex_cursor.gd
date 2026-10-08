class_name HexCursor
extends Control

var elapsed: float = 0.0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	var points: Array[Vector2] = []
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 30.0)
		points.append(Vector2(cos(angle), sin(angle)) * (PrototypeRules.HEX_RADIUS - 1))
	var color := Color(1, 0.83, 0.25, 0.85 + 0.15 * sin(elapsed * 4.0))
	for i in 6:
		var vertex := points[i]
		var a := vertex.lerp(points[(i + 5) % 6], 0.25)
		var b := vertex.lerp(points[(i + 1) % 6], 0.25)
		var bracket := PackedVector2Array([a, vertex, b])
		draw_polyline(bracket, Color(0.04, 0.04, 0.04, 0.9), 6, true)
		draw_polyline(bracket, color, 3, true)
