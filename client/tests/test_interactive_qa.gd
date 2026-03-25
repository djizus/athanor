extends SceneTree

var _frame: int = 0
var _scene_root: Node
var _combat_manager: CombatManager
var _combat_hud: CombatHUD
var _combat_grid: CombatGrid

var _strike_btn: Button
var _guard_btn: Button
var _end_turn_btn: Button

var _initial_enemy_positions: Dictionary = {}
var _node_asserts_logged: bool = false

func _initialize() -> void:
	var room_scene: PackedScene = load("res://scenes/combat/tactical_room.tscn")
	if room_scene == null:
		print("ASSERT FAIL: could not load tactical_room.tscn")
		return

	_scene_root = room_scene.instantiate()
	root.add_child(_scene_root)
	_resolve_runtime_nodes()
	print("Interactive QA harness initialized")

func _resolve_runtime_nodes() -> void:
	if _scene_root == null:
		return

	_combat_manager = _scene_root.get_node_or_null("CombatManager") as CombatManager
	_combat_hud = _scene_root.get_node_or_null("CombatHUD") as CombatHUD
	_combat_grid = _scene_root.get_node_or_null("CombatGrid") as CombatGrid

	if !_node_asserts_logged:
		_assert_true("CombatManager found", _combat_manager != null)
		_assert_true("CombatHUD found", _combat_hud != null)
		_assert_true("CombatGrid found", _combat_grid != null)
		_node_asserts_logged = true

	if _combat_hud == null:
		return

	var ability_bar: HBoxContainer = _combat_hud.ability_bar
	if ability_bar != null && ability_bar.get_child_count() >= 3:
		_strike_btn = ability_bar.get_child(0) as Button
		_guard_btn = ability_bar.get_child(2) as Button
	_end_turn_btn = _combat_hud.end_turn_button

	_assert_true("Strike button found", _strike_btn != null)
	_assert_true("Guard button found", _guard_btn != null)
	_assert_true("End Turn button found", _end_turn_btn != null)

func _process(_delta: float) -> bool:
	_frame += 1

	if _combat_manager == null || _combat_hud == null || _combat_grid == null:
		_resolve_runtime_nodes()

	match _frame:
		10:
			_step_assert_combat_started()
		15:
			print("=== Frame 15: Click tile (2,2) ===")
			_click_grid_tile(Vector2i(2, 2))
		30:
			_step_assert_player_moved()
		35:
			print("=== Frame 35: Click Strike button ===")
			_click_button(_strike_btn)
		45:
			_step_assert_targeting_active()
		50:
			print("=== Frame 50: Right-click cancel targeting ===")
			_right_click()
		55:
			print("=== Frame 55: Click Guard button ===")
			_click_button(_guard_btn)
		65:
			_step_assert_guard_used()
		70:
			print("=== Frame 70: Click End Turn button ===")
			_click_button(_end_turn_btn)
		80:
			_step_assert_enemy_turn_started()
		100:
			_step_assert_enemies_acted()
		105:
			_step_assert_back_to_player_turn()
		110:
			_step_print_final_summary()

	return false

func _step_assert_combat_started() -> void:
	print("=== Frame 10: Assert combat started ===")
	if _combat_manager == null:
		print("ASSERT FAIL: CombatManager is null at frame 10")
		return

	var turn_manager: TurnManager = _combat_manager.turn_manager
	var stamina: StaminaResource = _get_player_stamina()

	_assert_true(
		"Phase is PLAYER_TURN",
		turn_manager != null && turn_manager.phase == CombatEnums.Phase.PLAYER_TURN,
		"phase=%s" % str(turn_manager.phase if turn_manager != null else "null")
	)
	_assert_true(
		"Player stamina is 100",
		stamina != null && stamina.value == 100,
		"stamina=%s" % str(stamina.value if stamina != null else "null")
	)

	_initial_enemy_positions = _get_enemy_positions()

