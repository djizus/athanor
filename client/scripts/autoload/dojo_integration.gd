extends Node

var _enabled: bool = false
var _current_game_id: int = -1
var _turn_actions: Array[Dictionary] = []

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not _enabled:
		_turn_actions.clear()

func set_current_game_id(game_id: int) -> void:
	_current_game_id = game_id

func record_move(target_x: int, target_y: int) -> void:
	if not _enabled:
		return
	_turn_actions.push_back({
		"type": "move",
		"x": target_x,
		"y": target_y,
	})

func record_ability(ability_id: int, target_mode: int, target_a: int, target_b: int) -> void:
	if not _enabled:
		return
	_turn_actions.push_back({
		"type": "ability",
		"id": ability_id,
		"mode": target_mode,
		"a": target_a,
		"b": target_b,
	})

func submit_turn() -> void:
	if not _enabled:
		return
	if _current_game_id < 0:
		_current_game_id = GameState.get_game_id()
	if _current_game_id < 0:
		return

	for action in _turn_actions:
		match String(action.get("type", "")):
			"move":
				DojoBridge.move_action(_current_game_id, int(action.get("x", 0)), int(action.get("y", 0)))
			"ability":
				DojoBridge.use_ability(
					_current_game_id,
					int(action.get("id", 0)),
					int(action.get("mode", 0)),
					int(action.get("a", 0)),
					int(action.get("b", 0))
				)

	DojoBridge.end_player_phase(_current_game_id)
	_step_enemy_phase_deferred()
	_turn_actions.clear()

func _step_enemy_phase_deferred() -> void:
	await get_tree().create_timer(1.0).timeout
	if _enabled and _current_game_id >= 0:
		DojoBridge.step_enemy_phase(_current_game_id)

func _on_node_added(node: Node) -> void:
	if node is CombatManager:
		var combat_manager := node as CombatManager
		if not combat_manager.combat_started.is_connected(_on_combat_started):
			combat_manager.combat_started.connect(_on_combat_started)
		if not combat_manager.combat_finished.is_connected(_on_combat_finished):
			combat_manager.combat_finished.connect(_on_combat_finished)

func _on_combat_started() -> void:
	_turn_actions.clear()
	_current_game_id = GameState.get_game_id()

func _on_combat_finished(_player_won: bool) -> void:
	_turn_actions.clear()
