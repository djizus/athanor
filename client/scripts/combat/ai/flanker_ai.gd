extends EnemyGridAI

const BACKSTAB_DAMAGE:float = 18.0

func compute_intent(self_pos:Vector2i, player_pos:Vector2i, grid_state:Dictionary) -> Dictionary:
	var player_last_move_dir:Vector2i = grid_state.get("player_last_move_dir", Vector2i.LEFT)
	var flank_target:Vector2i = player_pos - player_last_move_dir

	var moved_to:Vector2i = self_pos
	var used_fallback:bool = false

	if !_is_in_bounds(flank_target, grid_state):
		used_fallback = true
		moved_to = _compute_brute_move(self_pos, player_pos, grid_state)
	else:
		var current:Vector2i = self_pos
		for _step in range(2):
			var next_cell:Vector2i = _choose_step_toward(current, flank_target, current, grid_state)
			if next_cell == current:
				break
			current = next_cell
		moved_to = current

		var start_distance:int = GridUtils.manhattan_distance(self_pos, flank_target)
		var end_distance:int = GridUtils.manhattan_distance(moved_to, flank_target)
		if self_pos != flank_target && end_distance >= start_distance:
			used_fallback = true
			moved_to = _compute_brute_move(self_pos, player_pos, grid_state)

	if used_fallback && GridUtils.manhattan_distance(self_pos, player_pos) <= 1:
		moved_to = self_pos

	var telegraph_cells:Array[Vector2i] = []
	var telegraph_damage:float = 0.0
	if GridUtils.manhattan_distance(moved_to, player_pos) == 1:
		telegraph_cells.append(player_pos)
		telegraph_damage = BACKSTAB_DAMAGE

	return {
		"move_to": moved_to,
		"telegraph_cells": telegraph_cells,
		"telegraph_damage": telegraph_damage,
	}

func _compute_brute_move(self_pos:Vector2i, player_pos:Vector2i, grid_state:Dictionary) -> Vector2i:
	if GridUtils.manhattan_distance(self_pos, player_pos) <= 1:
		return self_pos
	return _choose_step_toward(self_pos, player_pos, self_pos, grid_state)

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
