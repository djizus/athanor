extends Node3D

const MOVE_SPEED := 5.0

var _movement_enabled := true

func enable_movement() -> void:
	_movement_enabled = true

func disable_movement() -> void:
	_movement_enabled = false

func _process(delta: float) -> void:
	if not _movement_enabled:
		return
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_dir.y -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_dir.y += 1.0
	if input_dir.length_squared() < 0.01:
		return
	input_dir = input_dir.normalized()
	var iso_x := (input_dir.x - input_dir.y) * 0.7071
	var iso_z := (input_dir.x + input_dir.y) * 0.7071
	position += Vector3(iso_x, 0, iso_z) * MOVE_SPEED * delta
