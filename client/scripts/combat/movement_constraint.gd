class_name MovementConstraint
extends Node2D

signal moved(from:Vector2i, to:Vector2i)
signal movement_complete

@export var resource_node:ResourceNode
@export var tilemap:TileMapLayer
@export var astargrid_resource:AstarGridResource

@export var overlay_color:Color = Color(0.2, 0.45, 1.0, 0.35)

var tile_x:int = 0
var tile_y:int = 0

var _enabled:bool = true
var _stamina_resource:StaminaResource
var _combat_stats_resource:CombatStatsResource

func _ready()->void:
	if resource_node != null:
		_stamina_resource = resource_node.get_resource("stamina")
		_combat_stats_resource = resource_node.get_resource("combat_stats")

	if _stamina_resource != null:
		_stamina_resource.updated.connect(queue_redraw)

	if tilemap != null:
		var _start_tile:Vector2i = tilemap.local_to_map(tilemap.to_local(global_position))
		tile_x = _start_tile.x
		tile_y = _start_tile.y

	queue_redraw()

func set_enabled(active:bool)->void:
	_enabled = active
	visible = active
	set_process(active)
	set_physics_process(active)
	queue_redraw()

func get_reachable_tiles()->Array[Vector2i]:
	if !_enabled:
		return []
	if tilemap == null || _stamina_resource == null || _combat_stats_resource == null:
		return []

	var _move_cost:int = max(_combat_stats_resource.move_cost, 1)
	var _max_steps:int = int(_stamina_resource.value / _move_cost)
	var _start:Vector2i = Vector2i(tile_x, tile_y)

	var _reachable:Array[Vector2i] = [_start]
	var _queue:Array[Vector2i] = [_start]
	var _distance:Dictionary = {_start: 0}

	while !_queue.is_empty():
		var _current:Vector2i = _queue.pop_front()
		var _steps:int = _distance[_current]
		if _steps >= _max_steps:
			continue

		for _offset:Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var _next:Vector2i = _current + _offset
			if _distance.has(_next):
				continue
			if !_is_walkable(_next):
				continue

			_distance[_next] = _steps + 1
			_queue.push_back(_next)
			_reachable.push_back(_next)

	return _reachable

func try_move(direction:Vector2i)->bool:
	if !_enabled:
		return false
	if abs(direction.x) + abs(direction.y) != 1:
		return false
	if _stamina_resource == null || _combat_stats_resource == null:
		return false

	var _from:Vector2i = Vector2i(tile_x, tile_y)
	var _target:Vector2i = _from + direction
	var _reachable:Array[Vector2i] = get_reachable_tiles()
	if !_reachable.has(_target):
		return false

	var _move_cost:int = max(_combat_stats_resource.move_cost, 1)
	if !_stamina_resource.spend(_move_cost):
		return false

	tile_x = _target.x
	tile_y = _target.y
	moved.emit(_from, _target)
	snap_to_tile(_target)
	queue_redraw()
	return true

func snap_to_tile(tile:Vector2i)->void:
	if tilemap == null:
		movement_complete.emit()
		return

	var _target_local:Vector2 = tilemap.map_to_local(tile)
	var _target_global:Vector2 = tilemap.to_global(_target_local)
	var _tween:Tween = create_tween()
	_tween.tween_property(self, "global_position", _target_global, 0.15)
	_tween.finished.connect(movement_complete.emit, CONNECT_ONE_SHOT)

func _draw()->void:
	if !_enabled || tilemap == null:
		return

	var _tile_size:Vector2 = Vector2(64, 64)
	if tilemap.tile_set != null:
		_tile_size = tilemap.tile_set.tile_size

	for _tile:Vector2i in get_reachable_tiles():
		if _tile == Vector2i(tile_x, tile_y):
			continue
		var _tile_global:Vector2 = tilemap.to_global(tilemap.map_to_local(_tile))
		var _tile_local:Vector2 = to_local(_tile_global)
		var _rect := Rect2(_tile_local - (_tile_size * 0.5), _tile_size)
		draw_rect(_rect, overlay_color, true)

func _is_walkable(tile:Vector2i)->bool:
	if astargrid_resource == null || astargrid_resource.value == null:
		return true
	var _grid:AStarGrid2D = astargrid_resource.value
	if !_grid.is_in_boundsv(tile):
		return false
	return !_grid.is_point_solid(tile)
