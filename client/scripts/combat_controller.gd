extends Node

signal fight_action_done(action: String)
signal auto_finish_triggered(reason: String)

const AA_COST := 30

var _arena: Node
var _arena_ui: Node

var _auto_finishing := false
var _auto_advancing := false
var _action_in_flight := false
var _poll_timers: Array[Timer] = []

func setup(arena: Node, arena_ui: Node) -> void:
	_arena = arena
	_arena_ui = arena_ui

func cleanup_timers() -> void:
	for timer in _poll_timers:
		if is_instance_valid(timer):
			timer.queue_free()
	_poll_timers.clear()

func on_state_changed() -> void:
	_action_in_flight = false

func on_tx_submitted(_action: String) -> void:
	if _arena.current_state == _arena.ArenaState.FIGHTING:
		_arena_ui.turn_info.text = "Processing..."
	_poll_after_delay(2.0)
	_poll_after_delay(5.0)

func on_tx_failed(action: String, reason: String) -> void:
	var short_reason := ""
	var error_patterns := {
		"mob already dead": "Target already defeated",
		"no active fight": "No active fight",
		"not enough stamina": "Not enough stamina",
		"already cleared": "Zone already cleared",
		"not active": "Fight not active",
		"invalid": "Invalid action",
		"insufficient": "Insufficient resources",
	}
	for pattern in error_patterns.keys():
		if pattern in reason.to_lower():
			short_reason = error_patterns[pattern]
			break
	if short_reason.is_empty():
		short_reason = "Action failed"
	_arena_ui.turn_info.text = short_reason
	push_warning("[arena] TX failed (%s): %s" % [action, reason])
	_action_in_flight = false
	_arena_ui.attack_button.disabled = false
	_arena_ui.end_turn_button.disabled = false
	_arena_ui.start_fight_button.disabled = false
	_arena_ui.left_door_button.disabled = false
	_arena_ui.right_door_button.disabled = false
	_arena_ui.continue_button.disabled = false

func is_auto_finishing() -> bool:
	return _auto_finishing

func is_auto_advancing() -> bool:
	return _auto_advancing

func first_alive_mob() -> int:
	return _first_alive_mob()

func unpack_mob_hp(packed: int, mob_id: int) -> int:
	return _unpack_mob_hp(packed, mob_id)

func parse_int(value: Variant) -> int:
	return _parse_int(value)

func _on_left_door_pressed() -> void:
	audio_manager.play_sfx("click")
	_arena_ui.left_door_button.disabled = true
	_arena_ui.right_door_button.disabled = true
	dojo_bridge.choose(game_state.get_game_id(), dojo_bridge.DIRECTION_LEFT)
	fight_action_done.emit("choose_left")

func _on_right_door_pressed() -> void:
	audio_manager.play_sfx("click")
	_arena_ui.left_door_button.disabled = true
	_arena_ui.right_door_button.disabled = true
	dojo_bridge.choose(game_state.get_game_id(), dojo_bridge.DIRECTION_RIGHT)
	fight_action_done.emit("choose_right")

func _on_continue_pressed() -> void:
	_arena_ui.continue_button.disabled = true
	dojo_bridge.pull_entities_snapshot()
	fight_action_done.emit("continue")

func _on_start_fight_pressed() -> void:
	audio_manager.play_sfx("click")
	_arena_ui.start_fight_button.disabled = true
	dojo_bridge.start(game_state.get_game_id())
	fight_action_done.emit("start")

func _on_attack_pressed() -> void:
	if _arena.current_state != _arena.ArenaState.FIGHTING or _action_in_flight:
		return
	var stamina := int(game_state.character.get("stamina", 0))
	if stamina < AA_COST:
		_arena_ui.turn_info.text = "Not enough stamina"
		_arena_ui.attack_button.disabled = true
		return
	var target := -1
	if _arena.targeting_system != null and _arena.targeting_system.active and _arena.targeting_system.current_target >= 0:
		target = _arena.targeting_system.current_target
	if target < 0:
		target = _first_alive_mob()
	if target < 0:
		return
	audio_manager.play_sfx("click")
	_action_in_flight = true
	_arena_ui.attack_button.disabled = true
	_arena_ui.end_turn_button.disabled = true
	_arena_ui.turn_info.text = "Attacking..."
	dojo_bridge.cast(game_state.get_game_id(), target, 0)
	if _arena.dungeon_view != null and _arena.dungeon_view.has_method("play_attack"):
		_arena.dungeon_view.play_attack(target)
		var mob_pos: Vector3 = _arena.dungeon_view.get_mob_world_position(target) if _arena.dungeon_view.has_method("get_mob_world_position") else Vector3.ZERO
		if mob_pos != Vector3.ZERO and _arena.dungeon_view.has_method("spawn_damage_number"):
			_arena.dungeon_view.spawn_damage_number(mob_pos, int(game_state.character.get("power", 10)))
	if _arena.camera_rig and _arena.camera_rig.has_method("shake"):
		_arena.camera_rig.shake(0.15, 0.2)
	var new_stamina := maxi(0, stamina - AA_COST)
	_arena_ui.stamina_bar.value = new_stamina
	_arena_ui.stamina_label.text = "Stamina %d / %d" % [new_stamina, int(game_state.character.get("max_stamina", 100))]
	fight_action_done.emit("attack")

