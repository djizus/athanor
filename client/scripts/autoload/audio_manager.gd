extends Node

# Persistent audio manager — plays music and SFX, respects user settings.
# Settings saved to user://settings.json

const SETTINGS_PATH := "user://settings.json"

var music_volume: float = 0.8:
	set(v):
		music_volume = clampf(v, 0.0, 1.0)
		_apply_music_volume()
		save_settings()

var sfx_volume: float = 1.0:
	set(v):
		sfx_volume = clampf(v, 0.0, 1.0)
		save_settings()

var music_enabled: bool = true:
	set(v):
		music_enabled = v
		if not v:
			_stop_music()
		save_settings()

var sfx_enabled: bool = true:
	set(v):
		sfx_enabled = v
		save_settings()

var _music_player: AudioStreamPlayer
var _music_player_2: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _current_track: String = ""
var _active_player_idx: int = 0

# Audio tracks — loaded on demand (not preload, to avoid import-cache errors in headless)
var _track_paths := {
	"main_theme": "res://assets/sounds/music/main_theme.mp3",
	"game_loop_1": "res://assets/sounds/music/game_loop_1.mp3",
	"game_loop_2": "res://assets/sounds/music/game_loop_2.mp3",
	"ambient_dungeon": "res://assets/sounds/music/ambient_dungeon.mp3",
	"ambient_deep": "res://assets/sounds/music/ambient_deep.mp3",
}

var _sfx_paths := {
	"click": "res://assets/sounds/effects/click.mp3",
	"victory": "res://assets/sounds/effects/victory.mp3",
	"beast_lose": "res://assets/sounds/effects/beast_lose.mp3",
	"beast_win": "res://assets/sounds/effects/beast_win.mp3",
	"discovery": "res://assets/sounds/effects/discovery.mp3",
	"heal": "res://assets/sounds/effects/heal.mp3",
	"sword_slash": "res://assets/sounds/effects/sword_slash.mp3",
	"heavy_hit": "res://assets/sounds/effects/heavy_hit.mp3",
	"shield_block": "res://assets/sounds/effects/shield_block.mp3",
	"enemy_attack": "res://assets/sounds/effects/enemy_attack.mp3",
	"player_hurt": "res://assets/sounds/effects/player_hurt.mp3",
	"enemy_death": "res://assets/sounds/effects/enemy_death.mp3",
	"button_hover": "res://assets/sounds/effects/button_hover.mp3",
	"turn_start": "res://assets/sounds/effects/turn_start.mp3",
	"enemy_turn": "res://assets/sounds/effects/enemy_turn.mp3",
	"skill_select": "res://assets/sounds/effects/skill_select.mp3",
}

const REBINDABLE_ACTIONS := ["move_up", "move_down", "move_left", "move_right"]
const DISPLAY_MODES := ["Windowed", "Borderless", "Fullscreen"]

var display_mode: int = 1:
	set(v):
		display_mode = clampi(v, 0, 2)
		_apply_display_mode()
		save_settings()

var _loaded_tracks := {}
var _loaded_sfx := {}

func _get_track(name: String) -> AudioStream:
	if _loaded_tracks.has(name):
		return _loaded_tracks[name]
	if _track_paths.has(name) and ResourceLoader.exists(_track_paths[name]):
		_loaded_tracks[name] = load(_track_paths[name])
		return _loaded_tracks[name]
	return null

func _get_sfx(name: String) -> AudioStream:
	if _loaded_sfx.has(name):
		return _loaded_sfx[name]
	if _sfx_paths.has(name) and ResourceLoader.exists(_sfx_paths[name]):
		_loaded_sfx[name] = load(_sfx_paths[name])
		return _loaded_sfx[name]
	return null

func _ready() -> void:
	_ensure_bus_layout()

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Music"
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

	_music_player_2 = AudioStreamPlayer.new()
	_music_player_2.bus = &"Music"
	_music_player_2.finished.connect(_on_music_finished)
	add_child(_music_player_2)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = &"SFX"
	add_child(_sfx_player)

	load_settings()

