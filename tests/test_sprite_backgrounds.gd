extends SceneTree
var failures := 0
func check(ok: bool, note: String) -> void:
	if not ok:
		failures += 1
		push_error(note)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var frames := 0
	for id in SpriteLibrary.IDS:
		var profile := SpriteLibrary.profile(id)
		check(not profile.is_empty(), "Profile loads: " + id)
		for state in profile.animations:
			var animation: Dictionary = profile.animations[state]
			var keys: Dictionary = {}
			for rgb in animation.background_colors:
				keys[(int(rgb[0]) << 16) | (int(rgb[1]) << 8) | int(rgb[2])] = true
			for i in animation.frames.size():
				var texture: Texture2D = load(animation.frames[i].path)
				var image := texture.get_image()
				var area := image.get_used_rect()
				check(image.get_size() == Vector2i(240, 120) and area.has_area(), "Transparent canvas retains sprite: %s %s %d" % [id, state, i])
				var residue := 0
				for y in range(area.position.y, area.end.y):
					for x in range(area.position.x, area.end.x):
						var c := image.get_pixel(x, y)
						if c.a > 0 and keys.has((c.r8 << 16) | (c.g8 << 8) | c.b8):
							residue += 1
				check(residue == 0, "Imported texture has no sheet background: %s %s %d" % [id, state, i])
				frames += 1
	check(frames == 507, "Every current frame inspected")
	print("Sprite background transparency: ", "PASS" if failures == 0 else "FAIL", " (", frames, " frames, ", failures, " failures)")
	quit(failures)
