extends Node2D

signal return_to_menu

enum ArenaState { FORK, PRE_FIGHT, FIGHTING, CLEARED, COMPLETED, FAILED }

const ZONE_NAMES := ["Entrance", "Left Cavern", "Right Passage", "Deep Hall", "Final Chamber"]
const CombatControllerScript = preload("res://scripts/combat_controller.gd")
const ArenaUIScript = preload("res://scripts/arena_ui.gd")
const RoomControllerScript = preload("res://scripts/room_controller.gd")
const RoomConfigScript = preload("res://scripts/room_config.gd")

# Zone graph (mirrors contracts/src/constants.cairo)
const ZONE_CHILDREN := {0: [1, 2], 1: [3], 2: [3], 3: [4], 4: []}
const ZONE_MOB_COUNT := {0: 0, 1: 1, 2: 1, 3: 2, 4: 4}

# --- Node references ---
@onready var minimap_draw: Control = %MinimapDraw
@onready var hp_bar: ProgressBar = %HPBar
@onready var hp_label: Label = %HPLabel
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var stamina_label: Label = %StaminaLabel
@onready var zone_label: Label = %ZoneLabel
@onready var bottom_bar: PanelContainer = $UILayer/UIRoot/BottomBar
@onready var target_name: Label = %TargetName
@onready var target_hp_bar: ProgressBar = %TargetHPBar
@onready var target_hp_label: Label = %TargetHPLabel

# Door panel
@onready var door_panel: PanelContainer = %DoorPanel
@onready var door_title: Label = %DoorTitle
@onready var left_door_button: Button = %LeftDoorButton
@onready var right_door_button: Button = %RightDoorButton
@onready var continue_button: Button = %ContinueButton

@onready var turn_info: Label = %TurnInfo

# Start fight
@onready var start_fight_button: Button = %StartFightButton

# Result panel
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_title: Label = %ResultTitle
@onready var stats_label: Label = %StatsLabel

var current_state: ArenaState = ArenaState.FORK
var _auto_advancing := false
var combat_ctrl = null
var arena_ui = null
var room_ctrl = null
var _player_controller = null

@onready var dungeon_view: Node2D = $DungeonWorld
@onready var targeting_system: Node2D = $TargetingSystem

func _ready() -> void:
	game_state.character_updated.connect(_on_state_changed)
	game_state.dungeon_updated.connect(_on_state_changed)
	game_state.fight_updated.connect(_on_state_changed)
	dojo_bridge.tx_submitted.connect(_on_tx_submitted)
	dojo_bridge.tx_failed.connect(_on_tx_failed)

	var camera_rig := get_node_or_null("GameCamera")
	var player_anchor := get_node_or_null("DungeonWorld/Entities/PlayerAnchor")
	if camera_rig and camera_rig.has_method("set_follow_target") and player_anchor:
		camera_rig.set_follow_target(player_anchor)
	_player_controller = player_anchor
	combat_ctrl = CombatControllerScript.new()
	add_child(combat_ctrl)
	combat_ctrl.dungeon_view = dungeon_view
	combat_ctrl.targeting_system = targeting_system
	combat_ctrl.camera = camera_rig
	combat_ctrl.stamina_bar = stamina_bar
	combat_ctrl.stamina_label = stamina_label
	combat_ctrl.turn_info = turn_info
	combat_ctrl.is_fighting_fn = func() -> bool: return current_state == ArenaState.FIGHTING

	arena_ui = ArenaUIScript.new()
	arena_ui.name = "ArenaUI"
	add_child(arena_ui)
	arena_ui.combat_ctrl = combat_ctrl
	arena_ui.dungeon_view = dungeon_view
	arena_ui.targeting_system = targeting_system
	arena_ui.hp_bar = hp_bar
	arena_ui.hp_label = hp_label
	arena_ui.stamina_bar = stamina_bar
	arena_ui.stamina_label = stamina_label
	arena_ui.target_name = target_name
	arena_ui.target_hp_bar = target_hp_bar
	arena_ui.target_hp_label = target_hp_label
	arena_ui.stats_label = stats_label
	arena_ui.turn_info = turn_info
	arena_ui.bottom_bar = bottom_bar
	arena_ui.minimap_draw = minimap_draw
	arena_ui.build_ui(get_node("UILayer/UIRoot") as Control)
	arena_ui.command_pressed.connect(_on_ui_command)

	combat_ctrl.request_commands_enabled.connect(arena_ui.set_commands_enabled)
	combat_ctrl.request_turn_state.connect(arena_ui.set_turn_state)
	combat_ctrl.request_stamina_update.connect(func() -> void: arena_ui.update_command_states())
	combat_ctrl.request_status_icons_update.connect(func() -> void: arena_ui.update_status_icons())
	combat_ctrl.request_turn_order_update.connect(func() -> void: arena_ui.update_turn_order())
	if combat_ctrl.has_signal("request_refresh"):
		combat_ctrl.request_refresh.connect(func() -> void: _refresh())
	combat_ctrl.turn_status_label = arena_ui.turn_status_label

	# Room system initialization
	room_ctrl = RoomControllerScript.new()
	room_ctrl.name = "RoomController"
	add_child(room_ctrl)

	var initial_zone := int(game_state.character.get("current_zone", 0))
	room_manager.visual_zone = initial_zone
	room_manager.contract_zone = initial_zone

	var config: Dictionary = RoomConfigScript.get_config(initial_zone)
	room_ctrl.configure(config)
	if _player_controller != null:
		room_ctrl.place_player(_player_controller)

	room_ctrl.door_interacted.connect(_on_room_door_interacted)
	room_ctrl.battle_triggered.connect(_on_room_battle_triggered)

	room_ctrl.spawn_doors()
	if config.get("mob_count", 0) > 0 and not _is_zone_cleared(initial_zone):
		_clear_room_battle_trigger()
		room_ctrl.create_battle_trigger()
	set_process(true)

	_refresh()
	_sync_room_state_from_arena(current_state)
	_force_initial_visuals()
	audio_manager.play_music("game_loop_1")
	# Pull entities AFTER all controllers are initialized to prevent
	# _on_state_changed firing before combat_ctrl/arena_ui exist
	dojo_bridge.pull_entities_snapshot()
	dojo_bridge._schedule_entity_poll()

