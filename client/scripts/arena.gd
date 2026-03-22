extends Node3D

signal return_to_menu

enum ArenaState { FORK, PRE_FIGHT, FIGHTING, CLEARED, COMPLETED, FAILED }

const MAX_MOBS := 4
const ZONE_NAMES := ["Entrance", "Left Cavern", "Right Passage", "Deep Hall", "Final Chamber"]

# Zone graph (mirrors contracts/src/constants.cairo)
const ZONE_CHILDREN := {0: [1, 2], 1: [3], 2: [3], 3: [4], 4: []}
const ZONE_MOB_COUNT := {0: 0, 1: 1, 2: 1, 3: 2, 4: 4}
const NO_EXIT := 0xFF
const AA_COST := 30

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

@onready var dungeon_view: Node3D = $DungeonWorld
@onready var targeting_system: Node3D = $TargetingSystem

func _ready() -> void:
	game_state.character_updated.connect(_on_state_changed)
	game_state.dungeon_updated.connect(_on_state_changed)
	game_state.fight_updated.connect(_on_state_changed)
	dojo_bridge.tx_submitted.connect(_on_tx_submitted)
	dojo_bridge.tx_failed.connect(_on_tx_failed)

	dojo_bridge.pull_entities_snapshot()
	_refresh()
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
	if in_combat and not bottom_bar.visible:
		_show_combat_hud()
	elif not in_combat and bottom_bar.visible:
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
				turn_info.text = "All mobs defeated!"
				attack_button.disabled = true
				end_turn_button.disabled = true
			elif int(game_state.character.get("stamina", 0)) < AA_COST:
				_auto_finish("Out of stamina — ending turn...")

	# Targeting system activation
	if current_state == ArenaState.FIGHTING and targeting_system != null:
		if not targeting_system.active:
			var mob_nodes: Array = []
			for child in dungeon_view.get_node("MobAnchor").get_children():
				if child is AnimatedSprite3D:
					mob_nodes.append(child)
			targeting_system.activate(mob_nodes)
	elif targeting_system != null and targeting_system.active:
		targeting_system.deactivate()

	# 3D visual sync
	if current_state != prev_state and dungeon_view != null and dungeon_view.has_method("on_state_changed"):
		dungeon_view.on_state_changed(current_state, zone, prev_state)

func _update_player_bars() -> void:
	var max_hp := int(game_state.character.get("max_health", 100))
	var hp := int(game_state.character.get("health", 0))
	var max_stamina := int(game_state.character.get("max_stamina", 100))
	var stamina := int(game_state.character.get("stamina", 0))

	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_label.text = "HP %d / %d" % [hp, max_hp]

	stamina_bar.max_value = max_stamina
	stamina_bar.value = stamina
	stamina_label.text = "Stamina %d / %d" % [stamina, max_stamina]

func _show_combat_hud() -> void:
	bottom_bar.modulate.a = 0.0
	bottom_bar.visible = true
	var tween := create_tween()
	tween.tween_property(bottom_bar, "modulate:a", 1.0, 0.3)

func _hide_combat_hud() -> void:
	var tween := create_tween()
	tween.tween_property(bottom_bar, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): bottom_bar.visible = false)

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
	attack_button.disabled = _first_alive_mob() < 0 or int(game_state.character.get("stamina", 0)) < AA_COST
	end_turn_button.disabled = false

