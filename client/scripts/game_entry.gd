extends Node2D

const GameRoomScript: Script = preload("res://scripts/game_room.gd")

const PHASE_EXPLORE := 0
const PHASE_PLAYER_TURN := 1
const PHASE_ENEMY_TURN := 2
const PHASE_COMPLETE := 3
const PHASE_FAILED := 4

enum Screen { MENU, GAME }

var _current_screen: int = Screen.MENU
var _room_instance: Node = null
var _spawn_requested: bool = false
var _enter_requested: bool = false
var _active_game_id: int = -1
var _auth_pending := false
var _verifying := false

var _menu_layer: CanvasLayer
var _game_overlay_layer: CanvasLayer
var _status_label: Label
var _connect_button: Button
var _spawn_button: Button
var _disconnect_button: Button
var _player_label: Label
var _result_panel: PanelContainer
var _result_label: Label
var _retry_button: Button
var _auth_browser_node: Control

func _ready() -> void:
	_build_menu_ui()
	_build_game_overlay_ui()
	_connect_signals()
	_bootstrap_dojo_nodes()
	_start_flow()

func _connect_signals() -> void:
	if not game_state.run_updated.is_connected(_on_run_updated):
		game_state.run_updated.connect(_on_run_updated)
	if not game_state.room_updated.is_connected(_on_room_updated):
		game_state.room_updated.connect(_on_room_updated)
	if not game_state.game_over.is_connected(_on_game_over):
		game_state.game_over.connect(_on_game_over)
	DojoBridge.torii_connected.connect(_on_torii_connected)
	DojoBridge.session_ready.connect(_on_session_ready)
	DojoBridge.tx_failed.connect(_on_tx_failed)
	DojoBridge.tx_submitted.connect(_on_tx_submitted)
	DojoBridge.auth_url_ready.connect(_on_auth_url_ready)

func _bootstrap_dojo_nodes() -> void:
	var torii_node: Node = null
	var session_node: Node = null

	if ClassDB.class_exists("ToriiClient"):
		torii_node = ClassDB.instantiate("ToriiClient")
		if torii_node != null:
			torii_node.name = "ToriiClient"
			add_child(torii_node)

	if ClassDB.class_exists("DojoSessionAccount"):
		session_node = ClassDB.instantiate("DojoSessionAccount")
		if session_node != null:
			session_node.name = "DojoSessionAccount"
			add_child(session_node)

	if torii_node != null:
		if session_node != null:
			DojoBridge.configure_nodes(torii_node, session_node)
		else:
			DojoBridge.torii_client = torii_node

func _start_flow() -> void:
	_set_status("Connecting...")

	var is_local := DojoBridge.rpc_url.contains("localhost") or DojoBridge.rpc_url.contains("127.0.0.1")
	if is_local:
		_attempt_local_burner()

	DojoBridge.connect_torii()

	if not is_local and DojoBridge.current_player.is_empty():
		DojoBridge.try_resume_controller_session()

	_refresh_menu()

func _attempt_local_burner() -> void:
	var key := OS.get_environment("ATHANOR_BURNER_PRIVATE_KEY")
	var addr := OS.get_environment("ATHANOR_BURNER_ADDRESS")
	if key.is_empty() or addr.is_empty():
		addr = "0x2af9427c5a277474c079a1283c880ee8a6f0f8fbf73ce969c08d88befec1bba"
		key = "0x1800000000300000180000000000030000000000003006001800006600"
	DojoBridge.setup_burner(key, addr)

func _refresh_menu() -> void:
	var authed := not DojoBridge.current_player.is_empty()

	_connect_button.visible = not authed
	_spawn_button.visible = authed
	_disconnect_button.visible = authed

	if authed:
		var addr: String = DojoBridge.current_player
		var info: Dictionary = DojoBridge.get_player_info() if DojoBridge.has_method("get_player_info") else {}
		var username: String = info.get("username", "")
		if not username.is_empty():
			_player_label.text = username
		elif not addr.is_empty():
			_player_label.text = "%s...%s" % [addr.left(10), addr.right(4)]
		else:
			_player_label.text = "Connected"
		_player_label.visible = true
		_set_status("")
	else:
		_player_label.visible = false
		_set_status("Connect your wallet to enter Athanor")

func _on_torii_connected(success: bool) -> void:
	if not success:
		_set_status("Could not reach Torii")
		return
	if not DojoBridge.current_player.is_empty():
		_set_status("Connected")
		DojoBridge.pull_entities_snapshot()
	_refresh_menu()

func _on_session_ready(_address: String) -> void:
	_auth_pending = false
	_verifying = false
	_refresh_menu()

func _on_connect_pressed() -> void:
	if _auth_pending:
		return
	_auth_pending = true
	_connect_button.disabled = true
	_set_status("Opening authentication...")
	DojoBridge.initiate_controller_auth()
	await get_tree().create_timer(0.5).timeout
	if _auth_pending and (_auth_browser_node == null or not _auth_browser_node.call("is_showing")):
		_set_status("Approve the session in the browser window, then come back here")

