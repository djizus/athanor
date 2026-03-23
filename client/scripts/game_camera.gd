extends Camera2D

const ZOOM_DEFAULT := Vector2(1.0, 1.0)
const ZOOM_COMBAT := Vector2(1.2, 1.2)
const ZOOM_WIDE := Vector2(0.85, 0.85)
const FOLLOW_SPEED := 4.0

enum CameraMode { FOLLOW, FIXED }

var _follow_target: Node2D = null
var _tween: Tween
var _shake_intensity: float = 0.0
var _shake_decay: float = 8.0
var _mode: CameraMode = CameraMode.FOLLOW

func _ready() -> void:
	zoom = ZOOM_DEFAULT
	position_smoothing_enabled = true
	position_smoothing_speed = FOLLOW_SPEED

func _process(_delta: float) -> void:
	match _mode:
		CameraMode.FOLLOW:
			if _follow_target != null and is_instance_valid(_follow_target):
				global_position = _follow_target.global_position
		CameraMode.FIXED:
			pass
	if _shake_intensity > 0:
		offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
		_shake_intensity = lerp(_shake_intensity, 0.0, _shake_decay * _delta)
		if _shake_intensity < 0.1:
			_shake_intensity = 0.0
			offset = Vector2.ZERO

func set_follow_target(target: Node2D) -> void:
	_mode = CameraMode.FOLLOW
	_follow_target = target

func set_fixed_mode(pos: Vector2, tween_duration: float = 0.5) -> void:
	_mode = CameraMode.FIXED
	_follow_target = null
	var tween := create_tween()
	tween.tween_property(self, "global_position", pos, tween_duration).set_ease(Tween.EASE_IN_OUT)

func set_follow_mode(target: Node2D) -> void:
	_mode = CameraMode.FOLLOW
	_follow_target = target

func clear_follow_target() -> void:
	_follow_target = null

func shake(intensity: float = 8.0, decay: float = 8.0) -> void:
	_shake_intensity = intensity
	_shake_decay = decay

func combat_zoom_in() -> void:
	_tween_zoom(ZOOM_COMBAT, 0.5)

func combat_zoom_out() -> void:
	_tween_zoom(ZOOM_DEFAULT, 0.5)

func zone_transition() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "zoom", ZOOM_WIDE, 0.4).set_ease(Tween.EASE_IN)
	_tween.tween_interval(0.2)
	_tween.tween_property(self, "zoom", ZOOM_DEFAULT, 0.4).set_ease(Tween.EASE_OUT)

func _tween_zoom(target: Vector2, duration: float) -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "zoom", target, duration).set_ease(Tween.EASE_IN_OUT)
