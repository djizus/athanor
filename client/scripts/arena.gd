extends Node3D

signal return_to_menu

enum ArenaState { FORK, PRE_FIGHT, FIGHTING, CLEARED, COMPLETED, FAILED }

const MAX_MOBS := 4
const ZONE_NAMES := ["Entrance", "Left Cavern", "Right Passage", "Deep Hall", "Final Chamber"]
const ZONE_CHILDREN := {0: [1, 2], 1: [3], 2: [3], 3: [4], 4: []}
const ZONE_MOB_COUNT := {0: 0, 1: 1, 2: 1, 3: 2, 4: 4}
const NO_EXIT := 0xFF
const AA_COST := 30
const RoomStateMachine = preload("res://scripts/room_state_machine.gd")
const MINIMAP_POS := {
	0: Vector2(0.5, 0.1),
	1: Vector2(0.2, 0.4),
	2: Vector2(0.8, 0.4),
	3: Vector2(0.5, 0.7),
	4: Vector2(0.5, 0.95),
}

var current_state: ArenaState = ArenaState.FORK
var _room_zone_setup: int = -1

@onready var combat_controller: Node = $CombatController
@onready var arena_ui: Node = $ArenaUI
@onready var dungeon_view: Node3D = $DungeonWorld
@onready var targeting_system: Node3D = $TargetingSystem
@onready var camera_rig: Node3D = $CameraRig

func _ready() -> void:
	game_state.character_updated.connect(_on_state_changed)
	game_state.dungeon_updated.connect(_on_state_changed)
	game_state.fight_updated.connect(_on_state_changed)
	dojo_bridge.tx_submitted.connect(_on_tx_submitted)
	dojo_bridge.tx_failed.connect(_on_tx_failed)

	dojo_bridge.pull_entities_snapshot()

	var player_anchor := get_node_or_null("DungeonWorld/PlayerAnchor")
	if camera_rig and camera_rig.has_method("set_follow_target") and player_anchor:
		camera_rig.set_follow_target(player_anchor)

	# Wire room manager + room controller
	if room_manager != null and not room_manager.room_state_changed.is_connected(_on_room_state_changed):
		room_manager.room_state_changed.connect(_on_room_state_changed)
	if room_manager != null and not room_manager.room_changed.is_connected(_on_room_changed):
		room_manager.room_changed.connect(_on_room_changed)
	var room_ctrl := get_node_or_null("DungeonWorld/RoomTemplate")
	if room_ctrl != null and room_ctrl.has_method("setup_for_zone"):
		room_ctrl.setup_for_zone(0)
		if room_ctrl.has_signal("battle_trigger_hit") and not room_ctrl.battle_trigger_hit.is_connected(_on_battle_trigger_hit):
			room_ctrl.battle_trigger_hit.connect(_on_battle_trigger_hit)
		if room_ctrl.has_signal("door_triggered") and not room_ctrl.door_triggered.is_connected(_on_door_triggered):
			room_ctrl.door_triggered.connect(_on_door_triggered)

	arena_ui.setup(self)
	combat_controller.setup(self, arena_ui)

	_refresh()
	_force_initial_visuals()
	audio_manager.play_music("game_loop_1")
	dojo_bridge._schedule_entity_poll()

func _exit_tree() -> void:
	combat_controller.cleanup_timers()
	if room_manager != null and room_manager.room_state_changed.is_connected(_on_room_state_changed):
		room_manager.room_state_changed.disconnect(_on_room_state_changed)
	if room_manager != null and room_manager.room_changed.is_connected(_on_room_changed):
		room_manager.room_changed.disconnect(_on_room_changed)
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