func _on_auth_url_ready(url: String) -> void:
	if _auth_browser_node != null:
		_set_status("Approve the session below")
		_auth_browser_node.call("show_auth", url)
	else:
		_set_status("Approve the session in the browser window, then come back here")

func _on_auth_browser_matched(_url: String) -> void:
	if _auth_browser_node != null:
		_auth_browser_node.call("hide_auth")
	_try_complete_auth()

func _on_auth_browser_closed() -> void:
	_auth_pending = false
	_connect_button.disabled = false
	_set_status("Authentication cancelled")

func _on_auth_browser_error(_msg: String) -> void:
	if _auth_browser_node != null:
		_auth_browser_node.call("hide_auth")
	DojoBridge.initiate_controller_auth()
	_set_status("Approve the session in the browser, then come back")

func _try_complete_auth() -> void:
	if not _auth_pending or _verifying:
		return
	_verifying = true
	_set_status("Verifying session...")
	if DojoBridge.complete_controller_auth():
		_auth_pending = false
		_verifying = false
		DojoBridge.pull_entities_snapshot()
		_refresh_menu()
	else:
		_verifying = false
		_set_status("Session not ready — complete auth in browser, then click Connect again")
		_connect_button.disabled = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if _auth_pending and (_auth_browser_node == null or not _auth_browser_node.call("is_showing")):
			_try_complete_auth()

func _on_spawn_pressed() -> void:
	if _spawn_requested:
		return
	_spawn_requested = true
	_enter_requested = false
	_spawn_button.disabled = true
	_set_status("Entering dungeon...")
	DojoBridge.spawn_v2(0)

func _on_disconnect_pressed() -> void:
	DojoBridge.disconnect_session()
	game_state.reset()
	_spawn_requested = false
	_enter_requested = false
	_active_game_id = -1
	_refresh_menu()

func _switch_to_game() -> void:
	_current_screen = Screen.GAME
	_menu_layer.visible = false
	_game_overlay_layer.visible = true
	_ensure_room()

func _switch_to_menu() -> void:
	_current_screen = Screen.MENU
	_menu_layer.visible = true
	_game_overlay_layer.visible = false
	if _room_instance != null and is_instance_valid(_room_instance):
		_room_instance.queue_free()
		_room_instance = null
	_spawn_requested = false
	_enter_requested = false
	_spawn_button.disabled = false
	_refresh_menu()

func _on_run_updated(run_state: Dictionary) -> void:
	if run_state.is_empty():
		return
	_active_game_id = int(run_state.get("game_id", _active_game_id))
	var phase: int = int(run_state.get("phase", PHASE_EXPLORE))

	if phase == PHASE_COMPLETE:
		_show_result("Victory! Dungeon cleared.", false)
		return
	if phase == PHASE_FAILED:
		_show_result("You have fallen.", true)
		return

	if _active_game_id < 0:
		return
	if not _enter_requested:
		_enter_requested = true
		_set_status("Entering room...")
		DojoBridge.enter_room_v2(_active_game_id, 0)

func _on_room_updated(room_state: Dictionary) -> void:
	if room_state.is_empty():
		return
	var game_id: int = int(room_state.get("game_id", -1))
	if game_id < 0:
		return
	if _active_game_id >= 0 and game_id != _active_game_id:
		return

	_active_game_id = game_id
	_switch_to_game()
	_set_game_status("Room %d" % int(room_state.get("room_id", 0)))

	if _room_instance != null and _room_instance.has_method("configure"):
		_room_instance.call("configure", _active_game_id, int(room_state.get("room_id", 0)))

func _ensure_room() -> void:
	if _room_instance != null and is_instance_valid(_room_instance):
		return
	_room_instance = GameRoomScript.new()
	_room_instance.name = "GameRoom"
	add_child(_room_instance)

func _on_game_over() -> void:
	var phase: int = int(game_state.run_state.get("phase", PHASE_EXPLORE))
	if phase == PHASE_COMPLETE:
		_show_result("Victory! Dungeon cleared.", false)
	else:
		_show_result("You have fallen.", true)

func _on_tx_submitted(_action: String) -> void:
	pass

func _on_tx_failed(action: String, reason: String) -> void:
	if action == "spawn_v2":
		_spawn_requested = false
		_spawn_button.disabled = false
	if action == "enter_room_v2":
		_enter_requested = false
	_set_status("%s failed: %s" % [action, reason])

