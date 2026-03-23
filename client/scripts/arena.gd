extends Node2D

signal return_to_menu

enum ArenaState { FORK, PRE_FIGHT, FIGHTING, CLEARED, COMPLETED, FAILED }

const MAX_MOBS := 4
const ZONE_NAMES := ["Entrance", "Left Cavern", "Right Passage", "Deep Hall", "Final Chamber"]

# Zone graph (mirrors contracts/src/constants.cairo)
const ZONE_CHILDREN := {0: [1, 2], 1: [3], 2: [3], 3: [4], 4: []}
const ZONE_MOB_COUNT := {0: 0, 1: 1, 2: 1, 3: 2, 4: 4}
const NO_EXIT := 0xFF
const AA_COST := 30
const HEAVY_COST := 50
const TURN_ORDER_SLOTS := 8

# Minimap layout (normalized 0-1 positions for the 5 zones)
const MINIMAP_POS := {
	0: Vector2(0.5, 0.1),
	1: Vector2(0.2, 0.4),
	2: Vector2(0.8, 0.4),
	3: Vector2(0.5, 0.7),
	4: Vector2(0.5, 0.95),
}

# --- Node references ---
@onready var minimap_draw: Control = %MinimapDraw
@onready var hp_bar: ProgressBar = %HPBar
@onready var hp_label: Label = %HPLabel
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var stamina_label: Label = %StaminaLabel
@onready var zone_label: Label = %ZoneLabel
@onready var top_bar: PanelContainer = $UILayer/UIRoot/TopBar
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

@onready var attack_button: Button = %AttackButton
@onready var end_turn_button: Button = %EndTurnButton
@onready var turn_info: Label = %TurnInfo

# Start fight
@onready var start_fight_button: Button = %StartFightButton

# Result panel
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_title: Label = %ResultTitle
@onready var stats_label: Label = %StatsLabel
@onready var return_button: Button = %ReturnButton

var current_state: ArenaState = ArenaState.FORK
var _auto_finishing := false
var _auto_advancing := false
var _action_in_flight := false
var _turn_order_bar: HBoxContainer = null
var _turn_slots: Array[PanelContainer] = []
var _turn_slot_labels: Array[Label] = []
var _is_player_turn := true

var _command_panel: PanelContainer = null
var _cmd_buttons: Dictionary = {}
var _cmd_button_cycle: Array[Button] = []
var _selected_command_index := 0
var _stamina_preview_label: Label = null
var _turn_status_label: Label = null
var _status_icons_label: Label = null
var _mock_stamina := -1
var _defending := false

@onready var dungeon_view: Node2D = $DungeonWorld
@onready var targeting_system: Node2D = $TargetingSystem

func _ready() -> void:
	game_state.character_updated.connect(_on_state_changed)
	game_state.dungeon_updated.connect(_on_state_changed)
	game_state.fight_updated.connect(_on_state_changed)
	dojo_bridge.tx_submitted.connect(_on_tx_submitted)
	dojo_bridge.tx_failed.connect(_on_tx_failed)

	dojo_bridge.pull_entities_snapshot()

	var camera_rig := get_node_or_null("GameCamera")
	var player_anchor := get_node_or_null("DungeonWorld/PlayerAnchor")
	if camera_rig and camera_rig.has_method("set_follow_target") and player_anchor:
		camera_rig.set_follow_target(player_anchor)

	_build_turn_order_bar()
	_build_command_panel()
	set_process(true)

	_refresh()
	_force_initial_visuals()
	audio_manager.play_music("game_loop_1")
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

	# Visibility
	door_panel.visible = (current_state == ArenaState.FORK or current_state == ArenaState.CLEARED)
	var in_combat := (current_state == ArenaState.FIGHTING)
	if in_combat and (_command_panel == null or not _command_panel.visible):
		_show_combat_hud()
	elif not in_combat and _command_panel != null and _command_panel.visible:
		_hide_combat_hud()
	_set_target_visible(in_combat)
	start_fight_button.visible = (current_state == ArenaState.PRE_FIGHT)
	result_panel.visible = (current_state == ArenaState.COMPLETED or current_state == ArenaState.FAILED)

	# Zone label
	var zone_name: String = ZONE_NAMES[zone] if zone < ZONE_NAMES.size() else "Zone %d" % zone
	zone_label.text = "Zone %d — %s" % [zone, zone_name]

	# Player bars
	_update_player_bars()

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
		ArenaState.FIGHTING:
			_update_target_bar()
			_update_mob_hp_bars()
			_update_stamina_display()
			_update_command_states()
		ArenaState.COMPLETED:
			result_title.text = "Dungeon Cleared!"
			_update_stats()
		ArenaState.FAILED:
			result_title.text = "You Died"
			_update_stats()

	# Auto-transitions for fighting state
	if current_state == ArenaState.FIGHTING and not _auto_finishing:
		if bool(game_state.fight.get("active", false)):
			if _first_alive_mob() < 0:
				_auto_finish("All mobs defeated!")
			elif int(game_state.character.get("stamina", 0)) < AA_COST:
				_auto_finish("Out of stamina — ending turn...")

	# Targeting system activation
	if current_state == ArenaState.FIGHTING and targeting_system != null:
		if not targeting_system.active:
			var mob_nodes: Array = []
			for child in dungeon_view.get_node("MobAnchor").get_children():
				if child is AnimatedSprite2D:
					mob_nodes.append(child)
			targeting_system.activate(mob_nodes)
	elif targeting_system != null and targeting_system.active:
		targeting_system.deactivate()

	# 3D visual sync
	if current_state != prev_state and dungeon_view != null and dungeon_view.has_method("on_state_changed"):
		dungeon_view.on_state_changed(current_state, zone, prev_state)

	_update_turn_order()

