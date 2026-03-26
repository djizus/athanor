class_name CombatStatsResource
extends Resource

signal position_changed(old_pos:Vector2i, new_pos:Vector2i)
signal guard_changed(active:bool)

@export var grid_pos:Vector2i = Vector2i(-1, -1) : set = set_grid_pos
@export var faction:int = 0
@export var archetype:int = 0
@export var move_range:int = 10
@export var is_guarding:bool = false : set = set_is_guarding
@export var guard_reduction:float = 0.5
@export var is_immovable:bool = false

func set_grid_pos(new_pos:Vector2i) -> void:
	if grid_pos == new_pos:
		return
	var old_pos:Vector2i = grid_pos
	grid_pos = new_pos
	position_changed.emit(old_pos, new_pos)

func set_is_guarding(active:bool) -> void:
	if is_guarding == active:
		return
	is_guarding = active
	guard_changed.emit(active)
