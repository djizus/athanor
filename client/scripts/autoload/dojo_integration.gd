extends Node

const ACTION_TYPE_MOVE := 0
const ACTION_TYPE_ABILITY := 1

var _enabled: bool = false
var _current_game_id: int = -1
var _current_room_id: int = -1
var _turn_actions: Array[Dictionary] = []
var _combat_manager: CombatManager

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	DojoBridge.tx_failed.connect(_on_tx_failed)
	DojoBridge.tx_submitted.connect(_on_tx_submitted)

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not _enabled:
		_turn_actions.clear()
		_current_game_id = -1
		_current_room_id = -1

func set_current_game_id(game_id: int) -> void:
	_current_game_id = game_id

# --- Action recording ---

func record_move(target_x: int, target_y: int) -> void:
	if not _enabled:
		return
	_turn_actions.push_back({"type": "move", "x": target_x, "y": target_y})

func record_ability(ability_id: int, target_mode: int, target_a: int, target_b: int) -> void:
	if not _enabled:
		return
	_turn_actions.push_back({"type": "ability", "id": ability_id, "mode": target_mode, "a": target_a, "b": target_b})

# --- Turn submission ---

## Serialize recorded actions and submit as one confirm_turn TX.
func submit_turn() -> void:
	if not _enabled:
		return
	if _current_game_id < 0:
		_current_game_id = GameState.get_game_id()
	if _current_game_id < 0:
		push_warning("[dojo_integration] submit_turn skipped — no game_id")
		return

	var actions_packed: Array = []
	for action in _turn_actions:
		match String(action.get("type", "")):
			"move":
				actions_packed.append(ACTION_TYPE_MOVE)
				actions_packed.append(int(action.get("x", 0)))
				actions_packed.append(int(action.get("y", 0)))
			"ability":
				actions_packed.append(ACTION_TYPE_ABILITY)
				actions_packed.append(int(action.get("id", 0)))
				actions_packed.append(int(action.get("mode", 0)))
				actions_packed.append(int(action.get("a", 0)))
				actions_packed.append(int(action.get("b", 0)))

	push_warning("[dojo_integration] confirm_turn game_id=%d actions=%d felts=%d" % [
		_current_game_id, _turn_actions.size(), actions_packed.size()
	])
	for i in range(_turn_actions.size()):
		var a: Dictionary = _turn_actions[i]
		if String(a.get("type", "")) == "move":
			push_warning("[dojo_integration]   [%d] MOVE to (%d, %d)" % [i, int(a.get("x", 0)), int(a.get("y", 0))])
		else:
			push_warning("[dojo_integration]   [%d] ABILITY id=%d mode=%d a=%d b=%d" % [
				i, int(a.get("id", 0)), int(a.get("mode", 0)), int(a.get("a", 0)), int(a.get("b", 0))
			])
	DojoBridge.confirm_turn(_current_game_id, actions_packed)
	_turn_actions.clear()

# --- TX callbacks ---

func _on_tx_failed(action: String, _reason: String) -> void:
	if action == "confirm_turn" && _combat_manager != null:
		# TX failed — let player retry. Re-enable input.
		_combat_manager.reset_turn()
		_turn_actions.clear()

func _on_tx_submitted(action: String) -> void:
	if action == "confirm_turn" && _enabled:
		# TX accepted — wait for chain to process player actions + enemy phase,
		# then sync the result and start next player turn.
		_sync_chain_then_next_turn()

