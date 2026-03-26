class_name CombatManager
extends Node

signal combat_started
signal combat_finished(player_won:bool)

const TILE_MOVE_STAMINA_COST:int = 10

const BRUTE_AI_SCRIPT:Script = preload("res://scripts/combat/ai/brute_ai.gd")
const CASTER_AI_SCRIPT:Script = preload("res://scripts/combat/ai/caster_ai.gd")
const FLANKER_AI_SCRIPT:Script = preload("res://scripts/combat/ai/flanker_ai.gd")
const HEAVY_AI_SCRIPT:Script = preload("res://scripts/combat/ai/heavy_ai.gd")
const PULLER_AI_SCRIPT:Script = preload("res://scripts/combat/ai/puller_ai.gd")

const STRIKE_EFFECT_SCRIPT:Script = preload("res://scripts/combat/abilities/ability_strike.gd")
const DASH_EFFECT_SCRIPT:Script = preload("res://scripts/combat/abilities/ability_dash.gd")
const HEAL_EFFECT_SCRIPT:Script = preload("res://scripts/combat/abilities/ability_heal.gd")
const SHOVE_EFFECT_SCRIPT:Script = preload("res://scripts/combat/abilities/ability_shove.gd")
const SLAM_EFFECT_SCRIPT:Script = preload("res://scripts/combat/abilities/ability_slam.gd")

const ABILITY_STRIKE:AbilityResource = preload("res://resources/combat/ability_strike.tres")
const ABILITY_DASH:AbilityResource = preload("res://resources/combat/ability_dash.tres")
const ABILITY_HEAL:AbilityResource = preload("res://resources/combat/ability_heal.tres")
const ABILITY_SHOVE:AbilityResource = preload("res://resources/combat/ability_shove.tres")
const ABILITY_SLAM:AbilityResource = preload("res://resources/combat/ability_slam.tres")

var turn_manager:TurnManager
var grid_movement:GridMovement
var ability_manager:AbilityManager
var ability_targeting:AbilityTargeting
var telegraph_system:TelegraphSystem
var enemy_turn_resolver:EnemyTurnResolver
var bump_system:BumpSystem
var energy_orb_system:EnergyOrbSystem

var combat_grid:CombatGrid
var grid_cursor:GridCursor

var player:Dictionary = {}
var enemies:Array[Dictionary] = []

var grid_state:Dictionary = {
	"blocked_cells": Array([], TYPE_VECTOR2I, "", null),
	"obstacle_cells": Array([], TYPE_VECTOR2I, "", null),
	"occupied_cells": Array([], TYPE_VECTOR2I, "", null),
	"immovable_cells": Array([], TYPE_VECTOR2I, "", null),
	"grid_size": 8,
	"player_last_move_dir": Vector2i.RIGHT,
}

var _input_enabled:bool = false

var _ability_strike:AbilityStrike
var _ability_dash:AbilityDash
var _ability_heal:AbilityHeal
var _ability_shove:AbilityShove
var _ability_slam:AbilitySlam

var _camera:Camera2D
var _camera_prev_zoom:Vector2 = Vector2.ONE
var _camera_prev_position:Vector2 = Vector2.ZERO
var _camera_prev_follow:bool = true

var _turn_snapshot:Dictionary = {}
var _enemy_registry:Dictionary = {}

func _ready() -> void:
	_setup_subsystems()

