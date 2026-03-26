extends Node

signal run_updated(run: Dictionary)
signal room_updated(room: Dictionary)
signal actor_updated(actor: Dictionary)

var run_state: Dictionary = {}
var room_state: Dictionary = {}
var actors: Dictionary = {}
var current_game_id: int = -1

func reset() -> void:
	run_state = {}
	room_state = {}
	actors = {}
	current_game_id = -1
	run_updated.emit(run_state)
	room_updated.emit(room_state)

func set_current_game_id(game_id: int) -> void:
	current_game_id = game_id

func update_run(next_run: Dictionary) -> void:
	run_state = next_run.duplicate(true)
	if run_state.has("game_id"):
		current_game_id = int(run_state.get("game_id", current_game_id))
	run_updated.emit(run_state)

func update_room(next_room: Dictionary) -> void:
	room_state = next_room.duplicate(true)
	if room_state.has("game_id"):
		current_game_id = int(room_state.get("game_id", current_game_id))
	room_updated.emit(room_state)

func upsert_actor(next_actor: Dictionary) -> void:
	var actor_copy: Dictionary = next_actor.duplicate(true)
	if actor_copy.has("game_id"):
		current_game_id = int(actor_copy.get("game_id", current_game_id))
	var actor_id: int = int(actor_copy.get("actor_id", -1))
	if actor_id < 0:
		actor_id = int(actor_copy.get("id", -1))
	if actor_id >= 0:
		actors[actor_id] = actor_copy
	actor_updated.emit(actor_copy)

func get_game_id() -> int:
	if current_game_id >= 0:
		return current_game_id
	if run_state.has("game_id"):
		return int(run_state.get("game_id", -1))
	if room_state.has("game_id"):
		return int(room_state.get("game_id", -1))
	return -1
