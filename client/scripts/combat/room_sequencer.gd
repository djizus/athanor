class_name RoomSequencer
extends RefCounted

signal room_started(room_index:int, config:Dictionary)
signal room_cleared(room_index:int)
signal run_completed
signal run_failed

const ROOM_CONFIGS:Array[Dictionary] = [
	{
		"grid_size": 6,
		"obstacles": [
			Vector2i(1, 1), Vector2i(4, 4), Vector2i(2, 4),
			Vector2i(3, 1), Vector2i(0, 3), Vector2i(5, 2),
		],
		"enemies": [
			{"name": "Brute", "grid_pos": Vector2i(4, 1)},
			{"name": "Brute", "grid_pos": Vector2i(3, 4)},
			{"name": "Caster", "grid_pos": Vector2i(5, 3)},
		],
		"player_start": Vector2i(1, 2),
	},
	{
		"grid_size": 7,
		"obstacles": [
			Vector2i(1, 1), Vector2i(5, 5), Vector2i(3, 3),
			Vector2i(2, 5), Vector2i(4, 1), Vector2i(6, 3),
			Vector2i(0, 4), Vector2i(5, 0),
		],
		"enemies": [
			{"name": "Brute", "grid_pos": Vector2i(5, 2)},
			{"name": "Flanker", "grid_pos": Vector2i(4, 5)},
			{"name": "Heavy", "grid_pos": Vector2i(3, 1)},
		],
		"player_start": Vector2i(1, 3),
	},
	{
		"grid_size": 8,
		"obstacles": [
			Vector2i(1, 1), Vector2i(6, 6), Vector2i(3, 3),
			Vector2i(4, 4), Vector2i(2, 6), Vector2i(5, 1),
			Vector2i(7, 3), Vector2i(0, 5), Vector2i(6, 0),
			Vector2i(1, 7),
		],
		"enemies": [
			{"name": "Heavy", "grid_pos": Vector2i(6, 2)},
			{"name": "Puller", "grid_pos": Vector2i(5, 6)},
			{"name": "Flanker", "grid_pos": Vector2i(3, 5)},
			{"name": "Flanker", "grid_pos": Vector2i(4, 1)},
		],
		"player_start": Vector2i(1, 3),
	},
]

var current_room:int = -1


func get_room_count() -> int:
	return ROOM_CONFIGS.size()


func get_current_config() -> Dictionary:
	if current_room < 0 || current_room >= ROOM_CONFIGS.size():
		return {}
	return ROOM_CONFIGS[current_room]


func start_run() -> void:
	current_room = -1
	advance_room()


func advance_room() -> void:
	current_room += 1
	if current_room >= ROOM_CONFIGS.size():
		run_completed.emit()
		return
	room_started.emit(current_room, ROOM_CONFIGS[current_room])


func on_room_cleared() -> void:
	room_cleared.emit(current_room)
	advance_room()


func on_player_died() -> void:
	run_failed.emit()


func reset() -> void:
	current_room = -1
