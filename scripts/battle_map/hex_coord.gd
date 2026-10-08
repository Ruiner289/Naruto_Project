class_name HexCoord
extends RefCounted

var q: int
var r: int
const DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]

func _init(p_q: int = 0, p_r: int = 0) -> void:
	q = p_q
	r = p_r

func vector() -> Vector2i:
	return Vector2i(q, r)

static func from_vector(value: Vector2i) -> HexCoord:
	return HexCoord.new(value.x, value.y)

static func from_offset(column: int, row: int) -> HexCoord:
	return HexCoord.new(column - floori(float(row) / 2.0), row)

static func distance(a: Vector2i, b: Vector2i) -> int:
	var delta := a - b
	return maxi(maxi(absi(delta.x), absi(delta.y)), absi(delta.x + delta.y))

static func to_pixel(value: Vector2i, radius: float) -> Vector2:
	return Vector2(sqrt(3.0) * radius * (value.x + value.y / 2.0), radius * 1.5 * value.y)

static func from_pixel(point: Vector2, radius: float) -> Vector2i:
	var fractional_q: float = (sqrt(3.0) / 3.0 * point.x - point.y / 3.0) / radius
	var fractional_r: float = 2.0 / 3.0 * point.y / radius
	var fractional_s: float = -fractional_q - fractional_r
	var rounded_q := roundi(fractional_q)
	var rounded_r := roundi(fractional_r)
	var rounded_s := roundi(fractional_s)
	var q_error := absf(rounded_q - fractional_q)
	var r_error := absf(rounded_r - fractional_r)
	var s_error := absf(rounded_s - fractional_s)
	if q_error > r_error and q_error > s_error:
		rounded_q = -rounded_r - rounded_s
	elif r_error > s_error:
		rounded_r = -rounded_q - rounded_s
	return Vector2i(rounded_q, rounded_r)
