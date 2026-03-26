extends EnemyGridAI

const ContractAIUtils = preload("res://scripts/combat/ai/contract_ai_utils.gd")
const CombatConstants = preload("res://scripts/combat/combat_constants.gd")

func compute_intent(self_pos:Vector2i, player_pos:Vector2i, grid_state:Dictionary) -> Dictionary:
	var move_to:Vector2i = self_pos
	var blocked_cells:Array[Vector2i] = grid_state.get("blocked_cells", Array([], TYPE_VECTOR2I, "", null))
	var occupied_cells:Array[Vector2i] = grid_state.get("occupied_cells", Array([], TYPE_VECTOR2I, "", null)).duplicate()
	occupied_cells.erase(self_pos)
	var grid_size:int = int(grid_state.get("grid_size", 8))

	var move_result:Dictionary = ContractAIUtils.choose_step_toward(
		self_pos,
		player_pos,
		blocked_cells,
		occupied_cells,
		grid_size
	)
	move_to = move_result.get("pos", self_pos)

	var telegraph_cells:Array[Vector2i] = []
	var telegraph_damage:float = 0.0
	if GridUtils.manhattan_distance(move_to, player_pos) <= 1:
		telegraph_cells.append(player_pos)
		telegraph_damage = float(CombatConstants.BRUTE_OFFENSE)

	return {
		"move_to": move_to,
		"telegraph_cells": telegraph_cells,
		"telegraph_damage": telegraph_damage,
	}
