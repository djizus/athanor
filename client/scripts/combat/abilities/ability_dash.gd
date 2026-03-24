class_name AbilityDash
extends Node

@export var range_tiles:int = 3
@export var base_damage:float = 10.0


func execute(direction:Vector2i, player_pos:Vector2i, actors_on_grid:Dictionary) -> Dictionary:
	var blocked_map:Dictionary = _to_cell_map(actors_on_grid.get("blocked", []))
	var occupied_map:Dictionary = _get_occupied_map(actors_on_grid)

	var current:Vector2i = player_pos
	var impact_cell:Vector2i = Vector2i(-1, -1)

	for _step in range(range_tiles):
		var next_cell:Vector2i = current + direction
		if blocked_map.has(next_cell):
			impact_cell = next_cell
			break
		if occupied_map.has(next_cell):
			impact_cell = next_cell
			break
		current = next_cell

	if impact_cell == Vector2i(-1, -1):
		impact_cell = current + direction

	var hit:bool = _damage_enemy_at_cell(impact_cell, actors_on_grid)
	var player_stats:CombatStatsResource = _resolve_player_combat_stats(actors_on_grid)
	if player_stats != null:
		player_stats.grid_pos = current

	return {
		"moved_to": current,
		"impact_cell": impact_cell,
		"hit_enemy": hit,
	}


func _get_occupied_map(actors_on_grid:Dictionary) -> Dictionary:
	if actors_on_grid.has("occupied") && actors_on_grid["occupied"] is Dictionary:
		return actors_on_grid["occupied"]

	if actors_on_grid.has("enemies") && actors_on_grid["enemies"] is Dictionary:
		return actors_on_grid["enemies"]

	return {}


func _damage_enemy_at_cell(cell:Vector2i, actors_on_grid:Dictionary) -> bool:
	if cell.x < 0 || cell.y < 0:
		return false

	var enemy = null
	if actors_on_grid.has("enemies"):
		var enemies = actors_on_grid["enemies"]
		if enemies is Dictionary && enemies.has(cell):
			enemy = enemies[cell]
	elif actors_on_grid.has(cell):
		enemy = actors_on_grid[cell]

	var health:HealthResource = _resolve_health(enemy)
	if health == null:
		return false

	health.add_hp(-base_damage)
	return true


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


func _to_cell_map(cells:Array) -> Dictionary:
	var result:Dictionary = {}
	for cell in cells:
		result[cell] = true
	return result
