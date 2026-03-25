class_name CombatRoomSetup
extends Node

@export var fight_mode:BoolResource = preload("res://addons/top_down/resources/arena_resources/fight_mode_resource.tres")
@export var combat_grid_scene:PackedScene = preload("res://scenes/combat/combat_grid.tscn")
@export var combat_hud_scene:PackedScene = preload("res://scenes/combat/combat_hud.tscn")
@export var game_result_screen_scene:PackedScene = preload("res://scenes/combat/game_result_screen.tscn")
@export var brute_scene:PackedScene = preload("res://addons/top_down/scenes/actors/zombie.tscn")
@export var caster_scene:PackedScene = preload("res://addons/top_down/scenes/actors/slime.tscn")
@export var flanker_scene:PackedScene = preload("res://addons/top_down/scenes/actors/zombie_crawler.tscn")
@export var grid_size:Vector2i = Vector2i(8, 8)
@export var player_start_cell:Vector2i = Vector2i(1, 1)
@export var enemy_spawn_cells:Array[Vector2i] = [Vector2i(6, 1), Vector2i(5, 6), Vector2i(1, 5)]

var _room_root:Node
var _combat_grid:CombatGrid
var _combat_manager:CombatManager
var _combat_hud:CombatHUD
var _game_result_screen:GameResultScreen

var _spawned_enemies:Array[Node] = []

var _player_mover:MoverTopDown2D
var _player_input:PlayerInput
var _disabled_bot_inputs:Array[BotInput] = []
var _enemy_spawner:Node
var _enemy_wave_manager:Node

func _ready() -> void:
	_room_root = owner if owner != null else get_parent()
	if fight_mode == null:
		return
	fight_mode.changed_true.connect(_on_fight_mode_enabled)
	fight_mode.changed_false.connect(_on_fight_mode_disabled)
	_suppress_shooter_systems()
	get_tree().process_frame.connect(_suppress_shooter_systems, CONNECT_ONE_SHOT)

func _suppress_shooter_systems() -> void:
	if _room_root == null:
		return
	_enemy_wave_manager = _room_root.get_node_or_null("EnemyManager/EnemyWaveManager")
	if _enemy_wave_manager != null:
		_enemy_wave_manager.set_process(false)
		_enemy_wave_manager.set_physics_process(false)
	_enemy_spawner = _room_root.get_node_or_null("EnemyManager/EnemySpawner")
	if _enemy_spawner != null:
		_enemy_spawner.set_process(false)
	for bot_node in _find_nodes_of_type(_room_root, BotInput):
		if bot_node is BotInput:
			(bot_node as BotInput).set_enabled(false)
	for enemy_node in get_tree().get_nodes_in_group(&"enemy"):
		if is_instance_valid(enemy_node):
			enemy_node.queue_free()
	var enemy_mgr:Node = _room_root.get_node_or_null("EnemyManager")
	if enemy_mgr != null:
		for child in enemy_mgr.get_children():
			if child.name != "EnemyWaveManager" and child.name != "EnemySpawner" and child.name != "EnemySpawnPoints":
				child.queue_free()
	var hole_obstacle:Node2D = _room_root.get_node_or_null("Behind/HoleObstacle") as Node2D
	if hole_obstacle != null:
		for child in hole_obstacle.get_children():
			if child is Area2D:
				(child as Area2D).monitoring = false
				(child as Area2D).monitorable = false
				for shape in child.get_children():
					if shape is CollisionShape2D:
						(shape as CollisionShape2D).disabled = true

func _on_fight_mode_enabled() -> void:
	if _room_root == null:
		return
	if _combat_manager != null:
		return

	_fade_transition()
	_disable_realtime_systems()
	# Must wait for tree to finish processing before adding children
	get_tree().create_timer(0.05).timeout.connect(_spawn_combat_runtime)

func _on_fight_mode_disabled() -> void:
	_cleanup_combat_runtime()
	_enable_realtime_systems()
	_fade_transition()

