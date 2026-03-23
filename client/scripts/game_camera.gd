extends Camera2D

const ZOOM_DEFAULT := Vector2(0.5, 0.5)
const ZOOM_COMBAT := Vector2(0.65, 0.65)
const ZOOM_WIDE := Vector2(0.4, 0.4)
const FOLLOW_SPEED := 4.0

var _follow_target: Node2D = null
var _tween: Tween
var _shake_intensity: float = 0.0
var _shake_decay: float = 8.0

func _ready() -> void:
	zoom = ZOOM_DEFAULT
	position_smoothing_enabled = true
	position_smoothing_speed = FOLLOW_SPEED

func _process(_delta: float) -> void:
	if _follow_target != null and is_instance_valid(_follow_target):
		global_position = _follow_target.global_position
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