func _exit_tree() -> void:
	for timer in _poll_timers:
		if is_instance_valid(timer):
			timer.queue_free()
	_poll_timers.clear()
	if game_state.character_updated.is_connected(_on_state_changed):
		game_state.character_updated.disconnect(_on_state_changed)
	if game_state.dungeon_updated.is_connected(_on_state_changed):
		game_state.dungeon_updated.disconnect(_on_state_changed)
	if game_state.fight_updated.is_connected(_on_state_changed):
		game_state.fight_updated.disconnect(_on_state_changed)
	if dojo_bridge.tx_submitted.is_connected(_on_tx_submitted):
		dojo_bridge.tx_submitted.disconnect(_on_tx_submitted)
	if dojo_bridge.tx_failed.is_connected(_on_tx_failed):
		dojo_bridge.tx_failed.disconnect(_on_tx_failed)

# --- State machine ---

func _determine_state() -> ArenaState:
	var dungeon := game_state.dungeon
	var character := game_state.character
	var fight := game_state.fight

	if bool(dungeon.get("completed", false)):
		return ArenaState.COMPLETED
	if bool(dungeon.get("failed", false)):
		return ArenaState.FAILED
	# Death detection takes priority over fight state
	if not character.is_empty() and int(character.get("health", 0)) <= 0:
		return ArenaState.FAILED
	if bool(fight.get("active", false)):
		return ArenaState.FIGHTING

	var zone := int(character.get("current_zone", 0))
	var mob_count: int = ZONE_MOB_COUNT.get(zone, 0)
	var zone_cleared := _is_zone_cleared(zone)

	if mob_count > 0 and not zone_cleared:
		return ArenaState.PRE_FIGHT
	if _is_fork(zone) and not zone_cleared:
		return ArenaState.FORK

	return ArenaState.CLEARED

