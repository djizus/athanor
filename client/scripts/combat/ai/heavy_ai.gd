extends EnemyGridAI

const HEAVY_DAMAGE:float = 25.0

func compute_intent(self_pos:Vector2i, player_pos:Vector2i, grid_state:Dictionary) -> Dictionary:
	var move_to:Vector2i = self_pos
	if GridUtils.manhattan_distance(self_pos, player_pos) > 1:
		move_to = _choose_step_toward(self_pos, player_pos, self_pos, grid_state)

	var telegraph_cells:Array[Vector2i] = _build_cross_on_player(player_pos, int(grid_state.get("grid_size", 8)))

	return {
		"move_to": move_to,
		"telegraph_cells": telegraph_cells,
		"telegraph_damage": HEAVY_DAMAGE,
		"telegraph_type": 0,
	}

func _build_cross_on_player(center:Vector2i, grid_size:int) -> Array[Vector2i]:
	var result:Array[Vector2i] = []
	var candidates:Array[Vector2i] = [
		center,
		Vector2i(center.x - 1, center.y),
		Vector2i(center.x + 1, center.y),
		Vector2i(center.x, center.y - 1),
		Vector2i(center.x, center.y + 1),
	]

	for cell in candidates:
		if GridUtils.is_in_bounds(cell, grid_size):
			result.append(cell)

	return result

func _choose_step_toward(from_pos:Vector2i, target_pos:Vector2i, self_pos:Vector2i, grid_state:Dictionary) -> Vector2i:
	var dx:int = target_pos.x - from_pos.x
	var dy:int = target_pos.y - from_pos.y

	var primary_step:Vector2i = Vector2i.ZERO
	var secondary_step:Vector2i = Vector2i.ZERO

	if (absi(dx) <= absi(dy) && dx != 0) || dy == 0:
		if dx != 0:
			primary_step = Vector2i(signi(dx), 0)
		if dy != 0:
			secondary_step = Vector2i(0, signi(dy))
	else:
		if dy != 0:
			primary_step = Vector2i(0, signi(dy))
		if dx != 0:
			secondary_step = Vector2i(signi(dx), 0)

	if primary_step != Vector2i.ZERO:
		var primary_target:Vector2i = from_pos + primary_step
		if _is_walkable(primary_target, self_pos, grid_state):
			return primary_target

	if secondary_step != Vector2i.ZERO:
		var secondary_target:Vector2i = from_pos + secondary_step
		if _is_walkable(secondary_target, self_pos, grid_state):
			return secondary_target

	var current_distance:int = GridUtils.manhattan_distance(from_pos, target_pos)
	for candidate in GridUtils.get_adjacent_cells(from_pos):
		if !_is_walkable(candidate, self_pos, grid_state):
			continue
		if GridUtils.manhattan_distance(candidate, target_pos) < current_distance:
			return candidate

	return from_pos

func _is_walkable(cell:Vector2i, self_pos:Vector2i, grid_state:Dictionary) -> bool:
	if !_is_in_bounds(cell, grid_state):
		return false

	var blocked_cells:Array[Vector2i] = grid_state.get("blocked_cells", Array([], TYPE_VECTOR2I, "", null))
	if blocked_cells.has(cell):
		return false

	var occupied_cells:Array[Vector2i] = grid_state.get("occupied_cells", Array([], TYPE_VECTOR2I, "", null))
	if cell != self_pos && occupied_cells.has(cell):
		return false

	return true

func _is_in_bounds(cell:Vector2i, grid_state:Dictionary) -> bool:
	return GridUtils.is_in_bounds(cell, int(grid_state.get("grid_size", 8)))
