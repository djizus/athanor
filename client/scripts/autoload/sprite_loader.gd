extends Node

const SPRITE_BASE_PATH := "res://assets/sprites/"

var _cache: Dictionary = {}

func get_sprite_frames(character_id: String) -> SpriteFrames:
	if _cache.has(character_id):
		return _cache[character_id]

	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	var dir_path := SPRITE_BASE_PATH + character_id + "/"
	if not DirAccess.dir_exists_absolute(dir_path):
		push_warning("[sprite_loader] No sprite directory: %s" % dir_path)
		_cache[character_id] = frames
		return frames

	var dir := DirAccess.open(dir_path)
	if dir == null:
		_cache[character_id] = frames
		return frames

	var files: PackedStringArray = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	files.sort()

	var anim_frames: Dictionary = {}
	for fname in files:
		var parsed := _parse_filename(character_id, fname)
		if parsed.is_empty():
			continue
		var anim_name: String = parsed["animation"]
		if not anim_frames.has(anim_name):
			anim_frames[anim_name] = []
		anim_frames[anim_name].append(dir_path + fname)

	for anim_name in anim_frames.keys():
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, _get_animation_fps(anim_name))
		frames.set_animation_loop(anim_name, anim_name == "idle")
		var paths: Array = anim_frames[anim_name]
		for i in range(paths.size()):
			var texture: Texture2D = load(paths[i])
			if texture != null:
				frames.add_frame(anim_name, texture, 1.0, i)

	_cache[character_id] = frames
	return frames

func has_sprites(character_id: String) -> bool:
	if _cache.has(character_id):
		var frames: SpriteFrames = _cache[character_id]
		return frames.get_animation_names().size() > 0
	return DirAccess.dir_exists_absolute(SPRITE_BASE_PATH + character_id + "/")

func clear_cache() -> void:
	_cache.clear()

func _parse_filename(character_id: String, fname: String) -> Dictionary:
	var base := fname.get_basename()
	var prefix := character_id + "_"
	if not base.begins_with(prefix):
		return {}
	var rest := base.substr(prefix.length())
	var last_underscore := rest.rfind("_")
	if last_underscore < 0:
		return {}
	var anim_name := rest.left(last_underscore)
	var frame_str := rest.substr(last_underscore + 1)
	if not frame_str.is_valid_int():
		return {}
	return { "animation": anim_name, "frame": int(frame_str) }

func _get_animation_fps(anim_name: String) -> float:
	match anim_name:
		"idle": return 2.0
		"attack": return 6.0
		"hit": return 6.0
		"death": return 4.0
		_: return 4.0
