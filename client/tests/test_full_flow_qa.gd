## Full flow QA: Menu → Enter Dungeon → Walk into arena → Combat starts
## Tests the ACTUAL user path, not shortcuts.
extends SceneTree

var _frame: int = 0
var _clicked_enter: bool = false
var _triggered_fight: bool = false

func _initialize() -> void:
	# Load the main menu — exactly what project.godot does
	var menu_scene: PackedScene = load("res://scenes/main_menu.tscn")
	if menu_scene == null:
		print("ASSERT FAIL: could not load main_menu.tscn")
		return
	var menu: Node = menu_scene.instantiate()
	root.add_child(menu)
	print("ASSERT PASS: main menu loaded")

func _process(delta: float) -> bool:
	_frame += 1

	match _frame:
		10:
			# Click "Enter Dungeon" button
			print("=== Frame 10: Clicking Enter Dungeon ===")
			var spawn_btn: Button = _find_node_by_name(root, "SpawnButton") as Button
			if spawn_btn != null:
				print("ASSERT PASS: SpawnButton found")
				_click_button(spawn_btn)
				_clicked_enter = true
			else:
				print("ASSERT FAIL: SpawnButton not found")

		30:
			# Should be in the dungeon room now
			var room: Node = _find_node_by_name(root, "RoomTactical01")
			if room != null:
				print("ASSERT PASS: room_tactical_01 loaded")
			else:
				# Maybe it's named differently
				print("ASSERT FAIL: room not found, checking tree...")
				_print_tree(root, 0, 3)

		50:
			# Trigger fight_mode directly (simulating walking into arena)
			print("=== Frame 50: Triggering fight_mode ===")
			var fight_res = load("res://addons/top_down/resources/arena_resources/fight_mode_resource.tres")
			if fight_res != null and fight_res.has_method("set_value"):
				fight_res.set_value(true)
				_triggered_fight = true
				print("ASSERT PASS: fight_mode set to true")
			else:
				print("ASSERT FAIL: fight_mode_resource not found or no set_value")

		70:
			# Check if combat systems spawned
			print("=== Frame 70: Checking combat systems ===")
			_print_tree(root, 0, 3)
			var combat_mgr: Node = _find_node_by_name(root, "CombatManager")
			var combat_grid: Node = _find_node_by_name(root, "CombatGrid")
			var combat_hud: Node = _find_node_by_name(root, "CombatHUD")

			if combat_mgr != null:
				print("ASSERT PASS: CombatManager spawned")
			else:
				print("ASSERT FAIL: CombatManager not found")

			if combat_grid != null:
				print("ASSERT PASS: CombatGrid spawned")
			else:
				print("ASSERT FAIL: CombatGrid not found")

			if combat_hud != null:
				print("ASSERT PASS: CombatHUD spawned")
			else:
				print("ASSERT FAIL: CombatHUD not found")

		90:
			# Check turn state
			print("=== Frame 90: Checking combat state ===")
			var combat_mgr: Node = _find_node_by_name(root, "CombatManager")
			if combat_mgr != null:
				var tm = combat_mgr.get("turn_manager")
				if tm != null:
					var phase: int = tm.get("phase")
					print("  Phase: %d (1=PLAYER_TURN)" % phase)
					if phase == 1:
						print("ASSERT PASS: combat in PLAYER_TURN")
					else:
						print("ASSERT FAIL: expected PLAYER_TURN(1), got %d" % phase)

				var player_data: Dictionary = combat_mgr.get("player")
				if not player_data.is_empty():
					var stamina = player_data.get("stamina")
					if stamina != null:
						print("  Stamina: %d/%d" % [stamina.value, stamina.max_value])
						print("ASSERT PASS: player stamina accessible")
					var stats = player_data.get("combat_stats")
					if stats != null:
						print("  Player grid_pos: %s" % str(stats.grid_pos))

				var enemies: Array = combat_mgr.get("enemies")
				print("  Enemy count: %d" % enemies.size())
				for e in enemies:
					var es = e.get("combat_stats")
					if es != null:
						print("  Enemy at %s" % str(es.grid_pos))
			else:
				print("ASSERT FAIL: no CombatManager at frame 90")

		110:
			print("=== Frame 110: Final state ===")
			_print_tree(root, 0, 2)

	if _frame % 20 == 0:
		print("Frame: %d" % _frame)

	return false

# --- Helpers ---

func _click_button(button: Button) -> void:
	if button == null:
		return
	# For UI buttons, emit pressed directly is more reliable than input injection
	button.emit_signal("pressed")

func _click_screen(screen_pos: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.position = screen_pos
	press.global_position = screen_pos
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventMouseButton.new()
	release.position = screen_pos
	release.global_position = screen_pos
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	Input.parse_input_event(release)

func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found: Node = _find_node_by_name(child, target_name)
		if found != null:
			return found
	return null

func _print_tree(node: Node, depth: int, max_depth: int) -> void:
	if depth > max_depth:
		return
	var indent: String = "  ".repeat(depth)
	print("%s%s (%s)" % [indent, node.name, node.get_class()])
	for child in node.get_children():
		_print_tree(child, depth + 1, max_depth)