func _spawn_combat_runtime() -> void:
	var player_node:Node2D = _find_player_node()
	if player_node == null:
		return

	_combat_grid = combat_grid_scene.instantiate() as CombatGrid
	_room_root.add_child(_combat_grid)
	_combat_grid.global_position = _resolve_arena_anchor(player_node)
	_combat_grid.show_grid(Vector2i.ZERO, grid_size)

	_position_player(player_node)
	_spawned_enemies = _spawn_encounter_enemies()

	_combat_manager = CombatManager.new()
	_combat_manager.name = "CombatManager"
	_room_root.add_child(_combat_manager)
	_combat_manager.combat_finished.connect(_on_combat_finished)
	_combat_manager.start_combat(player_node, _spawned_enemies, _combat_grid)

	_combat_hud = combat_hud_scene.instantiate() as CombatHUD
	_room_root.add_child(_combat_hud)
	_combat_hud.bind_combat_manager(_combat_manager)

func _cleanup_combat_runtime() -> void:
	if _combat_hud != null && is_instance_valid(_combat_hud):
		_combat_hud.clear_bindings()
		_combat_hud.queue_free()
	if _combat_manager != null && is_instance_valid(_combat_manager):
		_combat_manager.queue_free()
	if _combat_grid != null && is_instance_valid(_combat_grid):
		_combat_grid.queue_free()
	if _game_result_screen != null && is_instance_valid(_game_result_screen):
		_game_result_screen.queue_free()

	for enemy_node in _spawned_enemies:
		if is_instance_valid(enemy_node):
			enemy_node.queue_free()
	_spawned_enemies.clear()

	_combat_hud = null
	_combat_manager = null
	_combat_grid = null
	_game_result_screen = null

func _disable_realtime_systems() -> void:
	_player_mover = _find_first_node_in_room(MoverTopDown2D) as MoverTopDown2D
	if _player_mover != null:
		_player_mover.set_enabled_process(false)

	_player_input = _find_first_node_in_room(PlayerInput) as PlayerInput
	if _player_input != null:
		_player_input.set_enabled(false)

	_disabled_bot_inputs.clear()
	for bot_node in _find_nodes_of_type(_room_root, BotInput):
		if bot_node is BotInput:
			var bot:BotInput = bot_node
			bot.set_enabled(false)
			_disabled_bot_inputs.push_back(bot)

	_enemy_spawner = _room_root.get_node_or_null("EnemyManager/EnemySpawner")
	if _enemy_spawner != null:
		_enemy_spawner.set_process(false)
	_enemy_wave_manager = _room_root.get_node_or_null("EnemyManager/EnemyWaveManager")
	if _enemy_wave_manager != null:
		_enemy_wave_manager.set_process(false)
		_enemy_wave_manager.set_physics_process(false)

func _enable_realtime_systems() -> void:
	if _player_mover != null && is_instance_valid(_player_mover):
		_player_mover.set_enabled_process(true)
	if _player_input != null && is_instance_valid(_player_input):
		_player_input.set_enabled(true)

	for bot in _disabled_bot_inputs:
		if is_instance_valid(bot):
			bot.set_enabled(true)
	_disabled_bot_inputs.clear()

	if _enemy_spawner != null && is_instance_valid(_enemy_spawner):
		_enemy_spawner.set_process(false)
	if _enemy_wave_manager != null && is_instance_valid(_enemy_wave_manager):
		_enemy_wave_manager.set_process(false)
		_enemy_wave_manager.set_physics_process(false)

func _spawn_encounter_enemies() -> Array[Node]:
	var enemies:Array[Node] = []
	var enemy_configs:Array[Dictionary] = [
		{"name": "BruteEnemy", "scene": brute_scene},
		{"name": "CasterEnemy", "scene": caster_scene},
		{"name": "FlankerEnemy", "scene": flanker_scene},
	]
	for i in enemy_spawn_cells.size():
		var config:Dictionary = enemy_configs[min(i, enemy_configs.size() - 1)]
		var scene:PackedScene = config["scene"] as PackedScene
		var enemy_node:Node2D = scene.instantiate() as Node2D
		enemy_node.name = String(config["name"])
		_strip_realtime_enemy_nodes(enemy_node)
		_room_root.add_child(enemy_node)
		enemy_node.global_position = _combat_grid.grid_to_world(enemy_spawn_cells[i])
		enemies.push_back(enemy_node)

	return enemies

