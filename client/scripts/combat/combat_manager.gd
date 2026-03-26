class_name CombatManager
extends Node

signal combat_started
signal combat_finished(player_won:bool)

const TILE_MOVE_STAMINA_COST:int = 10

const BRUTE_AI_SCRIPT:Script = preload("res://scripts/combat/ai/brute_ai.gd")
const CASTER_AI_SCRIPT:Script = preload("res://scripts/combat/ai/caster_ai.gd")
const FLANKER_AI_SCRIPT:Script = preload("res://scripts/combat/ai/flanker_ai.gd")

const STRIKE_EFFECT_SCRIPT:Script = preload("res://scripts/combat/abilities/ability_strike.gd")
const DASH_EFFECT_SCRIPT:Script = preload("res://scripts/combat/abilities/ability_dash.gd")
const GUARD_EFFECT_SCRIPT:Script = preload("res://scripts/combat/abilities/ability_guard.gd")

const ABILITY_STRIKE:AbilityResource = preload("res://resources/combat/ability_strike.tres")
const ABILITY_DASH:AbilityResource = preload("res://resources/combat/ability_dash.tres")
const ABILITY_GUARD:AbilityResource = preload("res://resources/combat/ability_guard.tres")

var turn_manager:TurnManager
var grid_movement:GridMovement
var ability_manager:AbilityManager
var ability_targeting:AbilityTargeting
var telegraph_system:TelegraphSystem
var enemy_turn_resolver:EnemyTurnResolver

var combat_grid:CombatGrid
var grid_cursor:GridCursor

var player:Dictionary = {}
var enemies:Array[Dictionary] = []

var grid_state:Dictionary = {
	"blocked_cells": Array([], TYPE_VECTOR2I, "", null),
	"occupied_cells": Array([], TYPE_VECTOR2I, "", null),
	"grid_size": 8,
	"player_last_move_dir": Vector2i.RIGHT,
}

var _input_enabled:bool = false

var _ability_strike:AbilityStrike
var _ability_dash:AbilityDash
var _ability_guard:AbilityGuard

var _camera:Camera2D
var _camera_prev_zoom:Vector2 = Vector2.ONE
var _camera_prev_position:Vector2 = Vector2.ZERO
var _camera_prev_follow:bool = true

func _ready() -> void:
	_setup_subsystems()

func start_combat(player_node:Node2D, enemy_nodes:Array[Node], combat_grid_node:Node) -> void:
	combat_grid = combat_grid_node as CombatGrid
	if combat_grid == null:
		return

	grid_cursor = combat_grid.get_node_or_null("GridCursor") as GridCursor
	grid_state["grid_size"] = mini(combat_grid.grid_size.x, combat_grid.grid_size.y)

	player = _build_player_data(player_node)
	enemies = _build_enemy_data(enemy_nodes)

	_bind_player_subsystems()
	_sync_world_positions_to_grid()
	_refresh_grid_state()
	_turn_reset_abilities()
	_clear_grid_overlay()
	_focus_camera_to_grid()
	turn_manager.start_combat()
	combat_started.emit()

func end_combat() -> void:
	if turn_manager != null:
		turn_manager.queue_combat_end(_are_enemies_defeated())

func _setup_subsystems() -> void:
	turn_manager = TurnManager.new()
	add_child(turn_manager)
	turn_manager.player_turn_started.connect(_on_player_turn_started)
	turn_manager.enemy_turn_started.connect(_on_enemy_turn_started)
	turn_manager.resolve_started.connect(_on_resolve_started)
	turn_manager.combat_ended.connect(_on_combat_ended)

	grid_movement = GridMovement.new()
	add_child(grid_movement)
	grid_movement.move_completed.connect(_on_move_completed)

	ability_manager = AbilityManager.new()
	ability_manager.abilities = [ABILITY_STRIKE.duplicate(), ABILITY_DASH.duplicate(), ABILITY_GUARD.duplicate()]
	add_child(ability_manager)
	ability_manager.ability_selected.connect(_on_ability_selected)
	ability_manager.ability_used.connect(_on_ability_used)
	ability_manager.ability_cancelled.connect(_on_ability_cancelled)

	ability_targeting = AbilityTargeting.new()
	add_child(ability_targeting)

	telegraph_system = TelegraphSystem.new()
	add_child(telegraph_system)
	telegraph_system.telegraph_added.connect(_on_telegraph_added)

	enemy_turn_resolver = EnemyTurnResolver.new()
	add_child(enemy_turn_resolver)

	_ability_strike = STRIKE_EFFECT_SCRIPT.new()
	add_child(_ability_strike)
	_ability_dash = DASH_EFFECT_SCRIPT.new()
	add_child(_ability_dash)
	_ability_guard = GUARD_EFFECT_SCRIPT.new()
	add_child(_ability_guard)

