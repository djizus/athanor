extends Control

signal connected

var _auth_pending := false
var _verifying := false

@onready var status_label: Label = %StatusLabel
@onready var connect_button: Button = %ConnectButton
@onready var retry_button: Button = %RetryButton

func _ready() -> void:
	retry_button.visible = false
	status_label.text = "Connecting to Torii..."
	get_window().focus_entered.connect(_on_window_focus)

	if not dojo_bridge.connect_torii():
		status_label.text = "Could not connect to Torii at %s" % dojo_bridge.torii_url
		return

	status_label.text = "Checking existing session..."
	if dojo_bridge.try_resume_controller_session():
		status_label.text = "Connected"
		connected.emit()
		return

	status_label.text = "Connect your account to enter Athanor"

func _on_connect_button_pressed() -> void:
	if _auth_pending:
		return
	connect_button.disabled = true
	status_label.text = "Connecting to Torii..."

	if not dojo_bridge.connect_torii():
		status_label.text = "Could not connect to Torii at %s" % dojo_bridge.torii_url
		connect_button.disabled = false
		return

	status_label.text = "Opening browser for authentication..."
	_auth_pending = true
	dojo_bridge.initiate_controller_auth()
	status_label.text = "Approve the session in your browser, then return here"
	retry_button.visible = true

func _on_retry_button_pressed() -> void:
	_try_complete_auth()

func _on_window_focus() -> void:
	if _auth_pending:
		_try_complete_auth()

func _try_complete_auth() -> void:
	if not _auth_pending or _verifying:
		return
	_verifying = true
	status_label.text = "Verifying session..."
	if dojo_bridge.complete_controller_auth():
		_auth_pending = false
		_verifying = false
		retry_button.visible = false
		var info := dojo_bridge.get_player_info()
		var username: String = info.get("username", "")
		if username.is_empty():
			status_label.text = "Connected"
		else:
			status_label.text = "Welcome, %s" % username
		connected.emit()
	else:
		_verifying = false
		status_label.text = "Session not ready yet — complete auth in browser, then click Retry"
		connect_button.disabled = false
