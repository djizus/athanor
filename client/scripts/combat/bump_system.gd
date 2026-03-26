class_name BumpSystem
extends Node

signal bump_occurred(bumper_pos:Vector2i, target_pos:Vector2i, push_dir:Vector2i, blocked:bool)
signal collision_damage_dealt(target_pos:Vector2i, damage:int)

const COLLISION_DAMAGE:int = 5

func compute_bump(mover_pos:Vector2i, target_pos:Vector2i, move_dir:Vector2i, grid_state:Dictionary) -> Dictionary:
	var blocked_cells:Array[Vector2i] = []
	if grid_state.has("blocked_cells"):
		blocked_cells = grid_state["blocked_cells"]

	var occupied_cells:Array[Vector2i] = []
	if grid_state.has("occupied_cells"):
		occupied_cells = grid_state["occupied_cells"]

	var immovable_cells:Array[Vector2i] = []
	if grid_state.has("immovable_cells"):
		immovable_cells = grid_state["immovable_cells"]

	var grid_size:int = int(grid_state.get("grid_size", 0))

	var blocked_lookup:Dictionary = _cells_to_lookup(blocked_cells)
	var occupied_lookup:Dictionary = _cells_to_lookup(occupied_cells)
	var immovable_lookup:Dictionary = _cells_to_lookup(immovable_cells)

	if !occupied_lookup.has(target_pos):
		return {}

	var target_is_immovable:bool = immovable_lookup.has(target_pos)
	var push_target:Vector2i = target_pos + move_dir

	if target_is_immovable:
		bump_occurred.emit(mover_pos, target_pos, move_dir, true)
		collision_damage_dealt.emit(target_pos, COLLISION_DAMAGE)
		return {
			"player_final_pos": mover_pos,
			"enemy_final_pos": target_pos,
			"collision_damage": COLLISION_DAMAGE,
			"bump_blocked": true,
			"target_is_immovable": true,
		}

	var push_blocked:bool = !GridUtils.is_in_bounds(push_target, grid_size) || blocked_lookup.has(push_target)
	var push_into_enemy:bool = occupied_lookup.has(push_target)

	if push_blocked:
		bump_occurred.emit(mover_pos, target_pos, move_dir, true)
		collision_damage_dealt.emit(target_pos, COLLISION_DAMAGE)
		return {
			"player_final_pos": mover_pos,
			"enemy_final_pos": target_pos,
			"collision_damage": COLLISION_DAMAGE,
			"bump_blocked": true,
			"target_is_immovable": false,
		}

	if push_into_enemy:
		bump_occurred.emit(mover_pos, target_pos, move_dir, true)
		collision_damage_dealt.emit(target_pos, COLLISION_DAMAGE)
		return {
			"player_final_pos": mover_pos,
			"enemy_final_pos": target_pos,
			"collision_damage": COLLISION_DAMAGE,
			"bump_blocked": true,
			"target_is_immovable": false,
		}

	bump_occurred.emit(mover_pos, target_pos, move_dir, false)
	return {
		"player_final_pos": target_pos,
		"enemy_final_pos": push_target,
		"collision_damage": 0,
		"bump_blocked": false,
		"target_is_immovable": false,
	}

func _cells_to_lookup(cells:Array[Vector2i]) -> Dictionary:
	var lookup:Dictionary = {}
	for cell in cells:
		lookup[cell] = true
	return lookup