func _force_initial_visuals() -> void:
	if dungeon_view != null and dungeon_view.has_method("on_state_changed"):
		var zone := int(game_state.character.get("current_zone", 0))
		dungeon_view.on_state_changed(current_state, zone, -1)

func _update_player_bars() -> void:
	var max_hp := int(game_state.character.get("max_health", 100))
	var hp := int(game_state.character.get("health", 0))
	var max_stamina := int(game_state.character.get("max_stamina", 100))
	var stamina := _get_display_stamina() if current_state == ArenaState.FIGHTING else int(game_state.character.get("stamina", 0))

	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_label.text = "HP %d / %d" % [hp, max_hp]

	stamina_bar.max_value = max_stamina
	stamina_bar.value = stamina
	stamina_label.text = "Stamina %d / %d" % [stamina, max_stamina]

func _show_combat_hud() -> void:
	_sync_mock_stamina()
	_set_turn_state(true, "Your Turn")
	if _command_panel != null:
		_command_panel.modulate.a = 0.0
		_command_panel.visible = true
		var tween := create_tween()
		tween.tween_property(_command_panel, "modulate:a", 1.0, 0.3)
	_set_commands_enabled(true)
	_set_selected_command_by_key("attack")
	_update_turn_order()

func _hide_combat_hud() -> void:
	if _command_panel != null:
		var tween := create_tween()
		tween.tween_property(_command_panel, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func(): _command_panel.visible = false)
	_update_turn_order()

func _set_target_visible(vis: bool) -> void:
	target_name.visible = vis
	target_hp_bar.visible = vis
	target_hp_label.visible = vis

func _update_target_bar() -> void:
	var mob_idx := _first_alive_mob()
	if mob_idx < 0:
		target_name.text = ""
		target_hp_bar.value = 0
		target_hp_label.text = ""
		return
	var packed: int = _parse_int(game_state.fight.get("mob_healths", 0))
	var mob_hp := _unpack_mob_hp(packed, mob_idx)
	var max_hp := 20
	target_name.text = _zone_mob_name(int(game_state.character.get("current_zone", 0)))
	target_hp_bar.max_value = max_hp
	target_hp_bar.value = mob_hp
	target_hp_label.text = "%d / %d" % [mob_hp, max_hp]
	_update_command_states()

func _update_mob_hp_bars() -> void:
	if dungeon_view == null:
		return
	var mob_count := int(game_state.fight.get("mob_count", 0))
	var packed: int = _parse_int(game_state.fight.get("mob_healths", 0))
	for i in range(mob_count):
		var hp := _unpack_mob_hp(packed, i)
		if dungeon_view.has_method("update_mob_hp"):
			dungeon_view.update_mob_hp(i, hp, 20)
		if dungeon_view.has_method("update_mob_visual"):
			dungeon_view.update_mob_visual(i, hp, 20)

