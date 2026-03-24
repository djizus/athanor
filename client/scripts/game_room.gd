class_name GameRoom
extends Node2D

const GRID_SIZE := 8
const TILE_HALF_WIDTH := 16.0
const TILE_HALF_HEIGHT := 8.0
const GRID_OFFSET := Vector2(240.0, 71.0)

const PHASE_EXPLORE := 0
const PHASE_PLAYER_TURN := 1
const PHASE_ENEMY_TURN := 2
const PHASE_COMPLETE := 3
const PHASE_FAILED := 4

# CombatManager.Phase mirror (avoid class_name dependency)
const CM_PHASE_PLAYER_TURN := 0
const CM_PHASE_ENEMY_TURN := 1

# AbilityResource.TargetMode mirror
const TM_SINGLE_TARGET := 0
const TM_DIRECTIONAL := 1
const TM_POSITIONAL := 2
const TM_SELF := 3

# Script paths for load()-based instantiation (avoids class_name resolution at parse time)
const _TELEGRAPH_SCRIPT := "res://scripts/combat/telegraph_system.gd"
const _MOVEMENT_SCRIPT := "res://scripts/combat/movement_constraint.gd"
const _AOE_SCRIPT := "res://scripts/combat/aoe_preview.gd"
const _DEBUG_SCRIPT := "res://scripts/combat/debug_overlay.gd"
const _ENEMY_VISUAL_SCRIPT := "res://scripts/combat/enemy_visual.gd"
const _COMBAT_MANAGER_SCRIPT := "res://scripts/combat/combat_manager.gd"
const _COMBAT_HUD_SCRIPT := "res://scripts/ui/combat_hud.gd"
const _STAMINA_SCRIPT := "res://scripts/resources/stamina_resource.gd"

class GridContainerNode extends Node2D:
	var blocked_bitmap: int = 0

	func _draw() -> void:
		var gs: int = GameRoom.GRID_SIZE
		var hw: float = GameRoom.TILE_HALF_WIDTH
		var hh: float = GameRoom.TILE_HALF_HEIGHT
		for y: int in range(gs):
			for x: int in range(gs):
				var tile := Vector2i(x, y)
				var center := Vector2((tile.x - tile.y) * hw, (tile.x + tile.y) * hh)
				var poly := PackedVector2Array([
					center + Vector2(0.0, -hh),
					center + Vector2(hw, 0.0),
					center + Vector2(0.0, hh),
					center + Vector2(-hw, 0.0),
				])
				var bit_index := y * gs + x
				var is_blocked := ((blocked_bitmap >> bit_index) & 1) == 1
				if is_blocked:
					draw_colored_polygon(poly, Color(0.12, 0.12, 0.15, 0.9))
				draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2], poly[3], poly[0]]), Color(1.0, 1.0, 1.0, 0.25), 1.0)

class PlayerVisualNode extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(Vector2(-10.0, -14.0), Vector2(20.0, 20.0)), Color(0.2, 0.75, 1.0, 1.0), true)

class RuntimeHealthResource extends Resource:
	signal hp_changed
	signal max_hp_changed

	var hp: float = 100.0
	var max_hp: float = 100.0

	func set_max_hp(value: float) -> void:
		max_hp = value
		max_hp_changed.emit()

var _current_game_id: int = -1
var _current_room_id: int = 0
var _run_phase: int = PHASE_EXPLORE

var _camera: Camera2D
var _grid: GridContainerNode
var _player_visual: PlayerVisualNode
var _enemy_container: Node2D
var _telegraph_system: Node2D
var _movement_constraint: Node2D
var _aoe_preview: Node2D
var _debug_overlay: Node2D
var _combat_hud: CanvasLayer
var _combat_manager: Node

var _stamina_resource: Resource
var _health_resource: RuntimeHealthResource
var _player_move_cost: int = 10

var _player_actor_id: int = 0
var _player_tile: Vector2i = Vector2i.ZERO
var _enemy_visuals: Dictionary = {}
var _enemy_step_scheduled: bool = false
var _combat_started: bool = false

func _ready() -> void:
	_build_scene_tree()
	_connect_signals()
	_refresh_full_state()

func configure(game_id: int, room_id: int) -> void:
	_current_game_id = game_id
	_current_room_id = room_id
	_refresh_full_state()

func tile_to_screen(tile: Vector2i) -> Vector2:
	return Vector2((tile.x - tile.y) * TILE_HALF_WIDTH, (tile.x + tile.y) * TILE_HALF_HEIGHT)

