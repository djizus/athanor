extends Node2D

const GameRoomScript: Script = preload("res://scripts/game_room.gd")

const PHASE_EXPLORE := 0
const PHASE_PLAYER_TURN := 1
const PHASE_ENEMY_TURN := 2
const PHASE_COMPLETE := 3
const PHASE_FAILED := 4

var _status_label: Label
var _result_panel: PanelContainer
var _result_label: Label
var _retry_button: Button

var _room_instance: Node = null
var _spawn_requested: bool = false
var _enter_requested: bool = false
var _active_game_id: int = -1

func _ready() -> void:
	_build_overlay_ui()
	_connect_signals()
	_start_flow()

func _connect_signals() -> void:
	if not game_state.run_updated.is_connected(_on_run_updated):
		game_state.run_updated.connect(_on_run_updated)
	if not game_state.room_updated.is_connected(_on_room_updated):
		game_state.room_updated.connect(_on_room_updated)
	if not game_state.game_over.is_connected(_on_game_over):
		game_state.game_over.connect(_on_game_over)

	if DojoBridge.has_signal("torii_connected") and not DojoBridge.torii_connected.is_connected(_on_torii_connected):
		DojoBridge.torii_connected.connect(_on_torii_connected)
	if DojoBridge.has_signal("session_ready") and not DojoBridge.session_ready.is_connected(_on_session_ready):
		DojoBridge.session_ready.connect(_on_session_ready)
	if DojoBridge.has_signal("tx_failed") and not DojoBridge.tx_failed.is_connected(_on_tx_failed):
		DojoBridge.tx_failed.connect(_on_tx_failed)

func _start_flow() -> void:
	_set_status("Connecting to Torii...")
	_bootstrap_dojo_nodes_if_available()
	_attempt_local_burner_auth()
	DojoBridge.connect_torii()

	# If state already exists (hot-reload / resumed session), continue immediately.
	if not game_state.run_state.is_empty():
		_on_run_updated(game_state.run_state)
	if not game_state.room_state.is_empty():
		_on_room_updated(game_state.room_state)

func _bootstrap_dojo_nodes_if_available() -> void:
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

	if torii_node != null and session_node != null:
		DojoBridge.configure_nodes(torii_node, session_node)

func _attempt_local_burner_auth() -> void:
	# Optional local dev auth. Set these env vars when running against Katana.
	var burner_key: String = OS.get_environment("ATHANOR_BURNER_PRIVATE_KEY")
	var burner_address: String = OS.get_environment("ATHANOR_BURNER_ADDRESS")
	if burner_key.is_empty() or burner_address.is_empty():
		return
	DojoBridge.setup_burner(burner_key, burner_address)

func _on_torii_connected(success: bool) -> void:
	if not success:
		_set_status("Torii unavailable. Running without network sync.")
		return
	_set_status("Connected. Spawning run...")
	_request_spawn()

func _on_session_ready(_address: String) -> void:
	if _spawn_requested:
		return
	_request_spawn()

func _request_spawn() -> void:
	if _spawn_requested:
		return
	_spawn_requested = true
	_enter_requested = false
	DojoBridge.spawn_v2(0)

func _on_run_updated(run_state: Dictionary) -> void:
	if run_state.is_empty():
		return

	_active_game_id = int(run_state.get("game_id", _active_game_id))
	var phase: int = int(run_state.get("phase", PHASE_EXPLORE))

	if phase == PHASE_COMPLETE:
		_show_result("Victory! Run completed.", false)
		return
	if phase == PHASE_FAILED:
		_show_result("Run failed.", true)
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
	_set_status("In combat room")
	_hide_result()
	_ensure_room()

	if _room_instance != null and _room_instance.has_method("configure"):
		_room_instance.call("configure", _active_game_id, int(room_state.get("room_id", 0)))

	if bool(room_state.get("cleared", false)):
		_show_result("Room cleared!", false)

func _ensure_room() -> void:
	if _room_instance != null and is_instance_valid(_room_instance):
		return
	_room_instance = GameRoomScript.new()
	_room_instance.name = "GameRoom"
	add_child(_room_instance)

func _on_game_over() -> void:
	var phase: int = int(game_state.run_state.get("phase", PHASE_EXPLORE))
	if phase == PHASE_COMPLETE:
		_show_result("Victory! Run completed.", false)
	else:
		_show_result("Run failed.", true)

func _on_tx_failed(action: String, reason: String) -> void:
	if action == "spawn_v2" and _spawn_requested:
		_spawn_requested = false
	if action == "enter_room_v2" and _enter_requested:
		_enter_requested = false
	_set_status("%s failed: %s" % [action, reason])

func _on_retry_pressed() -> void:
	_hide_result()
	if _room_instance != null and is_instance_valid(_room_instance):
		_room_instance.queue_free()
		_room_instance = null
	_active_game_id = -1
	_spawn_requested = false
	_enter_requested = false
	game_state.reset()
	_set_status("Respawning...")
	_request_spawn()

func _build_overlay_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	_status_label = Label.new()
	_status_label.text = "Starting..."
	_status_label.position = Vector2(8.0, 8.0)
	root.add_child(_status_label)

	_result_panel = PanelContainer.new()
	_result_panel.visible = false
	_result_panel.custom_minimum_size = Vector2(260.0, 100.0)
	_result_panel.position = Vector2(110.0, 84.0)
	root.add_child(_result_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_result_panel.add_child(vbox)

	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.text = ""
	vbox.add_child(_result_label)

	_retry_button = Button.new()
	_retry_button.text = "Retry"
	_retry_button.visible = false
	_retry_button.pressed.connect(_on_retry_pressed)
	vbox.add_child(_retry_button)

func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message

func _show_result(message: String, allow_retry: bool) -> void:
	if _result_panel == null:
		return
	_result_panel.visible = true
	_result_label.text = message
	_retry_button.visible = allow_retry

func _hide_result() -> void:
	if _result_panel == null:
		return
	_result_panel.visible = false
