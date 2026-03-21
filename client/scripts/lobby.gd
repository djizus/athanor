extends Control

signal dungeon_entered
signal disconnected

@onready var player_info: Label = %PlayerInfo
@onready var address_label: Label = %AddressLabel
@onready var enter_button: Button = %EnterDungeonButton
@onready var disconnect_button: Button = %DisconnectButton
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	var info := dojo_bridge.get_player_info()
	var username: String = info.get("username", "")
	var address: String = info.get("address", "")
	if not username.is_empty():
		player_info.text = "Connected as: %s" % username
	else:
		player_info.text = "Connected"
	if not address.is_empty():
		address_label.text = "%s...%s" % [address.left(8), address.right(4)]
	else:
		address_label.text = ""
	status_label.text = ""
	game_state.character_updated.connect(_on_character_updated)

func _on_enter_dungeon_pressed() -> void:
	enter_button.disabled = true
	status_label.text = "Spawning hero..."
	dojo_bridge.spawn(0)

func _on_character_updated(_character: Dictionary) -> void:
	if not _character.is_empty():
		dungeon_entered.emit()

func _on_disconnect_pressed() -> void:
	game_state.reset()
	disconnected.emit()