func is_enemy_at_tile(tile: Vector2i) -> bool:
	for actor_id_variant: Variant in game_state.actors.keys():
		var actor_id := int(actor_id_variant)
		if actor_id <= 0:
			continue
		var actor: Dictionary = game_state.actors[actor_id]
		if not bool(actor.get("alive", false)):
			continue
		if int(actor.get("room_id", _current_room_id)) != _current_room_id:
			continue
		if Vector2i(int(actor.get("pos_x", 0)), int(actor.get("pos_y", 0))) == tile:
			return true
	return false

func _build_scene_tree() -> void:
	_camera = Camera2D.new()
	_camera.name = "Camera2D"
	_camera.position = GRID_OFFSET
	_camera.zoom = Vector2.ONE
	_camera.enabled = true
	add_child(_camera)

	_grid = GridContainerNode.new()
	_grid.name = "GridContainer"
	_grid.position = GRID_OFFSET
	add_child(_grid)

	_player_visual = PlayerVisualNode.new()
	_player_visual.name = "PlayerVisual"
	_player_visual.position = GRID_OFFSET
	add_child(_player_visual)

	_enemy_container = Node2D.new()
	_enemy_container.name = "EnemyContainer"
	_enemy_container.position = GRID_OFFSET
	add_child(_enemy_container)

	_telegraph_system = _load_node(_TELEGRAPH_SCRIPT, "TelegraphSystem")
	_telegraph_system.position = GRID_OFFSET
	add_child(_telegraph_system)

	_movement_constraint = _load_node(_MOVEMENT_SCRIPT, "MovementConstraint")
	_movement_constraint.position = GRID_OFFSET
	add_child(_movement_constraint)

	_aoe_preview = _load_node(_AOE_SCRIPT, "AOEPreview")
	_aoe_preview.position = GRID_OFFSET
	add_child(_aoe_preview)

	_debug_overlay = _load_node(_DEBUG_SCRIPT, "DebugOverlay")
	_debug_overlay.position = GRID_OFFSET
	add_child(_debug_overlay)

	_stamina_resource = load(_STAMINA_SCRIPT).new()
	_stamina_resource.max_stamina = 100
	_stamina_resource.set_value(100)

	_health_resource = RuntimeHealthResource.new()

	_combat_manager = _load_node(_COMBAT_MANAGER_SCRIPT, "CombatManager")
	_combat_manager.set("movement_constraint", _movement_constraint)
	add_child(_combat_manager)

	_combat_hud = _load_node(_COMBAT_HUD_SCRIPT, "CombatHUD")
	_combat_hud.set("combat_manager", _combat_manager)
	_combat_hud.set("stamina_resource", _stamina_resource)
	_combat_hud.set("health_resource", _health_resource)
	_combat_manager.set("combat_ui", _combat_hud)
	add_child(_combat_hud)

func _load_node(script_path: String, node_name: String) -> Node:
	var script: GDScript = load(script_path) as GDScript
	if script == null:
		push_error("[game_room] Failed to load: %s" % script_path)
		var fallback := Node2D.new()
		fallback.name = node_name
		return fallback
	var instance: Node = script.new()
	instance.name = node_name
	return instance

func _connect_signals() -> void:
	if not game_state.actor_updated.is_connected(_on_actor_updated):
		game_state.actor_updated.connect(_on_actor_updated)
	if not game_state.telegraph_updated.is_connected(_on_telegraph_updated):
		game_state.telegraph_updated.connect(_on_telegraph_updated)
	if not game_state.run_updated.is_connected(_on_run_updated):
		game_state.run_updated.connect(_on_run_updated)
	if not game_state.room_updated.is_connected(_on_room_updated):
		game_state.room_updated.connect(_on_room_updated)
	if not game_state.ability_updated.is_connected(_on_ability_updated):
		game_state.ability_updated.connect(_on_ability_updated)

	if _combat_hud.has_signal("end_turn_requested"):
		_combat_hud.connect("end_turn_requested", _on_end_turn_requested)
	if _combat_hud.has_signal("ability_selected"):
		_combat_hud.connect("ability_selected", _on_ability_selected)
	if _combat_hud.has_signal("ability_cancelled"):
		_combat_hud.connect("ability_cancelled", _on_ability_cancelled)

	if _aoe_preview.has_signal("target_confirmed"):
		_aoe_preview.connect("target_confirmed", _on_target_confirmed)