func _step_assert_player_moved() -> void:
	print("=== Frame 30: Assert player moved ===")
	var stats: CombatStatsResource = _get_player_stats()
	var stamina: StaminaResource = _get_player_stamina()

	_assert_true(
		"Player grid_pos is (2,2)",
		stats != null && stats.grid_pos == Vector2i(2, 2),
		"grid_pos=%s" % str(stats.grid_pos if stats != null else "null")
	)
	_assert_true(
		"Player stamina is 80 after move",
		stamina != null && stamina.value == 80,
		"stamina=%s" % str(stamina.value if stamina != null else "null")
	)

func _step_assert_targeting_active() -> void:
	print("=== Frame 45: Assert targeting active ===")
	if _combat_manager == null:
		print("ASSERT FAIL: CombatManager is null at frame 45")
		return

	var selected: AbilityResource = _combat_manager.ability_manager.get_selected() if _combat_manager.ability_manager != null else null
	var highlighted: Array[Vector2i] = _get_highlighted_tiles_for_state(CombatGrid.STATE_ABILITY_RANGE)

	_assert_true(
		"Strike targeting is active",
		selected != null && selected.ability_id == CombatEnums.AbilityID.STRIKE,
		"selected=%s" % str(selected.ability_name if selected != null else "null")
	)
	_assert_true(
		"Ability tiles are highlighted",
		highlighted.size() > 0,
		"highlighted=%s" % str(highlighted)
	)
	print("Highlighted ability tiles (purple): %s" % str(highlighted))

func _step_assert_guard_used() -> void:
	print("=== Frame 65: Assert guard used ===")
	var stamina: StaminaResource = _get_player_stamina()
	var stats: CombatStatsResource = _get_player_stats()

	_assert_true(
		"Player stamina is 65 after Guard",
		stamina != null && stamina.value == 65,
		"stamina=%s" % str(stamina.value if stamina != null else "null")
	)
	_assert_true(
		"Player is_guarding is true",
		stats != null && stats.is_guarding,
		"is_guarding=%s" % str(stats.is_guarding if stats != null else "null")
	)

func _step_assert_enemy_turn_started() -> void:
	print("=== Frame 80: Assert enemy turn started ===")
	if _combat_manager == null || _combat_manager.turn_manager == null:
		print("ASSERT FAIL: TurnManager unavailable at frame 80")
		return

	_assert_true(
		"Phase is ENEMY_TURN",
		_combat_manager.turn_manager.phase == CombatEnums.Phase.ENEMY_TURN,
		"phase=%s" % str(_combat_manager.turn_manager.phase)
	)

func _step_assert_enemies_acted() -> void:
	print("=== Frame 100: Assert enemies acted ===")
	var current_positions: Dictionary = _get_enemy_positions()
	var moved_count: int = 0

	for enemy_name in _initial_enemy_positions.keys():
		var initial_pos: Vector2i = _initial_enemy_positions.get(enemy_name, Vector2i(-999, -999))
		var current_pos: Vector2i = current_positions.get(enemy_name, Vector2i(-999, -999))
		if initial_pos != current_pos:
			moved_count += 1

	_assert_true(
		"At least one enemy moved",
		moved_count > 0,
		"moved_count=%d, initial=%s, current=%s" % [moved_count, str(_initial_enemy_positions), str(current_positions)]
	)

func _step_assert_back_to_player_turn() -> void:
	print("=== Frame 105: Assert back to player turn ===")
	if _combat_manager == null || _combat_manager.turn_manager == null:
		print("ASSERT FAIL: TurnManager unavailable at frame 105")
		return

	var stamina: StaminaResource = _get_player_stamina()
	_assert_true(
		"Phase is PLAYER_TURN",
		_combat_manager.turn_manager.phase == CombatEnums.Phase.PLAYER_TURN,
		"phase=%s" % str(_combat_manager.turn_manager.phase)
	)
	_assert_true(
		"Stamina refilled to 100",
		stamina != null && stamina.value == 100,
		"stamina=%s" % str(stamina.value if stamina != null else "null")
	)

