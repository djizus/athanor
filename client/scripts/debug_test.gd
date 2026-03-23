extends Node3D

const ROOM_STATE_NAMES := ["ENTERING", "EXPLORING", "COMBAT_INTRO", "COMBAT", "CLEARED", "EXITING"]

func _ready() -> void:
	# Set up mock game state for testing
	game_state.character = {
		"health": 80, "max_health": 100,
		"stamina": 70, "max_stamina": 100,
		"power": 10, "current_zone": 1,
	}
	game_state.dungeon = {"game_id": 1, "completed": false, "failed": false, "zones_cleared": 0}
	game_state.fight = {"active": true, "mob_count": 1, "mob_healths": 15}

	# Load arena scene
	var arena_scene: PackedScene = load("res://scenes/arena.tscn")
	var arena: Node = arena_scene.instantiate()
	add_child(arena)

	# Run tests
	await get_tree().create_timer(1.0).timeout
	_test_room_state_sync(arena)

	await get_tree().create_timer(1.0).timeout
	_take_screenshot("arena_room_combat")

	# Test 2: CLEARED state
	game_state.fight = {"active": false, "mob_count": 1, "mob_healths": 0}
	game_state.dungeon = {"game_id": 1, "completed": false, "failed": false, "zones_cleared": 0b00000010}
	game_state.character_updated.emit({})

	await get_tree().create_timer(1.5).timeout
	_take_screenshot("arena_room_cleared")

func _test_room_state_sync(arena: Node) -> void:
	var room_state := room_manager.get_current_room_state()
	push_warning("[debug_test] Room state: %s (%d)" % [ROOM_STATE_NAMES[room_state] if room_state < ROOM_STATE_NAMES.size() else "?", room_state])
	push_warning("[debug_test] Room zone: %d" % room_manager.visual_zone)
	push_warning("[debug_test] Arena state: %d" % (arena.current_state if arena.has("current_state") else -1))

func _take_screenshot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/godot_%s.png" % name)
	push_warning("Screenshot saved: /tmp/godot_%s.png" % name)