func _determine_state() -> ArenaState:
	var dungeon := game_state.dungeon
	var character := game_state.character
	var fight := game_state.fight

	if bool(dungeon.get("completed", false)):
		return ArenaState.COMPLETED
	if bool(dungeon.get("failed", false)):
		return ArenaState.FAILED
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

	arena_ui.door_panel.visible = (current_state == ArenaState.FORK or current_state == ArenaState.CLEARED)
	var in_combat := (current_state == ArenaState.FIGHTING)
	if in_combat and not arena_ui.bottom_bar.visible:
		arena_ui._show_combat_hud()
	elif not in_combat and arena_ui.bottom_bar.visible:
		arena_ui._hide_combat_hud()
	arena_ui._set_target_visible(in_combat)
	arena_ui.start_fight_button.visible = (current_state == ArenaState.PRE_FIGHT)
	arena_ui.result_panel.visible = (current_state == ArenaState.COMPLETED or current_state == ArenaState.FAILED)

	var zone_name: String = ZONE_NAMES[zone] if zone < ZONE_NAMES.size() else "Zone %d" % zone
	arena_ui.zone_label.text = "Zone %d — %s" % [zone, zone_name]

	arena_ui.refresh(current_state, zone, game_state.character, game_state.fight, game_state.dungeon)

	match current_state:
		ArenaState.FORK:
			arena_ui.door_title.text = "Choose your path"
			arena_ui.left_door_button.visible = true
			arena_ui.right_door_button.visible = true
			arena_ui.continue_button.visible = false
		ArenaState.CLEARED:
			arena_ui.door_title.text = "Zone cleared!"
			var children: Array = ZONE_CHILDREN.get(zone, [])
			if children.size() == 0:
				arena_ui.door_title.text = "No exit..."
				arena_ui.continue_button.visible = false
			elif children.size() == 1:
				arena_ui.continue_button.visible = false
				arena_ui.left_door_button.visible = false
				arena_ui.right_door_button.visible = false
				if not combat_controller.is_auto_advancing():
					combat_controller._auto_advance_single_exit()
			else:
				arena_ui.left_door_button.visible = true
				arena_ui.right_door_button.visible = true
				arena_ui.continue_button.visible = false
		ArenaState.PRE_FIGHT:
			arena_ui.start_fight_button.text = "Begin Combat"
			arena_ui.start_fight_button.disabled = false
		ArenaState.COMPLETED:
			arena_ui.result_title.text = "Dungeon Cleared!"
		ArenaState.FAILED:
			arena_ui.result_title.text = "You Died"

	if current_state == ArenaState.FIGHTING and not combat_controller.is_auto_finishing():
		if bool(game_state.fight.get("active", false)):
			if combat_controller.first_alive_mob() < 0:
				combat_controller._auto_finish("All mobs defeated!")
			elif int(game_state.character.get("stamina", 0)) < AA_COST:
				combat_controller._auto_finish("Out of stamina — ending turn...")

	if current_state == ArenaState.FIGHTING and targeting_system != null:
		if not targeting_system.active:
			var mob_nodes: Array = []
			for child in dungeon_view.get_node("MobAnchor").get_children():
				if child is AnimatedSprite3D:
					mob_nodes.append(child)
			targeting_system.activate(mob_nodes)
	elif targeting_system != null and targeting_system.active:
		targeting_system.deactivate()

	if current_state != prev_state and dungeon_view != null and dungeon_view.has_method("on_state_changed"):
		dungeon_view.on_state_changed(current_state, zone, prev_state)

	# Keep room controller trigger wiring in sync with active zone.
	var room_ctrl := get_node_or_null("DungeonWorld/RoomTemplate")
	if room_ctrl != null and room_ctrl.has_method("setup_for_zone") and _room_zone_setup != zone:
		_room_zone_setup = zone
		room_ctrl.setup_for_zone(zone)

	# Sync room manager with contract state
	match current_state:
		ArenaState.FIGHTING:
			if not room_manager.is_in_combat():
				room_manager.start_combat()
		ArenaState.CLEARED:
			if room_manager.get_current_room_state() != RoomStateMachine.RoomState.CLEARED:
				room_manager.clear_room()
		ArenaState.FORK, ArenaState.PRE_FIGHT:
			var room_state := room_manager.get_current_room_state()
			if room_manager.visual_zone != zone or (room_state != RoomStateMachine.RoomState.EXPLORING and room_state != RoomStateMachine.RoomState.CLEARED):
				room_manager.enter_room(zone)

	# Handle zone divergence: contract zone advanced ahead of visual zone
	if zone != room_manager.visual_zone:
		room_manager.enter_room(zone)

func _force_initial_visuals() -> void:
	if dungeon_view != null and dungeon_view.has_method("on_state_changed"):
		var zone := int(game_state.character.get("current_zone", 0))
		dungeon_view.on_state_changed(current_state, zone, -1)

func _on_left_door_pressed() -> void:
	combat_controller._on_left_door_pressed()

func _on_right_door_pressed() -> void:
	combat_controller._on_right_door_pressed()

func _on_continue_pressed() -> void:
	combat_controller._on_continue_pressed()

func _on_start_fight_pressed() -> void:
	combat_controller._on_start_fight_pressed()

func _on_attack_pressed() -> void:
	combat_controller._on_attack_pressed()

func _on_end_turn_pressed() -> void:
	combat_controller._on_end_turn_pressed()