func _on_retry_pressed() -> void:
	_hide_result()
	_switch_to_menu()
	_active_game_id = -1
	game_state.reset()

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
	center.custom_minimum_size = Vector2(300, 0)
	_menu_layer.add_child(center)

	var title := Label.new()
	title.text = "ATHANOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	center.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Tactical Dungeon Crawler"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.modulate = Color(0.7, 0.7, 0.7)
	center.add_child(subtitle)

	center.add_child(HSeparator.new())

	_player_label = Label.new()
	_player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_label.visible = false
	center.add_child(_player_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(280, 0)
	center.add_child(_status_label)

	_connect_button = Button.new()
	_connect_button.text = "Connect Wallet"
	_connect_button.custom_minimum_size = Vector2(200, 40)
	_connect_button.pressed.connect(_on_connect_pressed)
	center.add_child(_connect_button)

	_spawn_button = Button.new()
	_spawn_button.text = "Enter Dungeon"
	_spawn_button.custom_minimum_size = Vector2(200, 40)
	_spawn_button.visible = false
	_spawn_button.pressed.connect(_on_spawn_pressed)
	center.add_child(_spawn_button)

	_disconnect_button = Button.new()
	_disconnect_button.text = "Disconnect"
	_disconnect_button.custom_minimum_size = Vector2(200, 30)
	_disconnect_button.visible = false
	_disconnect_button.pressed.connect(_on_disconnect_pressed)
	center.add_child(_disconnect_button)

	_setup_auth_browser()

func _setup_auth_browser() -> void:
	var AuthBrowserScript = load("res://scripts/auth_browser.gd")
	if AuthBrowserScript == null:
		return

	_auth_browser_node = Control.new()
	_auth_browser_node.set_script(AuthBrowserScript)
	_auth_browser_node.name = "AuthBrowser"
	_auth_browser_node.set_anchors_preset(Control.PRESET_FULL_RECT)

	var browser_container := MarginContainer.new()
	browser_container.name = "BrowserContainer"
	browser_container.unique_name_in_owner = true
	browser_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	browser_container.add_theme_constant_override("margin_top", 40)
	browser_container.add_theme_constant_override("margin_bottom", 40)
	browser_container.add_theme_constant_override("margin_left", 40)
	browser_container.add_theme_constant_override("margin_right", 40)
	_auth_browser_node.add_child(browser_container)

	var close_btn := Button.new()
	close_btn.name = "CloseButton"
	close_btn.unique_name_in_owner = true
	close_btn.text = "X"
	close_btn.position = Vector2(8, 8)
	close_btn.custom_minimum_size = Vector2(30, 30)
	_auth_browser_node.add_child(close_btn)

	var loading_lbl := Label.new()
	loading_lbl.name = "LoadingLabel"
	loading_lbl.unique_name_in_owner = true
	loading_lbl.text = "Loading..."
	loading_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_lbl.set_anchors_preset(Control.PRESET_CENTER)
	loading_lbl.visible = false
	_auth_browser_node.add_child(loading_lbl)

	var error_lbl := Label.new()
	error_lbl.name = "ErrorLabel"
	error_lbl.unique_name_in_owner = true
	error_lbl.text = ""
	error_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_lbl.set_anchors_preset(Control.PRESET_CENTER)
	error_lbl.visible = false
	_auth_browser_node.add_child(error_lbl)

	_menu_layer.add_child(_auth_browser_node)
	_auth_browser_node.set_owner(_menu_layer)
	for child in _auth_browser_node.get_children():
		child.set_owner(_auth_browser_node)

	if _auth_browser_node.has_signal("auth_url_matched"):
		_auth_browser_node.auth_url_matched.connect(_on_auth_browser_matched)
	if _auth_browser_node.has_signal("auth_closed"):
		_auth_browser_node.auth_closed.connect(_on_auth_browser_closed)
	if _auth_browser_node.has_signal("auth_error"):
		_auth_browser_node.auth_error.connect(_on_auth_browser_error)

func _build_game_overlay_ui() -> void:
	_game_overlay_layer = CanvasLayer.new()
	_game_overlay_layer.layer = 100
	_game_overlay_layer.visible = false
	add_child(_game_overlay_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_overlay_layer.add_child(root)

	_result_panel = PanelContainer.new()
	_result_panel.visible = false
	_result_panel.custom_minimum_size = Vector2(260, 100)
	_result_panel.set_anchors_preset(Control.PRESET_CENTER)
	_result_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_result_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(_result_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_result_panel.add_child(vbox)

	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_result_label)

	_retry_button = Button.new()
	_retry_button.text = "Return to Menu"
	_retry_button.pressed.connect(_on_retry_pressed)
	vbox.add_child(_retry_button)

func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message

func _set_game_status(_message: String) -> void:
	pass

func _show_result(message: String, allow_retry: bool) -> void:
	if _result_panel == null:
		return
	_game_overlay_layer.visible = true
	_result_panel.visible = true
	_result_label.text = message
	_retry_button.visible = allow_retry
	_retry_button.text = "Return to Menu" if allow_retry else "Back to Menu"

func _hide_result() -> void:
	if _result_panel == null:
		return
	_result_panel.visible = false
