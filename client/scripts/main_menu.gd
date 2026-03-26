extends Control

const DEFAULT_TORII_URL := "https://api.cartridge.gg/x/athanor-djizus-slot/torii"
const DEFAULT_RPC_URL := "https://api.cartridge.gg/x/athanor-djizus-slot/katana"
const DEFAULT_WORLD_ADDRESS := "0x2f7d2a01f4a8273a75d3c6b625a2a47469dbeac537afb38ada984e2b358b185"
const DEFAULT_ACTIONS_ADDRESS := "0x3ed528647b1f3f347b47f7048e02203517343f32f9c5d710a9bd836d6b412a5"

var _online_button: Button = null
var _awaiting_auth := false

func _ready() -> void:
	DojoBridge.configure_network(
		DEFAULT_TORII_URL,
		DEFAULT_RPC_URL,
		DEFAULT_WORLD_ADDRESS,
		DEFAULT_ACTIONS_ADDRESS
	)
	DojoIntegration.set_enabled(false)

	# Rename existing button to "Play Offline"
	$VBox/EnterDungeon.text = "Play Offline"
	$VBox/EnterDungeon.pressed.connect(_on_play_offline)

	# Add "Play Online" button right after
	_online_button = Button.new()
	_online_button.text = "Play Online"
	_online_button.pressed.connect(_on_play_online)
	$VBox.add_child(_online_button)
	$VBox.move_child(_online_button, 2)  # After Title + Play Offline

	$VBox/Quit.pressed.connect(_on_quit)

	# Auto-resume cached Controller session if SDK is present
	if _has_dojo_sdk():
		_ensure_sdk_nodes()
		if DojoBridge.try_resume_controller_session():
			_show_connected()

func _on_play_offline() -> void:
	DojoIntegration.set_enabled(false)
	get_tree().change_scene_to_file("res://scenes/dungeon_room.tscn")

func _on_play_online() -> void:
	if _awaiting_auth:
		# Second click: complete browser auth, then enter
		_online_button.text = "Completing..."
		_online_button.disabled = true
		if DojoBridge.complete_controller_auth():
			_enter_online()
		else:
			_online_button.text = "Auth Failed — Retry"
			_online_button.disabled = false
			_awaiting_auth = false
		return

	if not _has_dojo_sdk():
		push_warning("[main_menu] godot-dojo SDK not installed — entering offline")
		_on_play_offline()
		return

	_ensure_sdk_nodes()

	# Try cached session first
	if DojoBridge.try_resume_controller_session():
		_enter_online()
		return

	# Need browser auth — initiate and wait for second click
	DojoBridge.initiate_controller_auth()
	_awaiting_auth = true
	_online_button.text = "Complete Auth"

func _enter_online() -> void:
	_awaiting_auth = false
	_show_connected()
	DojoBridge.connect_torii()
	DojoIntegration.set_enabled(true)
	get_tree().change_scene_to_file("res://scenes/dungeon_room.tscn")

func _show_connected() -> void:
	var addr := DojoBridge.current_player
	var short := addr.left(6) + "..." + addr.right(4) if addr.length() > 10 else addr
	_online_button.text = "Play Online (%s)" % short

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
