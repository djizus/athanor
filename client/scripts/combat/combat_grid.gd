class_name CombatGrid
extends Node2D

const TILE_WIDTH:float = 32.0
const TILE_HEIGHT:float = 16.0
const HALF_W:float = TILE_WIDTH * 0.5
const HALF_H:float = TILE_HEIGHT * 0.5

const STATE_WALKABLE:int = 0
const STATE_SELECTED:int = 1
const STATE_DANGER:int = 2
const STATE_MOVE_RANGE:int = 3
const STATE_ABILITY_RANGE:int = 4
const STATE_OBSTACLE:int = 5

const STATE_COLORS:Dictionary = {
	STATE_WALKABLE: Color(0.2, 0.5, 1.0, 0.15),
	STATE_SELECTED: Color(1.0, 0.9, 0.1, 0.5),
	STATE_DANGER: Color(1.0, 0.08, 0.08, 0.55),
	STATE_MOVE_RANGE: Color(0.2, 0.9, 0.35, 0.3),
	STATE_ABILITY_RANGE: Color(0.7, 0.3, 0.95, 0.3),
	STATE_OBSTACLE: Color(0.18, 0.12, 0.22, 0.9),
}

const MOVE_COST_COLORS:Array[Color] = [
	Color(0.15, 0.85, 0.3, 0.3),
	Color(0.4, 0.85, 0.2, 0.28),
	Color(0.65, 0.8, 0.15, 0.26),
	Color(0.85, 0.7, 0.1, 0.24),
	Color(0.9, 0.5, 0.08, 0.22),
	Color(0.9, 0.35, 0.08, 0.2),
	Color(0.85, 0.2, 0.05, 0.18),
	Color(0.8, 0.12, 0.05, 0.16),
	Color(0.7, 0.08, 0.05, 0.14),
	Color(0.6, 0.05, 0.05, 0.12),
]

var grid_origin:Vector2i = Vector2i.ZERO
var grid_size:Vector2i = Vector2i(8, 8)
var _grid_visible:bool = false
var _cell_states:Dictionary = {}
var _tile_costs:Dictionary = {}
var _danger_pulse:float = 0.0
var _obstacle_cells:Array[Vector2i] = []

func _process(delta:float) -> void:
	_danger_pulse += delta * 3.0
	if _danger_pulse > TAU:
		_danger_pulse -= TAU
	var has_danger:bool = false
	for cell_key in _cell_states.keys():
		if int(_cell_states[cell_key]) == STATE_DANGER:
			has_danger = true
			break
	if has_danger:
		queue_redraw()

func show_grid(origin:Vector2i, size:Vector2i) -> void:
	grid_origin = origin
	grid_size = size
	_grid_visible = true
	queue_redraw()

func hide_grid() -> void:
	_grid_visible = false
	queue_redraw()

func set_obstacles(cells:Array[Vector2i]) -> void:
	_obstacle_cells.clear()
	for cell in cells:
		if _is_in_current_bounds(cell):
			_obstacle_cells.push_back(cell)
	queue_redraw()

func set_cell_state(pos:Vector2i, state:int) -> void:
	if !_is_in_current_bounds(pos):
		return
	_cell_states[pos] = state
	queue_redraw()

func clear_overlay() -> void:
	_cell_states.clear()
	_tile_costs.clear()
	queue_redraw()

func show_tile_costs(costs:Dictionary) -> void:
	_tile_costs.clear()
	for cell_key in costs.keys():
		var cell:Vector2i = cell_key
		if !_is_in_current_bounds(cell):
			continue
		_tile_costs[cell] = int(costs[cell_key])
	queue_redraw()

func highlight_cells(cells:Array[Vector2i], state:int) -> void:
	for cell in cells:
		if _is_in_current_bounds(cell):
			_cell_states[cell] = state
	queue_redraw()

func is_cell_valid(pos:Vector2i) -> bool:
	return _is_in_current_bounds(pos)

func grid_to_world(cell:Vector2i) -> Vector2:
	var rel:Vector2i = cell - grid_origin
	var local_pos:Vector2 = Vector2(
		(float(rel.x) - float(rel.y)) * HALF_W,
		(float(rel.x) + float(rel.y)) * HALF_H
	)
	return to_global(local_pos)

func world_to_grid(world_pos:Vector2) -> Vector2i:
	var local_pos:Vector2 = to_local(world_pos)
	var gx:float = ((local_pos.x / HALF_W) + (local_pos.y / HALF_H)) * 0.5
	var gy:float = ((local_pos.y / HALF_H) - (local_pos.x / HALF_W)) * 0.5
	return Vector2i(roundi(gx), roundi(gy)) + grid_origin

func _draw() -> void:
	if !_grid_visible:
		return

	for y in grid_size.y:
		for x in grid_size.x:
			var cell:Vector2i = grid_origin + Vector2i(x, y)
			_draw_cell(cell, STATE_COLORS[STATE_WALKABLE])

	for obstacle_cell in _obstacle_cells:
		if !_is_in_current_bounds(obstacle_cell):
			continue
		_draw_cell(obstacle_cell, Color(0.18, 0.12, 0.22, 0.9))
		_draw_cell_border(obstacle_cell, Color(0.3, 0.2, 0.35, 0.8), 1.4)

	for cell_key in _tile_costs.keys():
		var cell:Vector2i = cell_key
		if !_is_in_current_bounds(cell):
			continue
		var cost_steps:int = clampi(int(_tile_costs[cell]), 0, MOVE_COST_COLORS.size() - 1)
		_draw_cell(cell, MOVE_COST_COLORS[cost_steps])

	for cell_key in _cell_states.keys():
		var cell:Vector2i = cell_key
		if !_is_in_current_bounds(cell):
			continue
		var state:int = int(_cell_states[cell])
		if state == STATE_MOVE_RANGE && _tile_costs.has(cell):
			continue
		if state == STATE_DANGER:
			var pulse_alpha:float = 0.35 + 0.2 * sin(_danger_pulse)
			var danger_color:Color = Color(1.0, 0.08, 0.08, pulse_alpha)
			_draw_cell(cell, danger_color)
			_draw_cell_border(cell, Color(1.0, 0.2, 0.1, 0.7))
		else:
			var color:Color = STATE_COLORS.get(state, STATE_COLORS[STATE_WALKABLE])
			_draw_cell(cell, color)

func _draw_cell(cell:Vector2i, color:Color) -> void:
	var center:Vector2 = to_local(grid_to_world(cell))
	var points:PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -HALF_H),
		center + Vector2(HALF_W, 0.0),
		center + Vector2(0.0, HALF_H),
		center + Vector2(-HALF_W, 0.0),
	])
	draw_colored_polygon(points, color)

func _draw_cell_border(cell:Vector2i, color:Color, width:float = 1.0) -> void:
	var center:Vector2 = to_local(grid_to_world(cell))
	var points:PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -HALF_H),
		center + Vector2(HALF_W, 0.0),
		center + Vector2(0.0, HALF_H),
		center + Vector2(-HALF_W, 0.0),
		center + Vector2(0.0, -HALF_H),
	])
	draw_polyline(points, color, width)

func _is_in_current_bounds(pos:Vector2i) -> bool:
	if pos.x < grid_origin.x || pos.y < grid_origin.y:
		return false
	var rel:Vector2i = pos - grid_origin
	return GridUtils.is_in_bounds(rel, mini(grid_size.x, grid_size.y))