func _zone_mob_name(zone_id: int) -> String:
	match zone_id:
		1: return "Ember Fiend"
		2: return "Aether Wraith"
		3: return "Sunken Horror"
		4: return "Crystal Guardian"
		_: return "Creature"

func _update_stats() -> void:
	var hp := int(game_state.character.get("health", 0))
	var max_hp := int(game_state.character.get("max_health", 100))
	var zones_cleared := int(game_state.dungeon.get("zones_cleared", 0))
	var cleared_count := 0
	for i in range(5):
		if (zones_cleared & (1 << i)) != 0:
			cleared_count += 1
	stats_label.text = "Zones cleared: %d / 5\nHP remaining: %d / %d" % [cleared_count, hp, max_hp]

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

func _on_attack_pressed() -> void:
	if current_state != ArenaState.FIGHTING or _action_in_flight:
		return
	var stamina := _get_display_stamina()
	if stamina < AA_COST:
		if _turn_status_label != null:
			_turn_status_label.text = "Not enough stamina"
		turn_info.text = "Not enough stamina"
		_update_command_states()
		return
	var target := _get_current_target()
	if target < 0:
		return
	audio_manager.play_sfx("sword_slash")
	_action_in_flight = true
	_set_commands_enabled(false)
	_set_turn_state(true, "Attacking...")
	turn_info.text = "Attacking..."
	dojo_bridge.cast(game_state.get_game_id(), target, 0)
	if dungeon_view != null and dungeon_view.has_method("play_attack"):
		dungeon_view.play_attack(target)
		var mob_pos: Vector2 = dungeon_view.get_mob_world_position(target) if dungeon_view.has_method("get_mob_world_position") else Vector2.ZERO
		if mob_pos != Vector2.ZERO and dungeon_view.has_method("spawn_damage_number"):
			dungeon_view.spawn_damage_number(mob_pos, int(game_state.character.get("power", 10)))
		if mob_pos != Vector2.ZERO and dungeon_view.has_method("play_skill_vfx"):
			dungeon_view.play_skill_vfx("attack", mob_pos)
	var camera_rig := get_node_or_null("GameCamera")
	if camera_rig and camera_rig.has_method("shake"):
		camera_rig.shake(0.15, 0.2)
	_mock_stamina = maxi(0, stamina - AA_COST)
	_update_stamina_display()

func _on_heavy_attack_pressed() -> void:
	if current_state != ArenaState.FIGHTING or _action_in_flight:
		return
	var stamina := _get_display_stamina()
	if stamina < HEAVY_COST:
		if _turn_status_label != null:
			_turn_status_label.text = "Not enough stamina"
		turn_info.text = "Not enough stamina"
		_update_command_states()
		return
	var target := _get_current_target()
	if target < 0:
		return
	audio_manager.play_sfx("heavy_hit")
	_action_in_flight = true
	_set_commands_enabled(false)
	_set_turn_state(true, "Heavy Attack!")
	turn_info.text = "Heavy Attack!"
	dojo_bridge.cast(game_state.get_game_id(), target, 0)
	if dungeon_view != null and dungeon_view.has_method("play_attack"):
		dungeon_view.play_attack(target)
		var mob_pos: Vector2 = dungeon_view.get_mob_world_position(target) if dungeon_view.has_method("get_mob_world_position") else Vector2.ZERO
		if mob_pos != Vector2.ZERO and dungeon_view.has_method("spawn_damage_number"):
			dungeon_view.spawn_damage_number(mob_pos, int(game_state.character.get("power", 10)) * 2, false, true)
		if mob_pos != Vector2.ZERO and dungeon_view.has_method("play_skill_vfx"):
			dungeon_view.play_skill_vfx("heavy", mob_pos)
	var camera_rig := get_node_or_null("GameCamera")
	if camera_rig and camera_rig.has_method("shake"):
		camera_rig.shake(6.0, 8.0)
	_mock_stamina = maxi(0, stamina - HEAVY_COST)
	_update_stamina_display()