func _position_player(player_node:Node2D) -> void:
	player_node.global_position = _combat_grid.grid_to_world(player_start_cell)

func _on_combat_finished(player_won:bool) -> void:
	if _room_root == null || !is_instance_valid(_room_root):
		return
	if _game_result_screen != null && is_instance_valid(_game_result_screen):
		_game_result_screen.queue_free()

	_game_result_screen = game_result_screen_scene.instantiate() as GameResultScreen
	_room_root.add_child(_game_result_screen)
	_game_result_screen.continue_pressed.connect(_on_result_continue_pressed)
	_game_result_screen.retry_pressed.connect(_on_result_retry_pressed)
	_game_result_screen.menu_pressed.connect(_on_result_menu_pressed)
	_game_result_screen.show_result(player_won)

func _on_result_continue_pressed() -> void:
	if fight_mode != null && fight_mode.value:
		fight_mode.set_value(false)
	if _game_result_screen != null && is_instance_valid(_game_result_screen):
		_game_result_screen.queue_free()
	_game_result_screen = null

func _on_result_retry_pressed() -> void:
	get_tree().reload_current_scene()

func _on_result_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _fade_transition() -> void:
	if _room_root == null || !is_instance_valid(_room_root):
		return
	var layer:CanvasLayer = CanvasLayer.new()
	layer.layer = 127
	if _room_root.is_inside_tree():
		_room_root.add_child.call_deferred(layer)
	else:
		return

	var rect:ColorRect = ColorRect.new()
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(0.0, 0.0, 0.0, 0.0)
	layer.add_child(rect)

	var tween:Tween = create_tween()
	tween.tween_property(rect, "color:a", 0.38, 0.15)
	tween.tween_property(rect, "color:a", 0.0, 0.15)
	tween.tween_callback(layer.queue_free)

func _find_player_node() -> Node2D:
	if _player_mover != null && _player_mover.character != null:
		return _player_mover.character
	var player_input_node:PlayerInput = _find_first_node_in_room(PlayerInput) as PlayerInput
	if player_input_node != null:
		return player_input_node.get_parent() as Node2D
	return _find_first_node_in_room(CharacterBody2D) as CharacterBody2D

func _resolve_arena_anchor(player_node:Node2D) -> Vector2:
	var boss_marker:Marker2D = _room_root.get_node_or_null("EnemySpawnPoints/SpawnBoss") as Marker2D
	if boss_marker != null:
		return boss_marker.global_position
	return player_node.global_position

func _strip_realtime_enemy_nodes(enemy_node:Node) -> void:
	var remove_names:PackedStringArray = PackedStringArray([
		"WeaponManager",
		"ProjectileSpawner",
		"ArenaStarter",
		"EnemyWaveManager",
		"PlayerInput",
		"BotInput",
		"DebugInput",
		"CharacterStates",
	])
	for child in enemy_node.get_children():
		if remove_names.has(child.name):
			child.free()
			continue
		_strip_realtime_enemy_nodes(child)

func _find_first_node_in_room(target_type:Variant) -> Node:
	return _find_first_node_recursive(_room_root, target_type)

func _find_nodes_of_type(node:Node, target_type:Variant) -> Array[Node]:
	var result:Array[Node] = []
	if node == null:
		return result
	if is_instance_of(node, target_type):
		result.push_back(node)
	for child in node.get_children():
		for found in _find_nodes_of_type(child, target_type):
			result.push_back(found)
	return result

func _find_first_node_recursive(node:Node, target_type:Variant) -> Node:
	if is_instance_of(node, target_type):
		return node
	for child in node.get_children():
		var found:Node = _find_first_node_recursive(child, target_type)
		if found != null:
			return found
	return null
