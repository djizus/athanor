class_name ContractAIUtils
extends RefCounted

const DIRECTION_NORTH:int = 0
const DIRECTION_EAST:int = 1
const DIRECTION_SOUTH:int = 2
const DIRECTION_WEST:int = 3

static func choose_step_toward(from:Vector2i, to:Vector2i, blocked:Array[Vector2i], occupied:Array[Vector2i], grid_size:int) -> Dictionary:
	var dx:int = absi(to.x - from.x)
	var dy:int = absi(to.y - from.y)

	if GridUtils.manhattan_distance(from, to) <= 1:
		return {"pos": from, "moved": false}

	var prefer_x:bool = dx >= dy
	if prefer_x:
		var toward_x:Dictionary = _toward_x(from, to.x)
		if bool(toward_x.get("ok", false)):
			var toward_x_pos:Vector2i = toward_x.get("pos", from)
			if !is_blocked_or_occupied(toward_x_pos, blocked, occupied, grid_size):
				return {"pos": toward_x_pos, "moved": true}

		var toward_y:Dictionary = _toward_y(from, to.y)
		if bool(toward_y.get("ok", false)):
			var toward_y_pos:Vector2i = toward_y.get("pos", from)
			if !is_blocked_or_occupied(toward_y_pos, blocked, occupied, grid_size):
				return {"pos": toward_y_pos, "moved": true}
	else:
		var toward_y:Dictionary = _toward_y(from, to.y)
		if bool(toward_y.get("ok", false)):
			var toward_y_pos:Vector2i = toward_y.get("pos", from)
			if !is_blocked_or_occupied(toward_y_pos, blocked, occupied, grid_size):
				return {"pos": toward_y_pos, "moved": true}

		var toward_x:Dictionary = _toward_x(from, to.x)
		if bool(toward_x.get("ok", false)):
			var toward_x_pos:Vector2i = toward_x.get("pos", from)
			if !is_blocked_or_occupied(toward_x_pos, blocked, occupied, grid_size):
				return {"pos": toward_x_pos, "moved": true}

	return {"pos": from, "moved": false}


static func choose_step_toward_exact(from:Vector2i, to:Vector2i, blocked:Array[Vector2i], occupied:Array[Vector2i], grid_size:int) -> Dictionary:
	var dx:int = absi(to.x - from.x)
	var dy:int = absi(to.y - from.y)
	var prefer_x:bool = dx >= dy

	if prefer_x:
		var toward_x:Dictionary = _toward_x(from, to.x)
		if bool(toward_x.get("ok", false)):
			var toward_x_pos:Vector2i = toward_x.get("pos", from)
			if !is_blocked_or_occupied(toward_x_pos, blocked, occupied, grid_size):
				return {"pos": toward_x_pos, "moved": true}

		var toward_y:Dictionary = _toward_y(from, to.y)
		if bool(toward_y.get("ok", false)):
			var toward_y_pos:Vector2i = toward_y.get("pos", from)
			if !is_blocked_or_occupied(toward_y_pos, blocked, occupied, grid_size):
				return {"pos": toward_y_pos, "moved": true}
	else:
		var toward_y:Dictionary = _toward_y(from, to.y)
		if bool(toward_y.get("ok", false)):
			var toward_y_pos:Vector2i = toward_y.get("pos", from)
			if !is_blocked_or_occupied(toward_y_pos, blocked, occupied, grid_size):
				return {"pos": toward_y_pos, "moved": true}

		var toward_x:Dictionary = _toward_x(from, to.x)
		if bool(toward_x.get("ok", false)):
			var toward_x_pos:Vector2i = toward_x.get("pos", from)
			if !is_blocked_or_occupied(toward_x_pos, blocked, occupied, grid_size):
				return {"pos": toward_x_pos, "moved": true}

	return {"pos": from, "moved": false}


