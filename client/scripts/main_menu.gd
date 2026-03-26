extends Control

func _ready() -> void:
	$VBox/EnterDungeon.pressed.connect(_on_enter)
	$VBox/Quit.pressed.connect(_on_quit)

func _on_enter() -> void:
	get_tree().change_scene_to_file("res://scenes/dungeon_room.tscn")

func _on_quit() -> void:
	get_tree().quit()
