extends EnemyGridAI

const MELEE_DAMAGE:float = 20.0

func compute_intent(self_pos:Vector2i, player_pos:Vector2i, grid_state:Dictionary) -> Dictionary:
	var move_to:Vector2i = self_pos

	if GridUtils.manhattan_distance(self_pos, player_pos) > 1:
		move_to = _compute_chase_step(self_pos, player_pos, grid_state)

	var telegraph_cells:Array[Vector2i] = []
	var telegraph_damage:float = 0.0
	if GridUtils.manhattan_distance(move_to, player_pos) == 1:
		telegraph_cells.append(player_pos)
		telegraph_damage = MELEE_DAMAGE

	return {
		"move_to": move_to,
		"telegraph_cells": telegraph_cells,
		"telegraph_damage": telegraph_damage,
	}

func _compute_chase_step(self_pos:Vector2i, target_pos:Vector2i, grid_state:Dictionary) -> Vector2i:
	var dx:int = target_pos.x - self_pos.x
	var dy:int = target_pos.y - self_pos.y

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
		var primary_target:Vector2i = self_pos + primary_step
		if _is_walkable(primary_target, self_pos, grid_state):
			return primary_target

	if secondary_step != Vector2i.ZERO:
		var secondary_target:Vector2i = self_pos + secondary_step
		if _is_walkable(secondary_target, self_pos, grid_state):
			return secondary_target

	return self_pos

func _is_walkable(cell:Vector2i, self_pos:Vector2i, grid_state:Dictionary) -> bool:
	var grid_size:int = int(grid_state.get("grid_size", 8))
	if !GridUtils.is_in_bounds(cell, grid_size):
		return false

	var blocked_cells:Array[Vector2i] = grid_state.get("blocked_cells", Array([], TYPE_VECTOR2I, "", null))
	if blocked_cells.has(cell):
		return false

	var occupied_cells:Array[Vector2i] = grid_state.get("occupied_cells", Array([], TYPE_VECTOR2I, "", null))
	if cell != self_pos && occupied_cells.has(cell):
		return false

	return true