func _unhandled_input(event: InputEvent) -> void:
	if _run_phase != PHASE_PLAYER_TURN:
		return
	if bool(_aoe_preview.get("active")):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var direction := Vector2i.ZERO
		match event.keycode:
			KEY_W, KEY_UP:
				direction = Vector2i(0, -1)
			KEY_S, KEY_DOWN:
				direction = Vector2i(0, 1)
			KEY_A, KEY_LEFT:
				direction = Vector2i(-1, 0)
			KEY_D, KEY_RIGHT:
				direction = Vector2i(1, 0)
		if direction != Vector2i.ZERO:
			_try_move_player(direction)

func _try_move_player(direction: Vector2i) -> void:
	if _current_game_id < 0:
		return
	var target := _player_tile + direction
	if not _can_move_to_tile(target):
		return
	DojoBridge.move_v2(_current_game_id, target.x, target.y)

func _can_move_to_tile(tile: Vector2i) -> bool:
	if tile.x < 0 or tile.x >= GRID_SIZE or tile.y < 0 or tile.y >= GRID_SIZE:
		return false
	if _is_blocked(tile):
		return false
	if _is_occupied_by_enemy(tile):
		return false

	var move_cost: int = max(1, _player_move_cost)
	if not _stamina_resource.call("can_afford", move_cost):
		return false

	if abs(tile.x - _player_tile.x) + abs(tile.y - _player_tile.y) != 1:
		return false

	if _movement_constraint.has_method("get_reachable_tiles"):
		var reachable: Array = _movement_constraint.call("get_reachable_tiles")
		if not reachable.is_empty() and not reachable.has(tile):
			return false

	return true

func _is_blocked(tile: Vector2i) -> bool:
	var bit_index := tile.y * GRID_SIZE + tile.x
	var blocked_bitmap := int(game_state.room_state.get("blocked", 0))
	return ((blocked_bitmap >> bit_index) & 1) == 1

func _is_occupied_by_enemy(tile: Vector2i) -> bool:
	for actor_id_variant: Variant in game_state.actors.keys():
		var actor_id := int(actor_id_variant)
		if actor_id <= 0:
			continue
		var actor: Dictionary = game_state.actors[actor_id]
		if not bool(actor.get("alive", false)):
			continue
		if int(actor.get("room_id", _current_room_id)) != _current_room_id:
			continue
		if Vector2i(int(actor.get("pos_x", 0)), int(actor.get("pos_y", 0))) == tile:
			return true
	return false

func _on_run_updated(run_state: Dictionary) -> void:
	if run_state.is_empty():
		return
	_current_game_id = int(run_state.get("game_id", _current_game_id))
	_current_room_id = int(run_state.get("room_id", _current_room_id))
	_player_actor_id = int(run_state.get("player_actor_id", _player_actor_id))
	_run_phase = int(run_state.get("phase", PHASE_EXPLORE))

	_telegraph_system.call("set_current_turn", int(run_state.get("turn_index", 0)))
	_apply_phase_to_combat_manager(_run_phase)

	if _run_phase == PHASE_ENEMY_TURN:
		_queue_enemy_step()
	else:
		_enemy_step_scheduled = false

	if _run_phase == PHASE_COMPLETE or _run_phase == PHASE_FAILED:
		if _combat_hud.has_method("hide_combat_ui"):
			_combat_hud.call("hide_combat_ui")

	_refresh_cooldowns()
	_refresh_debug_overlay()

func _on_room_updated(room_state: Dictionary) -> void:
	if room_state.is_empty():
		return
	var next_game_id := int(room_state.get("game_id", -1))
	if _current_game_id >= 0 and next_game_id >= 0 and next_game_id != _current_game_id:
		return

	_current_game_id = max(_current_game_id, next_game_id)
	_current_room_id = int(room_state.get("room_id", _current_room_id))
	_grid.blocked_bitmap = int(room_state.get("blocked", 0))
	_grid.queue_redraw()

	if bool(room_state.get("cleared", false)):
		if _combat_hud.has_method("hide_combat_ui"):
			_combat_hud.call("hide_combat_ui")

	_refresh_debug_overlay()

func _on_actor_updated(actor_id: int) -> void:
	if not game_state.actors.has(actor_id):
		return
	var actor: Dictionary = game_state.actors[actor_id]
	if int(actor.get("room_id", _current_room_id)) != _current_room_id:
		return

	if actor_id == _player_actor_id:
		_update_player_from_state(actor)
	else:
		_upsert_enemy_visual(actor_id, actor)

	_refresh_enemy_focus_in_hud()
	_refresh_debug_overlay()

