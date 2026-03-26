class_name AbilitySlam
extends Node

@export var base_damage:float = 10.0
@export var push_tiles:int = 1


func execute(player_pos:Vector2i, actors_on_grid:Dictionary) -> Array[Dictionary]:
	var results:Array[Dictionary] = []
	var enemies:Dictionary = actors_on_grid.get("enemies", {})
	if !(enemies is Dictionary):
		return results

	var blocked_map:Dictionary = _to_cell_map(actors_on_grid.get("blocked", []))
	var grid_size:int = int(actors_on_grid.get("grid_size", 8))

	for enemy_pos in GridUtils.get_adjacent_cells(player_pos):
		if !enemies.has(enemy_pos):
			continue

		var enemy_data:Dictionary = enemies[enemy_pos]
		var health:HealthResource = _resolve_health(enemy_data)
		if health == null:
			continue

		var total_damage:float = base_damage
		var final_pos:Vector2i = enemy_pos
		var direction:Vector2i = enemy_pos - player_pos
		var blocked_push:bool = false

		var enemy_stats:CombatStatsResource = _resolve_combat_stats(enemy_data)
		if enemy_stats != null && enemy_stats.is_immovable:
			blocked_push = true
		else:
			var current_pos:Vector2i = enemy_pos
			var moved_steps:int = 0

			for _step in range(push_tiles):
				var next_cell:Vector2i = current_pos + direction
				var blocked_by_bounds:bool = !GridUtils.is_in_bounds(next_cell, grid_size)
				var blocked_by_obstacle:bool = blocked_map.has(next_cell)
				var blocked_by_enemy:bool = enemies.has(next_cell) && next_cell != enemy_pos

				if blocked_by_bounds || blocked_by_obstacle || blocked_by_enemy:
					blocked_push = true
					break

				current_pos = next_cell
				moved_steps += 1

			if moved_steps > 0:
				final_pos = current_pos
				enemies.erase(enemy_pos)
				enemies[final_pos] = enemy_data
				if enemy_stats != null:
					enemy_stats.grid_pos = final_pos

			if moved_steps < push_tiles:
				blocked_push = true

		if blocked_push:
			total_damage += 5.0

		health.add_hp(-total_damage)
		results.push_back({
			"enemy_pos": enemy_pos,
			"final_pos": final_pos,
			"total_damage": total_damage,
		})

	return results


func _resolve_health(actor) -> HealthResource:
	if actor == null:
		return null
	if actor is HealthResource:
		return actor
	if actor is Dictionary:
		if actor.has("health") && actor["health"] is HealthResource:
			return actor["health"]
		if actor.has("resource_node"):
			return _resolve_health(actor["resource_node"])
	if actor is Node && actor.has_method("get_resource"):
		return actor.get_resource("health")
	if actor is Node && actor.has_method("get"):
		var resource_node = actor.get("resource_node")
		if resource_node != null:
			return _resolve_health(resource_node)
	return null


func _resolve_combat_stats(actor) -> CombatStatsResource:
	if actor == null:
		return null
	if actor is CombatStatsResource:
		return actor
	if actor is Dictionary:
		if actor.has("combat_stats") && actor["combat_stats"] is CombatStatsResource:
			return actor["combat_stats"]
		if actor.has("resource_node"):
			return _resolve_combat_stats(actor["resource_node"])
	if actor is Node && actor.has_method("get_resource"):
		return actor.get_resource("combat_stats")
	if actor is Node && actor.has_method("get"):
		var resource_node = actor.get("resource_node")
		if resource_node != null:
			return _resolve_combat_stats(resource_node)
	return null


func _to_cell_map(cells:Array) -> Dictionary:
	var result:Dictionary = {}
	for cell in cells:
		result[cell] = true
	return result
