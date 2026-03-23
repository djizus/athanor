extends Node

# Tracks which room we're visually in vs. what contract says
var visual_zone: int = 0
var contract_zone: int = 0
var room_state_machine: RefCounted = null

signal room_changed(zone_id: int)
signal room_state_changed(new_state: int, old_state: int)

func _ready() -> void:
	room_state_machine = load("res://scripts/room_state_machine.gd").new()
	room_state_machine.state_changed.connect(_on_room_state_changed)

func enter_room(zone_id: int) -> void:
	visual_zone = zone_id
	room_changed.emit(zone_id)
	room_state_machine.transition_to(room_state_machine.RoomState.ENTERING)
	# After a short delay, transition to EXPLORING
	get_tree().create_timer(0.5).timeout.connect(func():
		room_state_machine.transition_to(room_state_machine.RoomState.EXPLORING)
	)

func start_combat() -> void:
	room_state_machine.transition_to(room_state_machine.RoomState.COMBAT_INTRO)
	get_tree().create_timer(1.0).timeout.connect(func():
		room_state_machine.transition_to(room_state_machine.RoomState.COMBAT)
	)

func clear_room() -> void:
	room_state_machine.transition_to(room_state_machine.RoomState.CLEARED)

func exit_room() -> void:
	room_state_machine.transition_to(room_state_machine.RoomState.EXITING)

func get_current_room_state() -> int:
	if room_state_machine == null:
		return 0
	return room_state_machine.current

func is_exploring() -> bool:
	if room_state_machine == null:
		return false
	return room_state_machine.is_exploring()

func is_in_combat() -> bool:
	if room_state_machine == null:
		return false
	return room_state_machine.is_in_combat()

func _on_room_state_changed(new_state: int, old_state: int) -> void:
	room_state_changed.emit(new_state, old_state)
