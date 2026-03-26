class_name AbilityStrike
extends Node

@export var base_damage:float = 15.0


func execute(target_cell:Vector2i, actors_on_grid:Dictionary) -> bool:
	var enemy = _get_enemy_at_cell(target_cell, actors_on_grid)
	var health:HealthResource = _resolve_health(enemy)
	if health == null:
		return false

	health.add_hp(-base_damage)
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