func _bind_player_subsystems() -> void:
	if player.is_empty():
		return

	grid_movement.combat_grid = combat_grid
	grid_movement.player_node = player.get("node", null)
	grid_movement.stamina = player.get("stamina", null)
	grid_movement.combat_stats = player.get("combat_stats", null)
	grid_movement.grid_size = int(grid_state.get("grid_size", 8))

	ability_manager.stamina_resource = player.get("stamina", null)

	if grid_cursor != null && !grid_cursor.tile_clicked.is_connected(_on_grid_tile_clicked):
		grid_cursor.tile_clicked.connect(_on_grid_tile_clicked)

func _build_player_data(player_node:Node2D) -> Dictionary:
	var stamina:StaminaResource = StaminaResource.new()
	stamina.max_value = 100
	stamina.value = 100

	var combat_stats:CombatStatsResource = CombatStatsResource.new()
	combat_stats.faction = CombatEnums.Faction.PLAYER
	combat_stats.archetype = CombatEnums.Archetype.PLAYER
	combat_stats.move_range = 10

	var health:HealthResource = HealthResource.new()
	health.max_hp = 100.0
	health.hp = 100.0

	return {
		"node": player_node,
		"combat_stats": combat_stats,
		"stamina": stamina,
		"health": health,
	}

func _build_enemy_data(enemy_nodes:Array[Node]) -> Array[Dictionary]:
	var result:Array[Dictionary] = []
	for enemy_node in enemy_nodes:
		if !(enemy_node is Node2D):
			continue

		var combat_stats:CombatStatsResource = CombatStatsResource.new()
		var health:HealthResource = HealthResource.new()
		var ai:EnemyGridAI = _assign_enemy_ai(enemy_node as Node2D, combat_stats, health)

		result.push_back({
			"node": enemy_node,
			"combat_stats": combat_stats,
			"health": health,
			"ai": ai,
			"enemy_id": enemy_node.get_instance_id(),
		})
	return result

func _assign_enemy_ai(enemy_node:Node2D, combat_stats:CombatStatsResource, health:HealthResource) -> EnemyGridAI:
	var archetype:int = _infer_enemy_archetype(enemy_node.name)
	combat_stats.faction = CombatEnums.Faction.ENEMY
	combat_stats.archetype = archetype

	match archetype:
		CombatEnums.Archetype.BRUTE:
			health.max_hp = 50.0
			health.hp = 50.0
			return BRUTE_AI_SCRIPT.new()
		CombatEnums.Archetype.CASTER:
			health.max_hp = 30.0
			health.hp = 30.0
			return CASTER_AI_SCRIPT.new()
		CombatEnums.Archetype.FLANKER:
			health.max_hp = 40.0
			health.hp = 40.0
			return FLANKER_AI_SCRIPT.new()
		_:
			health.max_hp = 50.0
			health.hp = 50.0
			return BRUTE_AI_SCRIPT.new()

func _infer_enemy_archetype(node_name:String) -> int:
	var lowered:String = node_name.to_lower()
	if lowered.contains("caster"):
		return CombatEnums.Archetype.CASTER
	if lowered.contains("flanker"):
		return CombatEnums.Archetype.FLANKER
	return CombatEnums.Archetype.BRUTE

