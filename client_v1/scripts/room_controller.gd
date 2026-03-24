extends Node3D

signal door_triggered(door_id: String) # "north", "south", "left", "right"
signal battle_trigger_hit

var _battle_triggered := false
var _door_proximity: Dictionary = {} # door_id -> bool (player near?)
var _active_door: String = "" # Which door player is near

# Called by arena.gd when setting up a zone
func setup_for_zone(zone_id: int) -> void:
	_battle_triggered = false
	_door_proximity.clear()
	_active_door = ""
	# Wire up Area3D signals if children exist
	for child in get_children():
		if child.name == "BattleTrigger" and child is Area3D:
			if not child.body_entered.is_connected(_on_battle_trigger_entered):
				child.body_entered.connect(_on_battle_trigger_entered)
		elif child.name.begins_with("Door") and child is Area3D:
			var door_id := child.name.to_lower().replace("door", "")
			if not child.body_entered.is_connected(_on_door_entered.bind(door_id)):
				child.body_entered.connect(_on_door_entered.bind(door_id))
			if not child.body_exited.is_connected(_on_door_exited.bind(door_id)):
				child.body_exited.connect(_on_door_exited.bind(door_id))

func get_active_door() -> String:
	return _active_door

func _on_battle_trigger_entered(body: Node3D) -> void:
	if _battle_triggered:
		return
	if body is CharacterBody3D:
		_battle_triggered = true
		battle_trigger_hit.emit()

func _on_door_entered(body: Node3D, door_id: String) -> void:
	if body is CharacterBody3D:
		_door_proximity[door_id] = true
		_active_door = door_id

func _on_door_exited(body: Node3D, door_id: String) -> void:
	if body is CharacterBody3D:
		_door_proximity.erase(door_id)
		if _active_door == door_id:
			_active_door = ""
