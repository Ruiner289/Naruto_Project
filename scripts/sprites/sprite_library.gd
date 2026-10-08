class_name SpriteLibrary
extends RefCounted

# Resources are shared; animation progress and facing remain on each view.
static var cache: Dictionary = {}
static var warned: Dictionary = {}
const IDS := ["naruto", "sasuke", "sakura", "kakashi", "generic_big_sound", "generic_dart", "generic_claw", "generic_pole", "generic_flail", "generic_scythe", "shikamaru", "ino", "choji", "kiba", "shino", "hinata", "asuma", "kurenai", "guy", "lee", "neji", "tenten"]

static func profile(id: String) -> Dictionary:
	if cache.has(id):
		return cache[id]
	var path := "res://data/sprite_profiles/%s.json" % id
	if not FileAccess.file_exists(path):
		if not warned.has(id):
			warned[id] = true
			print("[Sprite fallback] No reviewed profile: ", id)
		return {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for state in data.animations:
		var animation: Dictionary = data.animations[state]
		frames.add_animation(state)
		frames.set_animation_speed(state, animation.fps)
		frames.set_animation_loop(state, animation.loop)
		var order: Array = animation.get("playback_order", range(animation.frames.size()))
		for source_index in order:
			var frame: Dictionary = animation.frames[source_index]
			if not ResourceLoader.exists(frame.path):
				push_warning("Missing sprite frame; using token: " + str(frame.path))
				cache[id] = {}
				return {}
			var texture := load(frame.path) as Texture2D
			if texture == null:
				push_warning("Missing sprite frame: " + str(frame.path))
				return {}
			frames.add_frame(state, texture)
	data["sprite_frames"] = frames
	cache[id] = data
	return data