func _on_player_turn_started() -> void:
	if ability_manager.get_selected() != null:
		ability_manager.cancel_selection()

	var stamina:StaminaResource = player.get("stamina", null)
	if stamina != null:
		stamina.refill()

	_ability_guard.clear_guard(player.get("combat_stats", null))
	_refresh_grid_state()
	grid_movement.set_blocked_cells(grid_state.get("blocked_cells", Array([], TYPE_VECTOR2I, "", null)))
	grid_movement.set_occupied_cells(_occupied_cells_without_player())
	grid_movement.refresh_reachable()
	_draw_active_telegraphs()
	_enable_player_input(true)

func _on_enemy_turn_started() -> void:
	if ability_manager.get_selected() != null:
		ability_manager.cancel_selection()

	_enable_player_input(false)
	_refresh_grid_state()
	var intents:Array[Dictionary] = enemy_turn_resolver.execute_enemy_turn(
		enemies,
		player.get("combat_stats").grid_pos,
		telegraph_system,
		grid_state,
		turn_manager.turn_count
	)
	await _animate_enemy_intents(intents)
	_sync_enemy_positions_from_data()
	_refresh_grid_state()

func _on_resolve_started() -> void:
	var resolved:Array = telegraph_system.resolve_telegraphs(turn_manager.turn_count)
	for telegraph_data in resolved:
		_apply_telegraph_damage(telegraph_data)

	ability_manager.tick_cooldowns()
	_refresh_grid_state()
	_check_win_lose()

func _on_grid_tile_clicked(tile:Vector2i) -> void:
	if !_input_enabled:
		return

	var selected:AbilityResource = ability_manager.get_selected()
	if selected == null:
		await grid_movement.try_move_to(tile)
		return

	var player_pos:Vector2i = player.get("combat_stats").grid_pos
	var blocked:Array[Vector2i] = _ability_blocked_cells_for_targeting()
	var valid:Array[Vector2i] = ability_targeting.get_valid_targets(selected, player_pos, blocked, int(grid_state.get("grid_size", 8)))
	if !valid.has(tile):
		return

	var direction:Vector2i = _direction_to(player_pos, tile)
	var used:bool = ability_manager.use_ability({
		"target_cell": tile,
		"target_direction": direction,
	})
	if used:
		ability_manager.cancel_selection()

func _on_ability_selected(ability:AbilityResource) -> void:
	if !_input_enabled || combat_grid == null || ability == null:
		return

	var player_stats:CombatStatsResource = player.get("combat_stats", null)
	if player_stats == null:
		return

	var blocked:Array[Vector2i] = _ability_blocked_cells_for_targeting()
	var valid:Array[Vector2i] = ability_targeting.get_valid_targets(
		ability,
		player_stats.grid_pos,
		blocked,
		int(grid_state.get("grid_size", 8))
	)

	_clear_grid_overlay()
	_draw_active_telegraphs()
	combat_grid.highlight_cells(valid, CombatGrid.STATE_ABILITY_RANGE)

func _on_ability_cancelled() -> void:
	if combat_grid == null:
		return

	if !_input_enabled:
		_clear_grid_overlay()
		_draw_active_telegraphs()
		return

	_refresh_grid_state()
	grid_movement.set_blocked_cells(grid_state.get("blocked_cells", Array([], TYPE_VECTOR2I, "", null)))
	grid_movement.set_occupied_cells(_occupied_cells_without_player())
	grid_movement.refresh_reachable()
	_draw_active_telegraphs()

