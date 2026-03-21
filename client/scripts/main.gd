extends Node

@export var torii_url := "http://localhost:8080"
@export var rpc_url := "http://localhost:5050"
@export var world_address := "0x0"
@export var actions_address := "0x0"

var connection_scene: PackedScene = preload("res://scenes/connection.tscn")
var lobby_scene: PackedScene = preload("res://scenes/lobby.tscn")
var dungeon_scene: PackedScene = preload("res://scenes/dungeon.tscn")
var game_over_scene: PackedScene = preload("res://scenes/game_over.tscn")

var torii_client: Node
var session_account: Node
var http_tools: Node
var current_scene: Node

@onready var scene_container: Control = $SceneContainer

func _ready() -> void:
	torii_client = _create_or_fallback("ToriiClient", $ToriiClient)
	session_account = _create_or_fallback("DojoSessionAccount", $DojoSessionAccount)
	http_tools = _create_or_fallback("HttpTools", $HttpTools)
	dojo_bridge.configure_nodes(torii_client, session_account, http_tools)
	dojo_bridge.configure_network(torii_url, rpc_url, world_address, actions_address)

	# Listen to game_state autoload for game-over (single source of truth)
	game_state.game_over.connect(_on_game_over)

	_switch_scene(connection_scene)

func _create_or_fallback(type_name: String, placeholder: Node) -> Node:
	if ClassDB.class_exists(type_name):
		var real: Node = ClassDB.instantiate(type_name) as Node
		if real != null:
			real.name = placeholder.name
			placeholder.replace_by(real)
			placeholder.queue_free()
			return real
	return placeholder

# --- Scene management ---

func _switch_scene(packed: PackedScene) -> Node:
	if current_scene:
		current_scene.queue_free()
		current_scene = null
	var instance := packed.instantiate()
	scene_container.add_child(instance)
	current_scene = instance
	_connect_scene_signals(instance)
	return instance

func _connect_scene_signals(scene: Node) -> void:
	if scene.has_signal("connected"):
		scene.connected.connect(_on_connected)
	if scene.has_signal("dungeon_entered"):
		scene.dungeon_entered.connect(_on_dungeon_entered)
	if scene.has_signal("disconnected"):
		scene.disconnected.connect(_on_disconnected)
	if scene.has_signal("play_again"):
		scene.play_again.connect(_on_play_again)
	if scene.has_signal("back_to_lobby"):
		scene.back_to_lobby.connect(_on_back_to_lobby)

# --- Scene transition handlers ---

func _on_connected() -> void:
	_switch_scene(lobby_scene)

func _on_dungeon_entered() -> void:
	_switch_scene(dungeon_scene)

func _on_game_over(completed: bool, failed: bool) -> void:
	var scene := _switch_scene(game_over_scene)
	if scene.has_method("setup"):
		scene.call("setup", completed, failed)

func _on_play_again() -> void:
	_switch_scene(lobby_scene)

func _on_back_to_lobby() -> void:
	_switch_scene(lobby_scene)

func _on_disconnected() -> void:
	_switch_scene(connection_scene)