func _on_return_pressed() -> void:
	_archive_current_run()
	game_state.reset()
	return_to_menu.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				if current_state == ArenaState.FIGHTING:
					_on_attack_pressed()
			KEY_2:
				if current_state == ArenaState.FIGHTING:
					_on_end_turn_pressed()
			KEY_F:
				if room_manager.is_exploring() or room_manager.get_current_room_state() == RoomStateMachine.RoomState.CLEARED:
					var room := get_node_or_null("DungeonWorld/RoomTemplate")
					if room != null and room.has_method("get_active_door"):
						var door: String = room.get_active_door()
						if not door.is_empty():
							_on_door_triggered(door)

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

func _on_state_changed(_data: Dictionary = {}) -> void:
	combat_controller.on_state_changed()
	_refresh()

func _on_tx_submitted(action: String) -> void:
	combat_controller.on_tx_submitted(action)

func _on_tx_failed(action: String, reason: String) -> void:
	combat_controller.on_tx_failed(action, reason)

func _on_room_state_changed(new_state: int, _old_state: int) -> void:
	var player_anchor := get_node_or_null("DungeonWorld/PlayerAnchor")
	if player_anchor != null and player_anchor.has_method("enable_movement"):
		if room_manager.is_exploring() or new_state == RoomStateMachine.RoomState.CLEARED:
			player_anchor.enable_movement()
		else:
			player_anchor.disable_movement()

	if camera_rig != null:
		if new_state == RoomStateMachine.RoomState.COMBAT:
			if camera_rig.has_method("move_to_battle_position"):
				camera_rig.move_to_battle_position(Vector3.ZERO, 0.5)
			else:
				camera_rig.set_follow_target(null)
				camera_rig.position = Vector3(0, 8, 14)
		elif new_state == RoomStateMachine.RoomState.EXPLORING or new_state == RoomStateMachine.RoomState.CLEARED:
			var pa := get_node_or_null("DungeonWorld/PlayerAnchor")
			if pa != null and camera_rig.has_method("return_to_follow"):
				camera_rig.return_to_follow(pa)
			elif pa != null and camera_rig.has_method("set_follow_target"):
				camera_rig.set_follow_target(pa)

	if new_state == RoomStateMachine.RoomState.CLEARED:
		_reveal_doors()

func _on_room_changed(zone_id: int) -> void:
	_fade_in()
	var zone_name: String = ZONE_NAMES[zone_id] if zone_id < ZONE_NAMES.size() else "Zone %d" % zone_id
	if arena_ui != null and arena_ui.has_method("show_zone_title"):
		arena_ui.show_zone_title("Zone %d\n%s" % [zone_id, zone_name])

func _fade_in() -> void:
	var fade_rect := get_node_or_null("FadeLayer/FadeRect") as ColorRect
	if fade_rect == null:
		return
	fade_rect.color.a = 1.0
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, 0.5).set_ease(Tween.EASE_IN)

func _fade_out(on_complete: Callable = Callable()) -> void:
	var fade_rect := get_node_or_null("FadeLayer/FadeRect") as ColorRect
	if fade_rect == null:
		if on_complete.is_valid():
			on_complete.call()
		return
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)
	if on_complete.is_valid():
		tween.tween_callback(on_complete)

func _on_battle_trigger_hit() -> void:
	if current_state == ArenaState.PRE_FIGHT:
		combat_controller._on_start_fight_pressed()

func _on_door_triggered(door_id: String) -> void:
	if current_state != ArenaState.FORK and current_state != ArenaState.CLEARED:
		return
	match door_id:
		"left":
			combat_controller._on_left_door_pressed()
		"right":
			combat_controller._on_right_door_pressed()
		"north", "south":
			var zone := int(game_state.character.get("current_zone", 0))
			var children: Array = ZONE_CHILDREN.get(zone, [])
			if children.size() > 1:
				if door_id == "north":
					combat_controller._on_left_door_pressed()
				else:
					combat_controller._on_right_door_pressed()
			else:
				combat_controller._on_continue_pressed()

func _reveal_doors() -> void:
	var room := get_node_or_null("DungeonWorld/RoomTemplate")
	if room == null:
		return
	for child in room.get_children():
		if child.name.begins_with("Door") and child is Area3D:
			var marker := child.get_node_or_null("DoorMarker")
			if marker != null:
				marker.visible = true
				marker.scale = Vector3(0.01, 0.01, 0.01)
				var tween := create_tween()
				tween.tween_property(marker, "scale", Vector3.ONE, 0.5).set_ease(Tween.EASE_OUT)

func _draw_minimap() -> void:
	arena_ui._draw_minimap()

func _is_fork(zone_id: int) -> bool:
	var children: Array = ZONE_CHILDREN.get(zone_id, [])
	return children.size() >= 2

func _is_zone_cleared(zone_id: int) -> bool:
	var bitmap := int(game_state.dungeon.get("zones_cleared", 0))
	return (bitmap & (1 << zone_id)) != 0