static func choose_step_away(from:Vector2i, player:Vector2i, blocked:Array[Vector2i], occupied:Array[Vector2i], grid_size:int, threshold:int) -> Dictionary:
	var dx:int = absi(player.x - from.x)
	var dy:int = absi(player.y - from.y)
	var dist:int = GridUtils.manhattan_distance(from, player)

	if dist >= threshold:
		return {"pos": from, "moved": false}

	var prefer_x:bool = dx >= dy
	if prefer_x:
		var away_x:Dictionary = _away_x(from, player.x)
		if bool(away_x.get("ok", false)):
			var away_x_pos:Vector2i = away_x.get("pos", from)
			if !is_blocked_or_occupied(away_x_pos, blocked, occupied, grid_size):
				return {"pos": away_x_pos, "moved": true}

		var away_y:Dictionary = _away_y(from, player.y)
		if bool(away_y.get("ok", false)):
			var away_y_pos:Vector2i = away_y.get("pos", from)
			if !is_blocked_or_occupied(away_y_pos, blocked, occupied, grid_size):
				return {"pos": away_y_pos, "moved": true}
	else:
		var away_y:Dictionary = _away_y(from, player.y)
		if bool(away_y.get("ok", false)):
			var away_y_pos:Vector2i = away_y.get("pos", from)
			if !is_blocked_or_occupied(away_y_pos, blocked, occupied, grid_size):
				return {"pos": away_y_pos, "moved": true}

		var away_x:Dictionary = _away_x(from, player.x)
		if bool(away_x.get("ok", false)):
			var away_x_pos:Vector2i = away_x.get("pos", from)
			if !is_blocked_or_occupied(away_x_pos, blocked, occupied, grid_size):
				return {"pos": away_x_pos, "moved": true}

	return {"pos": from, "moved": false}


static func direction_from_delta(from:Vector2i, to:Vector2i) -> int:
	var dx:int = absi(to.x - from.x)
	var dy:int = absi(to.y - from.y)

	if dx >= dy:
		if to.x >= from.x:
			return DIRECTION_EAST
		return DIRECTION_WEST

	if to.y >= from.y:
		return DIRECTION_SOUTH
	return DIRECTION_NORTH


static func step_in_direction(x:int, y:int, direction:int) -> Dictionary:
	if direction == DIRECTION_NORTH:
		if y == 0:
			return {"x": x, "y": y, "ok": false}
		return {"x": x, "y": y - 1, "ok": true}

	if direction == DIRECTION_EAST:
		if x >= 7:
			return {"x": x, "y": y, "ok": false}
		return {"x": x + 1, "y": y, "ok": true}

	if direction == DIRECTION_SOUTH:
		if y >= 7:
			return {"x": x, "y": y, "ok": false}
		return {"x": x, "y": y + 1, "ok": true}

	if direction == DIRECTION_WEST:
		if x == 0:
			return {"x": x, "y": y, "ok": false}
		return {"x": x - 1, "y": y, "ok": true}

	return {"x": x, "y": y, "ok": false}


static func opposite_direction(dir:int) -> int:
	if dir == DIRECTION_NORTH:
		return DIRECTION_SOUTH
	if dir == DIRECTION_EAST:
		return DIRECTION_WEST
	if dir == DIRECTION_SOUTH:
		return DIRECTION_NORTH
	return DIRECTION_EAST


static func is_blocked_or_occupied(pos:Vector2i, blocked:Array[Vector2i], occupied:Array[Vector2i], grid_size:int) -> bool:
	if !GridUtils.is_in_bounds(pos, grid_size):
		return true
	if blocked.has(pos):
		return true
	if occupied.has(pos):
		return true
	return false


static func _toward_x(from:Vector2i, to_x:int) -> Dictionary:
	if to_x > from.x:
		if from.x >= 7:
			return {"pos": from, "ok": false}
		return {"pos": Vector2i(from.x + 1, from.y), "ok": true}

	if to_x < from.x:
		if from.x == 0:
			return {"pos": from, "ok": false}
		return {"pos": Vector2i(from.x - 1, from.y), "ok": true}

	return {"pos": from, "ok": false}


static func _toward_y(from:Vector2i, to_y:int) -> Dictionary:
	if to_y > from.y:
		if from.y >= 7:
			return {"pos": from, "ok": false}
		return {"pos": Vector2i(from.x, from.y + 1), "ok": true}

	if to_y < from.y:
		if from.y == 0:
			return {"pos": from, "ok": false}
		return {"pos": Vector2i(from.x, from.y - 1), "ok": true}

	return {"pos": from, "ok": false}


static func _away_x(from:Vector2i, player_x:int) -> Dictionary:
	if from.x >= player_x:
		if from.x >= 7:
			return {"pos": from, "ok": false}
		return {"pos": Vector2i(from.x + 1, from.y), "ok": true}

	if from.x > 0:
		return {"pos": Vector2i(from.x - 1, from.y), "ok": true}

	return {"pos": from, "ok": false}


static func _away_y(from:Vector2i, player_y:int) -> Dictionary:
	if from.y >= player_y:
		if from.y >= 7:
			return {"pos": from, "ok": false}
		return {"pos": Vector2i(from.x, from.y + 1), "ok": true}

	if from.y > 0:
		return {"pos": Vector2i(from.x, from.y - 1), "ok": true}

	return {"pos": from, "ok": false}
