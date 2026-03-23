extends Node3D

const MOVE_SPEED := 5.0
const ARENA_RADIUS := 12.0

var _movement_enabled := true

func enable_movement() -> void:
	_movement_enabled = true

func disable_movement() -> void:
	_movement_enabled = false

func _process(delta: float) -> void:
	if not _movement_enabled:
		return
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0
	if Input.is_action_pressed("move_up"):
		input_dir.y -= 1.0
	if Input.is_action_pressed("move_down"):
		input_dir.y += 1.0
	if input_dir.length_squared() < 0.01:
		return
	input_dir = input_dir.normalized()
	var iso_x := (input_dir.x - input_dir.y) * 0.7071
	var iso_z := (input_dir.x + input_dir.y) * 0.7071
	var new_pos := position + Vector3(iso_x, 0, iso_z) * MOVE_SPEED * delta
	var flat_dist := Vector2(new_pos.x, new_pos.z).length()
	if flat_dist <= ARENA_RADIUS:
		position = new_pos