## The core online loop: wait for Torii subscription to push updated actor state,
## then sync and start the next player turn. No polling — uses GameState.actor_updated signal.
func _sync_chain_then_next_turn() -> void:
	# Wait for at least one actor_updated signal from Torii subscription,
	# with a timeout fallback in case the subscription is slow.
	var received := false
	var _on_update := func(_actor: Dictionary) -> void:
		received = true

	GameState.actor_updated.connect(_on_update)
	# Timeout: if no subscription update after 12s, do a one-time snapshot pull as fallback.
	var elapsed := 0.0
	while !received && elapsed < 12.0:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
	GameState.actor_updated.disconnect(_on_update)

	if !received:
		push_warning("[dojo_integration] no subscription update after %.0fs — snapshot fallback" % elapsed)
		DojoBridge.pull_entities_snapshot()
		await get_tree().create_timer(1.0).timeout

	if _combat_manager != null && !GameState.actors.is_empty():
		_combat_manager.sync_positions_from_chain(GameState.actors)
		_combat_manager.start_next_turn_from_chain()
		push_warning("[dojo_integration] chain turn complete — next player turn started")
	else:
		push_warning("[dojo_integration] chain sync failed — no data, re-enabling input")
		if _combat_manager != null:
			_combat_manager._enable_player_input(true)

# --- Combat lifecycle ---

func _on_node_added(node: Node) -> void:
	if node is CombatManager:
		_combat_manager = node as CombatManager
		if not _combat_manager.combat_started.is_connected(_on_combat_started):
			_combat_manager.combat_started.connect(_on_combat_started)
		if not _combat_manager.combat_finished.is_connected(_on_combat_finished):
			_combat_manager.combat_finished.connect(_on_combat_finished)

func _on_combat_started() -> void:
	_turn_actions.clear()
	_current_room_id += 1
	if _enabled:
		if _current_room_id == 0:
			_spawn_and_enter_room()
		else:
			_enter_next_room()

func _on_combat_finished(player_won: bool) -> void:
	_turn_actions.clear()
	if not player_won:
		_current_room_id = -1
		_current_game_id = -1

# --- Chain setup (spawn + enter_room) ---

func _spawn_and_enter_room() -> void:
	push_warning("[dojo_integration] spawn() — creating onchain game...")
	DojoBridge.spawn()
	await get_tree().create_timer(3.0).timeout
	DojoBridge.pull_entities_snapshot()
	await get_tree().create_timer(1.0).timeout
	_current_game_id = GameState.get_game_id()
	if _current_game_id >= 0:
		push_warning("[dojo_integration] game_id=%d — entering room %d" % [_current_game_id, _current_room_id])
		DojoBridge.enter_room(_current_game_id, _current_room_id)
	else:
		push_warning("[dojo_integration] No game_id after spawn — retrying...")
		await get_tree().create_timer(3.0).timeout
		DojoBridge.pull_entities_snapshot()
		await get_tree().create_timer(1.0).timeout
		_current_game_id = GameState.get_game_id()
		if _current_game_id >= 0:
			push_warning("[dojo_integration] game_id=%d (retry) — entering room %d" % [_current_game_id, _current_room_id])
			DojoBridge.enter_room(_current_game_id, _current_room_id)
		else:
			push_warning("[dojo_integration] Failed to get game_id — online turns will not submit")

func _enter_next_room() -> void:
	if _current_game_id < 0:
		_current_game_id = GameState.get_game_id()
	if _current_game_id < 0:
		push_warning("[dojo_integration] Cannot enter room %d — no game_id" % _current_room_id)
		return

	# Wait for the previous room's confirm_turn to finalize on chain
	# (room cleared → PHASE_EXPLORE). The TX was just submitted and needs
	# time to be processed before we can enter the next room.
	var ready := false
	for attempt in range(8):
		await get_tree().create_timer(2.0).timeout
		DojoBridge.pull_entities_snapshot()
		await get_tree().create_timer(0.5).timeout
		var phase: int = int(GameState.run_state.get("phase", -1))
		# PHASE_EXPLORE=0, PHASE_COMPLETE=3 (from contract phase.cairo)
		if phase == 0 || phase == 3:
			ready = true
			break
		push_warning("[dojo_integration] waiting for room clear on chain (phase=%d, attempt %d)..." % [phase, attempt])

	if !ready:
		push_warning("[dojo_integration] room clear not confirmed on chain after 20s — entering anyway")

	push_warning("[dojo_integration] Entering room %d for game_id=%d" % [_current_room_id, _current_game_id])
	DojoBridge.enter_room(_current_game_id, _current_room_id)
