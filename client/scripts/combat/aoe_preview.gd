class_name AOEPreview
extends Node2D

signal target_confirmed(ability_index: int, target_mode: int, target_a: int, target_b: int)

@export var tilemap: TileMapLayer

var active: bool = false
var current_ability: AbilityResource = null
var preview_tiles: Array[Vector2i] = []
var player_tile: Vector2i = Vector2i.ZERO

var _hover_tile: Vector2i = Vector2i.ZERO

func _ready() -> void:
	set_process(true)

func show_preview(ability: AbilityResource, player_pos: Vector2i) -> void:
	current_ability = ability
	player_tile = player_pos
	active = current_ability != null
	preview_tiles.clear()
	queue_redraw()

func hide_preview() -> void:
	active = false
	current_ability = null
	preview_tiles.clear()
	queue_redraw()

func _process(_delta: float) -> void:
	if !active or current_ability == null:
		return

	var local_mouse: Vector2 = get_local_mouse_position()
	_hover_tile = screen_to_tile(local_mouse)
	preview_tiles = _compute_preview_tiles(_hover_tile)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if !active or current_ability == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if preview_tiles.is_empty():
			return
		var target_tile: Vector2i = _resolve_target_tile(_hover_tile)
		target_confirmed.emit(current_ability.id, current_ability.target_mode, target_tile.x, target_tile.y)

func _draw() -> void:
	if !active or preview_tiles.is_empty():
		return

	for tile: Vector2i in preview_tiles:
		var center: Vector2 = tile_to_screen(tile)
		var diamond: PackedVector2Array = PackedVector2Array([
			center + Vector2(0, -8),
			center + Vector2(16, 0),
			center + Vector2(0, 8),
			center + Vector2(-16, 0),
		])
		draw_colored_polygon(diamond, Color(1.0, 1.0, 0.0, 0.3))

func screen_to_tile(screen_pos: Vector2) -> Vector2i:
	var tx: float = (screen_pos.x / 16.0 + screen_pos.y / 8.0) / 2.0
	var ty: float = (screen_pos.y / 8.0 - screen_pos.x / 16.0) / 2.0
	return Vector2i(roundi(tx), roundi(ty))

func tile_to_screen(tile: Vector2i) -> Vector2:
	return Vector2((tile.x - tile.y) * 16, (tile.x + tile.y) * 8)

func _compute_preview_tiles(mouse_tile: Vector2i) -> Array[Vector2i]:
	match current_ability.target_mode:
		AbilityResource.TargetMode.SINGLE_TARGET:
			return _single_target_tiles(mouse_tile)
		AbilityResource.TargetMode.DIRECTIONAL:
			return _directional_tiles(mouse_tile)
		AbilityResource.TargetMode.POSITIONAL:
			return _positional_tiles(mouse_tile)
		AbilityResource.TargetMode.SELF:
			return [player_tile]
		_:
			return []

func _single_target_tiles(mouse_tile: Vector2i) -> Array[Vector2i]:
	if _manhattan(player_tile, mouse_tile) > 1:
		return []
	if !_tile_has_enemy(mouse_tile):
		return []
	if !_is_in_bounds(mouse_tile):
		return []
	return [mouse_tile]

func _directional_tiles(mouse_tile: Vector2i) -> Array[Vector2i]:
	var dir: Vector2i = _cardinal_direction(player_tile, mouse_tile)
	if dir == Vector2i.ZERO:
		return []

	if current_ability.id == AbilityResource.DASH:
		return _dash_tiles(dir)
	if current_ability.id == AbilityResource.CLEAVE:
		return _cleave_tiles(dir)

	# Fallback for any future directional skill.
	return _dash_tiles(dir)

func _positional_tiles(mouse_tile: Vector2i) -> Array[Vector2i]:
	if _manhattan(player_tile, mouse_tile) > 4:
		return []
	var tiles: Array[Vector2i] = [
		mouse_tile,
		mouse_tile + Vector2i(1, 0),
		mouse_tile + Vector2i(-1, 0),
		mouse_tile + Vector2i(0, 1),
		mouse_tile + Vector2i(0, -1),
	]
	return _filter_bounds(tiles)

func _dash_tiles(dir: Vector2i) -> Array[Vector2i]:
	var line: Array[Vector2i] = []
	for step: int in range(1, 4):
		line.append(player_tile + (dir * step))
	return _filter_bounds(line)

func _cleave_tiles(dir: Vector2i) -> Array[Vector2i]:
	var front: Vector2i = player_tile + dir
	var flank_a: Vector2i
	var flank_b: Vector2i
	if dir.x != 0:
		flank_a = front + Vector2i(0, 1)
		flank_b = front + Vector2i(0, -1)
	else:
		flank_a = front + Vector2i(1, 0)
		flank_b = front + Vector2i(-1, 0)
	return _filter_bounds([front, flank_a, flank_b])

func _filter_bounds(tiles: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tile: Vector2i in tiles:
		if _is_in_bounds(tile):
			result.append(tile)
	return result

func _resolve_target_tile(mouse_tile: Vector2i) -> Vector2i:
	match current_ability.target_mode:
		AbilityResource.TargetMode.SELF:
			return player_tile
		AbilityResource.TargetMode.DIRECTIONAL:
			var dir: Vector2i = _cardinal_direction(player_tile, mouse_tile)
			return player_tile + dir
		_:
			return mouse_tile

func _cardinal_direction(from_tile: Vector2i, to_tile: Vector2i) -> Vector2i:
	var delta: Vector2i = to_tile - from_tile
	if delta == Vector2i.ZERO:
		return Vector2i.ZERO
	if abs(delta.x) >= abs(delta.y):
		return Vector2i(signi(delta.x), 0)
	return Vector2i(0, signi(delta.y))

func _tile_has_enemy(tile: Vector2i) -> bool:
	if has_method("is_enemy_at_tile"):
		return bool(call("is_enemy_at_tile", tile))

	var parent_node: Node = get_parent()
	if parent_node != null and parent_node.has_method("is_enemy_at_tile"):
		return bool(parent_node.call("is_enemy_at_tile", tile))

	if tilemap == null:
		return false
	var tile_data: TileData = tilemap.get_cell_tile_data(tile)
	if tile_data == null:
		return false
	return bool(tile_data.get_custom_data("enemy"))

func _is_in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < 8 and tile.y >= 0 and tile.y < 8

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)
