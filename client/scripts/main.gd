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
	_apply_project_settings()

	torii_client = _create_or_fallback("ToriiClient", $ToriiClient)
	session_account = _create_or_fallback("DojoSessionAccount", $DojoSessionAccount)
	http_tools = _create_or_fallback("HttpTools", $HttpTools)
	dojo_bridge.configure_nodes(torii_client, session_account, http_tools)
	dojo_bridge.configure_network(torii_url, rpc_url, world_address, actions_address)

	game_state.game_over.connect(_on_game_over)

	# --- Auth + routing: connect Torii, resume session, route by game state ---
	var authenticated := false

	# Burner mode (localhost only)
	if _is_local_rpc(rpc_url):
		authenticated = _try_burner_connect()

	# Controller session resume (Slot / public RPC)
	if not authenticated:
		# Connect Torii early so resume + entity pull work
		dojo_bridge.connect_torii()
		authenticated = dojo_bridge.try_resume_controller_session()

	# Route based on state
	if authenticated:
		_route_after_auth()
	else:
		_switch_scene(connection_scene)

func _route_after_auth() -> void:
	# Pull latest entities to check if character already exists
	dojo_bridge.pull_entities_snapshot()

	if not game_state.character.is_empty() and game_state.is_alive():
		var completed := bool(game_state.dungeon.get("completed", false))
		var failed := bool(game_state.dungeon.get("failed", false))
		if completed or failed:
			_switch_scene(lobby_scene)
		else:
			_switch_scene(dungeon_scene)
	else:
		_switch_scene(lobby_scene)

func _apply_project_settings() -> void:
	var cfg_torii := String(ProjectSettings.get_setting("dojo/config/torii/torii_url", ""))
	var cfg_rpc := String(ProjectSettings.get_setting("dojo/config/katana_url", ""))
	var cfg_world := String(ProjectSettings.get_setting("dojo/config/world_address", ""))
	var cfg_actions := String(ProjectSettings.get_setting("dojo/config/actions_address", ""))
	if not cfg_torii.is_empty() and cfg_torii != "0x0":
		torii_url = cfg_torii
	if not cfg_rpc.is_empty() and cfg_rpc != "0x0":
		rpc_url = cfg_rpc
	if not cfg_world.is_empty() and cfg_world != "0x0":
		world_address = cfg_world
	if not cfg_actions.is_empty() and cfg_actions != "0x0":
		actions_address = cfg_actions

func _create_or_fallback(type_name: String, placeholder: Node) -> Node:
	if ClassDB.class_exists(type_name):
		var real: Node = ClassDB.instantiate(type_name) as Node
		if real != null:
			real.name = placeholder.name
			placeholder.replace_by(real)
			placeholder.queue_free()
			return real
	return placeholder

func _try_burner_connect() -> bool:
	var dev_key := String(ProjectSettings.get_setting("dojo/config/account/private_key", ""))
	var dev_address := String(ProjectSettings.get_setting("dojo/config/account/address", ""))
	if dev_key.is_empty() or dev_key == "0x0" or dev_address.is_empty() or dev_address == "0x0":
		return false
	if not dojo_bridge.connect_torii():
		return false
	return dojo_bridge.setup_burner(dev_key, dev_address)

func _is_local_rpc(url: String) -> bool:
	var u := url.to_lower()
	return u.begins_with("http://localhost") or u.begins_with("http://127.0.0.1")

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
	_route_after_auth()

func _on_dungeon_entered() -> void:
	_switch_scene(dungeon_scene)

func _on_game_over(completed: bool, failed: bool) -> void:
	var scene := _switch_scene(game_over_scene)
	if scene != null and scene.has_method("setup"):
		scene.call("setup", completed, failed)

func _on_play_again() -> void:
	_switch_scene(lobby_scene)

func _on_back_to_lobby() -> void:
	_switch_scene(lobby_scene)

func _on_disconnected() -> void:
	_switch_scene(connection_scene)
