class_name DebugOverlay
extends Node2D

const GRID_SIZE:int = 8
const TILE_HALF_WIDTH:float = 16.0
const TILE_HALF_HEIGHT:float = 8.0

var enabled:bool = false
var grid_data:Dictionary = {}
var telegraphs:Array = []
var turn_index:int = 0

func _input(event:InputEvent)->void:
	if event is InputEventKey && event.pressed && !event.echo && event.keycode == KEY_F3:
		enabled = !enabled
		queue_redraw()

func update_data(room_state:Dictionary, actors:Dictionary, telegraph_data:Dictionary, turn:int)->void:
	grid_data = {
		"room_state": room_state,
		"actors": actors,
	}
	telegraphs = telegraph_data.values() if telegraph_data != null else []
	turn_index = turn
	queue_redraw()

func tile_to_screen(tile:Vector2i)->Vector2:
	var x:float = (tile.x - tile.y) * TILE_HALF_WIDTH
	var y:float = (tile.x + tile.y) * TILE_HALF_HEIGHT
	return Vector2(x, y)

func _draw()->void:
	if !enabled:
		return

	var _font:Font = ThemeDB.fallback_font
	var _font_size:int = ThemeDB.fallback_font_size
	var _small_font_size:int = max(8, _font_size - 4)
	var _room_state:Dictionary = grid_data.get("room_state", {})
	var _actors:Dictionary = grid_data.get("actors", {})
	var _blocked_bitmap:int = int(_room_state.get("blocked_bitmap", 0))

	for _y:int in range(GRID_SIZE):
		for _x:int in range(GRID_SIZE):
			var _tile:Vector2i = Vector2i(_x, _y)
			var _screen:Vector2 = tile_to_screen(_tile)
			var _poly:PackedVector2Array = _diamond(_screen)
			var _bit_index:int = _y * GRID_SIZE + _x
			var _is_blocked:bool = ((_blocked_bitmap >> _bit_index) & 1) == 1
			var _fill_color:Color = Color(0.1, 0.8, 0.1, 0.18)
			if _is_blocked:
				_fill_color = Color(0.9, 0.15, 0.15, 0.25)

			draw_colored_polygon(_poly, _fill_color)
			draw_polyline(_closed_polyline(_poly), Color(1.0, 1.0, 1.0, 0.5), 1.0)

			if _font != null:
				draw_string(_font, _screen + Vector2(-10.0, 3.0), "(%d,%d)" % [_x, _y], HORIZONTAL_ALIGNMENT_LEFT, -1.0, _small_font_size, Color(1.0, 1.0, 1.0, 0.65))

	for _key:Variant in _actors.keys():
		var _actor:Dictionary = _actors[_key]
		var _tile:Vector2i = Vector2i(int(_actor.get("pos_x", 0)), int(_actor.get("pos_y", 0)))
		var _screen:Vector2 = tile_to_screen(_tile)
		var _label:String = "%s %d/%d" % [
			str(_actor.get("name", "A%s" % str(_key))),
			int(_actor.get("hp", 0)),
			max(1, int(_actor.get("max_hp", 1))),
		]
		draw_circle(_screen, 6.0, Color(0.1, 0.75, 1.0, 0.9))
		if _font != null:
			draw_string(_font, _screen + Vector2(8.0, -8.0), _label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _small_font_size, Color(1.0, 1.0, 1.0, 0.95))

	for _telegraph:Variant in telegraphs:
		if !(_telegraph is Dictionary):
			continue
		var _tiles:Array = (_telegraph as Dictionary).get("tiles", [])
		for _tile_variant:Variant in _tiles:
			var _tile:Vector2i = _tile_variant
			var _poly:PackedVector2Array = _diamond(tile_to_screen(_tile))
			draw_polyline(_closed_polyline(_poly), Color(1.0, 1.0, 0.2, 1.0), 2.0)

	if _font != null:
		draw_string(_font, Vector2(-120.0, -96.0), "Turn: %d" % turn_index, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _font_size, Color(1.0, 1.0, 1.0, 1.0))

func _diamond(center:Vector2)->PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0.0, -TILE_HALF_HEIGHT),
		center + Vector2(TILE_HALF_WIDTH, 0.0),
		center + Vector2(0.0, TILE_HALF_HEIGHT),
		center + Vector2(-TILE_HALF_WIDTH, 0.0),
	])

func _closed_polyline(poly:PackedVector2Array)->PackedVector2Array:
	var _closed:PackedVector2Array = poly.duplicate()
	if _closed.size() > 0:
		_closed.append(_closed[0])
	return _closed
