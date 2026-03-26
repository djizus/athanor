extends EnemyGridAI

const ContractAIUtils = preload("res://scripts/combat/ai/contract_ai_utils.gd")
const CombatConstants = preload("res://scripts/combat/combat_constants.gd")

func compute_intent(self_pos:Vector2i, player_pos:Vector2i, grid_state:Dictionary) -> Dictionary:
	var move_to:Vector2i = self_pos
	var blocked_cells:Array[Vector2i] = grid_state.get("blocked_cells", Array([], TYPE_VECTOR2I, "", null))
	var occupied_cells:Array[Vector2i] = grid_state.get("occupied_cells", Array([], TYPE_VECTOR2I, "", null)).duplicate()
	occupied_cells.erase(self_pos)
	var grid_size:int = int(grid_state.get("grid_size", 8))

	var move_result:Dictionary = ContractAIUtils.choose_step_away(
		self_pos,
		player_pos,
		blocked_cells,
		occupied_cells,
		grid_size,
		3
	)
	move_to = move_result.get("pos", self_pos)

	var telegraph_cells:Array[Vector2i] = _build_clamped_aoe(player_pos, grid_size)

	return {
		"move_to": move_to,
		"telegraph_cells": telegraph_cells,
		"telegraph_damage": float(CombatConstants.CASTER_OFFENSE),
	}

func _build_clamped_aoe(center:Vector2i, grid_size:int) -> Array[Vector2i]:
	var result:Array[Vector2i] = []
	for y in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			var cell:Vector2i = Vector2i(x, y)
			if GridUtils.is_in_bounds(cell, grid_size):
				result.append(cell)
	return result
