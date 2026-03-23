extends Camera2D

const ZOOM_DEFAULT := Vector2(0.5, 0.5)
const ZOOM_COMBAT := Vector2(0.65, 0.65)
const ZOOM_WIDE := Vector2(0.4, 0.4)
const FOLLOW_SPEED := 4.0

var _follow_target: Node2D = null
var _tween: Tween
var _shake_tween: Tween

func _ready() -> void:
	zoom = ZOOM_DEFAULT
	position_smoothing_enabled = true
	position_smoothing_speed = FOLLOW_SPEED

func _process(_delta: float) -> void:
	if _follow_target != null and is_instance_valid(_follow_target):
		global_position = _follow_target.global_position

func set_follow_target(target: Node2D) -> void:
	_follow_target = target

func clear_follow_target() -> void:
	_follow_target = null

func shake(intensity: float = 8.0, duration: float = 0.3) -> void:
	if _shake_tween and _shake_tween.is_running():
		_shake_tween.kill()
	var base_offset := Vector2.ZERO
	_shake_tween = create_tween()
	var steps := int(duration / 0.04)
	for i in range(steps):
		var decay := 1.0 - (float(i) / float(steps))
		var ofs := Vector2(randf_range(-intensity, intensity) * decay, randf_range(-intensity, intensity) * decay)
		_shake_tween.tween_property(self, "offset", base_offset + ofs, 0.04)
	_shake_tween.tween_property(self, "offset", Vector2.ZERO, 0.04)

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
