extends Control

signal resume_pressed
signal quit_to_menu

@onready var resume_button: Button = %ResumeButton
@onready var quit_button: Button = %QuitButton
@onready var music_slider: HSlider = %PauseMusicSlider
@onready var sfx_slider: HSlider = %PauseSfxSlider
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
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_keybind_rows()

func _unhandled_input(event: InputEvent) -> void:
	if _listening_action != "" and event is InputEventKey and event.pressed:
		audio_manager.rebind_action(_listening_action, event)
		_listening_button.text = audio_manager.get_action_key_name(_listening_action)
		_listening_action = ""
		_listening_button = null
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		if _listening_action != "":
			_listening_button.text = audio_manager.get_action_key_name(_listening_action)
			_listening_action = ""
			_listening_button = null
		else:
			toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		_sync_sliders()
		_refresh_keybind_labels()

func _on_resume_pressed() -> void:
	visible = false
	get_tree().paused = false
	resume_pressed.emit()

func _on_quit_pressed() -> void:
	visible = false
	get_tree().paused = false
	quit_to_menu.emit()

func _on_music_slider_changed(value: float) -> void:
	audio_manager.music_volume = value

func _on_sfx_slider_changed(value: float) -> void:
	audio_manager.sfx_volume = value

func _sync_sliders() -> void:
	if music_slider:
		music_slider.value = audio_manager.music_volume
	if sfx_slider:
		sfx_slider.value = audio_manager.sfx_volume

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
		btn.pressed.connect(_on_keybind_pressed.bind(action, btn))
		row.add_child(btn)
		_keybind_buttons[action] = btn
		keybind_container.add_child(row)

func _on_keybind_pressed(action: String, btn: Button) -> void:
	if _listening_action != "" and _listening_button != null:
		_listening_button.text = audio_manager.get_action_key_name(_listening_action)
	_listening_action = action
	_listening_button = btn
	btn.text = "Press a key..."

func _refresh_keybind_labels() -> void:
	for action in _keybind_buttons.keys():
		_keybind_buttons[action].text = audio_manager.get_action_key_name(action)
