extends Node

signal run_updated(run_state: Dictionary)
signal room_updated(room_state: Dictionary)
signal actor_updated(actor_id: int)
signal ability_updated(actor_id: int, slot: int)
signal telegraph_updated(telegraph_id: int)
signal game_over
signal history_updated

var run_state: Dictionary = {}
var room_state: Dictionary = {}
var actors: Dictionary = {}
var ability_slots: Dictionary = {}
var telegraphs: Dictionary = {}

# Latest known game_id for current player (also mirrors game_count semantics)
var latest_game_id: int = -1
var game_count: int = -1

# History of past runs: Array of {game_id, run_state, status}
var past_runs: Array[Dictionary] = []

func reset() -> void:
	run_state = {}
	room_state = {}
	actors = {}
	ability_slots = {}
	telegraphs = {}
	run_updated.emit(run_state)
	room_updated.emit(room_state)

func set_latest_game_id(game_id: int) -> void:
	latest_game_id = game_id
	game_count = maxi(game_count, game_id)

func add_historical_run(run: Dictionary) -> void:
	var gid := int(run.get("game_id", -1))
	if gid < 0:
		return
	for i in range(past_runs.size()):
		if int(past_runs[i].get("game_id", -1)) == gid:
			past_runs[i] = run
			history_updated.emit()
			return
	past_runs.append(run)
	past_runs.sort_custom(func(a, b): return int(a.get("game_id", 0)) > int(b.get("game_id", 0)))
	history_updated.emit()

func update_run(next_run: Dictionary) -> void:
	var parsed := _parse_run_state(next_run)
	var gid := int(parsed.get("game_id", -1))
	if gid < 0:
		return
	if gid > latest_game_id:
		set_latest_game_id(gid)
	if not run_state.is_empty() and int(run_state.get("game_id", -1)) != gid:
		_archive_current_run()
		room_state = {}
		actors = {}
		ability_slots = {}
		telegraphs = {}
	run_state = parsed
	run_updated.emit(run_state)
	_emit_game_over_if_needed()

func update_room(next_room: Dictionary) -> void:
	var parsed := _parse_room_state(next_room)
	if parsed.is_empty():
		return
	room_state = parsed
	room_updated.emit(room_state)
	_emit_game_over_if_needed()

func upsert_actor(next_actor: Dictionary) -> void:
	var parsed := _parse_actor_state(next_actor)
	var actor_id := int(parsed.get("actor_id", -1))
	if actor_id < 0:
		return
	actors[actor_id] = parsed
	actor_updated.emit(actor_id)
	_emit_game_over_if_needed()

func upsert_ability_slot(next_slot: Dictionary) -> void:
	var parsed := _parse_ability_slot_state(next_slot)
	var actor_id := int(parsed.get("actor_id", -1))
	var slot_index := int(parsed.get("slot_index", -1))
	if actor_id < 0 or slot_index < 0:
		return
	ability_slots["%d_%d" % [actor_id, slot_index]] = parsed
	ability_updated.emit(actor_id, slot_index)

func upsert_telegraph(next_telegraph: Dictionary) -> void:
	var parsed := _parse_telegraph_state(next_telegraph)
	var telegraph_id := int(parsed.get("telegraph_id", -1))
	if telegraph_id < 0:
		return
	telegraphs[telegraph_id] = parsed
	telegraph_updated.emit(telegraph_id)

func get_game_id() -> int:
	if run_state.has("game_id"):
		return int(run_state["game_id"])
	if room_state.has("game_id"):
		return int(room_state["game_id"])
	for actor in actors.values():
		if actor is Dictionary and actor.has("game_id"):
			return int(actor["game_id"])
	return -1

func is_alive() -> bool:
	if run_state.is_empty():
		return false
	var player_actor_id := int(run_state.get("player_actor_id", -1))
	if player_actor_id >= 0 and actors.has(player_actor_id):
		var actor: Dictionary = actors[player_actor_id]
		return bool(actor.get("alive", false)) and int(actor.get("hp", 0)) > 0
	return int(run_state.get("phase", 0)) != 4

func has_active_run() -> bool:
	if run_state.is_empty():
		return false
	var phase := int(run_state.get("phase", 0))
	if phase == 3 or phase == 4:
		return false
	return is_alive()

func _archive_current_run() -> void:
	if run_state.is_empty():
		return
	var gid := int(run_state.get("game_id", -1))
	if gid < 0:
		return
	add_historical_run({
		"game_id": gid,
		"run_state": run_state.duplicate(true),
		"status": _status_from_phase(int(run_state.get("phase", 0))),
	})