func _on_end_turn_pressed() -> void:
	if current_state != ArenaState.FIGHTING or _action_in_flight:
		return
	if not bool(game_state.fight.get("active", false)):
		_refresh()
		return
	audio_manager.play_sfx("click")
	_action_in_flight = true
	_set_commands_enabled(false)
	_set_turn_state(false, "Enemy Turn")
	turn_info.text = "Ending turn..."
	dojo_bridge.finish(game_state.get_game_id())
	if dungeon_view != null and dungeon_view.has_method("play_mob_turn"):
		dungeon_view.play_mob_turn()
		audio_manager.play_sfx("enemy_attack")
		var player_pos: Vector2 = dungeon_view.get_player_world_position() if dungeon_view.has_method("get_player_world_position") else Vector2.ZERO
		var alive_mobs := _count_alive_mobs()
		if player_pos != Vector2.ZERO and alive_mobs > 0 and dungeon_view.has_method("spawn_damage_number"):
			dungeon_view.spawn_damage_number(player_pos, alive_mobs * 5)
	var camera_rig := get_node_or_null("GameCamera")
	if camera_rig and camera_rig.has_method("shake"):
		camera_rig.shake(0.25, 0.3)
	_update_turn_order()

func _on_defend_pressed() -> void:
	if current_state != ArenaState.FIGHTING or _action_in_flight:
		return
	audio_manager.play_sfx("shield_block")
	_defending = true
	_action_in_flight = true
	_set_commands_enabled(false)
	_set_turn_state(false, "Defending...")
	_update_status_icons()
	turn_info.text = "Defending..."
	if dungeon_view != null and dungeon_view.has_method("_play_sprite_anim"):
		var player_sprite := dungeon_view.get("_player_sprite") as AnimatedSprite2D
		dungeon_view._play_sprite_anim(player_sprite, "defend")
	dojo_bridge.finish(game_state.get_game_id())
	if dungeon_view != null and dungeon_view.has_method("play_mob_turn"):
		dungeon_view.play_mob_turn()
		var player_pos_fx: Vector2 = dungeon_view.get_player_world_position() if dungeon_view.has_method("get_player_world_position") else Vector2.ZERO
		if player_pos_fx != Vector2.ZERO and dungeon_view.has_method("play_skill_vfx"):
			dungeon_view.play_skill_vfx("defend", player_pos_fx)
		var player_pos: Vector2 = dungeon_view.get_player_world_position() if dungeon_view.has_method("get_player_world_position") else Vector2.ZERO
		var alive_mobs := _count_alive_mobs()
		var raw_damage := alive_mobs * 5
		var displayed_damage := int(raw_damage / 2)
		if player_pos != Vector2.ZERO and alive_mobs > 0 and dungeon_view.has_method("spawn_damage_number"):
			dungeon_view.spawn_damage_number(player_pos, displayed_damage, false, false, true)
	var camera_rig := get_node_or_null("GameCamera")
	if camera_rig and camera_rig.has_method("shake"):
		camera_rig.shake(2.0, 8.0)
	_update_turn_order()

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
				_on_attack_pressed()
				get_viewport().set_input_as_handled()
			KEY_2:
				_on_heavy_attack_pressed()
				get_viewport().set_input_as_handled()
			KEY_3:
				_on_defend_pressed()
				get_viewport().set_input_as_handled()
			KEY_4:
				_on_end_turn_pressed()
				get_viewport().set_input_as_handled()
			KEY_TAB:
				_cycle_command_focus(1)
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				_confirm_selected_command()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_cancel_command_selection()
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
	_action_in_flight = false
	_sync_mock_stamina()
	_set_turn_state(true, "Your Turn")
	_refresh()
	if current_state == ArenaState.FIGHTING and _command_panel != null and _command_panel.visible:
		var tween := create_tween()
		tween.tween_property(_command_panel, "self_modulate", Color(1.2, 1.2, 1.2), 0.1)
		tween.tween_property(_command_panel, "self_modulate", Color(1.0, 1.0, 1.0), 0.2)
	_update_turn_order()

func _on_tx_submitted(_action: String) -> void:
	if current_state == ArenaState.FIGHTING:
		turn_info.text = "Processing..."
		if _turn_status_label != null:
			_turn_status_label.text = "Processing..."
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
	if _turn_status_label != null:
		_turn_status_label.text = short_reason
	push_warning("[arena] TX failed (%s): %s" % [action, reason])
	_action_in_flight = false
	_set_commands_enabled(true)
	_set_turn_state(true, "Your Turn")
	start_fight_button.disabled = false
	left_door_button.disabled = false
	right_door_button.disabled = false
	continue_button.disabled = false

