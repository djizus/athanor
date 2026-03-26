extends Node2D

const PLAYER_SCENE:PackedScene = preload("res://scenes/player.tscn")
const COMBAT_HUD_SCENE:PackedScene = preload("res://scenes/combat_hud.tscn")
const RESULT_SCREEN_SCENE:PackedScene = preload("res://scenes/game_result_screen.tscn")

const ENEMY_SPRITES:Dictionary = {
	"Brute": "res://assets/images/characters/zombie_16x16_strip8.png",
	"Caster": "res://assets/images/characters/slime_16x16_strip8.png",
	"Flanker": "res://assets/images/characters/zombie_crawler_16x16_strip6-sheet.png",
	"Heavy": "res://assets/images/characters/skeleton_16x16_strip8.png",
	"Puller": "res://assets/images/characters/mage_16x16_strip8.png",
}

const HP_BAR_Y:float = -12.0

var _player:CharacterBody2D
var _combat_manager:CombatManager
var _combat_hud:CombatHUD
var _combat_grid:CombatGrid
var _room_sequencer:RoomSequencer
var _result_screen:GameResultScreen

var _in_combat:bool = false
var _enemy_nodes:Array[Node] = []
var _enemy_hp_drawers:Array[Node2D] = []
var _player_health:HealthResource
var _result_is_victory:bool = false


func _ready() -> void:
	_spawn_player()
	_room_sequencer = RoomSequencer.new()
	_room_sequencer.room_started.connect(_on_room_started)
	_room_sequencer.run_completed.connect(_on_run_completed)
	_room_sequencer.run_failed.connect(_on_run_failed)
	_room_sequencer.start_run()


func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate() as CharacterBody2D
	_player.position = Vector2.ZERO
	_player.z_index = 10
	_player.set_movement_enabled(false)
	add_child(_player)


func _on_room_started(_room_index:int, config:Dictionary) -> void:
	_cleanup_combat_nodes()
	_start_room_combat(config)


func _start_room_combat(config:Dictionary) -> void:
	_in_combat = true
	_player.set_movement_enabled(false)

	var grid_size:int = int(config.get("grid_size", 8))
	var player_start:Vector2i = config.get("player_start", Vector2i(1, 3))
	var obstacles:Array[Vector2i] = []
	for obstacle_cell in config.get("obstacles", []):
		obstacles.push_back(obstacle_cell)

	_combat_grid = CombatGrid.new()
	_combat_grid.position = Vector2(0, -32)
	add_child(_combat_grid)
	_combat_grid.show_grid(Vector2i.ZERO, Vector2i(grid_size, grid_size))
	_combat_grid.set_obstacles(obstacles)

	var grid_cursor:GridCursor = GridCursor.new()
	grid_cursor.name = "GridCursor"
	_combat_grid.add_child(grid_cursor)

	_player.global_position = _combat_grid.grid_to_world(player_start)
	_enemy_nodes = _spawn_enemies(config.get("enemies", []))

	_combat_manager = CombatManager.new()
	add_child(_combat_manager)
	_combat_manager.combat_finished.connect(_on_combat_finished)

	_combat_hud = COMBAT_HUD_SCENE.instantiate() as CombatHUD
	add_child(_combat_hud)

	await get_tree().process_frame

	_combat_manager.start_combat(_player, _enemy_nodes, _combat_grid, {
		"grid_size": grid_size,
		"obstacles": obstacles,
	})
	_ensure_player_health_carryover()
	_combat_hud.bind_combat_manager(_combat_manager)
	_setup_enemy_hp_bars()


func _spawn_enemies(enemy_defs:Array) -> Array[Node]:
	var nodes:Array[Node] = []
	for enemy_def in enemy_defs:
		if !(enemy_def is Dictionary):
			continue
		var enemy_name:String = String(enemy_def.get("name", "Brute"))
		var grid_pos:Vector2i = enemy_def.get("grid_pos", Vector2i.ZERO)

		var enemy:Node2D = Node2D.new()
		enemy.name = enemy_name

		var sprite:Sprite2D = Sprite2D.new()
		var texture_path:String = ENEMY_SPRITES.get(enemy_name, ENEMY_SPRITES["Brute"])
		sprite.texture = load(texture_path)
		if enemy_name == "Flanker":
			sprite.hframes = 6
		else:
			sprite.hframes = 8
		enemy.add_child(sprite)

		enemy.global_position = _combat_grid.grid_to_world(grid_pos)
		enemy.z_index = 10
		add_child(enemy)
		nodes.push_back(enemy)
	return nodes


