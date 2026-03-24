extends Node2D

const GameRoomScript: Script = preload("res://scripts/game_room.gd")

@export var torii_url := "http://localhost:8080"
@export var rpc_url := "http://localhost:5050"
@export var world_address := "0x0"
@export var actions_address := "0x0"

enum Screen { MENU, GAME }

var torii_client: Node
var session_account: Node
var http_tools: Node

var _current_screen: int = Screen.MENU
var _room_instance: Node = null
var _spawn_requested := false
var _enter_requested := false
var _active_game_id := -1
var _auth_pending := false
var _verifying := false

var _menu_layer: CanvasLayer
var _status_label: Label
var _player_label: Label
var _connect_button: Button
var _enter_button: Button
var _disconnect_button: Button
var _auth_browser: Control

func _ready() -> void:
	_apply_project_settings()
	_build_menu_ui()
	_connect_signals()

	_bootstrap_dojo_nodes()
	if torii_client != null and session_account != null:
		DojoBridge.configure_nodes(torii_client, session_account, http_tools)
	else:
		DojoBridge.torii_client = torii_client
		DojoBridge.session_account = session_account
		DojoBridge.http_tools = http_tools
	DojoBridge.configure_network(torii_url, rpc_url, world_address, actions_address)

	DojoBridge.connect_torii()

	var authenticated := false
	if _is_local_rpc(rpc_url):
		authenticated = _try_burner_connect()
	if not authenticated:
		authenticated = DojoBridge.try_resume_controller_session()
	if authenticated:
		DojoBridge.pull_entities_snapshot()

	_show_menu()
	_refresh_menu_ui()

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

func _bootstrap_dojo_nodes() -> void:
	torii_client = _create_sdk_node("ToriiClient", "ToriiClient")
	session_account = _create_sdk_node("DojoSessionAccount", "DojoSessionAccount")
	http_tools = _create_sdk_node("HttpTools", "HttpTools")

func _create_sdk_node(type_name: String, node_name: String) -> Node:
	if not ClassDB.class_exists(type_name):
		return null
	var node: Node = ClassDB.instantiate(type_name) as Node
	if node == null:
		return null
	node.name = node_name
	add_child(node)
	return node

func _try_burner_connect() -> bool:
	var dev_key := String(ProjectSettings.get_setting("dojo/config/account/private_key", ""))
	var dev_address := String(ProjectSettings.get_setting("dojo/config/account/address", ""))

	if dev_key.is_empty() or dev_key == "0x0" or dev_address.is_empty() or dev_address == "0x0":
		dev_key = OS.get_environment("ATHANOR_BURNER_PRIVATE_KEY")
		dev_address = OS.get_environment("ATHANOR_BURNER_ADDRESS")

	if dev_key.is_empty() or dev_key == "0x0" or dev_address.is_empty() or dev_address == "0x0":
		dev_address = "0x2af9427c5a277474c079a1283c880ee8a6f0f8fbf73ce969c08d88befec1bba"
		dev_key = "0x1800000000300000180000000000030000000000003006001800006600"

	return DojoBridge.setup_burner(dev_key, dev_address)

func _is_local_rpc(url: String) -> bool:
	var u := url.to_lower()
	return u.begins_with("http://localhost") or u.begins_with("http://127.0.0.1")

func _connect_signals() -> void:
	if not game_state.run_updated.is_connected(_on_run_updated):
		game_state.run_updated.connect(_on_run_updated)
	if not game_state.room_updated.is_connected(_on_room_updated):
		game_state.room_updated.connect(_on_room_updated)
	if not game_state.game_over.is_connected(_on_game_over):
		game_state.game_over.connect(_on_game_over)

	if not DojoBridge.session_ready.is_connected(_on_session_ready):
		DojoBridge.session_ready.connect(_on_session_ready)
	if not DojoBridge.tx_failed.is_connected(_on_tx_failed):
		DojoBridge.tx_failed.connect(_on_tx_failed)
	if not DojoBridge.auth_url_ready.is_connected(_on_auth_url_ready):
		DojoBridge.auth_url_ready.connect(_on_auth_url_ready)

	var window := get_window()
	if window != null and not window.focus_entered.is_connected(_on_window_focus):
		window.focus_entered.connect(_on_window_focus)

