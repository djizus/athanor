extends Node

@export var torii_url := "http://localhost:8080"
@export var rpc_url := "http://localhost:5050"
@export var world_address := "0x0"
@export var actions_address := "0x0"

var main_menu_scene: PackedScene = preload("res://scenes/main_menu.tscn")
var arena_scene: PackedScene = preload("res://scenes/arena.tscn")

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

	# Connect Torii + try auth
	dojo_bridge.connect_torii()

	var authenticated := false
	if _is_local_rpc(rpc_url):
		authenticated = _try_burner_connect()
	if not authenticated:
		authenticated = dojo_bridge.try_resume_controller_session()
	if authenticated:
		dojo_bridge.pull_entities_snapshot()

	# Always start at main menu — it handles routing based on state
	_switch_scene(main_menu_scene)

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

func _switch_scene(packed: PackedScene, use_transition: bool = false) -> Node:
	if use_transition and not transition_manager.is_transitioning:
		transition_manager.fade_to_black(0.3)
		await transition_manager.transition_midpoint
	if current_scene:
		current_scene.queue_free()
		current_scene = null
	var instance := packed.instantiate()
	scene_container.add_child(instance)
	current_scene = instance
	_connect_scene_signals(instance)
	if use_transition:
		transition_manager.fade_from_black(0.3)
	return instance

func _connect_scene_signals(scene: Node) -> void:
	if scene.has_signal("enter_arena"):
		scene.enter_arena.connect(_on_enter_arena)
	if scene.has_signal("connected"):
		scene.connected.connect(_on_connected)
	if scene.has_signal("return_to_menu"):
		scene.return_to_menu.connect(_on_return_to_menu)

# --- Scene transition handlers ---

func _on_enter_arena() -> void:
	_switch_scene(arena_scene, true)

func _on_connected() -> void:
	pass

func _on_return_to_menu() -> void:
	_switch_scene(main_menu_scene, true)
