class_name EnergyOrbSystem
extends Node

signal orb_spawned(grid_pos:Vector2i, value:int)
signal orb_collected(grid_pos:Vector2i, value:int)
signal orb_expired(grid_pos:Vector2i)

const ORB_VALUE:int = 20
const ORB_LIFETIME:int = 2

var _orbs:Dictionary = {}

func spawn_orb(grid_pos:Vector2i, value:int = ORB_VALUE) -> void:
	_orbs[grid_pos] = {
		"value": value,
		"turns_remaining": ORB_LIFETIME,
	}
	orb_spawned.emit(grid_pos, value)

func check_pickup(player_pos:Vector2i) -> int:
	if !_orbs.has(player_pos):
		return 0

	var orb_data:Dictionary = _orbs[player_pos]
	var value:int = int(orb_data.get("value", 0))
	_orbs.erase(player_pos)
	orb_collected.emit(player_pos, value)
	return 0

func tick() -> void:
	var expired_positions:Array[Vector2i] = []

	for grid_pos in _orbs.keys():
		var orb_data:Dictionary = _orbs[grid_pos]
		var turns_remaining:int = int(orb_data.get("turns_remaining", 0)) - 1

		if turns_remaining <= 0:
			expired_positions.push_back(grid_pos)
			continue

		orb_data["turns_remaining"] = turns_remaining
		_orbs[grid_pos] = orb_data

	for grid_pos in expired_positions:
		_orbs.erase(grid_pos)
		orb_expired.emit(grid_pos)

func get_orb_positions() -> Array[Vector2i]:
	var positions:Array[Vector2i] = []
	for grid_pos in _orbs.keys():
		positions.push_back(grid_pos)
	return positions

func clear() -> void:
	_orbs.clear()
