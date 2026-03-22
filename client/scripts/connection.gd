extends Control

signal connected

enum AuthState {
	IDLE,
	OPENING_AUTH,
	AWAITING_APPROVAL,
	VERIFYING,
	CONNECTED,
}

const AUTH_BROWSER_SCENE: PackedScene = preload("res://scenes/auth_browser.tscn")

var _auth_state: AuthState = AuthState.IDLE
var _auth_url_handled := false
var _pending_external_url := ""
var _auth_browser: Control
var _external_auth_dialog: ConfirmationDialog

@onready var status_label: Label = %StatusLabel
@onready var connect_button: Button = %ConnectButton
@onready var retry_button: Button = %RetryButton

func _ready() -> void:
	retry_button.visible = false
	dojo_bridge.auth_url_ready.connect(_on_auth_url_ready)
	_external_auth_dialog = ConfirmationDialog.new()
	_external_auth_dialog.title = "Open External Browser"
	_external_auth_dialog.dialog_text = "This will open your browser for authentication."
	_external_auth_dialog.confirmed.connect(_on_external_auth_confirmed)
	_external_auth_dialog.canceled.connect(_on_external_auth_canceled)
	add_child(_external_auth_dialog)

	# Connect to Torii first
	status_label.text = "Connecting to Torii..."
	if not dojo_bridge.connect_torii():
		status_label.text = "Could not connect to Torii at %s" % dojo_bridge.torii_url
		return

	# Try resuming an existing session before showing Connect button
	status_label.text = "Checking existing session..."
	if dojo_bridge.try_resume_controller_session():
		_set_state(AuthState.CONNECTED)
		status_label.text = "Connected"
		connected.emit()
		return

	status_label.text = "Connect your account to enter Athanor"

func _on_connect_button_pressed() -> void:
	if _auth_state != AuthState.IDLE:
		return
	_auth_url_handled = false
	_set_state(AuthState.OPENING_AUTH)
	connect_button.disabled = true
	retry_button.visible = false

	# Ensure Torii is connected before starting auth
	status_label.text = "Connecting to Torii..."
	if not dojo_bridge.connect_torii():
		status_label.text = "Could not connect to Torii at %s" % dojo_bridge.torii_url
		connect_button.disabled = false
		_set_state(AuthState.IDLE)
		return

	status_label.text = "Opening authentication..."
	dojo_bridge.initiate_controller_auth()
	if not _auth_url_handled:
		# External browser fallback path — no auth_url_ready signal was emitted
		_set_state(AuthState.AWAITING_APPROVAL)
		status_label.text = "Approve the session in your browser, then click Retry"
		retry_button.visible = true

func _on_retry_button_pressed() -> void:
	_try_complete_auth()

func _on_auth_url_ready(url: String) -> void:
	_auth_url_handled = true
	if _can_use_embedded_auth_browser():
		_open_embedded_auth(url)
	else:
		_open_external_auth_with_confirmation(url)

func _open_embedded_auth(url: String) -> void:
	var browser := _ensure_auth_browser()
	if browser == null:
		_set_idle_with_retry("Embedded browser is unavailable — complete auth in browser, then click Retry")
		OS.shell_open(url)
		return
	browser.call("show_auth", url)
	_set_state(AuthState.AWAITING_APPROVAL)
	status_label.text = "Approve the session in the in-game browser"
	retry_button.visible = true

func _open_external_auth_with_confirmation(url: String) -> void:
	_pending_external_url = url
	_set_state(AuthState.OPENING_AUTH)
	_external_auth_dialog.popup_centered()

func _on_external_auth_confirmed() -> void:
	if _pending_external_url.is_empty():
		_set_idle_with_retry("Missing authentication URL — please try again")
		return
	OS.shell_open(_pending_external_url)
	_pending_external_url = ""
	_set_state(AuthState.AWAITING_APPROVAL)
	status_label.text = "Approve the session in your browser, then click Retry"
	retry_button.visible = true

func _on_external_auth_canceled() -> void:
	_pending_external_url = ""
	_set_idle_with_retry("Authentication canceled")

func _on_auth_url_matched(_url: String) -> void:
	_try_complete_auth()

func _on_auth_closed() -> void:
	_hide_auth_browser()
	_set_idle_with_retry("Authentication canceled — click Retry after approving")

func _on_auth_error(message: String) -> void:
	_hide_auth_browser()
	_set_idle_with_retry("Authentication error: %s" % message)

func _try_complete_auth() -> void:
	if _auth_state == AuthState.VERIFYING or _auth_state == AuthState.CONNECTED:
		return
	if _auth_state == AuthState.IDLE:
		return
	_set_state(AuthState.VERIFYING)
	connect_button.disabled = true
	retry_button.visible = false
	status_label.text = "Verifying session..."
	if dojo_bridge.complete_controller_auth():
		_set_state(AuthState.CONNECTED)
		_hide_auth_browser()
		retry_button.visible = false
		var info := dojo_bridge.get_player_info()
		var username: String = info.get("username", "")
		if username.is_empty():
			status_label.text = "Connected"
		else:
			status_label.text = "Welcome, %s" % username
		connected.emit()
	else:
		_set_state(AuthState.IDLE)
		status_label.text = "Session not ready yet — complete auth, then click Retry"
		connect_button.disabled = false
		retry_button.visible = true

func _set_idle_with_retry(message: String) -> void:
	_set_state(AuthState.IDLE)
	status_label.text = message
	connect_button.disabled = false
	retry_button.visible = true

func _ensure_auth_browser() -> Control:
	if _auth_browser != null and is_instance_valid(_auth_browser):
		return _auth_browser
	if AUTH_BROWSER_SCENE == null:
		return null
	var instance := AUTH_BROWSER_SCENE.instantiate()
	if not (instance is Control):
		return null
	_auth_browser = instance as Control
	add_child(_auth_browser)
	if _auth_browser.has_signal("auth_url_matched"):
		_auth_browser.connect("auth_url_matched", Callable(self, "_on_auth_url_matched"))
	if _auth_browser.has_signal("auth_closed"):
		_auth_browser.connect("auth_closed", Callable(self, "_on_auth_closed"))
	if _auth_browser.has_signal("auth_error"):
		_auth_browser.connect("auth_error", Callable(self, "_on_auth_error"))
	return _auth_browser

func _hide_auth_browser() -> void:
	if _auth_browser != null and is_instance_valid(_auth_browser):
		_auth_browser.call("hide_auth")

func _can_use_embedded_auth_browser() -> bool:
	var os_name := OS.get_name()
	var is_desktop := os_name in ["Linux", "Windows", "macOS"]
	return is_desktop and ClassDB.class_exists("CefTexture")

func _set_state(next_state: AuthState) -> void:
	_auth_state = next_state
