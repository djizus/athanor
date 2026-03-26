extends SceneTree

var _phase_log:Array[int] = []
var _player_turn_started_count:int = 0
var _enemy_turn_started_count:int = 0
var _resolve_started_count:int = 0
var _combat_ended_count:int = 0
var _combat_ended_result:bool = false

func _pass(pass_count:int, message:String) -> int:
	print("  PASS: %s" % message)
	return pass_count + 1

func _fail(fail_count:int, message:String) -> int:
	print("  FAIL: %s" % message)
	return fail_count + 1

func _init() -> void:
	var pass_count:int = 0
	var fail_count:int = 0

	var manager_script:GDScript = preload("res://scripts/combat/turn_manager.gd")
	var manager = manager_script.new()

	manager.phase_changed.connect(_on_phase_changed)
	manager.player_turn_started.connect(_on_player_turn_started)
	manager.enemy_turn_started.connect(_on_enemy_turn_started)
	manager.resolve_started.connect(_on_resolve_started)
	manager.combat_ended.connect(_on_combat_ended)

	manager.start_combat()
	if manager.phase == CombatEnums.Phase.PLAYER_TURN:
		pass_count = _pass(pass_count, "start_combat sets phase to PLAYER_TURN")
	else:
		fail_count = _fail(fail_count, "expected PLAYER_TURN, got %d" % manager.phase)

	if _player_turn_started_count == 1:
		pass_count = _pass(pass_count, "player_turn_started emitted on combat start")
	else:
		fail_count = _fail(fail_count, "player_turn_started expected 1, got %d" % _player_turn_started_count)

	manager.end_player_turn()
	if manager.phase == CombatEnums.Phase.PLAYER_TURN:
		pass_count = _pass(pass_count, "loop returns to PLAYER_TURN after enemy+resolve")
	else:
		fail_count = _fail(fail_count, "expected PLAYER_TURN after cycle, got %d" % manager.phase)

	if _enemy_turn_started_count == 1 && _resolve_started_count == 1:
		pass_count = _pass(pass_count, "enemy_turn_started and resolve_started emitted once per cycle")
	else:
		fail_count = _fail(fail_count, "expected enemy=1 resolve=1, got enemy=%d resolve=%d" % [_enemy_turn_started_count, _resolve_started_count])

	if manager.turn_count == 1:
		pass_count = _pass(pass_count, "turn_count increments after resolve")
	else:
		fail_count = _fail(fail_count, "turn_count expected 1, got %d" % manager.turn_count)

	if _phase_log.has(CombatEnums.Phase.ENEMY_TURN) && _phase_log.has(CombatEnums.Phase.RESOLVE):
		pass_count = _pass(pass_count, "phase_changed includes ENEMY_TURN and RESOLVE")
	else:
		fail_count = _fail(fail_count, "phase_changed log missing ENEMY_TURN or RESOLVE")

	manager.queue_combat_end(true)
	manager.end_player_turn()

	if manager.phase == CombatEnums.Phase.COMBAT_OVER:
		pass_count = _pass(pass_count, "combat transitions to COMBAT_OVER when queued")
	else:
		fail_count = _fail(fail_count, "expected COMBAT_OVER, got %d" % manager.phase)

	if _combat_ended_count == 1 && _combat_ended_result:
		pass_count = _pass(pass_count, "combat_ended emits with winning result")
	else:
		fail_count = _fail(fail_count, "combat_ended expected once with true, got count=%d result=%s" % [_combat_ended_count, str(_combat_ended_result)])

	print("\n%d passed, %d failed" % [pass_count, fail_count])
	quit(1 if fail_count > 0 else 0)

func _on_phase_changed(next_phase:int) -> void:
	_phase_log.push_back(next_phase)

func _on_player_turn_started() -> void:
	_player_turn_started_count += 1

func _on_enemy_turn_started() -> void:
	_enemy_turn_started_count += 1

func _on_resolve_started() -> void:
	_resolve_started_count += 1

func _on_combat_ended(player_won:bool) -> void:
	_combat_ended_count += 1
	_combat_ended_result = player_won
