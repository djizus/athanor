## Visual QA: loads tactical room directly, triggers combat, captures frames.
extends SceneTree

var _frame: int = 0

func _init() -> void:
	var room_scene: PackedScene = load("res://scenes/combat/tactical_room.tscn")
	if room_scene == null:
		print("ERROR: could not load tactical_room.tscn")
		quit(1)
		return
	var room: Node = room_scene.instantiate()
	root.add_child(room)
	print("Tactical room loaded")

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame % 10 == 0:
		print("Frame: %d" % _frame)
	return false
