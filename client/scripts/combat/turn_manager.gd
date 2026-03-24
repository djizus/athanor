class_name TurnManager
extends Node

signal phase_changed(phase:int)
signal player_turn_started
signal enemy_turn_started
signal resolve_started
signal combat_ended(player_won:bool)

signal _player_turn_ended

var phase:int = CombatEnums.Phase.IDLE
var turn_count:int = 0

var _running:bool = false
var _queued_combat_end:Variant = null

func start_combat() -> void:
	if _running:
		return
	turn_count = 0
	_queued_combat_end = null
	_running = true
	_run_combat_loop()

func end_player_turn() -> void:
	if !_running:
		return
	if phase != CombatEnums.Phase.PLAYER_TURN:
		return
	_player_turn_ended.emit()

func queue_combat_end(player_won:bool) -> void:
	if !_running:
		return
	_queued_combat_end = player_won

func _run_combat_loop() -> void:
	while _running:
		_set_phase(CombatEnums.Phase.PLAYER_TURN)
		player_turn_started.emit()
		await _player_turn_ended

		if _queued_combat_end != null:
			_end_combat_internal(bool(_queued_combat_end))
			break

		_set_phase(CombatEnums.Phase.ENEMY_TURN)
		enemy_turn_started.emit()

		_set_phase(CombatEnums.Phase.RESOLVE)
		resolve_started.emit()
		turn_count += 1

		if _queued_combat_end != null:
			_end_combat_internal(bool(_queued_combat_end))
			break

func _set_phase(next_phase:int) -> void:
	phase = next_phase
	phase_changed.emit(phase)

func _end_combat_internal(player_won:bool) -> void:
	_running = false
	_set_phase(CombatEnums.Phase.COMBAT_OVER)
	combat_ended.emit(player_won)
