class_name EnemyTurnResolver
extends Node

func execute_enemy_turn(
		enemies:Array[Dictionary],
		player_pos:Vector2i,
		telegraph_system:TelegraphSystem,
		grid_state:Dictionary,
		turn:int
	) -> Array[Dictionary]:
	var results:Array[Dictionary] = []
	var blocked_cells:Array[Vector2i] = grid_state.get("blocked_cells", Array([], TYPE_VECTOR2I, "", null))
	var occupied_cells:Array[Vector2i] = grid_state.get("occupied_cells", Array([], TYPE_VECTOR2I, "", null)).duplicate()
	var grid_size:int = int(grid_state.get("grid_size", 8))
	var player_last_move_dir:Vector2i = grid_state.get("player_last_move_dir", Vector2i.LEFT)

	for i in enemies.size():
		var enemy:Dictionary = enemies[i]
		var enemy_id:Variant = enemy.get("enemy_id", enemy.get("id", i))
		var combat_stats:CombatStatsResource = enemy.get("combat_stats", null)
		var self_pos:Vector2i = Vector2i.ZERO
		if combat_stats != null:
			self_pos = combat_stats.grid_pos
		else:
			self_pos = enemy.get("position", enemy.get("grid_pos", enemy.get("pos", Vector2i.ZERO)))
		var ai:EnemyGridAI = enemy.get("ai", null)
		if ai == null:
			continue

		var per_enemy_state:Dictionary = {
			"blocked_cells": blocked_cells,
			"occupied_cells": occupied_cells,
			"grid_size": grid_size,
			"player_last_move_dir": player_last_move_dir,
		}
		var intent:Dictionary = ai.compute_intent(self_pos, player_pos, per_enemy_state)
		var moved_to:Vector2i = intent.get("move_to", self_pos)
		var telegraph_cells:Array[Vector2i] = intent.get("telegraph_cells", Array([], TYPE_VECTOR2I, "", null))
		var telegraph_damage:float = float(intent.get("telegraph_damage", 0.0))
		var telegraph_type:int = int(intent.get("telegraph_type", CombatEnums.TelegraphType.DAMAGE))
		var pull_source:Vector2i = intent.get("pull_source", moved_to)
		var pull_distance:int = int(intent.get("pull_distance", 0))

		if moved_to != self_pos:
			occupied_cells.erase(self_pos)
			occupied_cells.append(moved_to)

		enemy["position"] = moved_to
		enemy["grid_pos"] = moved_to
		enemy["pos"] = moved_to
		if combat_stats != null:
			combat_stats.grid_pos = moved_to
			enemy["combat_stats"] = combat_stats
		enemies[i] = enemy

		telegraph_system.add_telegraph(
			telegraph_cells,
			telegraph_damage,
			enemy_id,
			turn,
			telegraph_type,
			pull_source,
			pull_distance
		)

		results.append({
			"enemy_id": enemy_id,
			"moved_to": moved_to,
			"telegraph_cells": telegraph_cells,
		})

	grid_state["occupied_cells"] = occupied_cells
	return results
