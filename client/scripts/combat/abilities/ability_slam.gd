class_name AbilitySlam
extends Node

const CombatConstants:Script = preload("res://scripts/combat/combat_constants.gd")
const DamageCalculator:Script = preload("res://scripts/combat/damage_calculator.gd")

@export var base_damage:float = 10.0
@export var push_tiles:int = 1


func execute(player_pos:Vector2i, actors_on_grid:Dictionary) -> Array[Dictionary]:
	var results:Array[Dictionary] = []
	var enemies:Dictionary = actors_on_grid.get("enemies", {})
	if !(enemies is Dictionary):
		return results

	var player_stats:CombatStatsResource = _resolve_player_combat_stats(actors_on_grid)
	var player_offense:int = player_stats.offense if player_stats != null else 0
	var blocked_map:Dictionary = _to_cell_map(actors_on_grid.get("blocked", []))
	var grid_size:int = int(actors_on_grid.get("grid_size", 8))

	for enemy_data in _ordered_enemies(enemies):
		var enemy_stats:CombatStatsResource = _resolve_combat_stats(enemy_data)
		if enemy_stats == null:
			continue
		var enemy_pos:Vector2i = enemy_stats.grid_pos
		if GridUtils.manhattan_distance(player_pos, enemy_pos) != 1:
			continue

		var health:HealthResource = _resolve_health(enemy_data)
		if health == null || health.hp <= 0.0:
			continue

		var hit_damage:int = DamageCalculator.compute_damage_with_stats(
			int(base_damage),
			player_offense,
			enemy_stats.defense
		)
		health.add_hp(-float(hit_damage))

		var total_damage:float = float(hit_damage)
		var final_pos:Vector2i = enemy_pos
		var direction:Vector2i = enemy_pos - player_pos
		var collision_damage:float = 0.0

		if health.hp > 0.0:
			if enemy_stats.is_immovable:
				health.add_hp(-float(CombatConstants.COLLISION_DAMAGE))
				collision_damage = float(CombatConstants.COLLISION_DAMAGE)
			else:
				var next_cell:Vector2i = enemy_pos + direction
				if !GridUtils.is_in_bounds(next_cell, grid_size) || blocked_map.has(next_cell) || enemies.has(next_cell):
					health.add_hp(-float(CombatConstants.COLLISION_DAMAGE))
					collision_damage = float(CombatConstants.COLLISION_DAMAGE)
				else:
					enemies.erase(enemy_pos)
					enemies[next_cell] = enemy_data
					enemy_stats.grid_pos = next_cell
					final_pos = next_cell

		total_damage += collision_damage
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


func _resolve_player_combat_stats(actors_on_grid:Dictionary) -> CombatStatsResource:
	if actors_on_grid.has("player_stats") && actors_on_grid["player_stats"] is CombatStatsResource:
		return actors_on_grid["player_stats"]
	if !actors_on_grid.has("player"):
		return null

	var player = actors_on_grid["player"]
	if player is CombatStatsResource:
		return player
	if player is Dictionary && player.has("combat_stats") && player["combat_stats"] is CombatStatsResource:
		return player["combat_stats"]

	return null


func _ordered_enemies(enemies:Dictionary) -> Array[Dictionary]:
	var by_id:Dictionary = {}
	for enemy_data in enemies.values():
		if enemy_data is Dictionary:
			var actor_id:int = int(enemy_data.get("contract_actor_id", -1))
			if actor_id > 0:
				by_id[actor_id] = enemy_data

	var ordered:Array[Dictionary] = []
	for actor_id in range(1, 6):
		if by_id.has(actor_id):
			ordered.push_back(by_id[actor_id])
	return ordered


func _to_cell_map(cells:Array) -> Dictionary:
	var result:Dictionary = {}
	for cell in cells:
		result[cell] = true
	return result
