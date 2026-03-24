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

const STATE_COLORS:Dictionary = {
	STATE_WALKABLE: Color(0.2, 0.5, 1.0, 0.3),
	STATE_SELECTED: Color(1.0, 0.9, 0.1, 0.5),
	STATE_DANGER: Color(1.0, 0.15, 0.15, 0.4),
	STATE_MOVE_RANGE: Color(0.2, 0.9, 0.35, 0.3),
	STATE_ABILITY_RANGE: Color(0.7, 0.3, 0.95, 0.3),
}

var grid_origin:Vector2i = Vector2i.ZERO
var grid_size:Vector2i = Vector2i(8, 8)
var _grid_visible:bool = false
var _cell_states:Dictionary = {}
var _tile_costs:Dictionary = {}

func show_grid(origin:Vector2i, size:Vector2i) -> void:
	grid_origin = origin
	grid_size = size
	_grid_visible = true
	queue_redraw()

func hide_grid() -> void:
	_grid_visible = false
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

	for cell_key in _cell_states.keys():
		var cell:Vector2i = cell_key
		if !_is_in_current_bounds(cell):
			continue
		var state:int = int(_cell_states[cell])
		var color:Color = STATE_COLORS.get(state, STATE_COLORS[STATE_WALKABLE])
		_draw_cell(cell, color)

	_draw_tile_cost_labels()

func _draw_cell(cell:Vector2i, color:Color) -> void:
	var center:Vector2 = to_local(grid_to_world(cell))
	var points:PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -HALF_H),
		center + Vector2(HALF_W, 0.0),
		center + Vector2(0.0, HALF_H),
		center + Vector2(-HALF_W, 0.0),
	])
	draw_colored_polygon(points, color)

func _draw_tile_cost_labels() -> void:
	if _tile_costs.is_empty():
		return

	var fallback_font:Font = ThemeDB.fallback_font
	if fallback_font == null:
		return

	var font_size:int = 6
	for cell_key in _tile_costs.keys():
		var cell:Vector2i = cell_key
		if !_is_in_current_bounds(cell):
			continue
		var tile_steps:int = int(_tile_costs[cell])
		var stamina_cost:int = tile_steps * 10
		var center:Vector2 = to_local(grid_to_world(cell))
		draw_string(
			fallback_font,
			center + Vector2(-4.0, 2.0),
			str(stamina_cost),
			HORIZONTAL_ALIGNMENT_CENTER,
			16.0,
			font_size,
			Color(1.0, 1.0, 1.0, 0.5)
		)

func _is_in_current_bounds(pos:Vector2i) -> bool:
	if pos.x < grid_origin.x || pos.y < grid_origin.y:
		return false
	var rel:Vector2i = pos - grid_origin
	return GridUtils.is_in_bounds(rel, mini(grid_size.x, grid_size.y))