func _build_menu_ui() -> void:
	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 50
	add_child(_menu_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.12, 0.18, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_layer.add_child(bg)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 12)
	center.custom_minimum_size = Vector2(320, 0)
	_menu_layer.add_child(center)

	var title := Label.new()
	title.text = "ATHANOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	center.add_child(title)

	center.add_child(HSeparator.new())

	_player_label = Label.new()
	_player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_label.visible = false
	center.add_child(_player_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(300, 0)
	center.add_child(_status_label)

	_connect_button = Button.new()
	_connect_button.text = "Connect Wallet"
	_connect_button.custom_minimum_size = Vector2(220, 40)
	_connect_button.pressed.connect(_on_connect_wallet_pressed)
	center.add_child(_connect_button)

	_enter_button = Button.new()
	_enter_button.text = "Enter Dungeon"
	_enter_button.custom_minimum_size = Vector2(220, 40)
	_enter_button.visible = false
	_enter_button.pressed.connect(_on_enter_dungeon_pressed)
	center.add_child(_enter_button)

	_disconnect_button = Button.new()
	_disconnect_button.text = "Disconnect"
	_disconnect_button.custom_minimum_size = Vector2(220, 32)
	_disconnect_button.visible = false
	_disconnect_button.pressed.connect(_on_disconnect_pressed)
	center.add_child(_disconnect_button)

	_setup_auth_browser()

func _setup_auth_browser() -> void:
	var auth_script: Script = load("res://scripts/auth_browser.gd")
	if auth_script == null:
		return

	_auth_browser = Control.new()
	_auth_browser.name = "AuthBrowser"
	_auth_browser.set_script(auth_script)
	_auth_browser.set_anchors_preset(Control.PRESET_FULL_RECT)

	var browser_container := MarginContainer.new()
	browser_container.name = "BrowserContainer"
	browser_container.unique_name_in_owner = true
	browser_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	browser_container.add_theme_constant_override("margin_top", 40)
	browser_container.add_theme_constant_override("margin_bottom", 40)
	browser_container.add_theme_constant_override("margin_left", 40)
	browser_container.add_theme_constant_override("margin_right", 40)
	_auth_browser.add_child(browser_container)

	var close_btn := Button.new()
	close_btn.name = "CloseButton"
	close_btn.unique_name_in_owner = true
	close_btn.text = "X"
	close_btn.position = Vector2(8, 8)
	close_btn.custom_minimum_size = Vector2(30, 30)
	_auth_browser.add_child(close_btn)

	var loading_lbl := Label.new()
	loading_lbl.name = "LoadingLabel"
	loading_lbl.unique_name_in_owner = true
	loading_lbl.text = "Loading..."
	loading_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_lbl.set_anchors_preset(Control.PRESET_CENTER)
	loading_lbl.visible = false
	_auth_browser.add_child(loading_lbl)

	var error_lbl := Label.new()
	error_lbl.name = "ErrorLabel"
	error_lbl.unique_name_in_owner = true
	error_lbl.text = ""
	error_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_lbl.set_anchors_preset(Control.PRESET_CENTER)
	error_lbl.visible = false
	_auth_browser.add_child(error_lbl)

	_menu_layer.add_child(_auth_browser)
	_auth_browser.set_owner(_menu_layer)
	for child in _auth_browser.get_children():
		child.set_owner(_auth_browser)

	if _auth_browser.has_signal("auth_url_matched"):
		_auth_browser.auth_url_matched.connect(_on_auth_browser_matched)
	if _auth_browser.has_signal("auth_closed"):
		_auth_browser.auth_closed.connect(_on_auth_browser_closed)
	if _auth_browser.has_signal("auth_error"):
		_auth_browser.auth_error.connect(_on_auth_browser_error)

func _refresh_menu_ui() -> void:
	var authed := not DojoBridge.current_player.is_empty()

	_connect_button.visible = not authed
	_enter_button.visible = authed
	_disconnect_button.visible = authed

	if authed:
		var info := DojoBridge.get_player_info() if DojoBridge.has_method("get_player_info") else {}
		var username := String(info.get("username", ""))
		var address := String(info.get("address", DojoBridge.current_player))
		if not username.is_empty():
			_player_label.text = "Welcome, %s" % username
		elif not address.is_empty():
			_player_label.text = "%s...%s" % [address.left(8), address.right(4)]
		else:
			_player_label.text = "Connected"
		_player_label.visible = true
		if _status_label.text.is_empty() or _status_label.text.begins_with("Connect your wallet"):
			_status_label.text = ""
	else:
		_player_label.visible = false
		_status_label.text = "Connect your wallet to enter Athanor"

	_enter_button.disabled = _spawn_requested
	_connect_button.disabled = _auth_pending or _verifying

func _on_connect_wallet_pressed() -> void:
	if _auth_pending:
		return
	_auth_pending = true
	_connect_button.disabled = true
	_status_label.text = "Connecting..."
	DojoBridge.initiate_controller_auth()

	if _auth_browser == null or not _auth_browser.call("is_showing"):
		_status_label.text = "A browser window has opened — approve the session there, then Alt-Tab back"

func _on_auth_url_ready(url: String) -> void:
	if _auth_browser != null:
		_status_label.text = "Approve the session below"
		_auth_browser.call("show_auth", url)
	else:
		_status_label.text = "A browser window has opened — approve the session there, then Alt-Tab back"

func _on_auth_browser_matched(_url: String) -> void:
	if _auth_browser != null:
		_auth_browser.call("hide_auth")
	_try_complete_auth()

func _on_auth_browser_closed() -> void:
	_auth_pending = false
	_verifying = false
	_connect_button.disabled = false
	_status_label.text = "Authentication cancelled"

func _on_auth_browser_error(_message: String) -> void:
	if _auth_browser != null:
		_auth_browser.call("hide_auth")
	DojoBridge.initiate_controller_auth()
	_status_label.text = "A browser window has opened — approve the session there, then Alt-Tab back"

func _on_window_focus() -> void:
	if _auth_pending and (_auth_browser == null or not _auth_browser.call("is_showing")):
		_try_complete_auth()

func _try_complete_auth() -> void:
	if not _auth_pending or _verifying:
		return
	_verifying = true
	_status_label.text = "Verifying session..."
	if DojoBridge.complete_controller_auth():
		_auth_pending = false
		_verifying = false
		DojoBridge.pull_entities_snapshot()
		_refresh_menu_ui()
	else:
		_verifying = false
		_status_label.text = "Session not ready yet — complete auth in browser, then return to the game window"
		_connect_button.disabled = false

func _on_session_ready(_address: String) -> void:
	_auth_pending = false
	_verifying = false
	_refresh_menu_ui()

func _on_enter_dungeon_pressed() -> void:
	if _spawn_requested:
		return
	_spawn_requested = true
	_enter_requested = false
	_active_game_id = -1
	game_state.reset()
	_enter_button.disabled = true
	_status_label.text = "Spawning new dungeon..."
	DojoBridge.spawn_v2(0)

func _on_disconnect_pressed() -> void:
	DojoBridge.disconnect_session()
	game_state.reset()
	_spawn_requested = false
	_enter_requested = false
	_active_game_id = -1
	_show_menu()
	_refresh_menu_ui()

func _on_run_updated(run_state: Dictionary) -> void:
	if run_state.is_empty():
		return
	if not _spawn_requested:
		return

	var run_game_id := int(run_state.get("game_id", -1))
	if run_game_id >= 0:
		_active_game_id = run_game_id

	var phase := int(run_state.get("phase", 0))
	if phase == 3 or phase == 4:
		return

	if _active_game_id < 0:
		return
	if _enter_requested:
		return

	_enter_requested = true
	_status_label.text = "Entering room..."
	DojoBridge.enter_room_v2(_active_game_id, 0)

func _on_room_updated(room_state: Dictionary) -> void:
	if room_state.is_empty():
		return
	var game_id := int(room_state.get("game_id", -1))
	if game_id < 0:
		return
	if _active_game_id >= 0 and game_id != _active_game_id:
		return

	_active_game_id = game_id
	_spawn_requested = false
	_show_game()
	if _room_instance != null and _room_instance.has_method("configure"):
		_room_instance.call("configure", _active_game_id, int(room_state.get("room_id", 0)))

func _on_game_over() -> void:
	_spawn_requested = false
	_enter_requested = false
	_active_game_id = -1
	_show_menu()
	_status_label.text = "Run ended. Enter Dungeon to start again."
	_refresh_menu_ui()

func _on_tx_failed(action: String, reason: String) -> void:
	if action == "spawn_v2":
		_spawn_requested = false
		_enter_requested = false
	if action == "enter_room_v2":
		_enter_requested = false
	_status_label.text = "Error: %s — %s" % [action, reason]
	_refresh_menu_ui()

func _show_game() -> void:
	_current_screen = Screen.GAME
	_menu_layer.visible = false
	if _room_instance == null or not is_instance_valid(_room_instance):
		_room_instance = GameRoomScript.new()
		_room_instance.name = "GameRoom"
		add_child(_room_instance)

func _show_menu() -> void:
	_current_screen = Screen.MENU
	_menu_layer.visible = true
	if _room_instance != null and is_instance_valid(_room_instance):
		_room_instance.queue_free()
		_room_instance = null
