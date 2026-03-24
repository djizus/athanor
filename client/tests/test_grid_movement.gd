extends SceneTree

class MockCombatGrid:
	extends Node2D

	var highlighted_cells:Array[Vector2i] = []

	func clear_overlay() -> void:
		highlighted_cells.clear()

	func highlight_cells(cells:Array[Vector2i], _state:int) -> void:
		highlighted_cells = cells.duplicate()

	func grid_to_world(cell:Vector2i) -> Vector2:
		return Vector2((cell.x - cell.y) * 16.0, (cell.x + cell.y) * 8.0)

var _move_completed_count:int = 0
var _move_cancelled_count:int = 0

func _pass(pass_count:int, message:String) -> int:
	print("  PASS: %s" % message)
	return pass_count + 1

func _fail(fail_count:int, message:String) -> int:
	print("  FAIL: %s" % message)
	return fail_count + 1

func _init() -> void:
	var pass_count:int = 0
	var fail_count:int = 0

	var movement_script:GDScript = preload("res://scripts/combat/grid_movement.gd")
	var movement = movement_script.new()
	var combat_grid = MockCombatGrid.new()
	var player := Node2D.new()

	var stamina_script:GDScript = preload("res://scripts/resources/stamina_resource.gd")
	var stamina:StaminaResource = stamina_script.new()
	var stats_script:GDScript = preload("res://scripts/resources/combat_stats_resource.gd")
	var stats:CombatStatsResource = stats_script.new()

	stamina.value = 100
	stats.grid_pos = Vector2i(4, 4)

	movement.grid_size = 8
	movement.move_duration_per_tile = 0.0
	movement.combat_grid = combat_grid
	movement.player_node = player
	movement.stamina = stamina
	movement.combat_stats = stats

	root.add_child(combat_grid)
	root.add_child(player)
	root.add_child(movement)

	movement.move_completed.connect(_on_move_completed)
	movement.move_cancelled.connect(_on_move_cancelled)

	movement.refresh_reachable()
	if movement.reachable_cells.has(Vector2i(7, 7)) && movement.reachable_cells.has(Vector2i(0, 4)):
		pass_count = _pass(pass_count, "100 stamina reaches far in-bounds cells")
	else:
		fail_count = _fail(fail_count, "100 stamina expected broad reachability from center")

	stamina.value = 30
	movement.refresh_reachable()
	if movement.reachable_cells.has(Vector2i(7, 4)) && !movement.reachable_cells.has(Vector2i(0, 4)):
		pass_count = _pass(pass_count, "30 stamina limits reach to max 3 tiles")
	else:
		fail_count = _fail(fail_count, "30 stamina reachability did not match expected distance cap")

	var blocked_cells:Array[Vector2i] = [Vector2i(5, 4)]
	var occupied_cells:Array[Vector2i] = [Vector2i(4, 5)]
	movement.set_blocked_cells(blocked_cells)
	movement.set_occupied_cells(occupied_cells)
	movement.refresh_reachable()
	if !movement.reachable_cells.has(Vector2i(5, 4)) && !movement.reachable_cells.has(Vector2i(4, 5)):
		pass_count = _pass(pass_count, "blocked and occupied cells are excluded")
	else:
		fail_count = _fail(fail_count, "blocked or occupied cells appeared in reachable set")

	var no_blocked:Array[Vector2i] = []
	var no_occupied:Array[Vector2i] = []
	movement.set_blocked_cells(no_blocked)
	movement.set_occupied_cells(no_occupied)
	stamina.value = 100
	stats.grid_pos = Vector2i(4, 4)
	movement.refresh_reachable()

	var moved:bool = await movement.try_move_to(Vector2i(7, 4))
	if moved && stamina.value == 70 && stats.grid_pos == Vector2i(7, 4):
		pass_count = _pass(pass_count, "moving 3 tiles deducts 30 stamina and updates grid_pos")
	else:
		fail_count = _fail(fail_count, "expected move success with stamina=70 at (7,4); got success=%s stamina=%d pos=%s" % [str(moved), stamina.value, str(stats.grid_pos)])

	stamina.value = 0
	movement.refresh_reachable()
	var failed_move:bool = await movement.try_move_to(Vector2i(7, 5))
	if !failed_move:
		pass_count = _pass(pass_count, "cannot move when stamina is 0")
	else:
		fail_count = _fail(fail_count, "expected movement failure at 0 stamina")

	if _move_completed_count >= 1 && _move_cancelled_count >= 1:
		pass_count = _pass(pass_count, "move_completed and move_cancelled signals emitted")
	else:
		fail_count = _fail(fail_count, "expected completed>=1 and cancelled>=1, got completed=%d cancelled=%d" % [_move_completed_count, _move_cancelled_count])

	print("\n%d passed, %d failed" % [pass_count, fail_count])
	quit(1 if fail_count > 0 else 0)

func _on_move_completed(_from:Vector2i, _to:Vector2i) -> void:
	_move_completed_count += 1

func _on_move_cancelled() -> void:
	_move_cancelled_count += 1
