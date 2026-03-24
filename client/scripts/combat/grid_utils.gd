class_name GridUtils
extends RefCounted

static func manhattan_distance(a:Vector2i, b:Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

static func is_in_bounds(pos:Vector2i, grid_size:int) -> bool:
	return pos.x >= 0 && pos.y >= 0 && pos.x < grid_size && pos.y < grid_size

static func get_adjacent_cells(pos:Vector2i) -> Array[Vector2i]:
	return [
		Vector2i(pos.x - 1, pos.y),
		Vector2i(pos.x + 1, pos.y),
		Vector2i(pos.x, pos.y - 1),
		Vector2i(pos.x, pos.y + 1),
	]

static func flood_fill_reachable(start:Vector2i, max_cost:int, blocked:Array[Vector2i], grid_size:int) -> Dictionary:
	var reachable:Dictionary = {}
	if max_cost < 0:
		return reachable
	if !is_in_bounds(start, grid_size):
		return reachable

	var blocked_map:Dictionary = {}
	for cell in blocked:
		blocked_map[cell] = true

	if blocked_map.has(start):
		return reachable

	var queue:Array[Vector2i] = [start]
	reachable[start] = 0

	while !queue.is_empty():
		var current:Vector2i = queue.pop_front()
		var current_cost:int = reachable[current]
		if current_cost >= max_cost:
			continue

		for next_cell in get_adjacent_cells(current):
			if !is_in_bounds(next_cell, grid_size):
				continue
			if blocked_map.has(next_cell):
				continue

			var next_cost:int = current_cost + 1
			if next_cost > max_cost:
				continue

			if !reachable.has(next_cell) || next_cost < int(reachable[next_cell]):
				reachable[next_cell] = next_cost
				queue.push_back(next_cell)

	return reachable