func _step_print_final_summary() -> void:
	print("=== Frame 110: Final state summary ===")
	if _combat_manager == null || _combat_manager.turn_manager == null:
		print("Final summary unavailable: CombatManager/TurnManager missing")
		return

	var turn_count: int = _combat_manager.turn_manager.turn_count
	var player_stats: CombatStatsResource = _get_player_stats()
	var player_health: HealthResource = _combat_manager.player.get("health", null)

	print("Turn count: %d" % turn_count)
	print("Player pos: %s" % str(player_stats.grid_pos if player_stats != null else "null"))
	print("Player HP: %s" % str(player_health.hp if player_health != null else "null"))

	for enemy_data in _combat_manager.enemies:
		var enemy_name: String = str(enemy_data.get("node", null).name if enemy_data.get("node", null) != null else "unknown")
		var enemy_stats: CombatStatsResource = enemy_data.get("combat_stats", null)
		var enemy_health: HealthResource = enemy_data.get("health", null)
		print("Enemy %s -> pos=%s hp=%s" % [
			enemy_name,
			str(enemy_stats.grid_pos if enemy_stats != null else "null"),
			str(enemy_health.hp if enemy_health != null else "null")
		])

func _get_player_stats() -> CombatStatsResource:
	if _combat_manager == null:
		return null
	return _combat_manager.player.get("combat_stats", null) as CombatStatsResource

func _get_player_stamina() -> StaminaResource:
	if _combat_manager == null:
		return null
	return _combat_manager.player.get("stamina", null) as StaminaResource

func _get_enemy_positions() -> Dictionary:
	var positions: Dictionary = {}
	if _combat_manager == null:
		return positions

	for enemy_data in _combat_manager.enemies:
		var enemy_node: Node2D = enemy_data.get("node", null)
		var stats: CombatStatsResource = enemy_data.get("combat_stats", null)
		if enemy_node == null || stats == null:
			continue
		positions[enemy_node.name] = stats.grid_pos
	return positions

func _get_highlighted_tiles_for_state(state: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if _combat_grid == null:
		return cells

	var states: Dictionary = _combat_grid.get("_cell_states")
	for key in states.keys():
		var cell: Vector2i = key
		if int(states[key]) == state:
			cells.push_back(cell)
	return cells

func _assert_true(name: String, condition: bool, details: String = "") -> void:
	if condition:
		print("ASSERT PASS: %s" % name)
	else:
		if details.is_empty():
			print("ASSERT FAIL: %s" % name)
		else:
			print("ASSERT FAIL: %s (%s)" % [name, details])

func _click_world_pos(world_pos: Vector2) -> void:
	var camera: Camera2D = root.get_camera_2d()
	if camera == null:
		print("ASSERT FAIL: camera is null for _click_world_pos")
		return
	var viewport_size: Vector2 = root.get_visible_rect().size
	var screen_pos: Vector2 = (world_pos - camera.global_position) * camera.zoom + viewport_size * 0.5
	_hover_screen(screen_pos)
	_click_screen(screen_pos)

func _click_grid_tile(grid_pos: Vector2i) -> void:
	var world_pos: Vector2 = _grid_to_world(grid_pos)
	_click_world_pos(world_pos)

func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2((grid_pos.x - grid_pos.y) * 16.0, (grid_pos.x + grid_pos.y) * 8.0)

func _click_button(button: Button) -> void:
	if button == null:
		print("ASSERT FAIL: button is null")
		return
	var rect: Rect2 = button.get_global_rect()
	var center: Vector2 = rect.get_center()
	_click_screen(center)

func _right_click() -> void:
	var center: Vector2 = root.get_visible_rect().size * 0.5
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.position = center
	press.global_position = center
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	Input.parse_input_event(press)

	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.position = center
	release.global_position = center
	release.button_index = MOUSE_BUTTON_RIGHT
	release.pressed = false
	Input.parse_input_event(release)

func _hover_screen(screen_pos: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = screen_pos
	motion.global_position = screen_pos
	Input.parse_input_event(motion)

func _click_screen(screen_pos: Vector2) -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.position = screen_pos
	press.global_position = screen_pos
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)

	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.position = screen_pos
	release.global_position = screen_pos
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	Input.parse_input_event(release)
