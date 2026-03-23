extends CharacterBody2D

const MOVE_SPEED := 300.0

var _movement_enabled := true

func enable_movement() -> void:
	_movement_enabled = true

func disable_movement() -> void:
	_movement_enabled = false
	velocity = Vector2.ZERO

func _physics_process(_delta: float) -> void:
	if not _movement_enabled:
		velocity = Vector2.ZERO
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
	if input_dir.length_squared() >= 0.01:
		input_dir = input_dir.normalized()
	velocity = input_dir * MOVE_SPEED
	move_and_slide()