# --- Minimap drawing ---

func _draw_minimap() -> void:
	if minimap_draw == null:
		return
	var size := minimap_draw.size
	var base_radius := 10.0
	var pulse_t := sin(Time.get_ticks_msec() * 0.003)
	var pulse_radius := lerpf(10.0, 14.0, (pulse_t + 1.0) * 0.5)

	# Draw edges
	for zone_id in ZONE_CHILDREN.keys():
		var from_pos: Vector2 = MINIMAP_POS[zone_id] * size
		var children: Array = ZONE_CHILDREN[zone_id]
		for child_id in children:
			if MINIMAP_POS.has(child_id):
				var to_pos: Vector2 = MINIMAP_POS[child_id] * size
				minimap_draw.draw_line(from_pos, to_pos, Color(0.3, 0.28, 0.22, 0.6), 2.0)

	# Draw nodes
	var current_zone := int(game_state.character.get("current_zone", 0))
	var zones_cleared := int(game_state.dungeon.get("zones_cleared", 0))

	for zone_id in MINIMAP_POS.keys():
		var pos: Vector2 = MINIMAP_POS[zone_id] * size
		var color: Color
		var node_radius := base_radius
		if zone_id == current_zone:
			color = Color(0.831, 0.659, 0.286, 1.0)  # Gold — current
			node_radius = pulse_radius
		elif (zones_cleared & (1 << zone_id)) != 0:
			color = Color(0.3, 0.55, 0.35, 1.0)  # Dim green — cleared
		else:
			color = Color(0.15, 0.15, 0.18, 0.5)  # Dark — locked

		minimap_draw.draw_circle(pos + Vector2(0, 1.0), node_radius + 2.0, Color(0.02, 0.02, 0.02, 0.45))
		minimap_draw.draw_circle(pos, node_radius, color)

		# Zone number
		minimap_draw.draw_string(
			ThemeDB.fallback_font, pos + Vector2(-4, 5),
			str(zone_id), HORIZONTAL_ALIGNMENT_CENTER, -1, 12,
			Color(0.9, 0.9, 0.9, 0.8)
		)

# --- Helpers ---

func _auto_finish(reason: String) -> void:
	if _auto_finishing:
		return
	_auto_finishing = true
	turn_info.text = reason
	if _turn_status_label != null:
		_turn_status_label.text = reason
	_set_commands_enabled(false)
	get_tree().create_timer(1.5).timeout.connect(func():
		_auto_finishing = false
		if current_state == ArenaState.FIGHTING and bool(game_state.fight.get("active", false)):
			dojo_bridge.finish(game_state.get_game_id())
		else:
			dojo_bridge.pull_entities_snapshot()
	)

func _build_turn_order_bar() -> void:
	var ui_root := get_node_or_null("UILayer/UIRoot")
	if ui_root == null:
		return
	_turn_order_bar = HBoxContainer.new()
	_turn_order_bar.name = "TurnOrderBar"
	_turn_order_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_turn_order_bar.position = Vector2(-170, 56)
	_turn_order_bar.add_theme_constant_override("separation", 4)
	for _i in range(TURN_ORDER_SLOTS):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(36, 36)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot.add_child(label)
		_turn_order_bar.add_child(slot)
		_turn_slots.append(slot)
		_turn_slot_labels.append(label)
	ui_root.add_child(_turn_order_bar)

