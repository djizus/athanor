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

# Door panel
@onready var door_panel: PanelContainer = %DoorPanel
@onready var door_title: Label = %DoorTitle
@onready var left_door_button: Button = %LeftDoorButton
@onready var right_door_button: Button = %RightDoorButton
@onready var continue_button: Button = %ContinueButton

# Fight panel
@onready var fight_panel: PanelContainer = %FightPanel
@onready var fight_title: Label = %FightTitle
@onready var mob_container: VBoxContainer = %MobContainer
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

var mob_rows: Array[HBoxContainer] = []
var current_state: ArenaState = ArenaState.FORK
var _auto_finishing := false
var _auto_advancing := false

@onready var dungeon_view: Node3D = $DungeonWorld

func _ready() -> void:
	game_state.character_updated.connect(_on_state_changed)
	game_state.dungeon_updated.connect(_on_state_changed)
	game_state.fight_updated.connect(_on_state_changed)
	dojo_bridge.tx_submitted.connect(_on_tx_submitted)
	dojo_bridge.tx_failed.connect(_on_tx_failed)

	_build_mob_rows()
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

func _build_mob_rows() -> void:
	for i in range(MAX_MOBS):
		var row := HBoxContainer.new()
		row.name = "MobRow%d" % i

		var label := Label.new()
		label.name = "Name"
		label.custom_minimum_size = Vector2(90, 0)
		label.text = "Mob %d" % i
		row.add_child(label)

		var bar := ProgressBar.new()
		bar.name = "Bar"
		bar.custom_minimum_size = Vector2(200, 22)
		bar.max_value = 20
		bar.show_percentage = false
		bar.theme_type_variation = &"MobBar"
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bar)

		var bar_label := Label.new()
		bar_label.name = "BarLabel"
		bar_label.text = "0 / 20"
		bar_label.theme_type_variation = &"SubtitleLabel"
		bar_label.custom_minimum_size = Vector2(70, 0)
		bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(bar_label)

		mob_container.add_child(row)
		mob_rows.append(row)

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
	fight_panel.visible = (current_state == ArenaState.FIGHTING)
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
			_update_fight_panel()
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

func _update_fight_panel() -> void:
	var zone := int(game_state.character.get("current_zone", 0))
	var zone_name: String = ZONE_NAMES[zone] if zone < ZONE_NAMES.size() else "Zone %d" % zone
	fight_title.text = "%s — Combat" % zone_name

	var mob_count := int(game_state.fight.get("mob_count", 0))
	var packed: int = _parse_int(game_state.fight.get("mob_healths", 0))

	for i in range(MAX_MOBS):
		var row := mob_rows[i]
		row.visible = i < mob_count
		if row.visible:
			var mob_hp := _unpack_mob_hp(packed, i)
			var label: Label = row.get_node("Name")
			var bar: ProgressBar = row.get_node("Bar")
			var bar_label: Label = row.get_node("BarLabel")
			label.text = "Mob %d" % i
			bar.max_value = 20
			bar.value = mob_hp
			bar_label.text = "%d / %d" % [mob_hp, 20]

	attack_button.disabled = _first_alive_mob() < 0 or int(game_state.character.get("stamina", 0)) < AA_COST
	end_turn_button.disabled = false

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
	var target := _first_alive_mob()
	if target < 0:
		return
	audio_manager.play_sfx("click")
	attack_button.disabled = true
	turn_info.text = "Attacking..."
	dojo_bridge.cast(game_state.get_game_id(), target, 0)
	if dungeon_view != null and dungeon_view.has_method("play_attack"):
		dungeon_view.play_attack(target)
	# Optimistic stamina update
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

func _on_return_pressed() -> void:
	# Archive current run to history before resetting
	_archive_current_run()
	game_state.reset()
	return_to_menu.emit()

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
	turn_info.text = "Error: %s" % reason
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
	push_warning("[arena] Auto-finish: %s" % reason)
	get_tree().create_timer(0.8).timeout.connect(func():
		_auto_finishing = false
		if current_state == ArenaState.FIGHTING and bool(game_state.fight.get("active", false)):
			dojo_bridge.finish(game_state.get_game_id())
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