func _ensure_player_health_carryover() -> void:
	if _combat_manager == null:
		return
	var room_health:HealthResource = _combat_manager.player.get("health", null)
	if room_health == null:
		return

	if _player_health == null:
		_player_health = room_health
	else:
		room_health.max_hp = _player_health.max_hp
		room_health.hp = _player_health.hp
		_combat_manager.player["health"] = _player_health


func _setup_enemy_hp_bars() -> void:
	_enemy_hp_drawers.clear()
	if _combat_manager == null:
		return
	for enemy_data in _combat_manager.enemies:
		var enemy_node:Node2D = enemy_data.get("node", null)
		var health:HealthResource = enemy_data.get("health", null)
		if enemy_node == null || health == null:
			continue
		var drawer:Node2D = _EnemyHPDrawer.new()
		drawer.health = health
		drawer.position = Vector2(0.0, HP_BAR_Y)
		enemy_node.add_child(drawer)
		_enemy_hp_drawers.push_back(drawer)


func _on_combat_finished(player_won:bool) -> void:
	_in_combat = false
	_cleanup_combat_nodes()
	if player_won:
		_room_sequencer.on_room_cleared()
	else:
		_room_sequencer.on_player_died()


func _on_run_completed() -> void:
	_result_is_victory = true
	_show_result_screen(true)


func _on_run_failed() -> void:
	_result_is_victory = false
	_show_result_screen(false)


func _show_result_screen(player_won:bool) -> void:
	if _result_screen != null:
		_result_screen.queue_free()
		_result_screen = null

	_result_screen = RESULT_SCREEN_SCENE.instantiate() as GameResultScreen
	add_child(_result_screen)
	_result_screen.show_result(player_won)
	_result_screen.continue_pressed.connect(_on_continue)
	_result_screen.retry_pressed.connect(_on_retry)
	_result_screen.menu_pressed.connect(_on_menu)


func _on_continue() -> void:
	if _result_is_victory:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		_reset_run()


func _on_retry() -> void:
	_reset_run()


func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _reset_run() -> void:
	_cleanup_combat_nodes()
	if _result_screen != null:
		_result_screen.queue_free()
		_result_screen = null
	_player_health = null
	_room_sequencer.reset()
	_room_sequencer.start_run()


func _cleanup_combat_nodes() -> void:
	_enemy_hp_drawers.clear()

	if _combat_hud != null:
		_combat_hud.clear_bindings()
		_combat_hud.queue_free()
		_combat_hud = null

	if _combat_manager != null:
		_combat_manager.queue_free()
		_combat_manager = null

	if _combat_grid != null:
		_combat_grid.queue_free()
		_combat_grid = null

	for enemy_node in _enemy_nodes:
		if enemy_node != null && is_instance_valid(enemy_node):
			enemy_node.queue_free()
	_enemy_nodes.clear()


class _EnemyHPDrawer extends Node2D:
	var health:HealthResource
	var _prev_hp:float = -1.0

	func _process(_delta:float) -> void:
		if health == null:
			return
		if health.hp != _prev_hp:
			_prev_hp = health.hp
			queue_redraw()

	func _draw() -> void:
		if health == null:
			return
		var w:float = 14.0
		var h:float = 2.0
		var bg_rect:Rect2 = Rect2(-w * 0.5, 0.0, w, h)
		draw_rect(bg_rect, Color(0.15, 0.0, 0.0, 0.8))
		var ratio:float = clampf(health.hp / maxf(health.max_hp, 1.0), 0.0, 1.0)
		if ratio > 0.0:
			var fill_color:Color = Color(0.2, 0.85, 0.2) if ratio > 0.5 else (Color(0.9, 0.7, 0.1) if ratio > 0.25 else Color(0.9, 0.15, 0.1))
			var fill_rect:Rect2 = Rect2(-w * 0.5, 0.0, w * ratio, h)
			draw_rect(fill_rect, fill_color)
		draw_rect(bg_rect, Color(0.4, 0.4, 0.5, 0.6), false, 1.0)
