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

var _sprite:Sprite2D
var _anim_timer:float = 0.0
var _move_tween:Tween
var _death_tween:Tween

const _TEXTURES:Dictionary = {
	1: "res://addons/top_down/assets/images/characters/skeleton_16x16_strip8.png",
	2: "res://addons/top_down/assets/images/characters/mage_16x16_strip8.png",
}
const _DEFAULT_TEXTURE:String = "res://addons/top_down/assets/images/characters/zombie_16x16_strip8.png"
const _FRAME_COUNT:int = 8

func _ready()->void:
	target_position = position
	_sprite = Sprite2D.new()
	_sprite.hframes = _FRAME_COUNT
	_sprite.position = Vector2(0.0, -8.0)
	_apply_archetype_texture()
	add_child(_sprite)
	queue_redraw()

func _apply_archetype_texture()->void:
	if _sprite == null:
		return
	var path:String = _TEXTURES.get(archetype, _DEFAULT_TEXTURE)
	_sprite.texture = load(path)

func update_from_state(actor_data:Dictionary)->void:
	var _next_tile:Vector2i = Vector2i(
		int(actor_data.get("pos_x", current_tile.x)),
		int(actor_data.get("pos_y", current_tile.y))
	)
	var _next_alive:bool = bool(actor_data.get("alive", is_alive))
	var _next_hp:int = int(actor_data.get("hp", hp))
	var _next_max_hp:int = max(1, int(actor_data.get("max_hp", max_hp)))

	actor_id = int(actor_data.get("actor_id", actor_id))
	var _next_archetype:int = int(actor_data.get("archetype", archetype))
	if _next_archetype != archetype:
		archetype = _next_archetype
		_apply_archetype_texture()
	actor_name = str(actor_data.get("name", actor_name))

	if _next_tile != current_tile:
		current_tile = _next_tile
		target_position = tile_to_screen(current_tile)
		_start_move_tween()

	if _next_hp != hp:
		hp = _next_hp
		_flash_hit()
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
	_anim_timer += delta
	if _anim_timer >= 0.12:
		_anim_timer -= 0.12
		if _sprite != null:
			_sprite.frame = (_sprite.frame + 1) % _FRAME_COUNT

func tile_to_screen(tile:Vector2i)->Vector2:
	var x:float = (tile.x - tile.y) * 16.0
	var y:float = (tile.x + tile.y) * 8.0
	return Vector2(x, y)

func _draw()->void:
	# Health bar above sprite
	var _bar_width:float = 24.0
	var _bar_height:float = 4.0
	var _bar_y:float = -20.0
	var _ratio:float = clamp(float(hp) / float(max(1, max_hp)), 0.0, 1.0)

	draw_rect(Rect2(Vector2(-_bar_width * 0.5, _bar_y), Vector2(_bar_width, _bar_height)), Color(0.1, 0.1, 0.1, 0.9))
	draw_rect(Rect2(Vector2(-_bar_width * 0.5, _bar_y), Vector2(_bar_width * _ratio, _bar_height)), Color(0.2, 0.95, 0.2, 0.95))

func _flash_hit()->void:
	if _sprite == null:
		return
	_sprite.modulate = Color(1.0, 0.3, 0.3, 1.0)
	var _flash_tween:Tween = create_tween()
	_flash_tween.tween_property(_sprite, "modulate", Color.WHITE, 0.15)

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