func _refresh(_data: Dictionary = {}) -> void:
	if combat_ctrl == null or arena_ui == null:
		return
	var prev_state := current_state
	current_state = _determine_state()
	var zone := int(game_state.character.get("current_zone", 0))

	# SFX on state transitions
	if current_state != prev_state:
		match current_state:
			ArenaState.CLEARED:
				audio_manager.play_sfx("beast_win")
			ArenaState.COMPLETED:
				audio_manager.play_sfx("victory")
			ArenaState.FAILED:
				audio_manager.play_sfx("beast_lose")
			ArenaState.PRE_FIGHT:
				audio_manager.play_sfx("discovery")

	# Room state machine sync + movement/camera control on state transitions
	if current_state != prev_state:
		_sync_room_state_from_arena(current_state)
		if _player_controller:
			match current_state:
				ArenaState.FORK, ArenaState.PRE_FIGHT, ArenaState.CLEARED:
					if _player_controller.has_method("enable_movement"):
						_player_controller.enable_movement()
				ArenaState.FIGHTING, ArenaState.COMPLETED, ArenaState.FAILED:
					if _player_controller.has_method("disable_movement"):
						_player_controller.disable_movement()

		var camera_rig := get_node_or_null("GameCamera")
		if camera_rig:
			match current_state:
				ArenaState.FIGHTING:
					if camera_rig.has_method("set_fixed_mode"):
						var battle_center: Vector2 = Vector2.ZERO
						if _player_controller != null:
							battle_center = _player_controller.position
						camera_rig.set_fixed_mode(battle_center, 0.5)
					if camera_rig.has_method("combat_zoom_in"):
						camera_rig.combat_zoom_in()
				ArenaState.CLEARED, ArenaState.FORK, ArenaState.PRE_FIGHT:
					if camera_rig.has_method("set_follow_mode") and _player_controller:
						camera_rig.set_follow_mode(_player_controller)
					if camera_rig.has_method("combat_zoom_out"):
						camera_rig.combat_zoom_out()

	# Visibility
	door_panel.visible = (current_state == ArenaState.FORK or current_state == ArenaState.CLEARED)
	var in_combat := (current_state == ArenaState.FIGHTING)
	var command_panel: PanelContainer = arena_ui.get_command_panel()
	if in_combat and (command_panel == null or not command_panel.visible):
		arena_ui.show_combat_hud()
	elif not in_combat and command_panel != null and command_panel.visible:
		arena_ui.hide_combat_hud()
	arena_ui.set_target_visible(in_combat)
	start_fight_button.visible = (current_state == ArenaState.PRE_FIGHT)
	result_panel.visible = (current_state == ArenaState.COMPLETED or current_state == ArenaState.FAILED)

	# Zone label
	var zone_name: String = ZONE_NAMES[zone] if zone < ZONE_NAMES.size() else "Zone %d" % zone
	zone_label.text = "Zone %d — %s" % [zone, zone_name]

	# Player bars
	arena_ui.update_player_bars(in_combat)

	# Minimap
	minimap_draw.queue_redraw()

	# State-specific UI
	match current_state:
		ArenaState.FORK:
			door_title.text = "Choose your path"
			left_door_button.visible = true
			right_door_button.visible = true
			continue_button.visible = false
		ArenaState.CLEARED:
			door_title.text = "Zone cleared!"
			var children: Array = ZONE_CHILDREN.get(zone, [])
			if room_ctrl:
				room_ctrl.show_exit_doors()
			if children.size() == 0:
				door_title.text = "No exit..."
				continue_button.visible = false
			elif children.size() == 1:
				# Single exit — contract already auto-advanced, just poll for update
				continue_button.visible = false
				left_door_button.visible = false
				right_door_button.visible = false
				if not _auto_advancing:
					_auto_advance_single_exit()
			else:
				left_door_button.visible = true
				right_door_button.visible = true
				continue_button.visible = false
		ArenaState.PRE_FIGHT:
			start_fight_button.text = "Begin Combat"
			start_fight_button.disabled = false
			if room_ctrl:
				room_ctrl.enable_battle_trigger()
		ArenaState.FIGHTING:
			arena_ui.update_target_bar(_zone_mob_name(int(game_state.character.get("current_zone", 0))))
			arena_ui.update_mob_hp_bars()
			combat_ctrl.update_stamina_display()
			arena_ui.update_command_states()
		ArenaState.COMPLETED:
			result_title.text = "Dungeon Cleared!"
			arena_ui.update_stats()
		ArenaState.FAILED:
			result_title.text = "You Died"
			arena_ui.update_stats()

	# Auto-transitions for fighting state
	if current_state == ArenaState.FIGHTING and not combat_ctrl.auto_finishing:
		if bool(game_state.fight.get("active", false)):
			if combat_ctrl.first_alive_mob() < 0:
				combat_ctrl.auto_finish("All mobs defeated!")
			elif int(game_state.character.get("stamina", 0)) < combat_ctrl.AA_COST:
				combat_ctrl.auto_finish("Out of stamina — ending turn...")

	# Targeting system activation
	if current_state == ArenaState.FIGHTING and targeting_system != null:
		if not targeting_system.active:
			var mob_nodes: Array = []
			for child in dungeon_view.entities.get_children():
				if child.name == "PlayerAnchor":
					continue
				if child is Node2D:
					for sub in child.get_children():
						if sub is AnimatedSprite2D:
							mob_nodes.append(sub)
							break
			targeting_system.activate(mob_nodes)
	elif targeting_system != null and targeting_system.active:
		targeting_system.deactivate()

	# 3D visual sync
	if current_state != prev_state and dungeon_view != null and dungeon_view.has_method("on_state_changed"):
		dungeon_view.on_state_changed(current_state, zone, prev_state)

	arena_ui.update_turn_order()

