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
var _sfx_player: AudioStreamPlayer
var _current_track: String = ""

# Audio tracks — loaded on demand (not preload, to avoid import-cache errors in headless)
var _track_paths := {
	"main_theme": "res://assets/sounds/music/main_theme.mp3",
	"game_loop_1": "res://assets/sounds/music/game_loop_1.mp3",
	"game_loop_2": "res://assets/sounds/music/game_loop_2.mp3",
}

var _sfx_paths := {
	"click": "res://assets/sounds/effects/click.mp3",
	"victory": "res://assets/sounds/effects/victory.mp3",
	"beast_lose": "res://assets/sounds/effects/beast_lose.mp3",
	"beast_win": "res://assets/sounds/effects/beast_win.mp3",
	"discovery": "res://assets/sounds/effects/discovery.mp3",
	"heal": "res://assets/sounds/effects/heal.mp3",
}

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
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Master"
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = &"Master"
	add_child(_sfx_player)

	load_settings()

func play_music(track_name: String) -> void:
	if not music_enabled:
		return
	if _current_track == track_name and _music_player.playing:
		return
	var stream := _get_track(track_name)
	if stream == null:
		push_warning("[audio] Track not found: %s" % track_name)
		return
	_current_track = track_name
	_music_player.stream = stream
	_apply_music_volume()
	_music_player.play()

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
	_current_track = ""

func _apply_music_volume() -> void:
	_music_player.volume_db = linear_to_db(music_volume)

func _on_music_finished() -> void:
	# Loop current track
	if music_enabled and not _current_track.is_empty():
		_music_player.play()

# --- Settings persistence ---

func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"music_enabled": music_enabled,
		"sfx_enabled": sfx_enabled,
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