func start_combat(player_node:Node2D, enemy_nodes:Array[Node], combat_grid_node:Node, combat_config:Dictionary = {}) -> void:
	combat_grid = combat_grid_node as CombatGrid
	if combat_grid == null:
		return

	grid_cursor = combat_grid.get_node_or_null("GridCursor") as GridCursor
	grid_state["grid_size"] = int(combat_config.get("grid_size", mini(combat_grid.grid_size.x, combat_grid.grid_size.y)))

	var obstacle_cells:Array[Vector2i] = []
	for cell in combat_config.get("obstacles", []):
		obstacle_cells.push_back(cell)
	grid_state["obstacle_cells"] = obstacle_cells
	grid_state["blocked_cells"] = obstacle_cells.duplicate()

	player = _build_player_data(player_node)
	enemies = _build_enemy_data(enemy_nodes)
	_enemy_registry.clear()
	for enemy_data in enemies:
		_enemy_registry[enemy_data.get("enemy_id", -1)] = enemy_data

	_bind_player_subsystems()
	_sync_world_positions_to_grid()
	# Debug: verify grid positions after sync match contract expectations
	push_warning("[combat_manager] player grid_pos=%s" % str(player.get("combat_stats").grid_pos))
	for i in range(enemies.size()):
		var e:Dictionary = enemies[i]
		push_warning("[combat_manager] enemy[%d] actor_id=%d pos=%s name=%s" % [
			i, int(e.get("contract_actor_id", 0)),
			str(e.get("combat_stats").grid_pos),
			str(e.get("node").name) if e.get("node") != null else "?"
		])
	_refresh_grid_state()
	_turn_reset_abilities()
	_clear_grid_overlay()
	_focus_camera_to_grid()
	turn_manager.start_combat()
	combat_started.emit()

