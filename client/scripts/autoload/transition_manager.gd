extends CanvasLayer

signal transition_midpoint
signal transition_finished

var _overlay: ColorRect
var _tween: Tween
var is_transitioning := false

func _ready() -> void:
	layer = 100
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

func fade_to_black(duration: float = 0.4) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_overlay, "color:a", 1.0, duration).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func(): transition_midpoint.emit())

func fade_from_black(duration: float = 0.4) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_overlay, "color:a", 0.0, duration).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func():
		is_transitioning = false
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		transition_finished.emit()
	)

func fade_through(duration: float = 0.8) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var half := duration * 0.5
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_overlay, "color:a", 1.0, half).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func(): transition_midpoint.emit())
	_tween.tween_interval(0.1)
	_tween.tween_property(_overlay, "color:a", 0.0, half).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func():
		is_transitioning = false
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		transition_finished.emit()
	)

func _kill_tween() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
