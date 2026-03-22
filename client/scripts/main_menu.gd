extends Control

signal enter_arena
signal connected

var _auth_pending := false
var _verifying := false
var _leaving := false
var _spawning := false

@onready var logo: TextureRect = %Logo
@onready var player_info: Label = %PlayerInfo
@onready var address_label: Label = %AddressLabel
@onready var status_label: Label = %StatusLabel
@onready var connect_button: Button = %ConnectButton
@onready var spawn_button: Button = %SpawnButton
@onready var resume_button: Button = %ResumeButton
@onready var retry_button: Button = %RetryButton
@onready var disconnect_button: Button = %DisconnectButton
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var music_toggle: CheckButton = %MusicToggle
@onready var sfx_toggle: CheckButton = %SfxToggle
@onready var auth_browser: Control = %AuthBrowser
@onready var history_container: VBoxContainer = %HistoryContainer
@onready var history_panel: PanelContainer = %HistoryPanel
@onready var keybind_container: VBoxContainer = %KeybindContainer

var _listening_action := ""
var _listening_button: Button = null
var _keybind_buttons: Dictionary = {}

const ACTION_LABELS := {
	"move_up": "Move Up",
	"move_down": "Move Down",
	"move_left": "Move Left",
	"move_right": "Move Right",
}

func _ready() -> void:
	get_window().focus_entered.connect(_on_window_focus)
	game_state.character_updated.connect(_on_state_changed)
	game_state.dungeon_updated.connect(_on_state_changed)
	dojo_bridge.tx_submitted.connect(_on_tx_submitted)
	dojo_bridge.tx_failed.connect(_on_tx_failed)
	dojo_bridge.auth_url_ready.connect(_on_auth_url_ready)
	auth_browser.auth_url_matched.connect(_on_auth_browser_matched)
	auth_browser.auth_closed.connect(_on_auth_browser_closed)
	auth_browser.auth_error.connect(_on_auth_browser_error)
	game_state.history_updated.connect(_refresh_history)
	_refresh_ui()
	_refresh_history()
	_init_settings()
	_build_keybind_rows()
	audio_manager.play_music("main_theme")

func _refresh_ui() -> void:
	var authed := not dojo_bridge.current_player.is_empty()
	var has_character := not game_state.character.is_empty()
	var alive := has_character and int(game_state.character.get("health", 0)) > 0
	var dungeon_active := has_character and alive \
		and not bool(game_state.dungeon.get("completed", false)) \
		and not bool(game_state.dungeon.get("failed", false))

	# Show player info
	if authed:
		var info := dojo_bridge.get_player_info()
		var username: String = info.get("username", "")
		var address: String = info.get("address", "")
		if address.is_empty():
			address = dojo_bridge.current_player
		player_info.text = "Welcome, %s" % username if not username.is_empty() else "Connected"
		player_info.visible = true
		if not address.is_empty():
			address_label.text = "%s...%s" % [address.left(8), address.right(4)]
			address_label.visible = true
		else:
			address_label.visible = false
	else:
		player_info.visible = false
		address_label.visible = false

	# Button visibility
	connect_button.visible = not authed
	retry_button.visible = false
	spawn_button.visible = authed and not dungeon_active
	spawn_button.text = "Enter Dungeon"
	resume_button.visible = authed and dungeon_active
	disconnect_button.visible = authed
	history_panel.visible = authed and not game_state.past_runs.is_empty()

	spawn_button.disabled = _spawning
	if not authed:
		status_label.text = "Connect your account to enter Athanor"
	elif dungeon_active:
		status_label.text = "You have an active dungeon run"
	else:
		status_label.text = ""

# --- Auth flow ---

func _on_connect_button_pressed() -> void:
	if _auth_pending:
		return
	connect_button.disabled = true
	status_label.text = "Connecting..."
	_auth_pending = true
	dojo_bridge.initiate_controller_auth()
	# If embedded browser is available, auth_url_ready signal will fire → _on_auth_url_ready
	# If not, OS.shell_open fires and we show the fallback text
	if not auth_browser.is_showing():
		status_label.text = "A browser window has opened — approve the session there, then Alt-Tab back"
		retry_button.visible = true

func _on_auth_url_ready(url: String) -> void:
	status_label.text = "Approve the session below"
	retry_button.visible = false
	auth_browser.show_auth(url)

func _on_auth_browser_matched(_url: String) -> void:
	auth_browser.hide_auth()
	_try_complete_auth()

func _on_auth_browser_closed() -> void:
	_auth_pending = false
	connect_button.disabled = false
	status_label.text = "Authentication cancelled"

func _on_auth_browser_error(message: String) -> void:
	auth_browser.hide_auth()
	status_label.text = message
	# Fall back to external browser
	dojo_bridge.initiate_controller_auth()
	status_label.text = "A browser window has opened — approve the session there, then Alt-Tab back"
	retry_button.visible = true

func _on_retry_button_pressed() -> void:
	_try_complete_auth()

func _on_window_focus() -> void:
	if _auth_pending and not auth_browser.is_showing():
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
		dojo_bridge.pull_entities_snapshot()
		_refresh_ui()
		connected.emit()
	else:
		_verifying = false
		status_label.text = "Session not ready yet — complete auth in browser, then click Retry"
		connect_button.disabled = false

# --- Game actions ---

func _on_spawn_button_pressed() -> void:
	if _spawning:
		return
	_spawning = true
	spawn_button.disabled = true
	status_label.text = "Spawning new dungeon..."
	game_state.reset()
	dojo_bridge.spawn(0)

