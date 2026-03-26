extends Control

const DEFAULT_TORII_URL := "https://api.cartridge.gg/x/athanor-djizus-slot/torii"
const DEFAULT_RPC_URL := "https://api.cartridge.gg/x/athanor-djizus-slot/katana"
const DEFAULT_WORLD_ADDRESS := "0x2f7d2a01f4a8273a75d3c6b625a2a47469dbeac537afb38ada984e2b358b185"
const DEFAULT_ACTIONS_ADDRESS := "0x3ed528647b1f3f347b47f7048e02203517343f32f9c5d710a9bd836d6b412a5"

var _connect_button: Button = null
var _awaiting_auth := false

func _ready() -> void:
	DojoBridge.configure_network(
		DEFAULT_TORII_URL,
		DEFAULT_RPC_URL,
		DEFAULT_WORLD_ADDRESS,
		DEFAULT_ACTIONS_ADDRESS
	)
	DojoIntegration.set_enabled(false)

	$VBox/EnterDungeon.pressed.connect(_on_enter)
	$VBox/Quit.pressed.connect(_on_quit)
	_setup_connect_button()

func _setup_connect_button() -> void:
	_connect_button = Button.new()
	_connect_button.text = "Connect"
	_connect_button.pressed.connect(_on_connect)
	$VBox.add_child(_connect_button)
	$VBox.move_child(_connect_button, 1)

	if _has_dojo_sdk():
		_ensure_sdk_nodes()
		if DojoBridge.try_resume_controller_session():
			_on_auth_success()

func _on_connect() -> void:
	if not _has_dojo_sdk():
		_connect_button.text = "SDK not installed"
		return

	_ensure_sdk_nodes()

	if _awaiting_auth:
		# Second click: complete auth after browser approval
		_connect_button.text = "Completing..."
		_connect_button.disabled = true
		if DojoBridge.complete_controller_auth():
			_on_auth_success()
		else:
			_connect_button.text = "Auth Failed — Retry"
			_connect_button.disabled = false
			_awaiting_auth = false
		return

	# First click: try resume, then initiate browser auth
	if DojoBridge.try_resume_controller_session():
		_on_auth_success()
		return

	DojoBridge.initiate_controller_auth()
	_awaiting_auth = true
	_connect_button.text = "Complete Auth"

func _on_auth_success() -> void:
	_awaiting_auth = false
	var addr := DojoBridge.current_player
	var short := addr.left(6) + "..." + addr.right(4) if addr.length() > 10 else addr
	_connect_button.text = "Connected (%s)" % short
	_connect_button.disabled = true

	DojoBridge.connect_torii()
	DojoIntegration.set_enabled(true)

func _on_enter() -> void:
	get_tree().change_scene_to_file("res://scenes/dungeon_room.tscn")

func _on_quit() -> void:
	get_tree().quit()

# --- SDK node helpers ---

func _has_dojo_sdk() -> bool:
	return ClassDB.class_exists("ToriiClient") and ClassDB.class_exists("DojoSessionAccount")

func _ensure_sdk_nodes() -> void:
	if DojoBridge.torii_client != null and DojoBridge.session_account != null:
		return
	var torii_client: Node = null
	var session_account: Node = null
	if ClassDB.class_exists("ToriiClient"):
		torii_client = ClassDB.instantiate("ToriiClient")
		torii_client.name = "ToriiClient"
		add_child(torii_client)
	if ClassDB.class_exists("DojoSessionAccount"):
		session_account = ClassDB.instantiate("DojoSessionAccount")
		session_account.name = "DojoSessionAccount"
		add_child(session_account)
	if torii_client != null and session_account != null:
		DojoBridge.configure_nodes(torii_client, session_account)
