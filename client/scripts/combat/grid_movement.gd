class_name GridMovement
extends Node

signal move_completed(from:Vector2i, to:Vector2i)
signal move_cancelled

@export var grid_size:int = 8
@export var move_duration_per_tile:float = 0.15

@export var combat_grid:Node
@export var grid_cursor:Node
@export var player_node:Node2D
@export var stamina:StaminaResource
@export var combat_stats:CombatStatsResource

var blocked_cells:Array[Vector2i] = []
var occupied_cells:Array[Vector2i] = []
var reachable_cells:Dictionary = {}

func _ready() -> void:
	if grid_cursor != null && grid_cursor.has_signal("tile_clicked"):
		grid_cursor.tile_clicked.connect(_on_tile_clicked)

func refresh_reachable() -> void:
	if combat_stats == null || stamina == null:
		reachable_cells.clear()
		if combat_grid != null && combat_grid.has_method("show_tile_costs"):
			combat_grid.call("show_tile_costs", {})
		return

	var max_cost:int = stamina.value / 10
	var blocked:Array[Vector2i] = _merged_blocked_cells(combat_stats.grid_pos)
	reachable_cells = GridUtils.flood_fill_reachable(combat_stats.grid_pos, max_cost, blocked, grid_size)
	_include_occupied_destinations(max_cost)
	_draw_reachable_overlay()

func set_blocked_cells(cells:Array[Vector2i]) -> void:
	blocked_cells = cells.duplicate()

func set_occupied_cells(cells:Array[Vector2i]) -> void:
	occupied_cells = cells.duplicate()

func _on_tile_clicked(pos:Vector2i) -> void:
	await try_move_to(pos)

func try_move_to(target:Vector2i) -> bool:
	if combat_stats == null || stamina == null || player_node == null:
		move_cancelled.emit()
		return false
	if !reachable_cells.has(target):
		move_cancelled.emit()
		return false

	var start:Vector2i = combat_stats.grid_pos
	var path:Array[Vector2i] = _build_path(start, target)
	if path.is_empty():
		move_cancelled.emit()
		return false

	var cost:int = GridUtils.manhattan_distance(start, target) * 10
	if !stamina.spend(cost):
		move_cancelled.emit()
		return false

	if move_duration_per_tile > 0.0 && path.size() > 1:
		var tween:Tween = create_tween()
		for i in range(1, path.size()):
			var waypoint:Vector2i = path[i]
			tween.tween_property(player_node, "global_position", _grid_to_world(waypoint), move_duration_per_tile)
		await tween.finished
	else:
		player_node.global_position = _grid_to_world(target)

	combat_stats.grid_pos = target
	move_completed.emit(start, target)
	refresh_reachable()
	return true

func _build_path(start:Vector2i, target:Vector2i) -> Array[Vector2i]:
	if start == target:
		return [start]

	var astar:AStarGrid2D = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, grid_size, grid_size)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()

	for cell in _merged_blocked_cells(start):
		if cell == target:
			continue
		if GridUtils.is_in_bounds(cell, grid_size):
			astar.set_point_solid(cell, true)

	var path:PackedVector2Array = astar.get_point_path(start, target)
	if path.is_empty():
		return []

	var result:Array[Vector2i] = []
	for point in path:
		result.push_back(Vector2i(roundi(point.x), roundi(point.y)))
	return result

func _merged_blocked_cells(ignore_cell:Vector2i) -> Array[Vector2i]:
	var merged:Array[Vector2i] = []
	var dedupe:Dictionary = {}

	for cell in blocked_cells:
		if cell == ignore_cell:
			continue
		if !dedupe.has(cell):
			dedupe[cell] = true
			merged.push_back(cell)

	for cell in occupied_cells:
		if cell == ignore_cell:
			continue
		if !dedupe.has(cell):
			dedupe[cell] = true
			merged.push_back(cell)

	return merged

func _include_occupied_destinations(max_cost:int) -> void:
	if occupied_cells.is_empty():
		return

	for occupied in occupied_cells:
		if occupied == combat_stats.grid_pos:
			continue
		var best_steps:int = max_cost + 1
		for adjacent in GridUtils.get_adjacent_cells(occupied):
			if !reachable_cells.has(adjacent):
				continue
			var candidate_steps:int = int(reachable_cells[adjacent]) + 1
			if candidate_steps < best_steps:
				best_steps = candidate_steps
		if best_steps <= max_cost:
			reachable_cells[occupied] = best_steps

func _draw_reachable_overlay() -> void:
	if combat_grid == null:
		return
	if combat_grid.has_method("clear_overlay"):
		combat_grid.clear_overlay()

	if !combat_grid.has_method("highlight_cells"):
		return

	var cells:Array[Vector2i] = []
	for cell_key in reachable_cells.keys():
		cells.push_back(cell_key)
	combat_grid.highlight_cells(cells, CombatGrid.STATE_MOVE_RANGE)
	if combat_grid.has_method("show_tile_costs"):
		combat_grid.call("show_tile_costs", reachable_cells)

func _grid_to_world(cell:Vector2i) -> Vector2:
	if combat_grid != null && combat_grid.has_method("grid_to_world"):
		return combat_grid.grid_to_world(cell)
	var half_w:float = 16.0
	var half_h:float = 8.0
	return Vector2((cell.x - cell.y) * half_w, (cell.x + cell.y) * half_h)
