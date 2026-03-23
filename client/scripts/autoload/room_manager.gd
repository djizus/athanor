extends Node

const RoomConfigScript := preload("res://scripts/room_config.gd")

signal room_loaded(zone_id: int)
signal room_transition_requested(from_zone: int, to_zone: int)

var visual_zone: int = -1
var contract_zone: int = -1
var pending_room_data: Dictionary = {}

func _ready() -> void:
	game_state.character_updated.connect(_on_character_updated)

func _on_character_updated(_data: Dictionary = {}) -> void:
	contract_zone = int(game_state.character.get("current_zone", contract_zone))

func get_current_config() -> Dictionary:
	return RoomConfigScript.get_config(visual_zone)

func request_transition(target_zone: int) -> void:
	pending_room_data = RoomConfigScript.get_config(target_zone)
	room_transition_requested.emit(visual_zone, target_zone)
	visual_zone = target_zone

func consume_pending_data() -> Dictionary:
	var data := pending_room_data
	pending_room_data = {}
	return data

func is_contract_ahead() -> bool:
	return contract_zone > visual_zone and contract_zone >= 0 and visual_zone >= 0
