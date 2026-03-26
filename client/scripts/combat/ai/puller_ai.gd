extends EnemyGridAI

const PULL_DISTANCE:int = 2
const MIN_SAFE_DISTANCE:int = 3

func compute_intent(self_pos:Vector2i, player_pos:Vector2i, grid_state:Dictionary) -> Dictionary:
	var current_distance:int = GridUtils.manhattan_distance(self_pos, player_pos)
	var move_to:Vector2i = self_pos

	if current_distance < MIN_SAFE_DISTANCE:
		move_to = _compute_retreat_step(self_pos, player_pos, grid_state)
	elif !_is_walkable(self_pos, self_pos, grid_state):
		move_to = _choose_best_adjacent(self_pos, player_pos, self_pos, grid_state)

	var telegraph_cells:Array[Vector2i] = _build_clamped_zone(player_pos, int(grid_state.get("grid_size", 8)))

	return {
		"move_to": move_to,
		"telegraph_cells": telegraph_cells,
		"telegraph_damage": 0.0,
		"telegraph_type": 1,
		"pull_source": move_to,
		"pull_distance": PULL_DISTANCE,
	}

func _compute_retreat_step(self_pos:Vector2i, player_pos:Vector2i, grid_state:Dictionary) -> Vector2i:
	var dx:int = self_pos.x - player_pos.x
	var dy:int = self_pos.y - player_pos.y

	var primary_step:Vector2i = Vector2i.ZERO
	var secondary_step:Vector2i = Vector2i.ZERO

	if absi(dx) >= absi(dy):
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
		var primary_target:Vector2i = self_pos + primary_step
		if _is_walkable(primary_target, self_pos, grid_state):
			return primary_target

	if secondary_step != Vector2i.ZERO:
		var secondary_target:Vector2i = self_pos + secondary_step
		if _is_walkable(secondary_target, self_pos, grid_state):
			return secondary_target

	return _choose_best_adjacent(self_pos, player_pos, self_pos, grid_state)

func _choose_best_adjacent(from_pos:Vector2i, player_pos:Vector2i, self_pos:Vector2i, grid_state:Dictionary) -> Vector2i:
	var best_cell:Vector2i = from_pos
	var best_distance:int = GridUtils.manhattan_distance(from_pos, player_pos)

	for candidate in GridUtils.get_adjacent_cells(from_pos):
		if !_is_walkable(candidate, self_pos, grid_state):
			continue

		var candidate_distance:int = GridUtils.manhattan_distance(candidate, player_pos)
		if candidate_distance > best_distance:
			best_distance = candidate_distance
			best_cell = candidate

	return best_cell

func _build_clamped_zone(center:Vector2i, grid_size:int) -> Array[Vector2i]:
	var result:Array[Vector2i] = []
	for y in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			var cell:Vector2i = Vector2i(x, y)
			if GridUtils.is_in_bounds(cell, grid_size):
				result.append(cell)
	return result

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