func _update_player_from_state(actor: Dictionary) -> void:
	_player_tile = Vector2i(int(actor.get("pos_x", 0)), int(actor.get("pos_y", 0)))
	_player_visual.position = GRID_OFFSET + tile_to_screen(_player_tile)
	_player_visual.queue_redraw()

	var stamina: int = int(actor.get("stamina", _stamina_resource.get("value")))
	var max_stamina: int = max(1, int(actor.get("max_stamina", _stamina_resource.get("max_stamina"))))
	_stamina_resource.set("max_stamina", max_stamina)
	_stamina_resource.call("set_value", stamina)

	var hp: float = float(actor.get("hp", _health_resource.hp))
	var max_hp: float = max(1.0, float(actor.get("max_hp", _health_resource.max_hp)))
	_health_resource.set_max_hp(max_hp)
	_health_resource.hp = clamp(hp, 0.0, max_hp)
	_health_resource.hp_changed.emit()

	_player_move_cost = max(1, int(actor.get("move_cost", _player_move_cost)))

	_movement_constraint.set("tile_x", _player_tile.x)
	_movement_constraint.set("tile_y", _player_tile.y)

func _upsert_enemy_visual(actor_id: int, actor: Dictionary) -> void:
	var visual: Node2D = null
	if _enemy_visuals.has(actor_id):
		visual = _enemy_visuals[actor_id]
	else:
		visual = _load_node(_ENEMY_VISUAL_SCRIPT, "Enemy_%d" % actor_id)
		_enemy_container.add_child(visual)
		_enemy_visuals[actor_id] = visual
	visual.call("update_from_state", actor)

func _on_telegraph_updated(telegraph_id: int) -> void:
	if not game_state.telegraphs.has(telegraph_id):
		_telegraph_system.call("remove_telegraph", telegraph_id)
		_refresh_debug_overlay()
		return

	var data: Dictionary = game_state.telegraphs[telegraph_id]
	if int(data.get("room_id", _current_room_id)) != _current_room_id:
		return

	# TelegraphSystem expects source_x/source_y in data for shape reconstruction.
	var source_actor_id := int(data.get("source_actor_id", -1))
	if source_actor_id >= 0 and game_state.actors.has(source_actor_id):
		var source_actor: Dictionary = game_state.actors[source_actor_id]
		data["source_x"] = int(source_actor.get("pos_x", 0))
		data["source_y"] = int(source_actor.get("pos_y", 0))

	_telegraph_system.call("add_telegraph", telegraph_id, data)
	if bool(data.get("resolved", false)):
		_telegraph_system.call("resolve_telegraph", telegraph_id)

	_refresh_debug_overlay()

func _on_ability_updated(actor_id: int, _slot: int) -> void:
	if actor_id != _player_actor_id:
		return
	_refresh_cooldowns()

func _on_end_turn_requested() -> void:
	if _current_game_id < 0:
		return
	DojoBridge.end_player_phase_v2(_current_game_id)
	_combat_manager.call("end_player_turn")
	_aoe_preview.call("hide_preview")

func _on_ability_selected(index: int) -> void:
	var abilities: Array = _combat_hud.get("abilities")
	if abilities == null or index < 0 or index >= abilities.size():
		return
	var ability: Resource = abilities[index]
	_aoe_preview.call("show_preview", ability, _player_tile)

func _on_ability_cancelled() -> void:
	_aoe_preview.call("hide_preview")

func _on_target_confirmed(ability_id: int, target_mode: int, target_a: int, target_b: int) -> void:
	if _current_game_id < 0:
		return

	var final_target_a := target_a
	var final_target_b := target_b

	if target_mode == TM_SINGLE_TARGET:
		var enemy_id := _enemy_actor_at_tile(Vector2i(target_a, target_b))
		if enemy_id < 0:
			return
		final_target_a = enemy_id
		final_target_b = 0
	elif target_mode == TM_DIRECTIONAL:
		var direction := Vector2i(target_a, target_b) - _player_tile
		final_target_a = _direction_to_index(direction)
		final_target_b = 0
	elif target_mode == TM_SELF:
		final_target_a = 0
		final_target_b = 0

	DojoBridge.use_ability_v2(_current_game_id, ability_id, target_mode, final_target_a, final_target_b)
	_aoe_preview.call("hide_preview")