func _on_disconnect_pressed() -> void:
	game_state.reset()
	dojo_bridge.disconnect_session()
	_refresh_ui()

# --- Callbacks ---

func _on_state_changed(_data: Dictionary) -> void:
	if _leaving:
		return
	var has_char := not game_state.character.is_empty()
	var alive := has_char and int(game_state.character.get("health", 0)) > 0
	var active := has_char and alive \
		and not bool(game_state.dungeon.get("completed", false)) \
		and not bool(game_state.dungeon.get("failed", false))
	if active:
		_spawning = false
		_leaving = true
		_disconnect_signals()
		enter_arena.emit()
	else:
		_refresh_ui()

func _on_resume_button_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	_disconnect_signals()
	enter_arena.emit()

func _disconnect_signals() -> void:
	if game_state.character_updated.is_connected(_on_state_changed):
		game_state.character_updated.disconnect(_on_state_changed)
	if game_state.dungeon_updated.is_connected(_on_state_changed):
		game_state.dungeon_updated.disconnect(_on_state_changed)
	if game_state.history_updated.is_connected(_refresh_history):
		game_state.history_updated.disconnect(_refresh_history)
	if dojo_bridge.tx_submitted.is_connected(_on_tx_submitted):
		dojo_bridge.tx_submitted.disconnect(_on_tx_submitted)
	if dojo_bridge.tx_failed.is_connected(_on_tx_failed):
		dojo_bridge.tx_failed.disconnect(_on_tx_failed)
	var window := get_window()
	if window != null and window.focus_entered.is_connected(_on_window_focus):
		window.focus_entered.disconnect(_on_window_focus)

func _on_tx_submitted(_action: String) -> void:
	pass

func _on_tx_failed(action: String, reason: String) -> void:
	status_label.text = "Error: %s — %s" % [action, reason]
	_spawning = false
	spawn_button.disabled = false

# --- Settings ---

func _init_settings() -> void:
	settings_panel.visible = false
	music_slider.value = audio_manager.music_volume
	sfx_slider.value = audio_manager.sfx_volume
	music_toggle.button_pressed = audio_manager.music_enabled
	sfx_toggle.button_pressed = audio_manager.sfx_enabled

func _on_settings_button_pressed() -> void:
	settings_panel.visible = not settings_panel.visible

func _on_music_slider_changed(value: float) -> void:
	audio_manager.music_volume = value

func _on_sfx_slider_changed(value: float) -> void:
	audio_manager.sfx_volume = value

func _on_music_toggle_toggled(pressed: bool) -> void:
	audio_manager.music_enabled = pressed
	if pressed:
		audio_manager.play_music("main_theme")

func _on_sfx_toggle_toggled(pressed: bool) -> void:
	audio_manager.sfx_enabled = pressed

func _unhandled_input(event: InputEvent) -> void:
	if _listening_action != "" and event is InputEventKey and event.pressed:
		audio_manager.rebind_action(_listening_action, event)
		_listening_button.text = audio_manager.get_action_key_name(_listening_action)
		_listening_action = ""
		_listening_button = null
		get_viewport().set_input_as_handled()

func _build_keybind_rows() -> void:
	if keybind_container == null:
		return
	for action in audio_manager.REBINDABLE_ACTIONS:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = ACTION_LABELS.get(action, action)
		label.custom_minimum_size = Vector2(100, 0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var btn := Button.new()
		btn.text = audio_manager.get_action_key_name(action)
		btn.custom_minimum_size = Vector2(120, 36)
		btn.pressed.connect(func(): _on_keybind_pressed(action, btn))
		row.add_child(btn)
		_keybind_buttons[action] = btn
		keybind_container.add_child(row)

func _on_keybind_pressed(action: String, btn: Button) -> void:
	if _listening_action != "" and _listening_button != null:
		_listening_button.text = audio_manager.get_action_key_name(_listening_action)
	_listening_action = action
	_listening_button = btn
	btn.text = "Press a key..."

# --- History ---

func _refresh_history() -> void:
	if history_container == null:
		return
	# Clear old rows
	for child in history_container.get_children():
		child.queue_free()
	# Build rows from game_state.past_runs
	for run in game_state.past_runs:
		var gid := int(run.get("game_id", 0))
		var status: String = run.get("status", "Unknown")
		var ch: Dictionary = run.get("character", {})
		var hp := int(ch.get("health", 0))
		var max_hp := int(ch.get("max_health", 100))
		var zone := int(ch.get("current_zone", 0))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var id_label := Label.new()
		id_label.text = "#%d" % gid
		id_label.custom_minimum_size = Vector2(40, 0)
		id_label.theme_type_variation = &"SubtitleLabel"
		row.add_child(id_label)

		var status_label_item := Label.new()
		match status:
			"Completed":
				status_label_item.text = "Cleared"
				status_label_item.add_theme_color_override("font_color", Color(0.25, 0.7, 0.35))
			"Failed":
				status_label_item.text = "Failed"
				status_label_item.add_theme_color_override("font_color", Color(0.85, 0.27, 0.27))
			_:
				status_label_item.text = status
		status_label_item.custom_minimum_size = Vector2(80, 0)
		row.add_child(status_label_item)

		var detail := Label.new()
		detail.text = "Zone %d  HP %d/%d" % [zone, hp, max_hp]
		detail.theme_type_variation = &"SubtitleLabel"
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(detail)

		history_container.add_child(row)
