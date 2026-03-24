## Visual test: directly loads room_combat_01 and triggers combat mode.
## Run with --write-movie and --quit-after to capture combat state.
extends SceneTree

var _frame: int = 0
var _combat_triggered: bool = false

func _init() -> void:
	# Load the combat room directly, bypassing boot/title screens
	var room_scene: PackedScene = load("res://scenes/combat/room_combat_01.tscn")
	if room_scene == null:
		print("ERROR: could not load room_combat_01.tscn")
		quit(1)
		return
	var room: Node = room_scene.instantiate()
	root.add_child(room)
	print("Room loaded: ", room.name)

func _process(delta: float) -> bool:
	_frame += 1

	# Frame 5: trigger fight_mode to start combat
	if _frame == 5 and not _combat_triggered:
		_combat_triggered = true
		var fight_res: BoolResource = load("res://addons/top_down/resources/arena_resources/fight_mode_resource.tres")
		if fight_res != null:
			print("Frame %d: triggering fight_mode" % _frame)
			fight_res.set_value(true)
		else:
			print("ERROR: fight_mode_resource not found")

	if _frame % 5 == 0:
		print("Frame: %d" % _frame)

	return false
