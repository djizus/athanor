class_name TelegraphSystem
extends Node2D

signal telegraph_added(id:int)
signal telegraph_resolved(id:int)

enum ShapeType {
	SINGLE_TILE,
	LINE,
	CONE,
	CIRCLE,
}

const TILE_WIDTH:float = 32.0
const TILE_HALF_WIDTH:float = TILE_WIDTH * 0.5
const TILE_HEIGHT:float = 16.0
const TILE_HALF_HEIGHT:float = TILE_HEIGHT * 0.5
const RESOLVE_ANIMATION_TIME:float = 0.25

var current_turn:int = 0
var active_telegraphs:Dictionary = {}

func _process(_delta:float)->void:
	if active_telegraphs.is_empty():
		return
	queue_redraw()

func set_current_turn(turn:int)->void:
	if current_turn == turn:
		return
	current_turn = turn
	queue_redraw()

func add_telegraph(id:int, data:Dictionary)->void:
	var _shape_type:int = int(data.get("shape_type", ShapeType.SINGLE_TILE))
	var _param_a:int = int(data.get("param_a", 0))
	var _param_b:int = int(data.get("param_b", 0))
	var _param_c:int = int(data.get("param_c", 0))
	var _source_tile:Vector2i = Vector2i(
		int(data.get("source_x", int(data.get("origin_x", 0)))),
		int(data.get("source_y", int(data.get("origin_y", 0))))
	)
	var _entry:Dictionary = {
		"shape_type": _shape_type,
		"param_a": _param_a,
		"param_b": _param_b,
		"param_c": _param_c,
		"source_tile": _source_tile,
		"damage": int(data.get("damage", 0)),
		"created_turn": int(data.get("created_turn", current_turn)),
		"resolves_turn": int(data.get("resolves_turn", current_turn + 1)),
		"resolved": bool(data.get("resolved", false)),
		"resolved_at": float(data.get("resolved_at", -1.0)),
		"tiles": _compute_tiles(_shape_type, _param_a, _param_b, _param_c, _source_tile),
	}
	active_telegraphs[id] = _entry
	telegraph_added.emit(id)
	queue_redraw()

func resolve_telegraph(id:int)->void:
	if !active_telegraphs.has(id):
		return
	var _entry:Dictionary = active_telegraphs[id]
	_entry["resolved"] = true
	_entry["resolved_at"] = Time.get_ticks_msec() / 1000.0
	active_telegraphs[id] = _entry
	telegraph_resolved.emit(id)
	queue_redraw()

func remove_telegraph(id:int)->void:
	if !active_telegraphs.has(id):
		return
	active_telegraphs.erase(id)
	queue_redraw()

func clear_all()->void:
	if active_telegraphs.is_empty():
		return
	active_telegraphs.clear()
	queue_redraw()

func tile_to_screen(tile:Vector2i)->Vector2:
	var x:float = (tile.x - tile.y) * TILE_HALF_WIDTH
	var y:float = (tile.x + tile.y) * TILE_HALF_HEIGHT
	return Vector2(x, y)

func _draw()->void:
	if active_telegraphs.is_empty():
		return

	for _id:Variant in active_telegraphs.keys():
		var _entry:Dictionary = active_telegraphs[_id]
		var _resolves_turn:int = int(_entry.get("resolves_turn", -1))
		var _is_resolving:bool = _resolves_turn == current_turn
		var _is_resolved:bool = bool(_entry.get("resolved", false))
		var _resolved_at:float = float(_entry.get("resolved_at", -1.0))

		if _is_resolved && _resolved_at > 0.0:
			var _elapsed:float = (Time.get_ticks_msec() / 1000.0) - _resolved_at
			if _elapsed > RESOLVE_ANIMATION_TIME:
				continue

		var _alpha:float = 0.4
		if _is_resolving || _is_resolved:
			_alpha = 1.0
			var _pulse:float = 0.85 + 0.15 * sin(Time.get_ticks_msec() / 90.0)
			_alpha *= _pulse

		var _tiles:Array = _entry.get("tiles", [])
		for _tile_variant:Variant in _tiles:
			var _tile:Vector2i = _tile_variant
			draw_colored_polygon(_diamond_points(tile_to_screen(_tile)), Color(1.0, 0.1, 0.1, _alpha))

func _compute_tiles(shape_type:int, param_a:int, param_b:int, param_c:int, source_tile:Vector2i)->Array[Vector2i]:
	var _tiles:Array[Vector2i] = []
	match shape_type:
		ShapeType.SINGLE_TILE:
			_tiles.append(Vector2i(param_a, param_b))
		ShapeType.LINE:
			var _direction:Vector2i = _direction_from_index(param_a)
			for _i:int in range(max(0, param_b)):
				_tiles.append(source_tile + (_direction * (_i + 1)))
		ShapeType.CONE:
			var _origin:Vector2i = Vector2i(param_b, param_c)
			for _offset:Vector2i in _cone_offsets(param_a):
				_tiles.append(_origin + _offset)
		ShapeType.CIRCLE:
			var _center:Vector2i = Vector2i(param_a, param_b)
			_tiles.append(_center)
			_tiles.append(_center + Vector2i.LEFT)
			_tiles.append(_center + Vector2i.RIGHT)
			_tiles.append(_center + Vector2i.UP)
			_tiles.append(_center + Vector2i.DOWN)

	return _unique_tiles(_tiles)

func _direction_from_index(index:int)->Vector2i:
	match posmod(index, 4):
		0:
			return Vector2i.UP
		1:
			return Vector2i.RIGHT
		2:
			return Vector2i.DOWN
		_:
			return Vector2i.LEFT

func _cone_offsets(direction:int)->Array[Vector2i]:
	match posmod(direction, 4):
		0:
			return [Vector2i.UP, Vector2i.UP + Vector2i.LEFT, Vector2i.UP + Vector2i.RIGHT]
		1:
			return [Vector2i.RIGHT, Vector2i.RIGHT + Vector2i.UP, Vector2i.RIGHT + Vector2i.DOWN]
		2:
			return [Vector2i.DOWN, Vector2i.DOWN + Vector2i.LEFT, Vector2i.DOWN + Vector2i.RIGHT]
		_:
			return [Vector2i.LEFT, Vector2i.LEFT + Vector2i.UP, Vector2i.LEFT + Vector2i.DOWN]

func _diamond_points(center:Vector2)->PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0.0, -TILE_HALF_HEIGHT),
		center + Vector2(TILE_HALF_WIDTH, 0.0),
		center + Vector2(0.0, TILE_HALF_HEIGHT),
		center + Vector2(-TILE_HALF_WIDTH, 0.0),
	])

func _unique_tiles(tiles:Array[Vector2i])->Array[Vector2i]:
	var _result:Array[Vector2i] = []
	var _seen:Dictionary = {}
	for _tile:Vector2i in tiles:
		if _seen.has(_tile):
			continue
		_seen[_tile] = true
		_result.append(_tile)
	return _result