func _force_initial_visuals() -> void:
	if dungeon_view != null and dungeon_view.has_method("on_state_changed"):
		var zone := int(game_state.character.get("current_zone", 0))
		dungeon_view.on_state_changed(current_state, zone, -1)

func _zone_mob_name(zone_id: int) -> String:
	match zone_id:
		1: return "Ember Fiend"
		2: return "Aether Wraith"
		3: return "Sunken Horror"
		4: return "Crystal Guardian"
		_: return "Creature"

# --- Actions ---

func _on_left_door_pressed() -> void:
	audio_manager.play_sfx("click")
	left_door_button.disabled = true
	right_door_button.disabled = true
	dojo_bridge.choose(game_state.get_game_id(), dojo_bridge.DIRECTION_LEFT)

func _on_right_door_pressed() -> void:
	audio_manager.play_sfx("click")
	left_door_button.disabled = true
	right_door_button.disabled = true
	dojo_bridge.choose(game_state.get_game_id(), dojo_bridge.DIRECTION_RIGHT)

func _on_continue_pressed() -> void:
	continue_button.disabled = true
	# For single-exit zones, the contract auto-advances on finish().
	# If we're here, it means the zone was already cleared and auto-advanced.
	# Re-pull to catch the updated zone.
	dojo_bridge.pull_entities_snapshot()

func _on_start_fight_pressed() -> void:
	audio_manager.play_sfx("click")
	start_fight_button.disabled = true
	dojo_bridge.start(game_state.get_game_id())

func _on_ui_command(action: String) -> void:
	match action:
		"attack": combat_ctrl.execute_attack()
		"heavy": combat_ctrl.execute_heavy()
		"defend": combat_ctrl.execute_defend()
		"end_turn": combat_ctrl.execute_end_turn()

func _on_attack_pressed() -> void:
	combat_ctrl.execute_attack()

func _on_end_turn_pressed() -> void:
	combat_ctrl.execute_end_turn()

func _on_return_pressed() -> void:
	# Archive current run to history before resetting
	_archive_current_run()
	game_state.reset()
	return_to_menu.emit()

func _unhandled_input(event: InputEvent) -> void:
	if current_state != ArenaState.FIGHTING:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				combat_ctrl.execute_attack()
				get_viewport().set_input_as_handled()
			KEY_2:
				combat_ctrl.execute_heavy()
				get_viewport().set_input_as_handled()
			KEY_3:
				combat_ctrl.execute_defend()
				get_viewport().set_input_as_handled()
			KEY_4:
				combat_ctrl.execute_end_turn()
				get_viewport().set_input_as_handled()
			KEY_TAB:
				arena_ui.cycle_command_focus(1)
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				arena_ui.confirm_selected_command()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				arena_ui.cancel_command_selection()
				get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if minimap_draw != null:
		minimap_draw.queue_redraw()

func _archive_current_run() -> void:
	if game_state.character.is_empty():
		return
	var gid := game_state.get_game_id()
	if gid < 0:
		return
	var status := "In Progress"
	if bool(game_state.dungeon.get("completed", false)):
		status = "Completed"
	elif bool(game_state.dungeon.get("failed", false)):
		status = "Failed"
	elif int(game_state.character.get("health", 0)) <= 0:
		status = "Failed"
	game_state.add_historical_run({
		"game_id": gid,
		"character": game_state.character.duplicate(true),
		"dungeon": game_state.dungeon.duplicate(true),
		"status": status,
	})

# --- Callbacks ---

func _on_state_changed(_data: Dictionary = {}) -> void:
	if combat_ctrl == null or arena_ui == null:
		return
	combat_ctrl.action_in_flight = false
	combat_ctrl.sync_mock_stamina()
	arena_ui.set_turn_state(true, "Your Turn")

	var new_zone := int(game_state.character.get("current_zone", 0))
	if new_zone != room_manager.visual_zone and room_manager.visual_zone >= 0:
		room_manager.contract_zone = new_zone
		room_manager.visual_zone = new_zone
		_reload_room_for_zone(new_zone)

	_refresh()
	var command_panel: PanelContainer = arena_ui.get_command_panel()
	if current_state == ArenaState.FIGHTING and command_panel != null and command_panel.visible:
		var tween := create_tween()
		tween.tween_property(command_panel, "self_modulate", Color(1.2, 1.2, 1.2), 0.1)
		tween.tween_property(command_panel, "self_modulate", Color(1.0, 1.0, 1.0), 0.2)
	arena_ui.update_turn_order()

