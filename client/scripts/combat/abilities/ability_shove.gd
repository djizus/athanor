class_name AbilityShove
extends Node

const CombatConstants:Script = preload("res://scripts/combat/combat_constants.gd")
const DamageCalculator:Script = preload("res://scripts/combat/damage_calculator.gd")

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
	if health.hp <= 0.0:
		return result

	var player_stats:CombatStatsResource = _resolve_player_combat_stats(actors_on_grid)
	var enemy_stats:CombatStatsResource = _resolve_combat_stats(enemy_data)
	var offense:int = player_stats.offense if player_stats != null else 0
	var defense:int = enemy_stats.defense if enemy_stats != null else 0
	var base_hit:int = DamageCalculator.compute_damage_with_stats(int(base_damage), offense, defense)
	health.add_hp(-float(base_hit))
	var total_damage:float = float(base_hit)

	if health.hp <= 0.0:
		result["total_damage"] = total_damage
		return result

	var player_pos:Vector2i = _resolve_player_pos(actors_on_grid)
	var direction:Vector2i = _cardinal_direction(player_pos, target_cell)

	var immovable:bool = enemy_stats != null && enemy_stats.is_immovable

	var final_pos:Vector2i = target_cell
	var pushed:bool = false
	if !immovable && direction != Vector2i.ZERO:
		var blocked_map:Dictionary = _to_cell_map(actors_on_grid.get("blocked", []))
		var grid_size:int = int(actors_on_grid.get("grid_size", 8))
		var current_pos:Vector2i = target_cell
		var blocked_collision:bool = false

		for _step in range(push_tiles):
			var next_cell:Vector2i = current_pos + direction
			if !GridUtils.is_in_bounds(next_cell, grid_size) || blocked_map.has(next_cell) || enemies.has(next_cell):
				blocked_collision = true
				break

			enemies.erase(current_pos)
			current_pos = next_cell
			enemies[current_pos] = enemy_data
			pushed = true

		if pushed:
			final_pos = current_pos
			if enemy_stats != null:
				enemy_stats.grid_pos = final_pos

		if blocked_collision:
			health.add_hp(-float(CombatConstants.COLLISION_DAMAGE))
			total_damage += float(CombatConstants.COLLISION_DAMAGE)
	elif immovable:
		health.add_hp(-float(CombatConstants.COLLISION_DAMAGE))
		total_damage += float(CombatConstants.COLLISION_DAMAGE)


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


func _resolve_player_combat_stats(actors_on_grid:Dictionary) -> CombatStatsResource:
	if actors_on_grid.has("player_stats") && actors_on_grid["player_stats"] is CombatStatsResource:
		return actors_on_grid["player_stats"]

	if !actors_on_grid.has("player"):
		return null

	var player = actors_on_grid["player"]
	if player is Dictionary && player.has("combat_stats") && player["combat_stats"] is CombatStatsResource:
		return player["combat_stats"]
	if player is CombatStatsResource:
		return player

	return null


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
