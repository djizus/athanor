extends SceneTree

func _pass(pass_count:int, message:String) -> int:
	print("  PASS: %s" % message)
	return pass_count + 1

func _fail(fail_count:int, message:String) -> int:
	print("  FAIL: %s" % message)
	return fail_count + 1

func _init() -> void:
	var pass_count:int = 0
	var fail_count:int = 0

	var grid_utils:GDScript = preload("res://scripts/combat/grid_utils.gd")

	var manhattan:int = grid_utils.manhattan_distance(Vector2i(0, 0), Vector2i(3, 4))
	if manhattan == 7:
		pass_count = _pass(pass_count, "manhattan_distance((0,0),(3,4)) equals 7")
	else:
		fail_count = _fail(fail_count, "manhattan expected 7, got %d" % manhattan)

	if grid_utils.is_in_bounds(Vector2i(7, 7), 8):
		pass_count = _pass(pass_count, "is_in_bounds((7,7),8) is true")
	else:
		fail_count = _fail(fail_count, "is_in_bounds((7,7),8) expected true")

	if !grid_utils.is_in_bounds(Vector2i(8, 0), 8):
		pass_count = _pass(pass_count, "is_in_bounds((8,0),8) is false")
	else:
		fail_count = _fail(fail_count, "is_in_bounds((8,0),8) expected false")

	var adjacent:Array[Vector2i] = grid_utils.get_adjacent_cells(Vector2i(3, 3))
	if adjacent.size() == 4:
		pass_count = _pass(pass_count, "get_adjacent_cells((3,3)) returns 4 cells")
	else:
		fail_count = _fail(fail_count, "adjacent count expected 4, got %d" % adjacent.size())

	var no_blocked:Array[Vector2i] = []
	var reachable_open:Dictionary = grid_utils.flood_fill_reachable(Vector2i(4, 4), 2, no_blocked, 8)
	if reachable_open.size() == 13:
		pass_count = _pass(pass_count, "flood_fill from center with no obstacles reaches 13 cells at cost<=2")
	else:
		fail_count = _fail(fail_count, "open flood fill expected 13 cells, got %d" % reachable_open.size())

	var blocked:Array[Vector2i] = [Vector2i(4, 5)]
	var reachable_blocked:Dictionary = grid_utils.flood_fill_reachable(Vector2i(4, 4), 2, blocked, 8)
	if !reachable_blocked.has(Vector2i(4, 5)):
		pass_count = _pass(pass_count, "flood_fill excludes blocked cells")
	else:
		fail_count = _fail(fail_count, "blocked cell (4,5) should not be reachable")

	print("\n%d passed, %d failed" % [pass_count, fail_count])
	quit(1 if fail_count > 0 else 0)