func _on_ability_used(ability:AbilityResource, target_data:Dictionary) -> void:
	var actors_on_grid:Dictionary = _build_actors_grid_context()
	var did_execute:bool = false

	match ability.ability_id:
		CombatEnums.AbilityID.STRIKE:
			did_execute = _ability_strike.execute(target_data.get("target_cell", Vector2i(-1, -1)), actors_on_grid)
			if did_execute:
				_spawn_tile_vfx(target_data.get("target_cell", Vector2i.ZERO), Color(1.0, 0.2, 0.2, 0.75), 0.22)
		CombatEnums.AbilityID.DASH:
			var result:Dictionary = _ability_dash.execute(
				target_data.get("target_direction", Vector2i.ZERO),
				player.get("combat_stats").grid_pos,
				actors_on_grid
			)
			did_execute = true
			var moved_to:Vector2i = result.get("moved_to", player.get("combat_stats").grid_pos)
			(player.get("node") as Node2D).global_position = combat_grid.grid_to_world(moved_to)
			var impact_cell:Vector2i = result.get("impact_cell", moved_to)
			_spawn_tile_vfx(impact_cell, Color(0.98, 0.55, 0.12, 0.75), 0.24)
		CombatEnums.AbilityID.GUARD:
			did_execute = _ability_guard.execute(player.get("combat_stats", null))
			if did_execute:
				_spawn_tile_vfx(player.get("combat_stats").grid_pos, Color(0.35, 0.65, 1.0, 0.65), 0.3)

	if !did_execute:
		return

	_sync_enemy_positions_from_data()
	_refresh_grid_state()
	grid_movement.set_occupied_cells(_occupied_cells_without_player())
	grid_movement.refresh_reachable()
	_draw_active_telegraphs()
	_check_win_lose()

func _on_move_completed(from:Vector2i, to:Vector2i) -> void:
	grid_state["player_last_move_dir"] = _direction_to(from, to)
	_refresh_grid_state()
	grid_movement.set_occupied_cells(_occupied_cells_without_player())
	grid_movement.refresh_reachable()
	_draw_active_telegraphs()

func _on_telegraph_added(data:Dictionary) -> void:
	var cells:Array[Vector2i] = data.get("cells", Array([], TYPE_VECTOR2I, "", null))
	combat_grid.highlight_cells(cells, CombatGrid.STATE_DANGER)

func _on_combat_ended(player_won:bool) -> void:
	_enable_player_input(false)
	_clear_grid_overlay()
	_restore_camera_follow()
	combat_finished.emit(player_won)

func _sync_world_positions_to_grid() -> void:
	var player_stats:CombatStatsResource = player.get("combat_stats", null)
	if player_stats != null:
		player_stats.grid_pos = combat_grid.world_to_grid((player.get("node") as Node2D).global_position)
		(player.get("node") as Node2D).global_position = combat_grid.grid_to_world(player_stats.grid_pos)

	for enemy_data in enemies:
		var enemy_node:Node2D = enemy_data.get("node", null)
		var stats:CombatStatsResource = enemy_data.get("combat_stats", null)
		if enemy_node == null || stats == null:
			continue
		stats.grid_pos = combat_grid.world_to_grid(enemy_node.global_position)
		enemy_node.global_position = combat_grid.grid_to_world(stats.grid_pos)

func _sync_enemy_positions_from_data() -> void:
	for enemy_data in enemies:
		var enemy_node:Node2D = enemy_data.get("node", null)
		var stats:CombatStatsResource = enemy_data.get("combat_stats", null)
		if enemy_node == null || stats == null:
			continue
		enemy_node.global_position = combat_grid.grid_to_world(stats.grid_pos)

func _refresh_grid_state() -> void:
	var occupied:Array[Vector2i] = []
	if !player.is_empty():
		occupied.append(player.get("combat_stats").grid_pos)

	var alive_enemies:Array[Dictionary] = []
	for enemy_data in enemies:
		var health:HealthResource = enemy_data.get("health", null)
		if health != null && health.hp <= 0.0:
			var dead_node:Node2D = enemy_data.get("node", null)
			if dead_node != null:
				dead_node.visible = false
			continue
		alive_enemies.push_back(enemy_data)
		occupied.append(enemy_data.get("combat_stats").grid_pos)
	enemies = alive_enemies

	grid_state["occupied_cells"] = occupied

	grid_movement.set_blocked_cells(grid_state.get("blocked_cells", Array([], TYPE_VECTOR2I, "", null)))
	grid_movement.set_occupied_cells(_occupied_cells_without_player())

func _occupied_cells_without_player() -> Array[Vector2i]:
	var result:Array[Vector2i] = []
	for enemy_data in enemies:
		result.push_back(enemy_data.get("combat_stats").grid_pos)
	return result

func _ability_blocked_cells_for_targeting() -> Array[Vector2i]:
	var blocked:Array[Vector2i] = []
	for cell in grid_state.get("blocked_cells", Array([], TYPE_VECTOR2I, "", null)):
		blocked.push_back(cell)
	return blocked

