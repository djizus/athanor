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

func _has_cell(cells:Array[Vector2i], wanted:Vector2i) -> bool:
	for cell in cells:
		if cell == wanted:
			return true
	return false

func _init() -> void:
	var pass_count:int = 0
	var fail_count:int = 0

	var caster_script:GDScript = preload("res://scripts/combat/ai/caster_ai.gd")
	var caster = caster_script.new()

	var retreat_intent:Dictionary = caster.compute_intent(
		Vector2i(4, 4),
		Vector2i(4, 2),
		_grid_state([], [Vector2i(4, 4), Vector2i(4, 2)])
	)
	if retreat_intent["move_to"] == Vector2i(4, 5):
		pass_count = _pass(pass_count, "caster retreats one tile away when distance < 3")
	else:
		fail_count = _fail(fail_count, "retreat expected (4,5), got %s" % [str(retreat_intent["move_to"])])

	var stay_intent:Dictionary = caster.compute_intent(
		Vector2i(4, 4),
		Vector2i(4, 0),
		_grid_state([], [Vector2i(4, 4), Vector2i(4, 0)])
	)
	if stay_intent["move_to"] == Vector2i(4, 4):
		pass_count = _pass(pass_count, "caster stays when distance >= 3")
	else:
		fail_count = _fail(fail_count, "stay expected (4,4), got %s" % [str(stay_intent["move_to"])])

	var aoe_mid:Array[Vector2i] = stay_intent["telegraph_cells"]
	if aoe_mid.size() == 6 && _has_cell(aoe_mid, Vector2i(3, 0)) && _has_cell(aoe_mid, Vector2i(5, 1)):
		pass_count = _pass(pass_count, "AOE around edge-clamped top row includes valid in-bounds cells")
	else:
		fail_count = _fail(fail_count, "edge AOE expected 6 valid cells, got %d (%s)" % [aoe_mid.size(), str(aoe_mid)])

	var corner_intent:Dictionary = caster.compute_intent(
		Vector2i(7, 7),
		Vector2i(0, 0),
		_grid_state([], [Vector2i(7, 7), Vector2i(0, 0)])
	)
	var aoe_corner:Array[Vector2i] = corner_intent["telegraph_cells"]
	if aoe_corner.size() == 4 && _has_cell(aoe_corner, Vector2i(0, 0)) && _has_cell(aoe_corner, Vector2i(1, 1)) && is_equal_approx(corner_intent["telegraph_damage"], 12.0):
		pass_count = _pass(pass_count, "corner AOE clamps to 4 cells with 12 damage")
	else:
		fail_count = _fail(fail_count, "corner AOE mismatch: size=%d cells=%s dmg=%s" % [aoe_corner.size(), str(aoe_corner), str(corner_intent["telegraph_damage"])])

	print("\n%d passed, %d failed" % [pass_count, fail_count])
	quit(1 if fail_count > 0 else 0)