func play_music(track_name: String) -> void:
	if not music_enabled:
		return
	var active_player := _get_active_music_player()
	if _current_track == track_name and active_player.playing:
		return
	var stream := _get_track(track_name)
	if stream == null:
		push_warning("[audio] Track not found: %s" % track_name)
		return
	_current_track = track_name
	active_player.stream = stream
	var inactive_player := _music_player_2 if _active_player_idx == 0 else _music_player
	inactive_player.stop()
	_apply_music_volume()
	active_player.play()

func crossfade_music(track_name: String, duration: float = 1.0) -> void:
	if not music_enabled:
		return
	if _current_track == track_name:
		return
	var stream := _get_track(track_name)
	if stream == null:
		return
	_current_track = track_name
	var old_player := _music_player if _active_player_idx == 0 else _music_player_2
	var new_player := _music_player_2 if _active_player_idx == 0 else _music_player
	_active_player_idx = 1 - _active_player_idx
	new_player.stream = stream
	new_player.volume_db = -80.0
	new_player.play()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(old_player, "volume_db", -80.0, duration)
	tween.tween_property(new_player, "volume_db", linear_to_db(music_volume), duration)
	tween.set_parallel(false)
	tween.tween_callback(func(): old_player.stop())

func stop_music() -> void:
	_stop_music()

func play_sfx(sfx_name: String) -> void:
	if not sfx_enabled:
		return
	var stream := _get_sfx(sfx_name)
	if stream == null:
		return
	_sfx_player.stream = stream
	_sfx_player.volume_db = linear_to_db(sfx_volume)
	_sfx_player.play()

func _stop_music() -> void:
	_music_player.stop()
	_music_player_2.stop()
	_active_player_idx = 0
	_current_track = ""

func _apply_music_volume() -> void:
	_get_active_music_player().volume_db = linear_to_db(music_volume)

func _get_active_music_player() -> AudioStreamPlayer:
	return _music_player if _active_player_idx == 0 else _music_player_2

func _ensure_bus_layout() -> void:
	var bus_names := ["Music", "SFX", "UI", "Ambient"]
	for bus_name in bus_names:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus(AudioServer.get_bus_count())
			var idx := AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

func _apply_display_mode() -> void:
	match display_mode:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var screen_size := DisplayServer.screen_get_size()
			DisplayServer.window_set_size(screen_size)
			DisplayServer.window_set_position(Vector2i.ZERO)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _on_music_finished() -> void:
	# Loop current track
	if music_enabled and not _current_track.is_empty():
		_get_active_music_player().play()

# --- Settings persistence ---

func rebind_action(action: String, event: InputEventKey) -> void:
	if action not in REBINDABLE_ACTIONS:
		return
	var events := InputMap.action_get_events(action)
	for old_event in events:
		if old_event is InputEventKey:
			InputMap.action_erase_event(action, old_event)
			break
	InputMap.action_add_event(action, event)
	save_settings()

func get_action_key_name(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string(event.keycode) if event.keycode != 0 else OS.get_keycode_string(event.physical_keycode)
	return "?"

func save_settings() -> void:
	var keybinds := {}
	for action in REBINDABLE_ACTIONS:
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				keybinds[action] = event.keycode if event.keycode != 0 else event.physical_keycode
				break
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"music_enabled": music_enabled,
		"sfx_enabled": sfx_enabled,
		"keybinds": keybinds,
		"display_mode": display_mode,
	}))

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	# Use internal vars to avoid triggering save during load
	music_volume = float(data.get("music_volume", 0.8))
	sfx_volume = float(data.get("sfx_volume", 1.0))
	music_enabled = bool(data.get("music_enabled", true))
	sfx_enabled = bool(data.get("sfx_enabled", true))
	_apply_music_volume()
	display_mode = int(data.get("display_mode", 1))
	_apply_display_mode()
	var keybinds: Variant = data.get("keybinds", {})
	if keybinds is Dictionary:
		for action in keybinds.keys():
			if action in REBINDABLE_ACTIONS:
				var keycode := int(keybinds[action])
				var event := InputEventKey.new()
				event.keycode = keycode as Key
				rebind_action(action, event)
