class_name EnemyVisual
extends Node2D

@export var actor_id:int = 0

var target_position:Vector2 = Vector2.ZERO
var current_tile:Vector2i = Vector2i.ZERO
var is_alive:bool = true
var archetype:int = 1

var hp:int = 1
var max_hp:int = 1
var actor_name:String = "Enemy"

var _flash_strength:float = 0.0
var _move_tween:Tween
var _death_tween:Tween

func _ready()->void:
	target_position = position
	queue_redraw()

func update_from_state(actor_data:Dictionary)->void:
	var _next_tile:Vector2i = Vector2i(
		int(actor_data.get("pos_x", current_tile.x)),
		int(actor_data.get("pos_y", current_tile.y))
	)
	var _next_alive:bool = bool(actor_data.get("alive", is_alive))
	var _next_hp:int = int(actor_data.get("hp", hp))
	var _next_max_hp:int = max(1, int(actor_data.get("max_hp", max_hp)))

	actor_id = int(actor_data.get("actor_id", actor_id))
	archetype = int(actor_data.get("archetype", archetype))
	actor_name = str(actor_data.get("name", actor_name))

	if _next_tile != current_tile:
		current_tile = _next_tile
		target_position = tile_to_screen(current_tile)
		_start_move_tween()

	if _next_hp != hp:
		hp = _next_hp
		_flash_strength = 1.0
		var _flash_tween:Tween = create_tween()
		_flash_tween.tween_property(self, "_flash_strength", 0.0, 0.1)
	else:
		hp = _next_hp

	max_hp = _next_max_hp

	if is_alive && !_next_alive:
		is_alive = false
		_play_death_animation()
	else:
		is_alive = _next_alive

	queue_redraw()

func _process(delta:float)->void:
	position = position.lerp(target_position, min(1.0, delta * 12.0))
	if _flash_strength > 0.0:
		queue_redraw()

func tile_to_screen(tile:Vector2i)->Vector2:
	var x:float = (tile.x - tile.y) * 16.0
	var y:float = (tile.x + tile.y) * 8.0
	return Vector2(x, y)

func _draw()->void:
	var _body_size:Vector2 = Vector2(20.0, 20.0)
	var _body_rect:Rect2 = Rect2(-_body_size * 0.5, _body_size)
	var _body_color:Color = _color_for_archetype()
	draw_rect(_body_rect, _body_color)

	if _flash_strength > 0.0:
		draw_rect(_body_rect, Color(1.0, 1.0, 1.0, clamp(_flash_strength, 0.0, 1.0)))

	var _bar_width:float = 24.0
	var _bar_height:float = 4.0
	var _bar_y:float = -18.0
	var _ratio:float = clamp(float(hp) / float(max(1, max_hp)), 0.0, 1.0)

	draw_rect(Rect2(Vector2(-_bar_width * 0.5, _bar_y), Vector2(_bar_width, _bar_height)), Color(0.1, 0.1, 0.1, 0.9))
	draw_rect(Rect2(Vector2(-_bar_width * 0.5, _bar_y), Vector2(_bar_width * _ratio, _bar_height)), Color(0.2, 0.95, 0.2, 0.95))

func _start_move_tween()->void:
	if _move_tween != null && _move_tween.is_running():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", target_position, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _play_death_animation()->void:
	if _death_tween != null && _death_tween.is_running():
		_death_tween.kill()
	_death_tween = create_tween()
	_death_tween.tween_property(self, "modulate:a", 0.0, 0.5)
	_death_tween.finished.connect(queue_free)

func _color_for_archetype()->Color:
	match archetype:
		0:
			return Color(0.25, 0.5, 1.0, 1.0)
		1:
			return Color(0.9, 0.25, 0.2, 1.0)
		2:
			return Color(0.6, 0.3, 0.9, 1.0)
		_:
			return Color(0.8, 0.8, 0.8, 1.0)
