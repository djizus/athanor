class_name GridCursor
extends Sprite2D

signal tile_hovered(pos:Vector2i)
signal tile_clicked(pos:Vector2i)

const HOVER_COLOR:Color = Color(1.0, 0.95, 0.1, 0.7)
const TILE_WIDTH:float = 32.0
const TILE_HEIGHT:float = 16.0
const HALF_W:float = TILE_WIDTH * 0.5
const HALF_H:float = TILE_HEIGHT * 0.5

var _hovered_tile:Vector2i = Vector2i(-999, -999)
var _has_valid_hover:bool = false

func _ready() -> void:
	set_process(true)

func _process(_delta:float) -> void:
	var grid:Node = _get_combat_grid()
	if grid == null:
		_set_hover_invalid()
		return

	if grid.has_method("world_to_grid"):
		var mouse_global:Vector2 = get_global_mouse_position()
		var snapped:Vector2i = grid.world_to_grid(mouse_global)
		if grid.has_method("is_cell_valid") && grid.is_cell_valid(snapped):
			_update_hover(snapped)
			return

	_set_hover_invalid()

func _unhandled_input(event:InputEvent) -> void:
	if !_has_valid_hover:
		return
	if event is InputEventMouseButton:
		var mouse_event:InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT && mouse_event.pressed:
			tile_clicked.emit(_hovered_tile)

func _draw() -> void:
	if !_has_valid_hover:
		return

	var grid:Node = _get_combat_grid()
	if grid == null || !grid.has_method("grid_to_world"):
		return

	var center_local:Vector2 = to_local(grid.grid_to_world(_hovered_tile))
	var points:PackedVector2Array = PackedVector2Array([
		center_local + Vector2(0.0, -HALF_H),
		center_local + Vector2(HALF_W, 0.0),
		center_local + Vector2(0.0, HALF_H),
		center_local + Vector2(-HALF_W, 0.0),
	])
	draw_colored_polygon(points, HOVER_COLOR)

func _get_combat_grid() -> Node:
	if get_parent() == null:
		return null
	return get_parent()

func _update_hover(tile:Vector2i) -> void:
	if _has_valid_hover && _hovered_tile == tile:
		return
	_hovered_tile = tile
	_has_valid_hover = true
	tile_hovered.emit(tile)
	queue_redraw()

func _set_hover_invalid() -> void:
	if !_has_valid_hover:
		return
	_has_valid_hover = false
	_hovered_tile = Vector2i(-999, -999)
	queue_redraw()
