class_name CharacterBattleView
extends Control

# Presentation only; resolver and formation data remain authoritative.
var ninja: NinjaData
var squad: SquadData
var home_z_index: int = 0
var home: Vector2
var emphasized: bool = false
var damage_text: String = ""
var displayed_hp: int = -1
var hit_flash: bool = false
var heal_flash: bool = false
var action_marker: String = ""
var compact_status: bool = false
var show_status: bool = true
var presentation_scale: float = 1.0
var sprite: AnimatedSprite2D
var sprite_profile: Dictionary = {}
var faces_right: bool = true
var visual_state: String = "idle"
var loop_phases: Dictionary = {}
const GROUND := Vector2(48, 78)
const CARD_SIZE := Vector2(96, 88)

func _init(p_ninja: NinjaData, p_squad: SquadData) -> void:
	ninja = p_ninja
	squad = p_squad
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var id := ninja.sprite_profile_id if not ninja.sprite_profile_id.is_empty() else ninja.id
	sprite_profile = SpriteLibrary.profile(id)
	if sprite_profile.is_empty():
		return
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = sprite_profile.sprite_frames
	sprite.centered = false
	var factor: float = sprite_profile.scale * presentation_scale
	sprite.scale = Vector2.ONE * factor
	sprite.position = GROUND - Vector2(sprite_profile.pivot[0], sprite_profile.pivot[1]) * factor
	add_child(sprite)
	sprite.animation_finished.connect(func():
		if visual_state == "hit" and hp_value() > 0:
			play_state("idle"))
	play_state("idle")
	# Units breathe independently instead of restarting in unison.
	var count := sprite.sprite_frames.get_frame_count("idle")
	sprite.set_frame_and_progress(posmod(ninja.id.hash(), count), float(posmod(ninja.id.hash(), 97)) / 97.0)

func play_state(state: String, speed: float = 1.0, restart: bool = false) -> void:
	if sprite == null:
		return
	if hp_value() <= 0 and state != "ko":
		state = "ko"
	if not sprite.sprite_frames.has_animation(state):
		state = "idle"
	var facing: String = sprite_profile.animations[state].get("default_facing", sprite_profile.default_facing)
	sprite.flip_h = faces_right != (facing == "right")
	# Flip around the ground pivot, not the left edge of the padded canvas.
	var factor: float = sprite_profile.scale * presentation_scale
	var pivot_x: float = sprite_profile.pivot[0]
	var width: float = sprite_profile.canvas[0]
	sprite.position.x = GROUND.x - (width - pivot_x if sprite.flip_h else pivot_x) * factor
	sprite.speed_scale = 1.0 if state == "idle" else speed
	if sprite.animation == state and not restart and (sprite.is_playing() or not sprite.sprite_frames.get_animation_loop(state)):
		# Updating facing, speed or HP must not rewind an existing animation.
		return
	if sprite.sprite_frames.get_animation_loop(sprite.animation):
		loop_phases[sprite.animation] = Vector2(sprite.frame, sprite.frame_progress)
	visual_state = state
	sprite.play(state)
	if sprite.sprite_frames.get_animation_loop(state) and loop_phases.has(state):
		var phase: Vector2 = loop_phases[state]
		sprite.set_frame_and_progress(int(phase.x), phase.y)
	elif restart:
		sprite.set_frame_and_progress(0, 0.0)

func impact_delay(ranged: bool) -> float:
	if sprite == null:
		return 0.0
	var state := "ranged_attack" if ranged and sprite.sprite_frames.has_animation("ranged_attack") else "attack"
	var frame: int = sprite_profile.get("ranged_impact_frame", 1) if state == "ranged_attack" else sprite_profile.attack_impact_frame
	return float(frame) / sprite.sprite_frames.get_animation_speed(state)

func attack_state(ranged: bool) -> String:
	if ranged and sprite != null and sprite.sprite_frames.has_animation("ranged_attack"):
		return "ranged_attack"
	return "attack"

func hp_value() -> int:
	return displayed_hp if displayed_hp >= 0 else int(squad.current_hp.get(ninja.id, 0))

func sync_sprite() -> void:
	if sprite == null:
		return
	if hp_value() <= 0 and visual_state != "ko":
		play_state("ko")
	sprite.modulate = Color(0.5, 1, 0.6) if heal_flash else (Color(1, 0.5, 0.5) if hit_flash else Color.WHITE)

