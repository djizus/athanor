extends Node

@export var torii_url := "http://localhost:8080"
@export var rpc_url := "http://localhost:5050"
@export var world_address := "0x0"
@export var actions_address := "0x0"

@onready var connection_screen: Control = %ConnectionScreen
@onready var dungeon_view: Node3D = %DungeonView

var torii_client: Node
var session_account: Node

func _ready() -> void:
	torii_client = _create_or_fallback("ToriiClient", $ToriiClient)
	session_account = _create_or_fallback("DojoSessionAccount", $DojoSessionAccount)
	dojo_bridge.configure_nodes(torii_client, session_account)
	dojo_bridge.configure_network(torii_url, rpc_url, world_address, actions_address)
	connection_screen.configure(torii_url, rpc_url, world_address, actions_address)
	connection_screen.connected.connect(_on_connected)
	dojo_bridge.session_ready.connect(_on_session_ready)
	_show_connection()

func _create_or_fallback(type_name: String, placeholder: Node) -> Node:
	if ClassDB.class_exists(type_name):
		var real: Node = ClassDB.instantiate(type_name) as Node
		if real != null:
			real.name = placeholder.name
			placeholder.replace_by(real)
			placeholder.queue_free()
			return real
	return placeholder

func _on_connected() -> void:
	_show_dungeon()

func _on_session_ready(_address: String) -> void:
	_show_dungeon()

func _show_connection() -> void:
	connection_screen.visible = true
	dungeon_view.visible = false

func _show_dungeon() -> void:
	connection_screen.visible = false
	dungeon_view.visible = true
