extends Node

signal character_updated(character: Dictionary)
signal dungeon_updated(dungeon: Dictionary)
signal fight_updated(fight: Dictionary)
signal game_over(completed: bool, failed: bool)

var character: Dictionary = {}
var dungeon: Dictionary = {}
var fight: Dictionary = {}

func reset() -> void:
	character = {}
	dungeon = {}
	fight = {}
	character_updated.emit(character)
	dungeon_updated.emit(dungeon)
	fight_updated.emit(fight)

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

func _emit_game_over_if_needed() -> void:
	var completed := bool(dungeon.get("completed", false))
	var failed := bool(dungeon.get("failed", false))
	if completed or failed:
		game_over.emit(completed, failed)