func _process(_delta: float) -> void:
	sync_sprite()

func _draw() -> void:
	if sprite != null:
		if show_status:
			draw_sprite_status()
		else:
			draw_ellipse_ground()
		return
	var hp: int = displayed_hp if displayed_hp >= 0 else int(squad.current_hp.get(ninja.id, 0))
	var maximum: int = ninja.test_stats().hp
	var tint := ninja.color if hp > 0 else Color(0.35, 0.35, 0.38)
	var rect := Rect2(Vector2.ZERO, CARD_SIZE)
	draw_rect(rect, Color(tint, 0.16))
	if hit_flash:
		draw_rect(rect, Color(0.3, 1, 0.5, 0.4) if heal_flash else Color(1, 0.5, 0.4, 0.4))
	draw_rect(rect, Color(1, 0.87, 0.3) if emphasized else tint, false, 3 if emphasized else 1)
	draw_rect(Rect2(Vector2.ZERO, Vector2(CARD_SIZE.x, 37)), tint.darkened(0.72))
	var font := ThemeDB.fallback_font
	var title: String = ninja.display_name + (" ★" if squad.leader_id == ninja.id else "")
	draw_string(font, Vector2(6, 18), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_rect(Rect2(Vector2(5, 23), Vector2(86, 7)), Color(0.15, 0.15, 0.18))
	draw_rect(Rect2(Vector2(5, 23), Vector2(86.0 * hp / maximum, 7)), Color(0.3, 0.85, 0.5) if hp > 0 else Color(0.4, 0.4, 0.4))
	draw_string(font, Vector2(5, 49), "%d/%d" % [hp, maximum] if hp > 0 else "전투불능", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	draw_string(font, Vector2(5, 62), NinjaData.class_label(ninja.class_type), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.8, 0.9))
	if not damage_text.is_empty():
		draw_string(font, Vector2(55, 84), damage_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.4, 1, 0.6) if heal_flash else Color(1, 0.55, 0.4))
	if not action_marker.is_empty():
		draw_string(font, Vector2(4, 74), action_marker, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.9, 0.4))

func draw_sprite_status() -> void:
	var hp := hp_value()
	var maximum: int = ninja.test_stats().hp
	var font := ThemeDB.fallback_font
	draw_ellipse_ground()
	if compact_status:
		draw_rect(Rect2(Vector2(16, 85), Vector2(64, 4)), Color(0.08, 0.1, 0.12, 0.9))
		draw_rect(Rect2(Vector2(16, 85), Vector2(64.0 * hp / maximum, 4)), Color(0.3, 0.85, 0.5))
		if emphasized:
			draw_string(font, Vector2(0, 106), ninja.display_name, HORIZONTAL_ALIGNMENT_CENTER, 96, 12, Color.WHITE)
		if not damage_text.is_empty():
			draw_string(font, Vector2(0, -15), damage_text, HORIZONTAL_ALIGNMENT_CENTER, 96, 24, Color(0.4, 1, 0.6) if heal_flash else Color(1, 0.6, 0.4))
		return
	var title: String = ninja.display_name + (" ★" if squad.leader_id == ninja.id else "")
	draw_string(font, Vector2(0, 96), title, HORIZONTAL_ALIGNMENT_CENTER, 96, 12, Color.WHITE)
	draw_rect(Rect2(Vector2(6, 101), Vector2(84, 5)), Color(0.16, 0.18, 0.23))
	draw_rect(Rect2(Vector2(6, 101), Vector2(84.0 * hp / maximum, 5)), Color(0.3, 0.85, 0.5))
	draw_string(font, Vector2(6, 120), "%d/%d" % [hp, maximum] if hp > 0 else "전투불능", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.86, 0.95))
	if not damage_text.is_empty():
		draw_string(font, Vector2(45, -35), damage_text, HORIZONTAL_ALIGNMENT_CENTER, 80, 24, Color(0.4, 1, 0.6) if heal_flash else Color(1, 0.6, 0.4))

func draw_ellipse_ground() -> void:
	draw_set_transform(GROUND, 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 26, Color(1, 0.85, 0.25, 0.35) if emphasized else Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO)
