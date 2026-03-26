class_name AbilityStrike
extends Node

const DamageCalculator:Script = preload("res://scripts/combat/damage_calculator.gd")

@export var base_damage:float = 15.0


func execute(target_cell:Vector2i, actors_on_grid:Dictionary) -> bool:
	var enemy = _get_enemy_at_cell(target_cell, actors_on_grid)
	var health:HealthResource = _resolve_health(enemy)
	if health == null:
		return false
	if health.hp <= 0.0:
		return false

	var player_stats:CombatStatsResource = _resolve_player_combat_stats(actors_on_grid)
	var enemy_stats:CombatStatsResource = _resolve_combat_stats(enemy)
	var offense:int = player_stats.offense if player_stats != null else 0
	var defense:int = enemy_stats.defense if enemy_stats != null else 0
	var damage:int = DamageCalculator.compute_damage_with_stats(int(base_damage), offense, defense)
	health.add_hp(-float(damage))
	return true


func _get_enemy_at_cell(cell:Vector2i, actors_on_grid:Dictionary):
	if actors_on_grid.has("enemies"):
		var enemies = actors_on_grid["enemies"]
		if enemies is Dictionary && enemies.has(cell):
			return enemies[cell]
	if actors_on_grid.has(cell):
		return actors_on_grid[cell]
	return null


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
	if player is Node && player.has_method("get_resource"):
		return player.get_resource("combat_stats")
	if player is Node && player.has_method("get"):
		var resource_node = player.get("resource_node")
		if resource_node != null && resource_node.has_method("get_resource"):
			return resource_node.get_resource("combat_stats")

	return null
