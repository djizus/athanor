extends Node3D

func _ready() -> void:
	game_state.character = {
		"health": 80, "max_health": 100,
		"stamina": 70, "max_stamina": 100,
		"power": 10, "current_zone": 3,
	}
	game_state.dungeon = {"game_id": 1, "completed": false, "failed": false}
	game_state.fight = {"active": true, "mob_count": 2, "mob_healths": 20 + (20 << 16)}

	var arena_scene: PackedScene = load("res://scenes/arena.tscn")
	var arena: Node = arena_scene.instantiate()
	add_child(arena)

	await get_tree().create_timer(2.0).timeout
	_take_screenshot("arena_combat")

func _take_screenshot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/godot_%s.png" % name)
	push_warning("Screenshot saved: /tmp/godot_%s.png" % name)