func _build_command_panel() -> void:
	bottom_bar.visible = false
	var ui_root := get_node_or_null("UILayer/UIRoot")
	if ui_root == null:
		return
	_command_panel = PanelContainer.new()
	_command_panel.name = "CommandPanel"
	_command_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_command_panel.offset_top = -96
	_command_panel.offset_bottom = -8
	_command_panel.offset_left = 60
	_command_panel.offset_right = -60

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_command_panel.add_child(hbox)

	var player_info := hp_bar.get_parent().get_parent() as VBoxContainer
	if player_info == null:
		return
	if player_info.get_parent() != null:
		player_info.get_parent().remove_child(player_info)
	player_info.custom_minimum_size = Vector2(260, 0)
	hbox.add_child(player_info)
	_status_icons_label = Label.new()
	_status_icons_label.text = "Status: ⚡ Ready"
	player_info.add_child(_status_icons_label)

	var cmd_center := HBoxContainer.new()
	cmd_center.add_theme_constant_override("separation", 8)
	cmd_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cmd_center.alignment = BoxContainer.ALIGNMENT_CENTER

	_cmd_buttons["attack"] = _create_cmd_button("1 ⚔ Attack", "30 ST", Callable(self, "_on_attack_pressed"), "attack")
	_cmd_buttons["heavy"] = _create_cmd_button("2 ⚡ Heavy", "50 ST", Callable(self, "_on_heavy_attack_pressed"), "heavy")
	_cmd_buttons["defend"] = _create_cmd_button("3 🛡 Defend", "0 ST", Callable(self, "_on_defend_pressed"), "defend")
	_cmd_buttons["end_turn"] = _create_cmd_button("4 ⏭ End Turn", "", Callable(self, "_on_end_turn_pressed"), "end_turn")
	_cmd_button_cycle.clear()
	_cmd_button_cycle.append(_cmd_buttons["attack"] as Button)
	_cmd_button_cycle.append(_cmd_buttons["heavy"] as Button)
	_cmd_button_cycle.append(_cmd_buttons["defend"] as Button)
	_cmd_button_cycle.append(_cmd_buttons["end_turn"] as Button)

	for btn in _cmd_button_cycle:
		cmd_center.add_child(btn)
	hbox.add_child(cmd_center)

	var context := VBoxContainer.new()
	context.custom_minimum_size = Vector2(220, 0)
	context.size_flags_horizontal = Control.SIZE_SHRINK_END
	context.add_theme_constant_override("separation", 4)

	_stamina_preview_label = Label.new()
	_stamina_preview_label.text = ""
	_stamina_preview_label.custom_minimum_size = Vector2(200, 36)
	context.add_child(_stamina_preview_label)

	_turn_status_label = Label.new()
	_turn_status_label.text = "Your Turn"
	_turn_status_label.add_theme_color_override("font_color", Color(0.831, 0.659, 0.286))
	context.add_child(_turn_status_label)

	if turn_info.get_parent() != null:
		turn_info.get_parent().remove_child(turn_info)
	turn_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	turn_info.custom_minimum_size = Vector2(220, 0)
	context.add_child(turn_info)
	hbox.add_child(context)

	ui_root.add_child(_command_panel)
	_command_panel.visible = false

func _create_cmd_button(text: String, cost: String, callback: Callable, key: String) -> Button:
	var btn := Button.new()
	btn.text = text + ("\n" + cost if not cost.is_empty() else "")
	btn.custom_minimum_size = Vector2(118, 60)
	btn.focus_mode = Control.FOCUS_ALL
	btn.pressed.connect(callback)
	btn.mouse_entered.connect(func(): _on_cmd_hover(text, cost))
	btn.mouse_exited.connect(_on_cmd_unhover)
	btn.focus_entered.connect(func(): _set_selected_command_by_key(key))
	return btn

func _set_commands_enabled(enabled: bool) -> void:
	for btn in _cmd_buttons.values():
		if btn is Button:
			(btn as Button).disabled = not enabled
	if enabled:
		_update_command_states()

func _update_command_states() -> void:
	if _cmd_buttons.is_empty():
		return
	var stamina := _get_display_stamina()
	var has_target := _first_alive_mob() >= 0
	(_cmd_buttons.get("attack") as Button).disabled = _action_in_flight or stamina < AA_COST or not has_target
	(_cmd_buttons.get("heavy") as Button).disabled = _action_in_flight or stamina < HEAVY_COST or not has_target
	(_cmd_buttons.get("defend") as Button).disabled = _action_in_flight
	(_cmd_buttons.get("end_turn") as Button).disabled = _action_in_flight

func _on_cmd_hover(name: String, cost: String) -> void:
	if _stamina_preview_label == null:
		return
	if cost.is_empty():
		_stamina_preview_label.text = ""
		_stamina_preview_label.remove_theme_color_override("font_color")
		return
	var cost_val := int(cost.replace(" ST", ""))
	var remaining := _get_display_stamina() - cost_val
	_stamina_preview_label.text = "%s\nCost: %s\nRemaining: %d ST" % [name, cost, maxi(remaining, 0)]
	if remaining < 0:
		_stamina_preview_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		_stamina_preview_label.remove_theme_color_override("font_color")

