class_name GameResultScreen
extends CanvasLayer

signal continue_pressed
signal retry_pressed
signal menu_pressed

@onready var _overlay:ColorRect = %Overlay
@onready var _title_label:Label = %TitleLabel
@onready var _message_label:Label = %MessageLabel
@onready var _continue_button:Button = %ContinueButton
@onready var _retry_button:Button = %RetryButton
@onready var _menu_button:Button = %MenuButton
@onready var _content:Control = %Content

func _ready() -> void:
	_continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	_retry_button.pressed.connect(func() -> void: retry_pressed.emit())
	_menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	visible = false

func show_result(player_won:bool) -> void:
	if player_won:
		_title_label.text = "VICTORY"
		_title_label.modulate = Color(0.2, 0.9, 0.3)
		_message_label.text = "All enemies defeated!"
		_continue_button.visible = true
	else:
		_title_label.text = "DEFEAT"
		_title_label.modulate = Color(0.9, 0.2, 0.2)
		_message_label.text = "You were slain..."
		_continue_button.visible = false

	visible = true
	_overlay.color.a = 0.0
	_content.modulate.a = 0.0

	var tween:Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_overlay, "color:a", 0.7, 0.2)
	tween.tween_property(_content, "modulate:a", 1.0, 0.2)