## Sync grid positions from on-chain actor data (contract = source of truth).
## Called by DojoIntegration after enter_room TX is indexed by Torii.
## chain_actors: Dictionary keyed by actor_id (int), values are model Dicts
## with at minimum "pos_x", "pos_y", "archetype", "alive".
func sync_positions_from_chain(chain_actors: Dictionary) -> void:
	# Sync player (actor_id 0)
	if chain_actors.has(0):
		var chain_player: Dictionary = chain_actors[0]
		var player_stats: CombatStatsResource = player.get("combat_stats", null)
		if player_stats != null:
			player_stats.grid_pos = Vector2i(int(chain_player.get("pos_x", 0)), int(chain_player.get("pos_y", 0)))
			var player_node: Node2D = player.get("node") as Node2D
			if player_node != null && combat_grid != null:
				player_node.global_position = combat_grid.grid_to_world(player_stats.grid_pos)

	# Sync player HP from chain
	if chain_actors.has(0):
		var chain_player: Dictionary = chain_actors[0]
		var player_health: HealthResource = player.get("health", null)
		if player_health != null && chain_player.has("hp"):
			player_health.hp = float(int(chain_player.get("hp", player_health.hp)))
			player_health.max_hp = float(int(chain_player.get("max_hp", player_health.max_hp)))

	# Sync enemies (actor_id 1+): position, HP, alive status
	for enemy_data in enemies:
		var actor_id: int = int(enemy_data.get("contract_actor_id", -1))
		if actor_id < 0 || !chain_actors.has(actor_id):
			continue
		var chain_enemy: Dictionary = chain_actors[actor_id]
		var stats: CombatStatsResource = enemy_data.get("combat_stats", null)
		if stats == null:
			continue
		stats.grid_pos = Vector2i(int(chain_enemy.get("pos_x", 0)), int(chain_enemy.get("pos_y", 0)))
		var enemy_node: Node2D = enemy_data.get("node", null)
		if enemy_node != null && combat_grid != null:
			enemy_node.global_position = combat_grid.grid_to_world(stats.grid_pos)
		# Sync HP and alive status
		var enemy_health: HealthResource = enemy_data.get("health", null)
		if enemy_health != null && chain_enemy.has("hp"):
			enemy_health.hp = float(int(chain_enemy.get("hp", enemy_health.hp)))
		# Hide dead enemies
		var alive: bool = bool(int(chain_enemy.get("alive", 1)))
		if !alive && enemy_node != null:
			enemy_node.visible = false
			if enemy_health != null:
				enemy_health.hp = 0.0

	push_warning("[combat_manager] synced positions from chain — player=%s enemies=%s" % [
		str(player.get("combat_stats").grid_pos),
		str(enemies.map(func(e: Dictionary) -> String: return "id%d@%s" % [int(e.get("contract_actor_id", 0)), str(e.get("combat_stats").grid_pos)]))
	])
	_refresh_grid_state()
	# Reset the turn: save new snapshot from chain-corrected state and clear recorded actions.
	_save_turn_snapshot()
	DojoIntegration._turn_actions.clear()
	grid_movement.set_blocked_cells(grid_state.get("blocked_cells", Array([], TYPE_VECTOR2I, "", null)))
	grid_movement.set_occupied_cells(_occupied_cells_without_player())
	grid_movement.refresh_reachable()
	_clear_grid_overlay()
	_draw_active_telegraphs()

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
	ability_manager.abilities = [
		ABILITY_STRIKE.duplicate(),
		ABILITY_DASH.duplicate(),
		ABILITY_HEAL.duplicate(),
		ABILITY_SHOVE.duplicate(),
		ABILITY_SLAM.duplicate(),
	]
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

	bump_system = BumpSystem.new()
	add_child(bump_system)
	bump_system.collision_damage_dealt.connect(_on_bump_collision_damage_dealt)

	energy_orb_system = EnergyOrbSystem.new()
	add_child(energy_orb_system)

	_ability_strike = STRIKE_EFFECT_SCRIPT.new()
	add_child(_ability_strike)
	_ability_dash = DASH_EFFECT_SCRIPT.new()
	add_child(_ability_dash)
	_ability_heal = HEAL_EFFECT_SCRIPT.new()
	add_child(_ability_heal)
	_ability_shove = SHOVE_EFFECT_SCRIPT.new()
	add_child(_ability_shove)
	_ability_slam = SLAM_EFFECT_SCRIPT.new()
	add_child(_ability_slam)

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
	stamina.max_value = 80
	stamina.value = 80

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
	for i in range(enemy_nodes.size()):
		var enemy_node:Node = enemy_nodes[i]
		if !(enemy_node is Node2D):
			continue

		var combat_stats:CombatStatsResource = CombatStatsResource.new()
		var health:HealthResource = HealthResource.new()
		var ai:EnemyGridAI = _assign_enemy_ai(enemy_node as Node2D, combat_stats, health)

		# contract_actor_id matches the contract's ENEMY_ACTOR_ID_N (1-indexed).
		# Order in ROOM_CONFIGS enemies array == contract spawn order.
		result.push_back({
			"node": enemy_node,
			"combat_stats": combat_stats,
			"health": health,
			"ai": ai,
			"enemy_id": enemy_node.get_instance_id(),
			"contract_actor_id": i + 1,
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
		CombatEnums.Archetype.HEAVY:
			health.max_hp = 70.0
			health.hp = 70.0
			combat_stats.is_immovable = true
			return HEAVY_AI_SCRIPT.new()
		CombatEnums.Archetype.PULLER:
			health.max_hp = 35.0
			health.hp = 35.0
			return PULLER_AI_SCRIPT.new()
		_:
			health.max_hp = 50.0
			health.hp = 50.0
			return BRUTE_AI_SCRIPT.new()

func _infer_enemy_archetype(node_name:String) -> int:
	var lowered:String = node_name.to_lower()
	if lowered.contains("heavy"):
		return CombatEnums.Archetype.HEAVY
	if lowered.contains("puller"):
		return CombatEnums.Archetype.PULLER
	if lowered.contains("caster"):
		return CombatEnums.Archetype.CASTER
	if lowered.contains("flanker"):
		return CombatEnums.Archetype.FLANKER
	return CombatEnums.Archetype.BRUTE

func confirm_turn() -> void:
	if turn_manager == null:
		return
	if turn_manager.phase != CombatEnums.Phase.PLAYER_TURN:
		return
	DojoIntegration.submit_turn()
	turn_manager.end_player_turn()

func reset_turn() -> void:
	if turn_manager == null || turn_manager.phase != CombatEnums.Phase.PLAYER_TURN:
		return
	if _turn_snapshot.is_empty():
		return

	if ability_manager.get_selected() != null:
		ability_manager.cancel_selection()

	var player_stats:CombatStatsResource = player.get("combat_stats", null)
	if player_stats != null:
		player_stats.grid_pos = _turn_snapshot.get("grid_pos", player_stats.grid_pos)
		(player.get("node") as Node2D).global_position = combat_grid.grid_to_world(player_stats.grid_pos)

	var stamina:StaminaResource = player.get("stamina", null)
	if stamina != null:
		stamina.value = int(_turn_snapshot.get("stamina_value", stamina.max_value))

	var saved_cooldowns:Array = _turn_snapshot.get("cooldowns", [])
	for i in range(mini(saved_cooldowns.size(), ability_manager.abilities.size())):
		ability_manager.abilities[i].current_cooldown = int(saved_cooldowns[i])

	var saved_enemies:Array = _turn_snapshot.get("enemies", [])
	var restored_enemies:Array[Dictionary] = []
	for saved_enemy_variant in saved_enemies:
		if !(saved_enemy_variant is Dictionary):
			continue
		var saved_enemy:Dictionary = saved_enemy_variant
		var enemy_id:Variant = saved_enemy.get("enemy_id", -1)
		var enemy_data:Dictionary = _enemy_registry.get(enemy_id, {})
		if enemy_data.is_empty():
			continue

		var enemy_health:HealthResource = enemy_data.get("health", null)
		if enemy_health != null:
			enemy_health.hp = float(saved_enemy.get("hp", enemy_health.max_hp))

		var enemy_stats:CombatStatsResource = enemy_data.get("combat_stats", null)
		if enemy_stats != null:
			enemy_stats.grid_pos = saved_enemy.get("grid_pos", enemy_stats.grid_pos)

		var enemy_node:Node2D = enemy_data.get("node", null)
		if enemy_node != null:
			enemy_node.global_position = combat_grid.grid_to_world(saved_enemy.get("grid_pos", Vector2i.ZERO))
			enemy_node.visible = bool(saved_enemy.get("visible", true))

		enemy_data["death_processed"] = bool(saved_enemy.get("death_processed", false))
		if enemy_health != null && enemy_health.hp > 0.0:
			restored_enemies.push_back(enemy_data)

	enemies = restored_enemies

	_refresh_grid_state()
	grid_movement.set_blocked_cells(grid_state.get("blocked_cells", Array([], TYPE_VECTOR2I, "", null)))
	grid_movement.set_occupied_cells(_occupied_cells_without_player())
	grid_movement.refresh_reachable()
	_clear_grid_overlay()
	_draw_active_telegraphs()

func _save_turn_snapshot() -> void:
	var player_stats:CombatStatsResource = player.get("combat_stats", null)
	var stamina:StaminaResource = player.get("stamina", null)
	var cooldowns:Array = []
	var enemy_snapshots:Array[Dictionary] = []
	for ability in ability_manager.abilities:
		cooldowns.push_back(ability.current_cooldown)

	for enemy_data in enemies:
		var enemy_health:HealthResource = enemy_data.get("health", null)
		var enemy_stats:CombatStatsResource = enemy_data.get("combat_stats", null)
		var enemy_node:Node2D = enemy_data.get("node", null)
		if enemy_health == null || enemy_stats == null:
			continue
		enemy_snapshots.push_back({
			"enemy_id": enemy_data.get("enemy_id", -1),
			"hp": enemy_health.hp,
			"grid_pos": enemy_stats.grid_pos,
			"visible": enemy_node.visible if enemy_node != null else true,
			"death_processed": bool(enemy_data.get("death_processed", false)),
		})

	_turn_snapshot = {
		"grid_pos": player_stats.grid_pos if player_stats != null else Vector2i.ZERO,
		"stamina_value": stamina.value if stamina != null else 80,
		"cooldowns": cooldowns,
		"enemies": enemy_snapshots,
	}

func _on_player_turn_started() -> void:
	if ability_manager.get_selected() != null:
		ability_manager.cancel_selection()

	var stamina:StaminaResource = player.get("stamina", null)
	if stamina != null:
		stamina.refill()

	_refresh_grid_state()

	_save_turn_snapshot()

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
		if int(telegraph_data.get("telegraph_type", CombatEnums.TelegraphType.DAMAGE)) == CombatEnums.TelegraphType.PULL:
			_apply_pull_telegraph(telegraph_data)

	for telegraph_data in resolved:
		if int(telegraph_data.get("telegraph_type", CombatEnums.TelegraphType.DAMAGE)) == CombatEnums.TelegraphType.DAMAGE:
			_apply_telegraph_damage(telegraph_data)

	_process_enemy_deaths()
	ability_manager.tick_cooldowns()
	energy_orb_system.tick()
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
		CombatEnums.AbilityID.HEAL:
			did_execute = _ability_heal.execute(player.get("health", null))
			if did_execute:
				_spawn_tile_vfx(player.get("combat_stats").grid_pos, Color(0.2, 0.95, 0.4, 0.7), 0.25)
		CombatEnums.AbilityID.SHOVE:
			var shove_result:Dictionary = _ability_shove.execute(target_data.get("target_cell", Vector2i(-1, -1)), actors_on_grid)
			did_execute = bool(shove_result.get("pushed", false)) || float(shove_result.get("total_damage", 0.0)) > 0.0
			if did_execute:
				_spawn_tile_vfx(shove_result.get("final_pos", target_data.get("target_cell", Vector2i.ZERO)), Color(0.95, 0.75, 0.25, 0.75), 0.22)
		CombatEnums.AbilityID.SLAM:
			var slam_results:Array[Dictionary] = _ability_slam.execute(player.get("combat_stats").grid_pos, actors_on_grid)
			did_execute = !slam_results.is_empty()
			for slam_result in slam_results:
				_spawn_tile_vfx(slam_result.get("final_pos", slam_result.get("enemy_pos", Vector2i.ZERO)), Color(1.0, 0.5, 0.1, 0.72), 0.2)

	if !did_execute:
		return

	var dojo_payload: Dictionary = _build_dojo_ability_payload(ability, target_data)
	var _player_pos:Vector2i = player.get("combat_stats").grid_pos
	var _target_cell:Vector2i = target_data.get("target_cell", Vector2i(-1, -1))
	push_warning("[combat_manager] ability=%d player_pos=%s target_cell=%s dojo(mode=%d a=%d b=%d)" % [
		int(ability.ability_id), str(_player_pos), str(_target_cell),
		int(dojo_payload.get("mode", 0)), int(dojo_payload.get("a", 0)), int(dojo_payload.get("b", 0))
	])
	DojoIntegration.record_ability(
		int(ability.ability_id),
		int(dojo_payload.get("mode", 0)),
		int(dojo_payload.get("a", 0)),
		int(dojo_payload.get("b", 0))
	)

	_sync_enemy_positions_from_data()
	_process_enemy_deaths()
	_refresh_grid_state()
	grid_movement.set_occupied_cells(_occupied_cells_without_player())
	grid_movement.refresh_reachable()
	_draw_active_telegraphs()
	_check_win_lose()

func _on_move_completed(from:Vector2i, to:Vector2i) -> void:
	if from == to:
		return
	grid_state["player_last_move_dir"] = _direction_to(from, to)
	push_warning("[combat_manager] move from=%s to=%s grid_pos=%s" % [str(from), str(to), str(player.get("combat_stats").grid_pos)])
	DojoIntegration.record_move(to.x, to.y)

	var collided_enemy:Dictionary = _find_enemy_at_cell(to)
	if !collided_enemy.is_empty() && bump_system != null:
		var bump_result:Dictionary = bump_system.compute_bump(from, to, _direction_to(from, to), grid_state)
		_apply_bump_result(collided_enemy, bump_result)

	var orb_bonus:int = energy_orb_system.check_pickup(player.get("combat_stats").grid_pos)
	if orb_bonus > 0:
		var stamina:StaminaResource = player.get("stamina", null)
		if stamina != null:
			stamina.add_bonus(orb_bonus)

	_process_enemy_deaths()
	_refresh_grid_state()
	grid_movement.set_occupied_cells(_occupied_cells_without_player())
	grid_movement.refresh_reachable()
	_draw_active_telegraphs()
	_check_win_lose()

func _on_telegraph_added(data:Dictionary) -> void:
	var cells:Array[Vector2i] = data.get("cells", Array([], TYPE_VECTOR2I, "", null))
	combat_grid.highlight_cells(cells, CombatGrid.STATE_DANGER)

func _on_bump_collision_damage_dealt(target_pos:Vector2i, damage:int) -> void:
	for enemy_data in enemies:
		if enemy_data.get("combat_stats").grid_pos == target_pos:
			_apply_damage_to_actor(enemy_data, float(damage))
			break

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
	var immovable:Array[Vector2i] = []
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
		var stats:CombatStatsResource = enemy_data.get("combat_stats", null)
		if stats != null:
			occupied.append(stats.grid_pos)
			if stats.is_immovable:
				immovable.append(stats.grid_pos)
	enemies = alive_enemies

	grid_state["occupied_cells"] = occupied
	grid_state["immovable_cells"] = immovable
	var obstacle_cells:Array[Vector2i] = grid_state.get("obstacle_cells", Array([], TYPE_VECTOR2I, "", null))
	grid_state["blocked_cells"] = obstacle_cells.duplicate()

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
		"grid_size": int(grid_state.get("grid_size", 8)),
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

func _apply_pull_telegraph(telegraph_data:Dictionary) -> void:
	var pull_source:Vector2i = telegraph_data.get("pull_source", Vector2i.ZERO)
	var pull_distance:int = maxi(0, int(telegraph_data.get("pull_distance", 0)))
	if pull_distance <= 0:
		return

	var player_stats:CombatStatsResource = player.get("combat_stats", null)
	if player_stats == null:
		return

	var current:Vector2i = player_stats.grid_pos
	var obstacle_lookup:Dictionary = _cells_to_lookup(grid_state.get("blocked_cells", Array([], TYPE_VECTOR2I, "", null)))
	var occupied_lookup:Dictionary = {}
	for enemy_data in enemies:
		var enemy_stats:CombatStatsResource = enemy_data.get("combat_stats", null)
		if enemy_stats != null:
			occupied_lookup[enemy_stats.grid_pos] = true

	for _step in range(pull_distance):
		if current == pull_source:
			break
		var step_dir:Vector2i = _step_toward(current, pull_source)
		if step_dir == Vector2i.ZERO:
			break
		var next_cell:Vector2i = current + step_dir
		if !GridUtils.is_in_bounds(next_cell, int(grid_state.get("grid_size", 8))):
			break
		if obstacle_lookup.has(next_cell) || occupied_lookup.has(next_cell):
			break
		current = next_cell

	if current != player_stats.grid_pos:
		player_stats.grid_pos = current
		(player.get("node") as Node2D).global_position = combat_grid.grid_to_world(current)

func _apply_bump_result(collided_enemy:Dictionary, bump_result:Dictionary) -> void:
	if bump_result.is_empty():
		return

	var player_stats:CombatStatsResource = player.get("combat_stats", null)
	if player_stats != null:
		var player_final:Vector2i = bump_result.get("player_final_pos", player_stats.grid_pos)
		player_stats.grid_pos = player_final
		(player.get("node") as Node2D).global_position = combat_grid.grid_to_world(player_final)

	var enemy_stats:CombatStatsResource = collided_enemy.get("combat_stats", null)
	var enemy_node:Node2D = collided_enemy.get("node", null)
	if enemy_stats != null:
		enemy_stats.grid_pos = bump_result.get("enemy_final_pos", enemy_stats.grid_pos)
	if enemy_node != null && enemy_stats != null:
		enemy_node.global_position = combat_grid.grid_to_world(enemy_stats.grid_pos)

func _apply_damage_to_actor(actor_data:Dictionary, amount:float) -> void:
	var health:HealthResource = actor_data.get("health", null)
	if health == null:
		return

	health.add_hp(-amount)

func _process_enemy_deaths() -> void:
	for enemy_data in enemies:
		var health:HealthResource = enemy_data.get("health", null)
		if health == null || health.hp > 0.0:
			continue
		if bool(enemy_data.get("death_processed", false)):
			continue
		enemy_data["death_processed"] = true
		_on_enemy_killed(enemy_data)

func _on_enemy_killed(enemy_data:Dictionary) -> void:
	var stamina:StaminaResource = player.get("stamina", null)
	if stamina != null:
		stamina.add_bonus(10)

	var enemy_stats:CombatStatsResource = enemy_data.get("combat_stats", null)
	if enemy_stats != null:
		energy_orb_system.spawn_orb(enemy_stats.grid_pos)

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

func _find_enemy_at_cell(cell:Vector2i) -> Dictionary:
	for enemy_data in enemies:
		var stats:CombatStatsResource = enemy_data.get("combat_stats", null)
		if stats != null && stats.grid_pos == cell:
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

func _step_toward(from_cell:Vector2i, target_cell:Vector2i) -> Vector2i:
	var delta:Vector2i = target_cell - from_cell
	if delta == Vector2i.ZERO:
		return Vector2i.ZERO
	if absi(delta.x) >= absi(delta.y):
		return Vector2i(signi(delta.x), 0)
	return Vector2i(0, signi(delta.y))

func _cells_to_lookup(cells:Array[Vector2i]) -> Dictionary:
	var lookup:Dictionary = {}
	for cell in cells:
		lookup[cell] = true
	return lookup

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

# Contract target_mode constants (must match phase.cairo)
const DOJO_TARGET_SINGLE:int = 0
const DOJO_TARGET_DIRECTIONAL:int = 1
const DOJO_TARGET_SELF:int = 3

# Contract direction constants (must match actions.cairo)
const DOJO_DIR_NORTH:int = 0
const DOJO_DIR_EAST:int = 1
const DOJO_DIR_SOUTH:int = 2
const DOJO_DIR_WEST:int = 3

func _build_dojo_ability_payload(ability: AbilityResource, target_data: Dictionary) -> Dictionary:
	var aid:int = int(ability.ability_id)
	match aid:
		CombatEnums.AbilityID.STRIKE, CombatEnums.AbilityID.SHOVE:
			# Contract expects: mode=TARGET_SINGLE, a=actor_id, b=0
			var target_cell:Vector2i = target_data.get("target_cell", Vector2i(-1, -1))
			var actor_id:int = _contract_actor_id_at(target_cell)
			return {"mode": DOJO_TARGET_SINGLE, "a": actor_id, "b": 0}
		CombatEnums.AbilityID.DASH:
			# Contract expects: mode=TARGET_DIRECTIONAL, a=direction(0-3), b=0
			var dir_vec:Vector2i = target_data.get("target_direction", Vector2i.RIGHT)
			return {"mode": DOJO_TARGET_DIRECTIONAL, "a": _vec_to_dojo_direction(dir_vec), "b": 0}
		CombatEnums.AbilityID.HEAL, CombatEnums.AbilityID.SLAM:
			# Contract expects: mode=TARGET_SELF, a=0, b=0
			return {"mode": DOJO_TARGET_SELF, "a": 0, "b": 0}
		_:
			return {"mode": 0, "a": 0, "b": 0}

## Find the contract actor_id (1-5) of the enemy at a grid cell, or 0 if none.
func _contract_actor_id_at(cell:Vector2i) -> int:
	for enemy_data in enemies:
		var stats:CombatStatsResource = enemy_data.get("combat_stats", null)
		if stats != null && stats.grid_pos == cell:
			return int(enemy_data.get("contract_actor_id", 0))
	return 0

## Convert a Vector2i unit direction to the contract's direction enum (0-3).
func _vec_to_dojo_direction(dir:Vector2i) -> int:
	if dir.x > 0:
		return DOJO_DIR_EAST
	if dir.x < 0:
		return DOJO_DIR_WEST
	if dir.y < 0:
		return DOJO_DIR_NORTH
	return DOJO_DIR_SOUTH

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

	var max_index:int = int(grid_state.get("grid_size", 8)) - 1
	var corners:Array[Vector2] = [
		combat_grid.grid_to_world(Vector2i(0, 0)),
		combat_grid.grid_to_world(Vector2i(max_index, 0)),
		combat_grid.grid_to_world(Vector2i(0, max_index)),
		combat_grid.grid_to_world(Vector2i(max_index, max_index)),
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
