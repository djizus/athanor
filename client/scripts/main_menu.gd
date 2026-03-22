extends Control

signal enter_arena
signal connected

var _auth_pending := false
var _verifying := false
var _leaving := false

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

func _ready() -> void:
	get_window().focus_entered.connect(_on_window_focus)
	game_state.character_updated.connect(_on_state_changed)
	game_state.dungeon_updated.connect(_on_state_changed)
	dojo_bridge.tx_submitted.connect(_on_tx_submitted)
	dojo_bridge.tx_failed.connect(_on_tx_failed)
	_refresh_ui()
	_init_settings()
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
	resume_button.visible = authed and dungeon_active
	disconnect_button.visible = authed

	spawn_button.disabled = false
	if not authed:
		status_label.text = "Connect your account to enter Athanor"
	elif dungeon_active:
		status_label.text = "Your dungeon awaits..."
	else:
		status_label.text = ""

# --- Auth flow ---

func _on_connect_button_pressed() -> void:
	if _auth_pending:
		return
	connect_button.disabled = true
	status_label.text = "Opening browser for authentication..."
	_auth_pending = true
	dojo_bridge.initiate_controller_auth()
	status_label.text = "A browser window has opened — approve the session there, then Alt-Tab back"
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
		dojo_bridge.pull_entities_snapshot()
		_refresh_ui()
		connected.emit()
	else:
		_verifying = false
		status_label.text = "Session not ready yet — complete auth in browser, then click Retry"
		connect_button.disabled = false

# --- Game actions ---

func _on_spawn_button_pressed() -> void:
	spawn_button.disabled = true
	status_label.text = "Spawning hero..."
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
	if dojo_bridge.tx_submitted.is_connected(_on_tx_submitted):
		dojo_bridge.tx_submitted.disconnect(_on_tx_submitted)
	if dojo_bridge.tx_failed.is_connected(_on_tx_failed):
		dojo_bridge.tx_failed.disconnect(_on_tx_failed)

func _on_tx_submitted(_action: String) -> void:
	pass

func _on_tx_failed(action: String, reason: String) -> void:
	status_label.text = "Error: %s — %s" % [action, reason]
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