func _build_actors_grid_context() -> Dictionary:
	var enemy_map:Dictionary = {}
	for enemy_data in enemies:
		enemy_map[enemy_data.get("combat_stats").grid_pos] = enemy_data

	return {
		"player": player,
		"player_stats": player.get("combat_stats", null),
		"enemies": enemy_map,
		"occupied": enemy_map,
		"blocked": grid_state.get("blocked_cells", Array([], TYPE_VECTOR2I, "", null)),
	}

func _apply_telegraph_damage(telegraph_data:Dictionary) -> void:
	var cells:Array[Vector2i] = telegraph_data.get("cells", Array([], TYPE_VECTOR2I, "", null))
	var damage:float = float(telegraph_data.get("damage", 0.0))
	if damage <= 0.0:
		return

	_flash_screen()
	for cell in cells:
		if player.get("combat_stats").grid_pos == cell:
			_apply_damage_to_actor(player, damage)

		for enemy_data in enemies:
			if enemy_data.get("combat_stats").grid_pos == cell:
				_apply_damage_to_actor(enemy_data, damage)

	_draw_active_telegraphs()

func _apply_damage_to_actor(actor_data:Dictionary, amount:float) -> void:
	var health:HealthResource = actor_data.get("health", null)
	if health == null:
		return

	var final_damage:float = amount
	var stats:CombatStatsResource = actor_data.get("combat_stats", null)
	if stats != null && stats.is_guarding:
		final_damage *= (1.0 - clampf(stats.guard_reduction, 0.0, 1.0))

	health.add_hp(-final_damage)

func _animate_enemy_intents(intents:Array[Dictionary]) -> void:
	if intents.is_empty():
		return

	for i in intents.size():
		var intent:Dictionary = intents[i]
		var enemy_id:Variant = intent.get("enemy_id", -1)
		var enemy_data:Dictionary = _find_enemy_by_id(enemy_id)
		if enemy_data.is_empty():
			continue
		var enemy_node:Node2D = enemy_data.get("node", null)
		if enemy_node == null:
			continue
		var moved_to:Vector2i = intent.get("moved_to", enemy_data.get("combat_stats").grid_pos)
		var tween:Tween = create_tween()
		tween.tween_property(enemy_node, "global_position", combat_grid.grid_to_world(moved_to), 0.2)
		await tween.finished
		if i < intents.size() - 1:
			await get_tree().create_timer(0.06).timeout

func _find_enemy_by_id(enemy_id:Variant) -> Dictionary:
	for enemy_data in enemies:
		if enemy_data.get("enemy_id", -1) == enemy_id:
			return enemy_data
	return {}

func _check_win_lose() -> void:
	if _is_player_dead():
		turn_manager.queue_combat_end(false)
		return
	if _are_enemies_defeated():
		turn_manager.queue_combat_end(true)

func _unhandled_input(event:InputEvent) -> void:
	if !_input_enabled || ability_manager == null:
		return
	if ability_manager.get_selected() == null:
		return

	var should_cancel:bool = false
	if event is InputEventMouseButton:
		var mouse_event:InputEventMouseButton = event
		should_cancel = mouse_event.pressed && mouse_event.button_index == MOUSE_BUTTON_RIGHT
	elif event is InputEventKey:
		var key_event:InputEventKey = event
		should_cancel = key_event.pressed && !key_event.echo && key_event.keycode == KEY_ESCAPE

	if should_cancel:
		ability_manager.cancel_selection()
		get_viewport().set_input_as_handled()

func _is_player_dead() -> bool:
	var health:HealthResource = player.get("health", null)
	return health != null && health.hp <= 0.0

func _are_enemies_defeated() -> bool:
	for enemy_data in enemies:
		var health:HealthResource = enemy_data.get("health", null)
		if health == null || health.hp > 0.0:
			return false
	return true

func _enable_player_input(enabled:bool) -> void:
	_input_enabled = enabled
	set_process_unhandled_input(enabled)
	if grid_cursor != null:
		grid_cursor.set_process(enabled)
		grid_cursor.set_process_unhandled_input(enabled)

