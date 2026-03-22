extends Control

signal resume_pressed
signal quit_to_menu

@onready var resume_button: Button = %ResumeButton
@onready var quit_button: Button = %QuitButton
@onready var music_slider: HSlider = %PauseMusicSlider
@onready var sfx_slider: HSlider = %PauseSfxSlider

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		_sync_sliders()

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
