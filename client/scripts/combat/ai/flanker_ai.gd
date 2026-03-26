extends EnemyGridAI

const ContractAIUtils = preload("res://scripts/combat/ai/contract_ai_utils.gd")
const CombatConstants = preload("res://scripts/combat/combat_constants.gd")

func compute_intent(self_pos:Vector2i, player_pos:Vector2i, grid_state:Dictionary) -> Dictionary:
	var blocked_cells:Array[Vector2i] = grid_state.get("blocked_cells", Array([], TYPE_VECTOR2I, "", null))
	var occupied_cells:Array[Vector2i] = grid_state.get("occupied_cells", Array([], TYPE_VECTOR2I, "", null)).duplicate()
	occupied_cells.erase(self_pos)
	var grid_size:int = int(grid_state.get("grid_size", 8))

	var player_last_move_direction:int = _coerce_direction(grid_state.get("player_last_move_dir", ContractAIUtils.DIRECTION_EAST))
	var behind_direction:int = ContractAIUtils.opposite_direction(player_last_move_direction)
	var flank_step:Dictionary = ContractAIUtils.step_in_direction(player_pos.x, player_pos.y, behind_direction)

	var move_result:Dictionary
	if bool(flank_step.get("ok", false)):
		var flank_target:Vector2i = Vector2i(int(flank_step.get("x", player_pos.x)), int(flank_step.get("y", player_pos.y)))
		move_result = ContractAIUtils.choose_step_toward_exact(
			self_pos,
			flank_target,
			blocked_cells,
			occupied_cells,
			grid_size
		)
	else:
		move_result = ContractAIUtils.choose_step_toward(
			self_pos,
			player_pos,
			blocked_cells,
			occupied_cells,
			grid_size
		)

	if !bool(move_result.get("moved", false)):
		move_result = ContractAIUtils.choose_step_toward(
			self_pos,
			player_pos,
			blocked_cells,
			occupied_cells,
			grid_size
		)

	var moved_to:Vector2i = move_result.get("pos", self_pos)

	var telegraph_cells:Array[Vector2i] = []
	var telegraph_damage:float = 0.0
	if GridUtils.manhattan_distance(moved_to, player_pos) <= 1:
		telegraph_cells.append(player_pos)
		telegraph_damage = float(CombatConstants.FLANKER_OFFENSE)

	return {
		"move_to": moved_to,
		"telegraph_cells": telegraph_cells,
		"telegraph_damage": telegraph_damage,
	}

func _coerce_direction(value:Variant) -> int:
	if value is int:
		return int(value)

	if value is Vector2i:
		var dir_vec:Vector2i = value
		if dir_vec == Vector2i(0, -1):
			return ContractAIUtils.DIRECTION_NORTH
		if dir_vec == Vector2i(1, 0):
			return ContractAIUtils.DIRECTION_EAST
		if dir_vec == Vector2i(0, 1):
			return ContractAIUtils.DIRECTION_SOUTH
		if dir_vec == Vector2i(-1, 0):
			return ContractAIUtils.DIRECTION_WEST

	return ContractAIUtils.DIRECTION_EAST
