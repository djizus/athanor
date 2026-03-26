extends Control

const DEFAULT_TORII_URL := "https://api.cartridge.gg/x/athanor-djizus-slot/torii"
const DEFAULT_RPC_URL := "https://api.cartridge.gg/x/athanor-djizus-slot/katana"
const DEFAULT_WORLD_ADDRESS := "WORLD_ADDRESS_PLACEHOLDER"
const DEFAULT_ACTIONS_ADDRESS := "ACTIONS_ADDRESS_PLACEHOLDER"

var _connect_button: Button = null

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
	_connect_button.text = "Connect (Burner)"
	$VBox.add_child(_connect_button)
	$VBox.move_child(_connect_button, 1)
	_connect_button.pressed.connect(_on_connect)

func _on_connect() -> void:
	var burner_key: String = String(ProjectSettings.get_setting("dojo/config/burner_private_key", ""))
	var burner_address: String = String(ProjectSettings.get_setting("dojo/config/burner_address", ""))
	if not burner_key.is_empty() and not burner_address.is_empty():
		DojoBridge.setup_burner(burner_key, burner_address)
		DojoBridge.connect_torii()
		DojoIntegration.set_enabled(true)
		_connect_button.text = "Connected (Burner)"
		return

	var torii_ok: bool = DojoBridge.connect_torii()
	DojoIntegration.set_enabled(torii_ok)
	_connect_button.text = "Connected" if torii_ok else "Connect (Burner)"

func _on_enter() -> void:
	get_tree().change_scene_to_file("res://scenes/dungeon_room.tscn")

func _on_quit() -> void:
	get_tree().quit()
