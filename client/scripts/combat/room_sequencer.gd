class_name RoomSequencer
extends RefCounted

signal room_started(room_index:int, config:Dictionary)
signal room_cleared(room_index:int)
signal run_completed
signal run_failed

# Room layouts MUST match contract definitions in actions.cairo.
# Obstacles = room_X_blocked_bitmap(), enemies = spawn_room_X_enemies(),
# player_start = (ENTRY_X, ENTRY_Y). Order matters: enemy[0]=actor_id 1, etc.
const ROOM_CONFIGS:Array[Dictionary] = [
	# Room 0 (Easy): 2 Brute + 1 Caster
	{
		"grid_size": 8,
		"obstacles": [
			# Row 0
			Vector2i(0, 0), Vector2i(1, 0), Vector2i(6, 0), Vector2i(7, 0),
			# Row 1
			Vector2i(0, 1), Vector2i(7, 1),
			# Row 2
			Vector2i(0, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(7, 2),
			# Row 3
			Vector2i(1, 3), Vector2i(6, 3),
			# Row 4
			Vector2i(1, 4), Vector2i(6, 4),
			# Row 5
			Vector2i(0, 5), Vector2i(7, 5),
			# Row 6
			Vector2i(0, 6), Vector2i(2, 6), Vector2i(7, 6),
			# Row 7
			Vector2i(0, 7), Vector2i(7, 7),
		],
		"enemies": [
			{"name": "Brute", "grid_pos": Vector2i(6, 2)},   # actor_id 1
			{"name": "Brute", "grid_pos": Vector2i(5, 2)},   # actor_id 2
			{"name": "Caster", "grid_pos": Vector2i(5, 6)},  # actor_id 3
		],
		"player_start": Vector2i(1, 1),
	},
	# Room 1 (Medium): 1 Brute + 1 Flanker + 1 Heavy
	{
		"grid_size": 8,
		"obstacles": [
			# Border
			Vector2i(0, 0), Vector2i(7, 0),
			Vector2i(0, 1), Vector2i(7, 1),
			Vector2i(0, 2), Vector2i(7, 2),
			Vector2i(0, 7), Vector2i(7, 7),
			# Interior
			Vector2i(2, 2), Vector2i(3, 2),
			Vector2i(4, 3), Vector2i(4, 4),
			Vector2i(1, 5), Vector2i(2, 5),
			Vector2i(5, 1), Vector2i(6, 1),
		],
		"enemies": [
			{"name": "Brute", "grid_pos": Vector2i(6, 2)},    # actor_id 1
			{"name": "Flanker", "grid_pos": Vector2i(5, 5)},  # actor_id 2
			{"name": "Heavy", "grid_pos": Vector2i(6, 6)},    # actor_id 3
		],
		"player_start": Vector2i(1, 1),
	},
	# Room 2 (Hard): 1 Heavy + 1 Puller + 2 Flanker
	{
		"grid_size": 8,
		"obstacles": [
			# Row 0
			Vector2i(0, 0), Vector2i(1, 0), Vector2i(6, 0), Vector2i(7, 0),
			# Row 1
			Vector2i(0, 1), Vector2i(7, 1),
			# Row 2
			Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2),
			# Row 5
			Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5),
			# Row 6
			Vector2i(0, 6), Vector2i(7, 6),
			# Row 7
			Vector2i(0, 7), Vector2i(1, 7), Vector2i(6, 7), Vector2i(7, 7),
		],
		"enemies": [
			{"name": "Heavy", "grid_pos": Vector2i(6, 3)},    # actor_id 1
			{"name": "Puller", "grid_pos": Vector2i(6, 6)},   # actor_id 2
			{"name": "Flanker", "grid_pos": Vector2i(3, 3)},  # actor_id 3
			{"name": "Flanker", "grid_pos": Vector2i(1, 5)},  # actor_id 4
		],
		"player_start": Vector2i(1, 1),
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
