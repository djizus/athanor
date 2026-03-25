extends Node2D

const GRID_SIZE:int = 8
const FLOOR_TILESET:TileSet = preload("res://addons/top_down/resources/tilesets/tileset_isometric_floors.tres")
const WALL_TILESET:TileSet = preload("res://addons/top_down/resources/tilesets/tileset_isometric_walls.tres")
const ACTOR_SCENE:PackedScene = preload("res://addons/top_down/scenes/actors/actor.tscn")
const ZOMBIE_SCENE:PackedScene = preload("res://addons/top_down/scenes/actors/zombie.tscn")
const SLIME_SCENE:PackedScene = preload("res://addons/top_down/scenes/actors/slime.tscn")
const CRAWLER_SCENE:PackedScene = preload("res://addons/top_down/scenes/actors/zombie_crawler.tscn")
const COMBAT_GRID_SCENE:PackedScene = preload("res://scenes/combat/combat_grid.tscn")
const COMBAT_HUD_SCENE:PackedScene = preload("res://scenes/combat/combat_hud.tscn")
const GAME_RESULT_SCREEN_SCENE:PackedScene = preload("res://scenes/combat/game_result_screen.tscn")

const FLOOR_SOURCE_ID:int = 1
const FLOOR_ATLAS:Vector2i = Vector2i(1, 3)
const WALL_SOURCE_ID:int = 0
const WALL_ATLAS:Vector2i = Vector2i(1, 1)

var _combat_grid:CombatGrid
var _combat_manager:CombatManager
var _combat_hud:CombatHUD
var _game_result_screen:GameResultScreen
var _player:Node2D
var _enemies:Array[Node] = []

func _ready() -> void:
	_build_tile_layers()
	_spawn_combat_runtime()
	_center_camera()
	call_deferred("_start_combat")

func _build_tile_layers() -> void:
	var floor_layer:TileMapLayer = TileMapLayer.new()
	floor_layer.name = "FloorLayer"
	floor_layer.tile_set = FLOOR_TILESET.duplicate(true)
	add_child(floor_layer)

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			floor_layer.set_cell(Vector2i(x, y), FLOOR_SOURCE_ID, FLOOR_ATLAS, 0)

	var obstacle_layer:TileMapLayer = TileMapLayer.new()
	obstacle_layer.name = "ObstacleLayer"
	obstacle_layer.tile_set = WALL_TILESET.duplicate(true)
	obstacle_layer.y_sort_enabled = true
	obstacle_layer.z_index = 2
	add_child(obstacle_layer)

	var obstacle_cells:Array[Vector2i] = [
		Vector2i(3, 2),
		Vector2i(4, 2),
		Vector2i(2, 4),
		Vector2i(5, 5),
	]
	for cell in obstacle_cells:
		obstacle_layer.set_cell(cell, WALL_SOURCE_ID, WALL_ATLAS, 0)

func _spawn_combat_runtime() -> void:
	_combat_grid = COMBAT_GRID_SCENE.instantiate() as CombatGrid
	_combat_grid.name = "CombatGrid"
	add_child(_combat_grid)
	_combat_grid.show_grid(Vector2i.ZERO, Vector2i(GRID_SIZE, GRID_SIZE))

	_player = _spawn_actor(ACTOR_SCENE, "Player", Vector2i(1, 1), true)

	_enemies = [
		_spawn_actor(ZOMBIE_SCENE, "BruteEnemy", Vector2i(6, 1), false),
		_spawn_actor(SLIME_SCENE, "CasterEnemy", Vector2i(5, 6), false),
		_spawn_actor(CRAWLER_SCENE, "FlankerEnemy", Vector2i(1, 5), false),
	]

	_combat_manager = CombatManager.new()
	_combat_manager.name = "CombatManager"
	add_child(_combat_manager)
	_combat_manager.combat_finished.connect(_on_combat_finished)

	_combat_hud = COMBAT_HUD_SCENE.instantiate() as CombatHUD
	_combat_hud.name = "CombatHUD"
	add_child(_combat_hud)

func _spawn_actor(actor_scene:PackedScene, node_name:String, grid_pos:Vector2i, is_player:bool) -> Node2D:
	var actor:Node2D = actor_scene.instantiate() as Node2D
	actor.name = node_name
	_strip_realtime_children(actor, is_player)
	actor.position = _iso_to_world(grid_pos)
	add_child(actor)
	return actor

func _strip_realtime_children(actor:Node, is_player:bool) -> void:
	var remove_names:PackedStringArray = PackedStringArray([
		"WeaponManager",
		"ProjectileSpawner",
		"ArenaStarter",
		"EnemyWaveManager",
		"PlayerInput",
		"BotInput",
		"ZombieInput",
		"SlashAttack",
		"ActiveEnemy",
		"CriticalDamageReplace",
		"SlimeSplit",
		"BloodTrail",
		"PoolNode",
		"DebugInput",
		"CharacterStates",
	])

	for child in actor.get_children():
		if child == null:
			continue
		if remove_names.has(child.name):
			child.free()
			continue

		var script:Script = child.get_script() as Script
		if script == null:
			continue
		var script_path:String = script.resource_path.to_lower()
		if script_path.contains("weapon") || script_path.contains("projectile") || script_path.contains("bot"):
			child.free()
			continue
		if script_path.contains("enemy_ai") || script_path.contains("activeenemy") || script_path.contains("slimesplit") || script_path.contains("bloodtrail"):
			child.free()
			continue
		if is_player && script_path.contains("playerinput"):
			child.free()

func _center_camera() -> void:
	var camera:Camera2D = get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	var center_cell:Vector2i = Vector2i(GRID_SIZE / 2, GRID_SIZE / 2)
	camera.global_position = _iso_to_world(center_cell)
	camera.zoom = Vector2(4.0, 4.0)
	camera.enabled = true

func _start_combat() -> void:
	if _combat_manager == null || _combat_grid == null || _player == null:
		return
	_combat_manager.start_combat(_player, _enemies, _combat_grid)
	if _combat_hud != null:
		_combat_hud.bind_combat_manager(_combat_manager)

func _on_combat_finished(player_won:bool) -> void:
	if _game_result_screen != null && is_instance_valid(_game_result_screen):
		_game_result_screen.queue_free()

	_game_result_screen = GAME_RESULT_SCREEN_SCENE.instantiate() as GameResultScreen
	add_child(_game_result_screen)
	_game_result_screen.continue_pressed.connect(_on_result_continue_pressed)
	_game_result_screen.retry_pressed.connect(_on_result_retry_pressed)
	_game_result_screen.menu_pressed.connect(_on_result_menu_pressed)
	_game_result_screen.show_result(player_won)

func _on_result_continue_pressed() -> void:
	get_tree().reload_current_scene()

func _on_result_retry_pressed() -> void:
	get_tree().reload_current_scene()

func _on_result_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _iso_to_world(grid_pos:Vector2i) -> Vector2:
	return Vector2((grid_pos.x - grid_pos.y) * 16.0, (grid_pos.x + grid_pos.y) * 8.0)