func _update_mob_hp_bars() -> void:
	if dungeon_view == null or not dungeon_view.has_method("update_mob_hp"):
		return
	var mob_count := int(game_state.fight.get("mob_count", 0))
	var packed: int = _parse_int(game_state.fight.get("mob_healths", 0))
	for i in range(mob_count):
		dungeon_view.update_mob_hp(i, _unpack_mob_hp(packed, i), 20)

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
	if current_state != ArenaState.FIGHTING:
		return
	var stamina := int(game_state.character.get("stamina", 0))
	if stamina < AA_COST:
		turn_info.text = "Not enough stamina"
		attack_button.disabled = true
		return
	var target := -1
	if targeting_system != null and targeting_system.active and targeting_system.current_target >= 0:
		target = targeting_system.current_target
	if target < 0:
		target = _first_alive_mob()
	if target < 0:
		return
	audio_manager.play_sfx("click")
	attack_button.disabled = true
	turn_info.text = "Attacking..."
	dojo_bridge.cast(game_state.get_game_id(), target, 0)
	if dungeon_view != null and dungeon_view.has_method("play_attack"):
		dungeon_view.play_attack(target)
		var mob_pos: Vector3 = dungeon_view.get_mob_world_position(target) if dungeon_view.has_method("get_mob_world_position") else Vector3.ZERO
		if mob_pos != Vector3.ZERO and dungeon_view.has_method("spawn_damage_number"):
			dungeon_view.spawn_damage_number(mob_pos, int(game_state.character.get("power", 10)))
	var camera_rig := get_node_or_null("CameraRig")
	if camera_rig and camera_rig.has_method("shake"):
		camera_rig.shake(0.15, 0.2)
	var new_stamina := maxi(0, stamina - AA_COST)
	stamina_bar.value = new_stamina
	stamina_label.text = "Stamina %d / %d" % [new_stamina, int(game_state.character.get("max_stamina", 100))]

func _on_end_turn_pressed() -> void:
	if current_state != ArenaState.FIGHTING:
		return
	if not bool(game_state.fight.get("active", false)):
		_refresh()
		return
	audio_manager.play_sfx("click")
	end_turn_button.disabled = true
	turn_info.text = "Ending turn..."
	dojo_bridge.finish(game_state.get_game_id())
	if dungeon_view != null and dungeon_view.has_method("play_mob_turn"):
		dungeon_view.play_mob_turn()
		var player_pos: Vector3 = dungeon_view.get_player_world_position() if dungeon_view.has_method("get_player_world_position") else Vector3.ZERO
		var alive_mobs := 0
		var mob_count := int(game_state.fight.get("mob_count", 0))
		var packed: int = _parse_int(game_state.fight.get("mob_healths", 0))
		for i in range(mob_count):
			if _unpack_mob_hp(packed, i) > 0:
				alive_mobs += 1
		if player_pos != Vector3.ZERO and alive_mobs > 0 and dungeon_view.has_method("spawn_damage_number"):
			dungeon_view.spawn_damage_number(player_pos, alive_mobs * 5)
	var camera_rig := get_node_or_null("CameraRig")
	if camera_rig and camera_rig.has_method("shake"):
		camera_rig.shake(0.25, 0.3)

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
			KEY_1: _on_attack_pressed()
			KEY_2: _on_end_turn_pressed()

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
	_refresh()

func _on_tx_submitted(_action: String) -> void:
	if current_state == ArenaState.FIGHTING:
		turn_info.text = "Processing..."
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
	var short_reason := "TX failed"
	for keyword in ["No active fight", "already cleared", "not active", "invalid"]:
		if keyword.to_lower() in reason.to_lower():
			short_reason = keyword
			break
	if short_reason == "TX failed" and reason.length() > 40:
		short_reason = reason.left(40) + "..."
	elif short_reason == "TX failed":
		short_reason = reason
	turn_info.text = short_reason
	push_warning("[arena] TX failed (%s): %s" % [action, reason])
	attack_button.disabled = false
	end_turn_button.disabled = false
	start_fight_button.disabled = false
	left_door_button.disabled = false
	right_door_button.disabled = false
	continue_button.disabled = false

# --- Minimap drawing ---

func _draw_minimap() -> void:
	if minimap_draw == null:
		return
	var size := minimap_draw.size
	var radius := 10.0

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
		if zone_id == current_zone:
			color = Color(0.831, 0.659, 0.286, 1.0)  # Gold — current
		elif (zones_cleared & (1 << zone_id)) != 0:
			color = Color(0.25, 0.5, 0.3, 1.0)  # Green — cleared
		else:
			color = Color(0.2, 0.2, 0.24, 0.6)  # Dark — locked

		minimap_draw.draw_circle(pos, radius, color)

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
	attack_button.disabled = true
	end_turn_button.disabled = true
	get_tree().create_timer(1.0).timeout.connect(func():
		if current_state == ArenaState.FIGHTING and bool(game_state.fight.get("active", false)):
			dojo_bridge.finish(game_state.get_game_id())
		else:
			dojo_bridge.pull_entities_snapshot()
		_auto_finishing = false
	)

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
