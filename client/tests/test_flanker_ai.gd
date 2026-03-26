extends SceneTree

func _pass(pass_count:int, message:String) -> int:
	print("  PASS: %s" % message)
	return pass_count + 1

func _fail(fail_count:int, message:String) -> int:
	print("  FAIL: %s" % message)
	return fail_count + 1

func _grid_state(blocked:Array[Vector2i], occupied:Array[Vector2i], player_last_move_dir:Vector2i, grid_size:int = 8) -> Dictionary:
	return {
		"blocked_cells": blocked,
		"occupied_cells": occupied,
		"grid_size": grid_size,
		"player_last_move_dir": player_last_move_dir,
	}

func _init() -> void:
	var pass_count:int = 0
	var fail_count:int = 0

	var flanker_script:GDScript = preload("res://scripts/combat/ai/flanker_ai.gd")
	var flanker = flanker_script.new()

	var flank_intent:Dictionary = flanker.compute_intent(
		Vector2i(1, 4),
		Vector2i(4, 4),
		_grid_state([], [Vector2i(1, 4), Vector2i(4, 4)], Vector2i(1, 0))
	)
	if flank_intent["move_to"] == Vector2i(3, 4):
		pass_count = _pass(pass_count, "flanker moves two tiles toward behind-player flank target")
	else:
		fail_count = _fail(fail_count, "flank expected move_to (3,4), got %s" % [str(flank_intent["move_to"])])

	var flank_cells:Array[Vector2i] = flank_intent["telegraph_cells"]
	if flank_cells.size() == 1 && flank_cells[0] == Vector2i(4, 4) && is_equal_approx(flank_intent["telegraph_damage"], 18.0):
		pass_count = _pass(pass_count, "adjacent after flank telegraphs player with 18 damage")
	else:
		fail_count = _fail(fail_count, "flank telegraph mismatch: cells=%s dmg=%s" % [str(flank_cells), str(flank_intent["telegraph_damage"])])

	var fallback_intent:Dictionary = flanker.compute_intent(
		Vector2i(1, 1),
		Vector2i(4, 1),
		_grid_state([Vector2i(2, 1), Vector2i(1, 2)], [Vector2i(1, 1), Vector2i(4, 1)], Vector2i(0, -1))
	)
	if fallback_intent["move_to"] == Vector2i(1, 1):
		pass_count = _pass(pass_count, "flanker falls back to brute behavior when flank cannot progress")
	else:
		fail_count = _fail(fail_count, "fallback expected stay at (1,1), got %s" % [str(fallback_intent["move_to"])])

	var blocked_intent:Dictionary = flanker.compute_intent(
		Vector2i(2, 2),
		Vector2i(4, 2),
		_grid_state(
			[Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 1), Vector2i(2, 3)],
			[Vector2i(2, 2), Vector2i(4, 2)],
			Vector2i(1, 0)
		)
	)
	if blocked_intent["move_to"] == Vector2i(2, 2) && blocked_intent["telegraph_cells"].is_empty():
		pass_count = _pass(pass_count, "fully blocked flanker stays and emits no telegraph")
	else:
		fail_count = _fail(fail_count, "blocked expected stay+no telegraph, got move=%s telegraph=%s" % [str(blocked_intent["move_to"]), str(blocked_intent["telegraph_cells"])])

	print("\n%d passed, %d failed" % [pass_count, fail_count])
	quit(1 if fail_count > 0 else 0)
