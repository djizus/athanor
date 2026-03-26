class_name AbilityShove
extends Node

@export var base_damage:float = 5.0
@export var push_tiles:int = 2


func execute(target_cell:Vector2i, actors_on_grid:Dictionary) -> Dictionary:
	var result:Dictionary = {
		"pushed": false,
		"final_pos": target_cell,
		"total_damage": 0.0,
	}

	var enemies:Dictionary = actors_on_grid.get("enemies", {})
	if !(enemies is Dictionary) || !enemies.has(target_cell):
		return result

	var enemy_data:Dictionary = enemies[target_cell]
	var health:HealthResource = _resolve_health(enemy_data)
	if health == null:
		return result

	var total_damage:float = base_damage
	var player_pos:Vector2i = _resolve_player_pos(actors_on_grid)
	var direction:Vector2i = _cardinal_direction(player_pos, target_cell)

	var enemy_stats:CombatStatsResource = _resolve_combat_stats(enemy_data)
	var immovable:bool = enemy_stats != null && enemy_stats.is_immovable

	var final_pos:Vector2i = target_cell
	var pushed:bool = false
	if !immovable && direction != Vector2i.ZERO:
		var blocked_map:Dictionary = _to_cell_map(actors_on_grid.get("blocked", []))
		var grid_size:int = int(actors_on_grid.get("grid_size", 8))
		var blocked_collision:bool = false
		var moved_steps:int = 0
		var current_pos:Vector2i = target_cell

		for _step in range(push_tiles):
			var next_cell:Vector2i = current_pos + direction
			var blocked_by_bounds:bool = !GridUtils.is_in_bounds(next_cell, grid_size)
			var blocked_by_obstacle:bool = blocked_map.has(next_cell)
			var blocked_by_enemy:bool = enemies.has(next_cell) && next_cell != target_cell

			if blocked_by_bounds || blocked_by_obstacle || blocked_by_enemy:
				blocked_collision = true
				break

			current_pos = next_cell
			moved_steps += 1

		if moved_steps < push_tiles:
			blocked_collision = true

		if moved_steps > 0:
			pushed = true
			final_pos = current_pos
			enemies.erase(target_cell)
			enemies[final_pos] = enemy_data
			if enemy_stats != null:
				enemy_stats.grid_pos = final_pos

		if blocked_collision:
			total_damage += 5.0

	health.add_hp(-total_damage)

	result["pushed"] = pushed
	result["final_pos"] = final_pos
	result["total_damage"] = total_damage
	return result


func _resolve_player_pos(actors_on_grid:Dictionary) -> Vector2i:
	if actors_on_grid.has("player_stats") && actors_on_grid["player_stats"] is CombatStatsResource:
		return actors_on_grid["player_stats"].grid_pos

	if !actors_on_grid.has("player"):
		return Vector2i.ZERO

	var player = actors_on_grid["player"]
	if player is Dictionary && player.has("combat_stats") && player["combat_stats"] is CombatStatsResource:
		return player["combat_stats"].grid_pos
	if player is CombatStatsResource:
		return player.grid_pos

	return Vector2i.ZERO


func _cardinal_direction(from_cell:Vector2i, to_cell:Vector2i) -> Vector2i:
	var delta:Vector2i = to_cell - from_cell
	if delta == Vector2i.ZERO:
		return Vector2i.ZERO

	if absi(delta.x) >= absi(delta.y):
		return Vector2i(signi(delta.x), 0)
	return Vector2i(0, signi(delta.y))


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