func _clear_grid_overlay() -> void:
	if combat_grid != null:
		combat_grid.clear_overlay()

func _draw_active_telegraphs() -> void:
	if combat_grid == null:
		return
	var active:Array = telegraph_system.get_active()
	for data in active:
		var cells:Array[Vector2i] = data.get("cells", Array([], TYPE_VECTOR2I, "", null))
		combat_grid.highlight_cells(cells, CombatGrid.STATE_DANGER)

func _direction_to(from:Vector2i, to:Vector2i) -> Vector2i:
	var delta:Vector2i = to - from
	if delta == Vector2i.ZERO:
		return Vector2i.ZERO
	if absi(delta.x) >= absi(delta.y):
		return Vector2i(signi(delta.x), 0)
	return Vector2i(0, signi(delta.y))

func _turn_reset_abilities() -> void:
	for ability in ability_manager.abilities:
		ability.current_cooldown = 0

func _spawn_tile_vfx(cell:Vector2i, color:Color, duration:float) -> void:
	if combat_grid == null:
		return
	var marker:Polygon2D = Polygon2D.new()
	marker.color = color
	marker.polygon = PackedVector2Array([
		Vector2(0, -8),
		Vector2(16, 0),
		Vector2(0, 8),
		Vector2(-16, 0),
	])
	marker.global_position = combat_grid.grid_to_world(cell)
	add_child(marker)
	var tween:Tween = create_tween()
	tween.tween_property(marker, "modulate:a", 0.0, duration)
	tween.tween_callback(marker.queue_free)

func _flash_screen() -> void:
	var flash_layer:CanvasLayer = CanvasLayer.new()
	flash_layer.layer = 128
	add_child(flash_layer)

	var rect:ColorRect = ColorRect.new()
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(1.0, 1.0, 1.0, 0.0)
	flash_layer.add_child(rect)

	var tween:Tween = create_tween()
	tween.tween_property(rect, "color:a", 0.25, 0.05)
	tween.tween_property(rect, "color:a", 0.0, 0.16)
	tween.tween_callback(flash_layer.queue_free)

func _focus_camera_to_grid() -> void:
	if combat_grid == null:
		return
	_camera = get_viewport().get_camera_2d()
	if _camera == null:
		return

	_camera_prev_zoom = _camera.zoom
	_camera_prev_position = _camera.global_position
	if _camera.has_method("get"):
		_camera_prev_follow = bool(_camera.get("follow")) if _camera.get("follow") != null else true
	if _camera.has_method("set_follow"):
		_camera.call("set_follow", false)

	var corners:Array[Vector2] = [
		combat_grid.grid_to_world(Vector2i(0, 0)),
		combat_grid.grid_to_world(Vector2i(7, 0)),
		combat_grid.grid_to_world(Vector2i(0, 7)),
		combat_grid.grid_to_world(Vector2i(7, 7)),
	]
	var min_x:float = corners[0].x
	var max_x:float = corners[0].x
	var min_y:float = corners[0].y
	var max_y:float = corners[0].y
	for point in corners:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)

	var bounds_size:Vector2 = Vector2(max_x - min_x + 64.0, max_y - min_y + 48.0)
	var viewport_size:Vector2 = get_viewport().get_visible_rect().size
	var zoom_x:float = viewport_size.x / maxf(bounds_size.x, 1.0)
	var zoom_y:float = viewport_size.y / maxf(bounds_size.y, 1.0)
	var target_zoom:Vector2 = Vector2.ONE * minf(zoom_x, zoom_y) * 0.85
	var target_center:Vector2 = Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)

	var tween:Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_camera, "global_position", target_center, 0.3)
	tween.tween_property(_camera, "zoom", target_zoom, 0.3)

func _restore_camera_follow() -> void:
	if _camera == null:
		return
	var tween:Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_camera, "global_position", _camera_prev_position, 0.3)
	tween.tween_property(_camera, "zoom", _camera_prev_zoom, 0.3)
	if _camera.has_method("set_follow"):
		tween.finished.connect(func() -> void:
			_camera.call("set_follow", _camera_prev_follow)
		)
