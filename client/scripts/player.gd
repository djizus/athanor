extends CharacterBody2D

const SPEED:float = 80.0

var _movement_enabled:bool = true


func set_movement_enabled(enabled:bool) -> void:
	_movement_enabled = enabled
	if !enabled:
		velocity = Vector2.ZERO


func _physics_process(_delta:float) -> void:
	if !_movement_enabled:
		return

	var dir:Vector2 = Vector2.ZERO
	dir.x = Input.get_axis("left", "right")
	dir.y = Input.get_axis("up", "down")

	if dir.length_squared() > 0.0:
		dir = dir.normalized()

	velocity = dir * SPEED
	move_and_slide()