func _emit_game_over_if_needed() -> void:
	if run_state.is_empty():
		return
	var phase := int(run_state.get("phase", 0))
	if phase == 3 or phase == 4:
		add_historical_run({
			"game_id": int(run_state.get("game_id", -1)),
			"run_state": run_state.duplicate(true),
			"status": _status_from_phase(phase),
		})
		game_over.emit()
		return
	if not is_alive():
		add_historical_run({
			"game_id": int(run_state.get("game_id", -1)),
			"run_state": run_state.duplicate(true),
			"status": "Failed",
		})
		game_over.emit()

func _status_from_phase(phase: int) -> String:
	if phase == 3:
		return "Completed"
	if phase == 4:
		return "Failed"
	return "In Progress"

func _parse_run_state(model: Dictionary) -> Dictionary:
	return {
		"player": String(model.get("player", "")).to_lower(),
		"game_id": _as_int(model.get("game_id", -1)),
		"phase": _as_int(model.get("phase", 0)),
		"room_id": _as_int(model.get("room_id", 0)),
		"turn_index": _as_int(model.get("turn_index", 0)),
		"player_actor_id": _as_int(model.get("player_actor_id", -1)),
		"status_flags": _as_int(model.get("status_flags", 0)),
	}

func _parse_room_state(model: Dictionary) -> Dictionary:
	return {
		"player": String(model.get("player", "")).to_lower(),
		"game_id": _as_int(model.get("game_id", -1)),
		"room_id": _as_int(model.get("room_id", 0)),
		"width": _as_int(model.get("width", 0)),
		"height": _as_int(model.get("height", 0)),
		"blocked": _as_int(model.get("blocked", 0)),
		"occupancy": _as_int(model.get("occupancy", 0)),
		"enemy_count": _as_int(model.get("enemy_count", 0)),
		"cleared": _as_bool(model.get("cleared", false)),
	}

func _parse_actor_state(model: Dictionary) -> Dictionary:
	return {
		"player": String(model.get("player", "")).to_lower(),
		"game_id": _as_int(model.get("game_id", -1)),
		"actor_id": _as_int(model.get("actor_id", -1)),
		"faction": _as_int(model.get("faction", 0)),
		"archetype": _as_int(model.get("archetype", 0)),
		"hp": _as_int(model.get("hp", 0)),
		"max_hp": _as_int(model.get("max_hp", 0)),
		"stamina": _as_int(model.get("stamina", 0)),
		"max_stamina": _as_int(model.get("max_stamina", 0)),
		"offense": _as_int(model.get("offense", 0)),
		"defense": _as_int(model.get("defense", 0)),
		"speed": _as_int(model.get("speed", 0)),
		"move_cost": _as_int(model.get("move_cost", 0)),
		"pos_x": _as_int(model.get("pos_x", 0)),
		"pos_y": _as_int(model.get("pos_y", 0)),
		"alive": _as_bool(model.get("alive", false)),
		"guard_active": _as_bool(model.get("guard_active", false)),
		"room_id": _as_int(model.get("room_id", 0)),
	}

func _parse_ability_slot_state(model: Dictionary) -> Dictionary:
	return {
		"player": String(model.get("player", "")).to_lower(),
		"game_id": _as_int(model.get("game_id", -1)),
		"actor_id": _as_int(model.get("actor_id", -1)),
		"slot_index": _as_int(model.get("slot_index", -1)),
		"ability_id": _as_int(model.get("ability_id", 0)),
		"cooldown_remaining": _as_int(model.get("cooldown_remaining", 0)),
	}

func _parse_telegraph_state(model: Dictionary) -> Dictionary:
	return {
		"player": String(model.get("player", "")).to_lower(),
		"game_id": _as_int(model.get("game_id", -1)),
		"telegraph_id": _as_int(model.get("telegraph_id", -1)),
		"source_actor_id": _as_int(model.get("source_actor_id", 0)),
		"shape_type": _as_int(model.get("shape_type", 0)),
		"param_a": _as_int(model.get("param_a", 0)),
		"param_b": _as_int(model.get("param_b", 0)),
		"param_c": _as_int(model.get("param_c", 0)),
		"damage": _as_int(model.get("damage", 0)),
		"created_turn": _as_int(model.get("created_turn", 0)),
		"resolves_turn": _as_int(model.get("resolves_turn", 0)),
		"resolved": _as_bool(model.get("resolved", false)),
		"room_id": _as_int(model.get("room_id", 0)),
	}

func _as_int(value: Variant) -> int:
	if value is String:
		var s := String(value)
		if s.begins_with("0x"):
			return s.hex_to_int()
		if s.is_valid_int():
			return int(s)
	return int(value)

func _as_bool(value: Variant) -> bool:
	if value is String:
		var s := String(value).to_lower()
		if s == "true" or s == "1":
			return true
		if s == "false" or s == "0":
			return false
	return bool(value)
