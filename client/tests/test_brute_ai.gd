extends SceneTree

func _pass(pass_count:int, message:String) -> int:
	print("  PASS: %s" % message)
	return pass_count + 1

func _fail(fail_count:int, message:String) -> int:
	print("  FAIL: %s" % message)
	return fail_count + 1

func _grid_state(blocked:Array[Vector2i], occupied:Array[Vector2i], grid_size:int = 8) -> Dictionary:
	return {
		"blocked_cells": blocked,
		"occupied_cells": occupied,
		"grid_size": grid_size,
	}

func _init() -> void:
	var pass_count:int = 0
	var fail_count:int = 0

	var brute_script:GDScript = preload("res://scripts/combat/ai/brute_ai.gd")
	var brute = brute_script.new()

	var chase_intent:Dictionary = brute.compute_intent(
		Vector2i(0, 0),
		Vector2i(3, 4),
		_grid_state([], [Vector2i(0, 0), Vector2i(3, 4)])
	)
	if chase_intent["move_to"] == Vector2i(1, 0):
		pass_count = _pass(pass_count, "chase moves one tile using deterministic axis priority")
	else:
		fail_count = _fail(fail_count, "expected move_to (1,0), got %s" % [str(chase_intent["move_to"])])

	var adjacent_intent:Dictionary = brute.compute_intent(
		Vector2i(1, 0),
		Vector2i(0, 0),
		_grid_state([], [Vector2i(1, 0), Vector2i(0, 0)])
	)
	var adjacent_cells:Array[Vector2i] = adjacent_intent["telegraph_cells"]
	if adjacent_cells.size() == 1 && adjacent_cells[0] == Vector2i(0, 0) && is_equal_approx(adjacent_intent["telegraph_damage"], 20.0):
		pass_count = _pass(pass_count, "adjacent brute telegraphs player cell with 20 damage")
	else:
		fail_count = _fail(fail_count, "adjacent telegraph mismatch: cells=%s dmg=%s" % [str(adjacent_cells), str(adjacent_intent["telegraph_damage"])])

	var blocked_path_intent:Dictionary = brute.compute_intent(
		Vector2i(1, 1),
		Vector2i(4, 1),
		_grid_state([], [Vector2i(1, 1), Vector2i(2, 1), Vector2i(4, 1)])
	)
	if blocked_path_intent["move_to"] == Vector2i(1, 1):
		pass_count = _pass(pass_count, "blocked primary and secondary path keeps brute in place")
	else:
		fail_count = _fail(fail_count, "blocked-path expected stay at (1,1), got %s" % [str(blocked_path_intent["move_to"])])

	var surrounded_intent:Dictionary = brute.compute_intent(
		Vector2i(1, 1),
		Vector2i(4, 4),
		_grid_state(
			[Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 0), Vector2i(1, 2)],
			[Vector2i(1, 1), Vector2i(4, 4)]
		)
	)
	if surrounded_intent["move_to"] == Vector2i(1, 1) && surrounded_intent["telegraph_cells"].is_empty():
		pass_count = _pass(pass_count, "surrounded brute stays with no telegraph")
	else:
		fail_count = _fail(fail_count, "surrounded expected stay+no telegraph, got move=%s telegraph=%s" % [str(surrounded_intent["move_to"]), str(surrounded_intent["telegraph_cells"])])

	print("\n%d passed, %d failed" % [pass_count, fail_count])
	quit(1 if fail_count > 0 else 0)
