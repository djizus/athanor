extends Node

const TACTICAL_ROOM_SCENE:String = "res://scenes/combat/tactical_room.tscn"

func _ready() -> void:
	call_deferred("_load_tactical_room")

func _load_tactical_room() -> void:
	get_tree().change_scene_to_file(TACTICAL_ROOM_SCENE)