func _enemy_actor_at_tile(tile: Vector2i) -> int:
	for actor_id_variant: Variant in game_state.actors.keys():
		var actor_id := int(actor_id_variant)
		if actor_id <= 0:
			continue
		var actor: Dictionary = game_state.actors[actor_id]
		if not bool(actor.get("alive", false)):
			continue
		if int(actor.get("room_id", _current_room_id)) != _current_room_id:
			continue
		if Vector2i(int(actor.get("pos_x", 0)), int(actor.get("pos_y", 0))) == tile:
			return actor_id
	return -1

func _direction_to_index(direction: Vector2i) -> int:
	if abs(direction.x) >= abs(direction.y):
		if direction.x >= 0:
			return 1
		return 3
	if direction.y >= 0:
		return 2
	return 0

func _apply_phase_to_combat_manager(run_phase: int) -> void:
	if run_phase == PHASE_PLAYER_TURN or run_phase == PHASE_ENEMY_TURN:
		if not _combat_started:
			_combat_started = true
			_combat_manager.call("start_combat")
			if _combat_hud.has_method("show_combat_ui"):
				_combat_hud.call("show_combat_ui")
		if run_phase == PHASE_PLAYER_TURN:
			_combat_manager.call("_set_phase", CM_PHASE_PLAYER_TURN)
		else:
			_combat_manager.call("_set_phase", CM_PHASE_ENEMY_TURN)
	else:
		if _combat_started:
			_combat_started = false
			_combat_manager.call("end_combat")
			if _combat_hud.has_method("hide_combat_ui"):
				_combat_hud.call("hide_combat_ui")
		_combat_manager.call("set_phase_resolving")

func _queue_enemy_step() -> void:
	if _enemy_step_scheduled or _current_game_id < 0:
		return
	_enemy_step_scheduled = true
	_call_enemy_step_after_delay()

func _call_enemy_step_after_delay() -> void:
	await get_tree().create_timer(0.5).timeout
	if _run_phase == PHASE_ENEMY_TURN and _current_game_id >= 0:
		DojoBridge.step_enemy_phase_v2(_current_game_id)
	_enemy_step_scheduled = false

func _refresh_cooldowns() -> void:
	var cooldowns: Array[int] = [0, 0, 0, 0, 0]
	for key: Variant in game_state.ability_slots.keys():
		var slot: Dictionary = game_state.ability_slots[key]
		if int(slot.get("actor_id", -1)) != _player_actor_id:
			continue
		var slot_index := int(slot.get("slot_index", -1))
		if slot_index < 0 or slot_index >= cooldowns.size():
			continue
		cooldowns[slot_index] = int(slot.get("cooldown_remaining", 0))
	_combat_hud.call("update_cooldowns", cooldowns)

func _refresh_enemy_focus_in_hud() -> void:
	for actor_id_variant: Variant in game_state.actors.keys():
		var actor_id := int(actor_id_variant)
		if actor_id <= 0:
			continue
		var actor: Dictionary = game_state.actors[actor_id]
		if int(actor.get("room_id", _current_room_id)) != _current_room_id:
			continue
		if not bool(actor.get("alive", false)):
			continue
		_combat_hud.call("update_enemy_info",
			"Enemy %d" % actor_id,
			int(actor.get("hp", 0)),
			max(1, int(actor.get("max_hp", 1)))
		)
		return
	_combat_hud.call("clear_enemy_info")

func _refresh_debug_overlay() -> void:
	var telegraph_data: Dictionary = {}
	if _telegraph_system.has_method("get") and _telegraph_system.get("active_telegraphs") is Dictionary:
		telegraph_data = _telegraph_system.get("active_telegraphs")
	_debug_overlay.call("update_data", game_state.room_state, game_state.actors, telegraph_data, int(game_state.run_state.get("turn_index", 0)))

func _refresh_full_state() -> void:
	if not game_state.run_state.is_empty():
		_on_run_updated(game_state.run_state)
	if not game_state.room_state.is_empty():
		_on_room_updated(game_state.room_state)
	for actor_id_variant: Variant in game_state.actors.keys():
		_on_actor_updated(int(actor_id_variant))
	for telegraph_id_variant: Variant in game_state.telegraphs.keys():
		_on_telegraph_updated(int(telegraph_id_variant))
	_refresh_cooldowns()
