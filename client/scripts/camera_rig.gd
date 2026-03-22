extends Node3D

@onready var camera: Camera3D = $CameraYaw/CameraPitch/Camera3D

const SIZE_DEFAULT := 12.0
const SIZE_COMBAT := 10.0
const SIZE_WIDE := 16.0

var _tween: Tween

func combat_zoom_in() -> void:
	_tween_size(SIZE_COMBAT, 0.5)

func combat_zoom_out() -> void:
	_tween_size(SIZE_DEFAULT, 0.5)

func zone_transition() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(camera, "size", SIZE_WIDE, 0.4).set_ease(Tween.EASE_IN)
	_tween.tween_interval(0.2)
	_tween.tween_property(camera, "size", SIZE_DEFAULT, 0.4).set_ease(Tween.EASE_OUT)

func _tween_size(target: float, duration: float) -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(camera, "size", target, duration).set_ease(Tween.EASE_IN_OUT)
