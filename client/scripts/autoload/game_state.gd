extends Node

signal character_updated(character: Dictionary)
signal dungeon_updated(dungeon: Dictionary)
signal fight_updated(fight: Dictionary)
signal game_over(completed: bool, failed: bool)
signal history_updated()

var character: Dictionary = {}
var dungeon: Dictionary = {}
var fight: Dictionary = {}

# Latest game_id from PlayerState.game_count
var latest_game_id: int = -1

# History of past runs: Array of {game_id, character, dungeon, status}
var past_runs: Array[Dictionary] = []

func reset() -> void:
	character = {}
	dungeon = {}
	fight = {}
	character_updated.emit(character)
	dungeon_updated.emit(dungeon)
	fight_updated.emit(fight)

func set_latest_game_id(game_id: int) -> void:
	latest_game_id = game_id

func add_historical_run(run: Dictionary) -> void:
	var gid := int(run.get("game_id", -1))
	if gid < 0:
		return
	# Replace existing or append
	for i in range(past_runs.size()):
		if int(past_runs[i].get("game_id", -1)) == gid:
			past_runs[i] = run
			history_updated.emit()
			return
	past_runs.append(run)
	# Sort by game_id descending (newest first)
	past_runs.sort_custom(func(a, b): return int(a.get("game_id", 0)) > int(b.get("game_id", 0)))
	history_updated.emit()

func update_character(next_character: Dictionary) -> void:
	character = next_character.duplicate(true)
	character_updated.emit(character)
	_emit_game_over_if_needed()

func update_dungeon(next_dungeon: Dictionary) -> void:
	dungeon = next_dungeon.duplicate(true)
	dungeon_updated.emit(dungeon)
	_emit_game_over_if_needed()

func update_fight(next_fight: Dictionary) -> void:
	fight = next_fight.duplicate(true)
	fight_updated.emit(fight)

func get_game_id() -> int:
	if character.has("game_id"):
		return int(character["game_id"])
	if dungeon.has("game_id"):
		return int(dungeon["game_id"])
	if fight.has("game_id"):
		return int(fight["game_id"])
	return -1

func is_alive() -> bool:
	return not character.is_empty() and int(character.get("health", 0)) > 0

func has_active_run() -> bool:
	if character.is_empty():
		return false
	if not is_alive():
		return false
	if bool(dungeon.get("completed", false)) or bool(dungeon.get("failed", false)):
		return false
	return true

func _emit_game_over_if_needed() -> void:
	var completed := bool(dungeon.get("completed", false))
	var failed := bool(dungeon.get("failed", false))
	if completed or failed:
		game_over.emit(completed, failed)
