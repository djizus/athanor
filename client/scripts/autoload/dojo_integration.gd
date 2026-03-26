extends Node

const ACTION_TYPE_MOVE := 0
const ACTION_TYPE_ABILITY := 1

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

## Serialize all recorded actions into a flat felt252 array and submit as a single
## confirm_turn transaction. The contract processes all actions then auto-runs enemy phase.
func submit_turn() -> void:
	if not _enabled:
		return
	if _current_game_id < 0:
		_current_game_id = GameState.get_game_id()
	if _current_game_id < 0:
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

	DojoBridge.confirm_turn(_current_game_id, actions_packed)
	_turn_actions.clear()

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