func _on_tx_submitted(_action: String) -> void:
	if current_state == ArenaState.FIGHTING:
		turn_info.text = "Processing..."
		if arena_ui.turn_status_label != null:
			arena_ui.turn_status_label.text = "Processing..."
	_poll_after_delay(2.0)
	_poll_after_delay(5.0)

var _poll_timers: Array[Timer] = []

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

func _on_tx_failed(action: String, reason: String) -> void:
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
	turn_info.text = short_reason
	if arena_ui.turn_status_label != null:
		arena_ui.turn_status_label.text = short_reason
	push_warning("[arena] TX failed (%s): %s" % [action, reason])
	combat_ctrl.action_in_flight = false
	arena_ui.set_commands_enabled(true)
	arena_ui.set_turn_state(true, "Your Turn")
	start_fight_button.disabled = false
	left_door_button.disabled = false
	right_door_button.disabled = false
	continue_button.disabled = false

# --- Minimap drawing ---

func _draw_minimap() -> void:
	if arena_ui != null:
		arena_ui.draw_minimap()

func _auto_advance_single_exit() -> void:
	_auto_advancing = true
	door_title.text = "Advancing..."
	push_warning("[arena] Auto-advancing from single-exit zone")
	get_tree().create_timer(1.0).timeout.connect(func():
		_auto_advancing = false
		dojo_bridge.pull_entities_snapshot()
	)

func _is_fork(zone_id: int) -> bool:
	var children: Array = ZONE_CHILDREN.get(zone_id, [])
	return children.size() >= 2

func _is_zone_cleared(zone_id: int) -> bool:
	var bitmap := int(game_state.dungeon.get("zones_cleared", 0))
	return (bitmap & (1 << zone_id)) != 0

func _on_room_door_interacted(target_zone: int) -> void:
	audio_manager.play_sfx("click")
	if room_ctrl == null:
		return
	var config: Dictionary = room_ctrl.config
	var current_zone := int(game_state.character.get("current_zone", 0))
	if current_zone == 0 and config.get("is_fork", false):
		var door_configs: Array = config.get("door_configs", [])
		var direction := 0
		for i in range(door_configs.size()):
			if int(door_configs[i].get("target_zone", -1)) == target_zone:
				direction = i
				break
		dojo_bridge.choose(game_state.get_game_id(), direction)

	room_manager.request_transition(target_zone)
	_reload_room_for_zone(target_zone)

func _on_room_battle_triggered() -> void:
	audio_manager.play_sfx("discovery")
	if _player_controller and _player_controller.has_method("disable_movement"):
		_player_controller.disable_movement()
	dojo_bridge.start(game_state.get_game_id())

func _reload_room_for_zone(zone_id: int) -> void:
	if room_ctrl == null:
		return
	var new_config: Dictionary = RoomConfigScript.get_config(zone_id)
	room_ctrl.configure(new_config)
	if _player_controller != null:
		room_ctrl.place_player(_player_controller)
	room_ctrl.spawn_doors()
	_clear_room_battle_trigger()
	if new_config.get("mob_count", 0) > 0 and not _is_zone_cleared(zone_id):
		room_ctrl.create_battle_trigger()
	if dungeon_view and dungeon_view.has_method("on_state_changed"):
		dungeon_view.on_state_changed(current_state, zone_id, -1)

func _clear_room_battle_trigger() -> void:
	if room_ctrl == null:
		return
	var trigger: Node = room_ctrl.get_node_or_null("BattleTrigger")
	if trigger != null:
		trigger.queue_free()

func _sync_room_state_from_arena(state: ArenaState) -> void:
	if room_ctrl == null or room_ctrl.state_machine == null:
		return
	var sm = room_ctrl.state_machine
	match state:
		ArenaState.FORK, ArenaState.PRE_FIGHT:
			sm.transition_to(sm.State.EXPLORING)
		ArenaState.FIGHTING:
			sm.transition_to(sm.State.COMBAT)
		ArenaState.CLEARED:
			sm.transition_to(sm.State.CLEARED)
		ArenaState.COMPLETED:
			sm.transition_to(sm.State.COMPLETED)
		ArenaState.FAILED:
			sm.transition_to(sm.State.FAILED)
