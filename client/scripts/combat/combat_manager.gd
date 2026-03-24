class_name CombatManager
extends Node

signal phase_changed(phase:int)
signal combat_started
signal combat_ended
signal turn_started(turn_index:int)

enum Phase {
	PLAYER_TURN,
	ENEMY_TURN,
	RESOLVING,
}

@export var fight_mode:BoolResource
@export var resource_node:ResourceNode
@export var movement_constraint:MovementConstraint
@export var free_mover:Node
@export var combat_ui:CanvasItem

var current_phase:Phase = Phase.RESOLVING
var turn_index:int = 0

var _stamina_resource:StaminaResource
var _cooldowns:Dictionary = {}

func _ready()->void:
	if fight_mode != null:
		fight_mode.changed_true.connect(start_combat)
		fight_mode.changed_false.connect(end_combat)

	if resource_node != null:
		_stamina_resource = resource_node.get_resource("stamina")

func start_combat()->void:
	turn_index = 1
	_set_free_movement_enabled(false)

	if movement_constraint != null:
		movement_constraint.set_enabled(true)
		movement_constraint.snap_to_tile(Vector2i(movement_constraint.tile_x, movement_constraint.tile_y))

	_set_combat_ui_visible(true)
	_set_phase(Phase.PLAYER_TURN)
	combat_started.emit()
	turn_started.emit(turn_index)

func end_player_turn()->void:
	if current_phase != Phase.PLAYER_TURN:
		return
	_set_phase(Phase.ENEMY_TURN)
	# TODO: send end_player_phase_v2 transaction via network bridge.

func on_enemy_phase_complete()->void:
	if current_phase != Phase.ENEMY_TURN && current_phase != Phase.RESOLVING:
		return
	_tick_cooldowns()
	if _stamina_resource != null:
		_stamina_resource.refill()
	turn_index += 1
	_set_phase(Phase.PLAYER_TURN)
	turn_started.emit(turn_index)

func end_combat()->void:
	_set_phase(Phase.RESOLVING)
	_set_free_movement_enabled(true)
	if movement_constraint != null:
		movement_constraint.set_enabled(false)
	_set_combat_ui_visible(false)
	combat_ended.emit()

func set_phase_resolving()->void:
	_set_phase(Phase.RESOLVING)

func set_ability_cooldown(ability_id:int, turns:int)->void:
	_cooldowns[ability_id] = max(turns, 0)

func get_ability_cooldown(ability_id:int)->int:
	if !_cooldowns.has(ability_id):
		return 0
	return _cooldowns[ability_id]

func _tick_cooldowns()->void:
	for _ability_id:Variant in _cooldowns.keys():
		var _remaining:int = int(_cooldowns[_ability_id])
		if _remaining <= 0:
			continue
		_cooldowns[_ability_id] = _remaining - 1

func _set_phase(phase:Phase)->void:
	current_phase = phase
	phase_changed.emit(int(current_phase))

func _set_free_movement_enabled(active:bool)->void:
	if free_mover == null:
		return
	if free_mover.has_method("set_enabled_process"):
		free_mover.call("set_enabled_process", active)
	elif free_mover.has_method("set_enabled"):
		free_mover.call("set_enabled", active)
	elif free_mover.has_method("set_process"):
		free_mover.call("set_process", active)

func _set_combat_ui_visible(active:bool)->void:
	if combat_ui != null:
		combat_ui.visible = active
