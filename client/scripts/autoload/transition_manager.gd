extends CanvasLayer

signal transition_midpoint
signal transition_finished

var _overlay: ColorRect
var _tween: Tween
var _title_label: Label = null
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

func show_zone_title(zone_name: String, duration: float = 2.0) -> void:
	if _title_label == null:
		_title_label = Label.new()
		_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_title_label.set_anchors_preset(Control.PRESET_CENTER)
		_title_label.add_theme_font_size_override("font_size", 36)
		_title_label.add_theme_color_override("font_color", Color(0.831, 0.659, 0.286))
		_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_title_label)
	_title_label.text = zone_name
	_title_label.modulate.a = 0.0
	_title_label.visible = true
	var tween := create_tween()
	tween.tween_property(_title_label, "modulate:a", 1.0, 0.5)
	tween.tween_interval(duration - 1.5)
	tween.tween_property(_title_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func(): _title_label.visible = false)

func _kill_tween() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
