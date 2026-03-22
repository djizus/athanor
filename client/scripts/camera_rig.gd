extends Node3D

@onready var camera: Camera3D = $CameraYaw/CameraPitch/Camera3D

const SIZE_DEFAULT := 12.0
const SIZE_COMBAT := 10.0
const SIZE_WIDE := 16.0
const FOLLOW_SPEED := 4.0

var _tween: Tween
var _shake_tween: Tween
var _follow_target: Node3D = null
var _original_offset := Vector3.ZERO

func _ready() -> void:
	_original_offset = position

func _process(delta: float) -> void:
	if _follow_target != null and is_instance_valid(_follow_target):
		var target_pos := _follow_target.global_position + _original_offset
		global_position = global_position.lerp(target_pos, FOLLOW_SPEED * delta)

func set_follow_target(target: Node3D) -> void:
	_follow_target = target

func clear_follow_target() -> void:
	_follow_target = null

func shake(intensity: float = 0.3, duration: float = 0.3) -> void:
	if _shake_tween and _shake_tween.is_running():
		_shake_tween.kill()
	var cam_node := camera
	if cam_node == null:
		return
	var base_offset := cam_node.position
	_shake_tween = create_tween()
	var steps := int(duration / 0.04)
	for i in range(steps):
		var decay := 1.0 - (float(i) / float(steps))
		var offset := Vector3(
			randf_range(-intensity, intensity) * decay,
			randf_range(-intensity, intensity) * decay,
			0
		)
		_shake_tween.tween_property(cam_node, "position", base_offset + offset, 0.04)
	_shake_tween.tween_property(cam_node, "position", base_offset, 0.04)

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
