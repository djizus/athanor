extends Node2D

func _ready() -> void:
	game_state.character = {
		"health": 80, "max_health": 100,
		"stamina": 70, "max_stamina": 100,
		"power": 10, "current_zone": 1,
	}
	game_state.dungeon = {"game_id": 1, "completed": false, "failed": false}
	game_state.fight = {"active": true, "mob_count": 1, "mob_healths": 20}

	var arena_scene: PackedScene = load("res://scenes/arena.tscn")
	var arena: Node = arena_scene.instantiate()
	add_child(arena)

	await get_tree().create_timer(2.0).timeout

	var dv: Node2D = arena.get_node("DungeonWorld")
	var cam: Camera2D = arena.get_node("GameCamera")
	_run_contracts(dv, cam)

	await get_tree().create_timer(1.0).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/godot_2d_test.png")
	push_warning("Screenshot saved: /tmp/godot_2d_test.png")

func _run_contracts(dv: Node2D, cam: Camera2D) -> void:
	var passed := 0
	var total := 0
	for m in ["on_state_changed", "update_mob_hp", "update_mob_visual",
		"get_mob_world_position", "get_mob_node", "play_attack", "play_mob_turn",
		"play_player_death", "play_victory", "get_player_world_position",
		"face_hero_toward", "spawn_damage_number", "load_zone", "spawn_hero",
		"spawn_mobs", "clear_mobs"]:
		total += 1
		if dv.has_method(m):
			passed += 1
		else:
			push_warning("FAIL: dungeon_view.%s MISSING" % m)
	for m in ["set_follow_target", "shake", "combat_zoom_in", "combat_zoom_out", "zone_transition"]:
		total += 1
		if cam.has_method(m):
			passed += 1
		else:
			push_warning("FAIL: game_camera.%s MISSING" % m)
	total += 1
	if dv.get_player_world_position() is Vector2:
		passed += 1
	total += 1
	if dv.get_mob_world_position(0) is Vector2:
		passed += 1
	push_warning("=== %d/%d contract tests passed ===" % [passed, total])
