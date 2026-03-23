extends CharacterBody3D

const MOVE_SPEED := 5.0
const GRAVITY := 9.8

var _movement_enabled := true

func enable_movement() -> void:
	_movement_enabled = true

func disable_movement() -> void:
	_movement_enabled = false

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if not _movement_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
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

	if input_dir.length_squared() > 0.01:
		input_dir = input_dir.normalized()
		# Isometric direction mapping
		var iso_x := (input_dir.x - input_dir.y) * 0.7071
		var iso_z := (input_dir.x + input_dir.y) * 0.7071
		velocity.x = iso_x * MOVE_SPEED
		velocity.z = iso_z * MOVE_SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, MOVE_SPEED)
		velocity.z = move_toward(velocity.z, 0, MOVE_SPEED)

	move_and_slide()
