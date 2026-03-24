extends Control

const DUNGEON_SCENE:String = "res://scenes/combat/room_tactical_01.tscn"
const MUSIC_BUS_NAME:StringName = &"Music"
const SFX_BUS_NAME:StringName = &"Sounds"

const ACTION_LABELS:Dictionary = {
	"up": "Move Up",
	"down": "Move Down",
	"left": "Move Left",
	"right": "Move Right",
}

@onready var settings_panel:PanelContainer = %SettingsPanel
@onready var music_slider:HSlider = %MusicSlider
@onready var sfx_slider:HSlider = %SfxSlider
@onready var music_toggle:CheckButton = %MusicToggle
@onready var sfx_toggle:CheckButton = %SfxToggle
@onready var keybind_container:VBoxContainer = %KeybindContainer

var _listening_action:String = ""
var _listening_button:Button = null

func _ready() -> void:
	settings_panel.visible = false
	_init_settings()
	_build_keybind_rows()

func _on_spawn_button_pressed() -> void:
	get_tree().change_scene_to_file(DUNGEON_SCENE)

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_settings_button_pressed() -> void:
	settings_panel.visible = !settings_panel.visible

func _init_settings() -> void:
	music_slider.value = _get_bus_volume_linear(MUSIC_BUS_NAME)
	sfx_slider.value = _get_bus_volume_linear(SFX_BUS_NAME)
	music_toggle.button_pressed = !_is_bus_muted(MUSIC_BUS_NAME)
	sfx_toggle.button_pressed = !_is_bus_muted(SFX_BUS_NAME)

func _on_music_slider_changed(value:float) -> void:
	_set_bus_volume_linear(MUSIC_BUS_NAME, value)
	music_toggle.button_pressed = value > 0.001

func _on_sfx_slider_changed(value:float) -> void:
	_set_bus_volume_linear(SFX_BUS_NAME, value)
	sfx_toggle.button_pressed = value > 0.001

func _on_music_toggle_toggled(pressed:bool) -> void:
	_set_bus_muted(MUSIC_BUS_NAME, !pressed)

func _on_sfx_toggle_toggled(pressed:bool) -> void:
	_set_bus_muted(SFX_BUS_NAME, !pressed)

func _unhandled_input(event:InputEvent) -> void:
	if _listening_action == "":
		return
	if event is InputEventKey && event.pressed && !event.echo:
		_rebind_action_to_key(_listening_action, event)
		_listening_button.text = _get_action_key_name(_listening_action)
		_listening_action = ""
		_listening_button = null
		get_viewport().set_input_as_handled()

func _build_keybind_rows() -> void:
	for child in keybind_container.get_children():
		child.queue_free()

	for action_name in ACTION_LABELS.keys():
		if !InputMap.has_action(action_name):
			continue
		var row:HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var label:Label = Label.new()
		label.text = String(ACTION_LABELS[action_name])
		label.custom_minimum_size = Vector2(120.0, 0.0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var button:Button = Button.new()
		button.custom_minimum_size = Vector2(150.0, 36.0)
		button.text = _get_action_key_name(action_name)
		button.pressed.connect(_on_keybind_button_pressed.bind(action_name, button))
		row.add_child(button)

		keybind_container.add_child(row)

func _on_keybind_button_pressed(action_name:String, button:Button) -> void:
	if _listening_button != null && _listening_action != "":
		_listening_button.text = _get_action_key_name(_listening_action)
	_listening_action = action_name
	_listening_button = button
	button.text = "Press a key..."

func _rebind_action_to_key(action_name:String, event:InputEventKey) -> void:
	if !InputMap.has_action(action_name):
		return
	for existing in InputMap.action_get_events(action_name):
		if existing is InputEventKey:
			InputMap.action_erase_event(action_name, existing)
	InputMap.action_add_event(action_name, event)

func _get_action_key_name(action_name:String) -> String:
	if !InputMap.has_action(action_name):
		return "Unbound"
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event:InputEventKey = event
			return OS.get_keycode_string(key_event.physical_keycode)
	return "Unbound"

func _get_bus_idx(bus_name:StringName) -> int:
	return AudioServer.get_bus_index(bus_name)

func _is_bus_muted(bus_name:StringName) -> bool:
	var idx:int = _get_bus_idx(bus_name)
	return idx < 0 || AudioServer.is_bus_mute(idx)

func _set_bus_muted(bus_name:StringName, muted:bool) -> void:
	var idx:int = _get_bus_idx(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, muted)

func _get_bus_volume_linear(bus_name:StringName) -> float:
	var idx:int = _get_bus_idx(bus_name)
	if idx < 0:
		return 1.0
	if AudioServer.is_bus_mute(idx):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))

func _set_bus_volume_linear(bus_name:StringName, value:float) -> void:
	var idx:int = _get_bus_idx(bus_name)
	if idx < 0:
		return
	var clamped:float = clampf(value, 0.0, 1.0)
	if clamped <= 0.001:
		AudioServer.set_bus_volume_db(idx, -80.0)
		AudioServer.set_bus_mute(idx, true)
		return
	AudioServer.set_bus_mute(idx, false)
	AudioServer.set_bus_volume_db(idx, linear_to_db(clamped))