func _on_end_turn_pressed() -> void:
	if _arena.current_state != _arena.ArenaState.FIGHTING or _action_in_flight:
		return
	if not bool(game_state.fight.get("active", false)):
		_arena._refresh()
		return
	audio_manager.play_sfx("click")
	_action_in_flight = true
	_arena_ui.attack_button.disabled = true
	_arena_ui.end_turn_button.disabled = true
	_arena_ui.turn_info.text = "Ending turn..."
	dojo_bridge.finish(game_state.get_game_id())
	if _arena.dungeon_view != null and _arena.dungeon_view.has_method("play_mob_turn"):
		_arena.dungeon_view.play_mob_turn()
		var player_pos: Vector3 = _arena.dungeon_view.get_player_world_position() if _arena.dungeon_view.has_method("get_player_world_position") else Vector3.ZERO
		var alive_mobs := 0
		var mob_count := int(game_state.fight.get("mob_count", 0))
		var packed: int = _parse_int(game_state.fight.get("mob_healths", 0))
		for i in range(mob_count):
			if _unpack_mob_hp(packed, i) > 0:
				alive_mobs += 1
		if player_pos != Vector3.ZERO and alive_mobs > 0 and _arena.dungeon_view.has_method("spawn_damage_number"):
			_arena.dungeon_view.spawn_damage_number(player_pos, alive_mobs * 5)
	if _arena.camera_rig and _arena.camera_rig.has_method("shake"):
		_arena.camera_rig.shake(0.25, 0.3)
	fight_action_done.emit("end_turn")

func _auto_finish(reason: String) -> void:
	if _auto_finishing:
		return
	_auto_finishing = true
	_arena_ui.turn_info.text = reason
	_arena_ui.attack_button.disabled = true
	_arena_ui.end_turn_button.disabled = true
	auto_finish_triggered.emit(reason)
	get_tree().create_timer(1.5).timeout.connect(func():
		_auto_finishing = false
		if _arena.current_state == _arena.ArenaState.FIGHTING and bool(game_state.fight.get("active", false)):
			dojo_bridge.finish(game_state.get_game_id())
		else:
			dojo_bridge.pull_entities_snapshot()
	)

func _auto_advance_single_exit() -> void:
	_auto_advancing = true
	_arena_ui.door_title.text = "Advancing..."
	push_warning("[arena] Auto-advancing from single-exit zone")
	get_tree().create_timer(1.0).timeout.connect(func():
		_auto_advancing = false
		dojo_bridge.pull_entities_snapshot()
	)

func _poll_after_delay(delay: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = delay
	timer.timeout.connect(func():
		dojo_bridge.pull_entities_snapshot()
		timer.queue_free()
	)
	add_child(timer)
	timer.start()
	_poll_timers.append(timer)

func _first_alive_mob() -> int:
	var mob_count := int(game_state.fight.get("mob_count", 0))
	var packed: int = _parse_int(game_state.fight.get("mob_healths", 0))
	for i in range(mob_count):
		if _unpack_mob_hp(packed, i) > 0:
			return i
	return -1

func _unpack_mob_hp(packed: int, mob_id: int) -> int:
	return (packed >> (mob_id * 16)) & 0xFFFF

func _parse_int(value: Variant) -> int:
	if value is int:
		return value
	if value is String:
		var text := String(value)
		if text.begins_with("0x"):
			return int("0x" + text.trim_prefix("0x"))
		if text.is_valid_int():
			return int(text)
	return 0
