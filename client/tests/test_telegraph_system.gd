extends SceneTree

var _added_count:int = 0
var _resolved_count:int = 0
var _cleared_count:int = 0

func _pass(pass_count:int, message:String) -> int:
	print("  PASS: %s" % message)
	return pass_count + 1

func _fail(fail_count:int, message:String) -> int:
	print("  FAIL: %s" % message)
	return fail_count + 1

func _init() -> void:
	var pass_count:int = 0
	var fail_count:int = 0

	var telegraph_script:GDScript = preload("res://scripts/combat/telegraph_system.gd")
	var telegraph_system = telegraph_script.new()
	telegraph_system.telegraph_added.connect(_on_telegraph_added)
	telegraph_system.telegraph_resolved.connect(_on_telegraph_resolved)
	telegraph_system.telegraphs_cleared.connect(_on_telegraphs_cleared)

	var brute_cells:Array[Vector2i] = [Vector2i(2, 2)]
	telegraph_system.add_telegraph(brute_cells, 20.0, "brute_1", 1)
	var active_after_add:Array = telegraph_system.get_active()
	if active_after_add.size() == 1 && _added_count == 1:
		pass_count = _pass(pass_count, "add_telegraph stores active telegraph and emits signal")
	else:
		fail_count = _fail(fail_count, "add mismatch: active=%d added_signals=%d" % [active_after_add.size(), _added_count])

	var resolved_same_turn:Array = telegraph_system.resolve_telegraphs(1)
	if resolved_same_turn.is_empty() && telegraph_system.get_active().size() == 1:
		pass_count = _pass(pass_count, "resolve on same turn does not trigger telegraph")
	else:
		fail_count = _fail(fail_count, "same-turn resolve expected none, got resolved=%d active=%d" % [resolved_same_turn.size(), telegraph_system.get_active().size()])

	var resolved_next_turn:Array = telegraph_system.resolve_telegraphs(2)
	if resolved_next_turn.size() == 1 && telegraph_system.get_active().is_empty() && _resolved_count == 1:
		pass_count = _pass(pass_count, "resolve on N+1 returns and removes telegraph")
	else:
		fail_count = _fail(fail_count, "N+1 resolve mismatch: resolved=%d active=%d resolved_signals=%d" % [resolved_next_turn.size(), telegraph_system.get_active().size(), _resolved_count])

	var caster_cells:Array[Vector2i] = [Vector2i(0, 0)]
	var flanker_cells:Array[Vector2i] = [Vector2i(7, 7)]
	telegraph_system.add_telegraph(caster_cells, 12.0, "caster_1", 2)
	telegraph_system.add_telegraph(flanker_cells, 18.0, "flanker_1", 3)
	var multi_resolve:Array = telegraph_system.resolve_telegraphs(3)
	var active_after_multi:Array = telegraph_system.get_active()
	if multi_resolve.size() == 1 && active_after_multi.size() == 1:
		pass_count = _pass(pass_count, "multiple telegraphs resolve only those with turn_created < current_turn")
	else:
		fail_count = _fail(fail_count, "multi resolve mismatch: resolved=%d active=%d" % [multi_resolve.size(), active_after_multi.size()])

	telegraph_system.clear_all()
	if telegraph_system.get_active().is_empty() && _cleared_count == 1:
		pass_count = _pass(pass_count, "clear_all removes all telegraphs and emits signal")
	else:
		fail_count = _fail(fail_count, "clear mismatch: active=%d cleared_signals=%d" % [telegraph_system.get_active().size(), _cleared_count])

	print("\n%d passed, %d failed" % [pass_count, fail_count])
	quit(1 if fail_count > 0 else 0)

func _on_telegraph_added(_data:Dictionary) -> void:
	_added_count += 1

func _on_telegraph_resolved(_data:Dictionary) -> void:
	_resolved_count += 1

func _on_telegraphs_cleared() -> void:
	_cleared_count += 1