func _on_cmd_unhover() -> void:
	if _stamina_preview_label == null:
		return
	_stamina_preview_label.text = ""
	_stamina_preview_label.remove_theme_color_override("font_color")

func _set_turn_state(is_player_turn: bool, status_text: String) -> void:
	_is_player_turn = is_player_turn
	if _turn_status_label != null:
		_turn_status_label.text = status_text
		if is_player_turn:
			_turn_status_label.add_theme_color_override("font_color", Color(0.831, 0.659, 0.286))
		else:
			_turn_status_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	if _command_panel != null:
		_command_panel.self_modulate = Color(1.0, 1.0, 1.0) if is_player_turn else Color(0.72, 0.72, 0.72)
	_update_status_icons()
	_update_turn_order()

func _update_turn_order() -> void:
	if _turn_slots.is_empty():
		return
	var alive_mobs := maxi(_count_alive_mobs(), 1)
	var cycle := alive_mobs + 1
	for i in range(_turn_slots.size()):
		var slot := _turn_slots[i]
		var label := _turn_slot_labels[i]
		var is_player := (i % cycle) == 0
		label.text = "P" if is_player else "E"
		var current_index := 0 if _is_player_turn else mini(1, cycle - 1)
		var is_current := i == current_index
		if is_current:
			slot.modulate = Color(0.831, 0.659, 0.286) if _is_player_turn else Color(1.0, 0.3, 0.3)
		else:
			slot.modulate = Color(0.52, 0.52, 0.52)

func _get_display_stamina() -> int:
	if _mock_stamina >= 0:
		return _mock_stamina
	return int(game_state.character.get("stamina", 0))

func _sync_mock_stamina() -> void:
	_mock_stamina = int(game_state.character.get("stamina", 0))
	_defending = false
	_update_status_icons()

func _update_status_icons() -> void:
	if _status_icons_label == null:
		return
	var icons: Array[String] = []
	if _defending:
		icons.append("🛡 Guard")
	icons.append("⚡ Ready" if _is_player_turn else "⏳ Waiting")
	_status_icons_label.text = "Status: %s" % " · ".join(icons)

func _count_alive_mobs() -> int:
	var mob_count := int(game_state.fight.get("mob_count", 0))
	var packed: int = _parse_int(game_state.fight.get("mob_healths", 0))
	var count := 0
	for i in range(mob_count):
		if _unpack_mob_hp(packed, i) > 0:
			count += 1
	return count

func _get_current_target() -> int:
	if targeting_system != null and targeting_system.active and targeting_system.current_target >= 0:
		return targeting_system.current_target
	return _first_alive_mob()

func _update_stamina_display() -> void:
	var stamina := _get_display_stamina()
	var max_st := int(game_state.character.get("max_stamina", 100))
	stamina_bar.max_value = max_st
	stamina_bar.value = stamina
	stamina_label.text = "Stamina %d / %d" % [stamina, max_st]
	_update_command_states()

func _cycle_command_focus(direction: int) -> void:
	if _cmd_button_cycle.is_empty():
		return
	for _attempt in range(_cmd_button_cycle.size()):
		_selected_command_index = wrapi(_selected_command_index + direction, 0, _cmd_button_cycle.size())
		var btn := _cmd_button_cycle[_selected_command_index]
		if is_instance_valid(btn) and not btn.disabled:
			btn.grab_focus()
			break

func _set_selected_command_by_key(key: String) -> void:
	if _cmd_buttons.is_empty() or not _cmd_buttons.has(key):
		return
	var target_btn := _cmd_buttons[key] as Button
	for i in range(_cmd_button_cycle.size()):
		if _cmd_button_cycle[i] == target_btn:
			_selected_command_index = i
			break

func _confirm_selected_command() -> void:
	if _cmd_button_cycle.is_empty():
		return
	var btn := _cmd_button_cycle[_selected_command_index]
	if is_instance_valid(btn) and not btn.disabled:
		btn.emit_signal("pressed")

func _cancel_command_selection() -> void:
	if targeting_system != null and targeting_system.active and targeting_system.has_method("_set_target"):
		targeting_system._set_target(-1)
	if _turn_status_label != null and _is_player_turn:
		_turn_status_label.text = "Your Turn"

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
