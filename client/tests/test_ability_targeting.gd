extends SceneTree


func _pass(pass_count:int, message:String) -> int:
	print("  PASS: %s" % message)
	return pass_count + 1


func _fail(fail_count:int, message:String) -> int:
	print("  FAIL: %s" % message)
	return fail_count + 1


func _cells_to_key(cells:Array[Vector2i]) -> String:
	var parts:PackedStringArray = []
	for cell in cells:
		parts.append("%d,%d" % [cell.x, cell.y])
	parts.sort()
	return "|".join(parts)


func _expect_cells(pass_count:int, fail_count:int, label:String, actual:Array[Vector2i], expected:Array[Vector2i]) -> Array[int]:
	if _cells_to_key(actual) == _cells_to_key(expected):
		pass_count = _pass(pass_count, label)
	else:
		fail_count = _fail(fail_count, "%s expected=%s actual=%s" % [label, _cells_to_key(expected), _cells_to_key(actual)])
	return [pass_count, fail_count]


func _make_ability(ability_script:GDScript, target_mode:int, range_tiles:int) -> AbilityResource:
	var ability:AbilityResource = ability_script.new()
	ability.target_mode = target_mode
	ability.range_tiles = range_tiles
	return ability


func _init() -> void:
	var pass_count:int = 0
	var fail_count:int = 0
	var enums_script:GDScript = preload("res://scripts/combat/combat_enums.gd")
	var ability_script:GDScript = preload("res://scripts/resources/ability_resource.gd")
	var targeting_script:GDScript = preload("res://scripts/combat/ability_targeting.gd")

	var targeting = targeting_script.new()

	var adjacent_ability:AbilityResource = _make_ability(ability_script, enums_script.TargetMode.ADJACENT, 1)
	var line_ability:AbilityResource = _make_ability(ability_script, enums_script.TargetMode.LINE, 3)
	var self_ability:AbilityResource = _make_ability(ability_script, enums_script.TargetMode.SELF, 0)

	var no_blocked:Array[Vector2i] = []
	var adjacent_center:Array[Vector2i] = targeting.get_valid_targets(adjacent_ability, Vector2i(4, 4), no_blocked, 8)
	var result_center:Array[int] = _expect_cells(
		pass_count,
		fail_count,
		"ADJACENT at (4,4) returns four neighbors",
		adjacent_center,
		[Vector2i(3, 4), Vector2i(5, 4), Vector2i(4, 3), Vector2i(4, 5)]
	)
	pass_count = result_center[0]
	fail_count = result_center[1]

	var adjacent_edge:Array[Vector2i] = targeting.get_valid_targets(adjacent_ability, Vector2i(0, 0), no_blocked, 8)
	var result_edge:Array[int] = _expect_cells(
		pass_count,
		fail_count,
		"ADJACENT at (0,0) is bounded to two in-bounds cells",
		adjacent_edge,
		[Vector2i(1, 0), Vector2i(0, 1)]
	)
	pass_count = result_edge[0]
	fail_count = result_edge[1]

	var blocked_adjacent:Array[Vector2i] = [Vector2i(1, 0)]
	var adjacent_with_block:Array[Vector2i] = targeting.get_valid_targets(adjacent_ability, Vector2i(0, 0), blocked_adjacent, 8)
	var result_blocked_adj:Array[int] = _expect_cells(
		pass_count,
		fail_count,
		"ADJACENT excludes blocked tiles",
		adjacent_with_block,
		[Vector2i(0, 1)]
	)
	pass_count = result_blocked_adj[0]
	fail_count = result_blocked_adj[1]

	var line_center:Array[Vector2i] = targeting.get_valid_targets(line_ability, Vector2i(4, 4), no_blocked, 8)
	if line_center.size() == 12:
		pass_count = _pass(pass_count, "LINE at (4,4) range=3 returns 12 cells")
	else:
		fail_count = _fail(fail_count, "LINE expected 12 cells, got %d" % line_center.size())

	var blocked_line:Array[Vector2i] = [Vector2i(4, 2)]
	var line_with_block:Array[Vector2i] = targeting.get_valid_targets(line_ability, Vector2i(4, 4), blocked_line, 8)
	if line_with_block.has(Vector2i(4, 3)) && !line_with_block.has(Vector2i(4, 2)) && !line_with_block.has(Vector2i(4, 1)):
		pass_count = _pass(pass_count, "LINE stops at blocked tile when traversing north")
	else:
		fail_count = _fail(fail_count, "north line should include (4,3) and stop before blocked (4,2)")

	var single_line:Array[Vector2i] = targeting.get_line_targets(Vector2i(4, 4), Vector2i(0, -1), 3, blocked_line, 8)
	var result_single_line:Array[int] = _expect_cells(
		pass_count,
		fail_count,
		"get_line_targets returns truncated line up to obstacle",
		single_line,
		[Vector2i(4, 3)]
	)
	pass_count = result_single_line[0]
	fail_count = result_single_line[1]

	var self_targets:Array[Vector2i] = targeting.get_valid_targets(self_ability, Vector2i(4, 4), no_blocked, 8)
	var result_self:Array[int] = _expect_cells(
		pass_count,
		fail_count,
		"SELF mode returns only player tile",
		self_targets,
		[Vector2i(4, 4)]
	)
	pass_count = result_self[0]
	fail_count = result_self[1]

	print("\n%d passed, %d failed" % [pass_count, fail_count])
	quit(1 if fail_count > 0 else 0)
