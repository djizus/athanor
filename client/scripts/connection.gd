extends Control

signal connected

var private_key := ""
var is_connecting := false

@onready var status_label: Label = %StatusLabel
@onready var connect_button: Button = %ConnectButton
@onready var complete_button: Button = %CompleteButton
@onready var private_key_input: LineEdit = %PrivateKeyInput

func configure(torii_url: String, rpc_url: String, world_address: String, actions_address: String) -> void:
	dojo_bridge.configure_network(torii_url, rpc_url, world_address, actions_address)

func _ready() -> void:
	complete_button.disabled = true
	status_label.text = "Connect Controller to enter Athanor"

func _on_connect_button_pressed() -> void:
	if is_connecting:
		return
	is_connecting = true
	connect_button.disabled = true
	status_label.text = "Connecting Torii..."
	if not dojo_bridge.connect_torii():
		status_label.text = "Could not connect to Torii at %s" % dojo_bridge.torii_url
		connect_button.disabled = false
		is_connecting = false
		return

	if private_key.is_empty():
		private_key = private_key_input.text.strip_edges()
	if private_key.is_empty():
		private_key = String(ProjectSettings.get_setting("dojo/config/account/private_key", ""))
	if private_key.is_empty():
		status_label.text = "Set a private key to create session"
		connect_button.disabled = false
		is_connecting = false
		return

	var session_url: String = dojo_bridge.get_session_request_url(private_key)
	if not session_url.is_empty():
		OS.shell_open(session_url)
	status_label.text = "Approve session in browser if opened, then click Complete"
	complete_button.disabled = false
	is_connecting = false

func _on_complete_button_pressed() -> void:
	status_label.text = "Creating session..."
	if dojo_bridge.create_session_from_private_key(private_key):
		status_label.text = "Connected"
		connected.emit()
		return
	status_label.text = "Session is not valid yet, complete auth and retry"
