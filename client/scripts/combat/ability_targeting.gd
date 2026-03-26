class_name AbilityTargeting
extends Node

signal target_confirmed(ability:AbilityResource, cells:Array[Vector2i])
signal target_cancelled

const CARDINAL_DIRECTIONS:Array[Vector2i] = [
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(0, -1),
	Vector2i(0, 1),
]


func get_valid_targets(ability:AbilityResource, player_pos:Vector2i, blocked:Array[Vector2i], grid_size:int) -> Array[Vector2i]:
	var valid_targets:Array[Vector2i] = []
	if ability == null:
		return valid_targets

	match ability.target_mode:
		CombatEnums.TargetMode.ADJACENT:
			var blocked_map:Dictionary = _blocked_to_map(blocked)
			for cell in GridUtils.get_adjacent_cells(player_pos):
				if !GridUtils.is_in_bounds(cell, grid_size):
					continue
				if blocked_map.has(cell):
					continue
				valid_targets.append(cell)
		CombatEnums.TargetMode.LINE:
			for direction in CARDINAL_DIRECTIONS:
				valid_targets.append_array(get_line_targets(player_pos, direction, ability.range_tiles, blocked, grid_size))
		CombatEnums.TargetMode.SELF:
			if GridUtils.is_in_bounds(player_pos, grid_size):
				valid_targets.append(player_pos)

	return valid_targets


func get_line_targets(start:Vector2i, direction:Vector2i, range_tiles:int, blocked:Array[Vector2i], grid_size:int) -> Array[Vector2i]:
	var targets:Array[Vector2i] = []
	var blocked_map:Dictionary = _blocked_to_map(blocked)

	for step in range(1, range_tiles + 1):
		var cell:Vector2i = start + (direction * step)
		if !GridUtils.is_in_bounds(cell, grid_size):
			break
		if blocked_map.has(cell):
			break
		targets.append(cell)

	return targets


func _blocked_to_map(blocked:Array[Vector2i]) -> Dictionary:
	var blocked_map:Dictionary = {}
	for cell in blocked:
		blocked_map[cell] = true
	return blocked_map
