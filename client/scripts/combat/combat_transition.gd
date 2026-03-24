class_name CombatTransition
extends Node

@export var fight_mode:BoolResource
@export var room_root:Node
@export var combat_grid_scene:PackedScene = preload("res://scenes/combat/combat_grid.tscn")
@export var combat_manager_scene:PackedScene
@export var combat_hud_path:NodePath

var _combat_grid_instance:Node
var _combat_manager_instance:Node

var _player_mover:MoverTopDown2D
var _player_input:PlayerInput
var _enemy_inputs:Array[BotInput] = []

func _ready() -> void:
	if fight_mode == null:
		return
	fight_mode.changed_true.connect(_on_fight_mode_enabled)
	fight_mode.changed_false.connect(_on_fight_mode_disabled)

	if fight_mode.value:
		_on_fight_mode_enabled()

func _on_fight_mode_enabled() -> void:
	var room:Node = _get_room_root()
	if room == null:
		return

	_disable_realtime_systems()
	_spawn_combat_grid(room)
	_snap_player_to_grid()
	_disable_and_place_enemies()
	_spawn_combat_manager(room)
	_set_combat_hud_visible(true)
	_start_turn_manager()

func _on_fight_mode_disabled() -> void:
	_destroy_combat_runtime()
	_enable_realtime_systems()
	_set_combat_hud_visible(false)

func _disable_realtime_systems() -> void:
	_player_mover = _find_first_node(MoverTopDown2D) as MoverTopDown2D
	if _player_mover != null:
		_player_mover.set_enabled_process(false)

	_player_input = _find_first_node(PlayerInput) as PlayerInput
	if _player_input != null:
		_player_input.set_enabled(false)

func _enable_realtime_systems() -> void:
	if _player_mover != null:
		_player_mover.set_enabled_process(true)
	if _player_input != null:
		_player_input.set_enabled(true)

	for bot_input in _enemy_inputs:
		if is_instance_valid(bot_input):
			bot_input.set_enabled(true)
	_enemy_inputs.clear()

func _spawn_combat_grid(room:Node) -> void:
	if _combat_grid_instance != null && is_instance_valid(_combat_grid_instance):
		return
	if combat_grid_scene == null:
		return

	_combat_grid_instance = combat_grid_scene.instantiate()
	room.add_child(_combat_grid_instance)
	if _combat_grid_instance.has_method("show_grid"):
		_combat_grid_instance.show_grid(Vector2i.ZERO, Vector2i(8, 8))

func _spawn_combat_manager(room:Node) -> void:
	if _combat_manager_instance != null && is_instance_valid(_combat_manager_instance):
		return

	if combat_manager_scene != null:
		_combat_manager_instance = combat_manager_scene.instantiate()
	else:
		_combat_manager_instance = TurnManager.new()
	room.add_child(_combat_manager_instance)

func _start_turn_manager() -> void:
	if _combat_manager_instance == null:
		return
	if _combat_manager_instance.has_method("start_combat"):
		_combat_manager_instance.start_combat()

func _destroy_combat_runtime() -> void:
	if _combat_grid_instance != null && is_instance_valid(_combat_grid_instance):
		_combat_grid_instance.queue_free()
	if _combat_manager_instance != null && is_instance_valid(_combat_manager_instance):
		_combat_manager_instance.queue_free()
	_combat_grid_instance = null
	_combat_manager_instance = null

func _snap_player_to_grid() -> void:
	var player:Node2D = _find_player_node2d()
	if player == null:
		return
	if _combat_grid_instance == null:
		return
	if !_combat_grid_instance.has_method("world_to_grid") || !_combat_grid_instance.has_method("grid_to_world"):
		return

	var grid_pos:Vector2i = _combat_grid_instance.world_to_grid(player.global_position)
	player.global_position = _combat_grid_instance.grid_to_world(grid_pos)

func _disable_and_place_enemies() -> void:
	_enemy_inputs.clear()
	if _combat_grid_instance == null:
		return

	for node in get_tree().get_nodes_in_group(&"enemy"):
		if node is Node2D && _combat_grid_instance.has_method("world_to_grid") && _combat_grid_instance.has_method("grid_to_world"):
			var enemy_2d:Node2D = node
			var enemy_cell:Vector2i = _combat_grid_instance.world_to_grid(enemy_2d.global_position)
			enemy_2d.global_position = _combat_grid_instance.grid_to_world(enemy_cell)

	var all_bot_inputs:Array = get_tree().get_nodes_in_group(&"bot_input")
	for bot in all_bot_inputs:
		if bot is BotInput:
			var bot_input:BotInput = bot
			bot_input.set_enabled(false)
			_enemy_inputs.push_back(bot_input)

	if _enemy_inputs.is_empty():
		var root_node:Node = get_tree().root
		if root_node == null:
			return
		_find_bot_inputs_recursive(root_node)

func _find_bot_inputs_recursive(node:Node) -> void:
	if node is BotInput:
		var bot_input:BotInput = node
		bot_input.set_enabled(false)
		_enemy_inputs.push_back(bot_input)
	for child in node.get_children():
		_find_bot_inputs_recursive(child)

func _set_combat_hud_visible(visible:bool) -> void:
	if combat_hud_path.is_empty():
		return
	var hud_node:Node = get_node_or_null(combat_hud_path)
	if hud_node == null:
		return
	if hud_node is CanvasItem:
		(hud_node as CanvasItem).visible = visible

func _get_room_root() -> Node:
	if room_root != null:
		return room_root
	return owner if owner != null else get_parent()

func _find_player_node2d() -> Node2D:
	if _player_mover != null && is_instance_valid(_player_mover) && _player_mover.character != null:
		return _player_mover.character

	var candidate:Node = _find_first_node(CharacterBody2D)
	if candidate is CharacterBody2D:
		return candidate as CharacterBody2D
	return null

func _find_first_node(target_type:Variant) -> Node:
	return _find_first_node_recursive(get_tree().root, target_type)

func _find_first_node_recursive(node:Node, target_type:Variant) -> Node:
	if is_instance_of(node, target_type):
		return node
	for child in node.get_children():
		var found:Node = _find_first_node_recursive(child, target_type)
		if found != null:
			return found
	return null
